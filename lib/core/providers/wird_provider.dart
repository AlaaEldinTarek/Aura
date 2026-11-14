import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wird.dart';
import '../models/wird_marker.dart';
import '../services/wird_marker_logic.dart' show kLastQuranPage;
import '../services/wird_marker_service.dart';
import '../services/wird_service.dart';
import 'auth_provider.dart' show authStateProvider;

/// The Wird service. Overridden in tests with a fake.
final wirdServiceProvider = Provider<WirdService>((ref) => WirdService.instance);

/// The color last picked on the Wird start sheet (ARGB, from `Color.toARGB32()`),
/// or null when none was picked yet. Session memory only: nothing is persisted or
/// synced, and it is not part of [WirdState] (spec: docs/designs/wird-marker.md,
/// "Start sheet remembers the color"). It resets when the signed-in uid changes
/// (sign-out, account switch); Reset All Progress invalidates it.
final wirdStartColorProvider = StateProvider<int?>((ref) {
  ref.watch(authStateProvider.select((a) => a.valueOrNull?.uid));
  return null;
});

final quranStatsProvider = FutureProvider.autoDispose<QuranStatsData>((ref) async {
  final wird = ref.watch(wirdServiceProvider);
  final wirdState = ref.watch(wirdStateProvider).valueOrNull ?? const WirdState();
  final results = await Future.wait([
    wird.getWeeklyPageData(),
    wird.getWeeklyJuzData(),
    wird.getBestStreak(),
  ]);
  final weeklyPages = results[0] as List<int>;
  final weeklyJuz = results[1] as List<int>;
  final bestStreak = results[2] as int;
  final totalPages = wirdState.totalPagesRead;
  final totalDays = wirdState.totalDaysCompleted;
  return QuranStatsData(
    weeklyPages: weeklyPages,
    weeklyJuz: weeklyJuz,
    totalPages: totalPages,
    totalDays: totalDays,
    currentStreak: wirdState.streakCount,
    bestStreak: bestStreak,
    averageDaily: totalDays > 0 ? totalPages / totalDays : 0.0,
    khatmCount: wirdState.khatmCount,
    allCompletedJuz: wirdState.allCompletedJuz,
    wirdUnit: wirdState.settings.wirdUnit,
  );
});

final wirdStateProvider =
    StateNotifierProvider<WirdNotifier, AsyncValue<WirdState>>((ref) {
  return WirdNotifier();
});

class WirdNotifier extends StateNotifier<AsyncValue<WirdState>> {
  /// All arguments are optional; the defaults are the production services.
  /// [uid] returns the signed-in uid or null (a guest). When [uid] or [cloud]
  /// is given and [marker] is not, the marker service is built from them.
  WirdNotifier({
    WirdService? wird,
    WirdMarkerService? marker,
    String? Function()? uid,
    WirdMarkerCloud? cloud,
  })  : _wird = wird ?? WirdService.instance,
        _uid = uid ?? _defaultUid,
        _marker = marker ??
            ((uid != null || cloud != null)
                ? WirdMarkerService.forTesting(
                    cloud: cloud ?? FirestoreWirdMarkerCloud(),
                    wird: wird ?? WirdService.instance,
                    uid: uid,
                  )
                : WirdMarkerService.instance),
        super(const AsyncValue.loading()) {
    // One listener, attached here and not in _init (refresh() calls _init again).
    _marker.revision.addListener(_onMarkerRevision);
    _init();
  }

  final WirdService _wird;
  final WirdMarkerService _marker;
  final String? Function() _uid;

  static String? _defaultUid() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return (uid == null || uid == 'guest_user') ? null : uid;
  }

  Future<void> _init() async {
    try {
      // Pull latest from Firestore first (no-op if offline or guest)
      final uid = _uid();
      if (uid != null) {
        await _wird.syncFromFirestore(uid);
      }
      if (!mounted) return;
      final data = await _marker.compose(await _wird.getFullState());
      if (!mounted) return;
      state = AsyncValue.data(data);
      // Marker sync never blocks start-up and never throws.
      unawaited(_marker.syncMarker());
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setDailyPageGoal(int goal) async {
    final current = state.value;
    if (current == null) return;
    final clamped = goal.clamp(1, kLastQuranPage);
    final newSettings = current.settings.copyWith(dailyPageGoal: clamped);
    await _wird.updateSettings(newSettings);
    state = AsyncValue.data(current.copyWith(settings: newSettings));
  }

  Future<void> setReminderTimes(List<String> times) async {
    final current = state.value;
    if (current == null) return;
    final capped = times.length > 10 ? times.sublist(0, 10) : times;
    final newSettings = current.settings.copyWith(reminderTimes: capped);
    await _wird.updateSettings(newSettings);
    state = AsyncValue.data(current.copyWith(settings: newSettings));
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    final newSettings = current.settings.copyWith(remindersEnabled: enabled);
    await _wird.updateSettings(newSettings);
    state = AsyncValue.data(current.copyWith(settings: newSettings));
  }

  Future<void> addReminder(String time) async {
    final current = state.value;
    if (current == null) return;
    if (current.settings.reminderTimes.length >= 10) return;
    final newTimes = [...current.settings.reminderTimes, time];
    await setReminderTimes(newTimes);
  }

  Future<void> removeReminder(int index) async {
    final current = state.value;
    if (current == null) return;
    final newTimes = [...current.settings.reminderTimes]..removeAt(index);
    await setReminderTimes(newTimes);
  }

  Future<void> recordPagesRead(int additionalPages, int currentPage) async {
    await _wird.recordPagesRead(additionalPages, currentPage);
    final updatedState = await _wird.getFullState();
    if (!mounted) return;
    state = AsyncValue.data(updatedState);
  }

  Future<void> markComplete() async {
    await _wird.markDayComplete();
    final updatedState = await _wird.getFullState();
    if (!mounted) return;
    state = AsyncValue.data(updatedState);
  }

  Future<void> undoComplete() async {
    await _wird.undoComplete();
    final updatedState = await _wird.getFullState();
    if (!mounted) return;
    state = AsyncValue.data(updatedState);
  }

  /// Reloads from local storage: the service state composed with the marker
  /// and undo records. Never reads the cloud.
  Future<void> _reload() async {
    final updated = await _marker.compose(await _wird.getFullState());
    if (!mounted) return;
    state = AsyncValue.data(updated);
  }

  void _onMarkerRevision() {
    if (mounted) unawaited(_reload());
  }

  @override
  void dispose() {
    _marker.revision.removeListener(_onMarkerRevision);
    super.dispose();
  }

  // ── Wird marker actions ─────────────────────────────────────────────────

  Future<PlaceOutcome> placeMarker(int page, int color) async {
    final outcome = await _marker.placeMarker(page, color);
    await _reload();
    return outcome;
  }

  Future<MoveOutcome> moveMarker(int target) async {
    final outcome = await _marker.moveMarker(target);
    await _reload();
    return outcome;
  }

  Future<UndoOutcome> undoMove() async {
    final outcome = await _marker.undoMove();
    await _reload();
    return outcome;
  }

  Future<KhatmaOutcome> completeKhatma() async {
    final outcome = await _marker.completeKhatma();
    await _reload();
    return outcome;
  }

  Future<void> restartWird() async {
    await _marker.restartWird();
    await _reload();
  }

  Future<void> refresh() async {
    await _init();
  }

  Future<void> setWirdUnit(WirdUnit unit) async {
    final current = state.value;
    if (current == null) return;
    final newSettings = current.settings.copyWith(wirdUnit: unit);
    await _wird.updateSettings(newSettings);
    state = AsyncValue.data(current.copyWith(settings: newSettings));
  }

  Future<void> setDailyJuzGoal(int goal) async {
    final current = state.value;
    if (current == null) return;
    final clamped = goal.clamp(1, 30);
    final newSettings = current.settings.copyWith(dailyJuzGoal: clamped);
    await _wird.updateSettings(newSettings);
    state = AsyncValue.data(current.copyWith(settings: newSettings));
  }

  Future<void> toggleJuzCompleted(int juzNo) async {
    await _wird.toggleJuzCompleted(juzNo);
    final updatedState = await _marker.compose(await _wird.getFullState());
    if (!mounted) return;
    state = AsyncValue.data(updatedState);
  }

  /// Mark a set of juz from bookmark pages and update counted pages.
  Future<int> markJuzFromBookmarks(Set<int> newJuzNos, Set<int> allBookmarkPages) async {
    final current = state.value;
    if (current == null) return 0;

    // Only mark juz not already completed
    final toMark = newJuzNos.difference(current.allCompletedJuz.toSet());
    for (final juzNo in toMark) {
      await _wird.toggleJuzCompleted(juzNo);
    }

    // Update counted pages so we don't reprocess them
    final updatedCounted = {...current.settings.countedBookmarkPages, ...allBookmarkPages}.toList()..sort();
    final newSettings = current.settings.copyWith(countedBookmarkPages: updatedCounted);
    await _wird.updateSettings(newSettings);

    final updatedState = await _marker.compose(await _wird.getFullState());
    if (!mounted) return toMark.length;
    state = AsyncValue.data(updatedState);
    return toMark.length;
  }

  Future<void> setLinkedBookmarkColor(String colorName, Set<int> initialPages) async {
    await _wird.setLinkedBookmarkColor(colorName, initialPages);
    final updatedState = await _marker.compose(await _wird.getFullState());
    if (!mounted) return;
    state = AsyncValue.data(updatedState);
  }

  /// Sync new bookmark pages. Returns count of newly added pages.
  Future<int> syncBookmarkPages(Set<int> currentBookmarkPages) async {
    final added = await _wird.syncBookmarkPages(currentBookmarkPages);
    if (added > 0) {
      final updatedState = await _marker.compose(await _wird.getFullState());
      if (!mounted) return added;
      state = AsyncValue.data(updatedState);
    }
    return added;
  }

  Future<void> resetAllProgress() async {
    // Wipes streak, totals, history, juz and legacy khatma data, then saves a
    // restarted marker record (a tombstone when there was none).
    await _marker.resetAll();
    final updatedState = await _marker.compose(await _wird.getFullState());
    if (!mounted) return;
    state = AsyncValue.data(updatedState);
  }

  /// Records a khatma, resets the juz grid for a new cycle. Returns the new khatm count.
  Future<int> resetJuzForKhatma() async {
    final count = await _wird.recordKhatma();
    await _wird.resetAllJuz();
    final updatedState = await _marker.compose(await _wird.getFullState());
    if (!mounted) return count;
    state = AsyncValue.data(updatedState);
    return count;
  }

  /// Records a khatma without resetting juz (used for page mode completion). Returns new khatm count.
  Future<int> recordPageKhatma() async {
    final count = await _wird.recordKhatma();
    final updatedState = await _marker.compose(await _wird.getFullState());
    if (!mounted) return count;
    state = AsyncValue.data(updatedState);
    return count;
  }
}
