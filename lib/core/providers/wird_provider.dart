import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wird.dart';
import '../services/wird_service.dart';

final wirdStateProvider =
    StateNotifierProvider<WirdNotifier, AsyncValue<WirdState>>((ref) {
  return WirdNotifier();
});

class WirdNotifier extends StateNotifier<AsyncValue<WirdState>> {
  WirdNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      // Pull latest from Firestore first (no-op if offline or guest)
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await WirdService.instance.syncFromFirestore(uid);
      }
      if (!mounted) return;
      final data = await WirdService.instance.getFullState();
      if (!mounted) return;
      state = AsyncValue.data(data);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setDailyPageGoal(int goal) async {
    final current = state.value;
    if (current == null) return;
    final clamped = goal.clamp(1, 604);
    final newSettings = current.settings.copyWith(dailyPageGoal: clamped);
    await WirdService.instance.updateSettings(newSettings);
    state = AsyncValue.data(current.copyWith(settings: newSettings));
  }

  Future<void> setReminderTimes(List<String> times) async {
    final current = state.value;
    if (current == null) return;
    final capped = times.length > 10 ? times.sublist(0, 10) : times;
    final newSettings = current.settings.copyWith(reminderTimes: capped);
    await WirdService.instance.updateSettings(newSettings);
    state = AsyncValue.data(current.copyWith(settings: newSettings));
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    final newSettings = current.settings.copyWith(remindersEnabled: enabled);
    await WirdService.instance.updateSettings(newSettings);
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
    await WirdService.instance.recordPagesRead(additionalPages, currentPage);
    final updatedState = await WirdService.instance.getFullState();
    if (!mounted) return;
    state = AsyncValue.data(updatedState);
  }

  Future<void> markComplete() async {
    await WirdService.instance.markDayComplete();
    final updatedState = await WirdService.instance.getFullState();
    if (!mounted) return;
    state = AsyncValue.data(updatedState);
  }

  Future<void> undoComplete() async {
    await WirdService.instance.undoComplete();
    final updatedState = await WirdService.instance.getFullState();
    if (!mounted) return;
    state = AsyncValue.data(updatedState);
  }

  Future<void> refresh() async {
    await _init();
  }

  Future<void> setWirdUnit(WirdUnit unit) async {
    final current = state.value;
    if (current == null) return;
    final newSettings = current.settings.copyWith(wirdUnit: unit);
    await WirdService.instance.updateSettings(newSettings);
    state = AsyncValue.data(current.copyWith(settings: newSettings));
  }

  Future<void> setDailyJuzGoal(int goal) async {
    final current = state.value;
    if (current == null) return;
    final clamped = goal.clamp(1, 30);
    final newSettings = current.settings.copyWith(dailyJuzGoal: clamped);
    await WirdService.instance.updateSettings(newSettings);
    state = AsyncValue.data(current.copyWith(settings: newSettings));
  }

  Future<void> toggleJuzCompleted(int juzNo) async {
    await WirdService.instance.toggleJuzCompleted(juzNo);
    final updatedState = await WirdService.instance.getFullState();
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
      await WirdService.instance.toggleJuzCompleted(juzNo);
    }

    // Update counted pages so we don't reprocess them
    final updatedCounted = {...current.settings.countedBookmarkPages, ...allBookmarkPages}.toList()..sort();
    final newSettings = current.settings.copyWith(countedBookmarkPages: updatedCounted);
    await WirdService.instance.updateSettings(newSettings);

    final updatedState = await WirdService.instance.getFullState();
    if (!mounted) return toMark.length;
    state = AsyncValue.data(updatedState);
    return toMark.length;
  }

  Future<void> setLinkedBookmarkColor(String colorName, Set<int> initialPages) async {
    await WirdService.instance.setLinkedBookmarkColor(colorName, initialPages);
    final updatedState = await WirdService.instance.getFullState();
    if (!mounted) return;
    state = AsyncValue.data(updatedState);
  }

  /// Sync new bookmark pages. Returns count of newly added pages.
  Future<int> syncBookmarkPages(Set<int> currentBookmarkPages) async {
    final added = await WirdService.instance.syncBookmarkPages(currentBookmarkPages);
    if (added > 0) {
      final updatedState = await WirdService.instance.getFullState();
      if (!mounted) return added;
      state = AsyncValue.data(updatedState);
    }
    return added;
  }
}
