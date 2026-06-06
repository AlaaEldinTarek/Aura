import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prayer_record.dart';
import '../models/prayer_time.dart';
import '../services/prayer_tracking_service.dart';
import '../utils/prayer_time_rules.dart';
import 'prayer_times_provider.dart';

DateTime _norm(DateTime d) => DateTime(d.year, d.month, d.day);

/// Single source of truth for prayer tracking — all records keyed by date.
///
/// Every surface (home "today" card, Prayer Times page, Prayer Tracking
/// calendar, and the notification Done/Late/Missed buttons) reads from and
/// writes through this one store, so a change in any of them propagates to all
/// the others instantly.
class DailyPrayerStatus {
  /// normalized date → { prayerName → status }
  final Map<DateTime, Map<String, PrayerStatus>> byDate;

  /// The current Islamic day. Between midnight and Fajr it is still yesterday.
  final DateTime effectiveToday;

  final DateTime loadedAt;

  const DailyPrayerStatus({
    this.byDate = const {},
    required this.effectiveToday,
    required this.loadedAt,
  });

  /// Today's (effective Islamic day) statuses — raw. Callers that display today
  /// apply the 20-minute [isPrayerTimeReached] filter themselves.
  Map<String, PrayerStatus> get statuses => byDate[effectiveToday] ?? const {};

  /// Statuses recorded for an arbitrary [date].
  Map<String, PrayerStatus> statusesFor(DateTime date) =>
      byDate[_norm(date)] ?? const {};

  bool get isStale {
    final now = DateTime.now();
    final loadedDay = _norm(loadedAt);
    final today = _norm(now);
    if (loadedDay != today) return true;
    return now.difference(loadedAt).inSeconds > 30;
  }

  DailyPrayerStatus copyWith({
    Map<DateTime, Map<String, PrayerStatus>>? byDate,
    DateTime? effectiveToday,
    DateTime? loadedAt,
  }) {
    return DailyPrayerStatus(
      byDate: byDate ?? this.byDate,
      effectiveToday: effectiveToday ?? this.effectiveToday,
      loadedAt: loadedAt ?? this.loadedAt,
    );
  }
}

class DailyPrayerStatusNotifier extends StateNotifier<DailyPrayerStatus> {
  DailyPrayerStatusNotifier(this._ref)
      : super(DailyPrayerStatus(
          effectiveToday: _norm(DateTime.now()),
          loadedAt: DateTime.fromMillisecondsSinceEpoch(0),
        ));

  final Ref _ref;
  final PrayerTrackingService _trackingService = PrayerTrackingService.instance;

  /// Last known Fajr time — fallback when prayerTimesProvider isn't loaded yet.
  DateTime? _lastFajr;

  List<PrayerTime> get _prayerTimes {
    try {
      return _ref.read(prayerTimesProvider).prayerTimes;
    } catch (_) {
      return const [];
    }
  }

  DateTime? _fajrTime() {
    for (final p in _prayerTimes) {
      if (p.name == 'Fajr') return p.time;
    }
    return _lastFajr;
  }

  /// The current Islamic day. Computed in this ONE place so every surface agrees.
  /// Between midnight and today's Fajr, the active day is still yesterday.
  DateTime computeEffectiveToday() {
    final now = DateTime.now();
    final today = _norm(now);
    final fajr = _fajrTime();
    if (fajr != null && now.isBefore(fajr)) {
      return today.subtract(const Duration(days: 1));
    }
    return today;
  }

  /// Load today's (effective Islamic day) statuses.
  Future<void> load({bool forceRefresh = false, DateTime? fajrTime}) async {
    if (fajrTime != null) _lastFajr = fajrTime;
    final eff = computeEffectiveToday();
    final isEmpty = (state.byDate[eff] ?? const {}).isEmpty;
    if (!forceRefresh && !isEmpty && !state.isStale) {
      if (state.effectiveToday != eff) {
        state = state.copyWith(effectiveToday: eff);
      }
      return;
    }
    await _loadDay(eff, forceRefresh: forceRefresh, effectiveToday: eff);
  }

  Future<void> _loadDay(DateTime date,
      {bool forceRefresh = false, DateTime? effectiveToday}) async {
    try {
      await _trackingService.initialize();
      final userId = getCurrentUserId();
      final summary = await _trackingService.getDailySummary(
        userId: userId,
        date: date,
        forceRefresh: forceRefresh,
      );
      final newByDate =
          Map<DateTime, Map<String, PrayerStatus>>.from(state.byDate);
      newByDate[_norm(date)] = Map<String, PrayerStatus>.from(summary.prayers);
      state = DailyPrayerStatus(
        byDate: newByDate,
        effectiveToday: effectiveToday ?? computeEffectiveToday(),
        loadedAt: DateTime.now(),
      );
    } catch (_) {
      // Keep existing state on error
    }
  }

  /// Load an entire month into the store (used by the Prayer Tracking calendar).
  /// Replaces that month's entries wholesale so a record unmarked on another
  /// device is reflected (and never leaks into a different day).
  Future<void> loadMonth(DateTime month, {bool forceRefresh = false}) async {
    try {
      await _trackingService.initialize();
      if (forceRefresh) _trackingService.clearCache();
      final userId = getCurrentUserId();
      final data =
          await _trackingService.getMonthData(userId: userId, month: month);
      final newByDate =
          Map<DateTime, Map<String, PrayerStatus>>.from(state.byDate);
      newByDate.removeWhere(
          (d, _) => d.year == month.year && d.month == month.month);
      data.forEach((day, summary) {
        newByDate[_norm(day)] = Map<String, PrayerStatus>.from(summary.prayers);
      });
      state = DailyPrayerStatus(
        byDate: newByDate,
        effectiveToday: computeEffectiveToday(),
        loadedAt: DateTime.now(),
      );
    } catch (_) {
      // Keep existing state on error
    }
  }

  /// The ONE write path. Persists to Firestore and updates the store.
  /// Rules (all enforced here, in one place):
  ///  - a future day can never be marked;
  ///  - "today" can only be marked once the prayer's Adhan + 20 min has passed;
  ///  - a past day writes only to that day — it can never touch today.
  Future<bool> markDate(
      DateTime date, String prayerName, PrayerStatus status) async {
    final day = _norm(date);
    final eff = computeEffectiveToday();
    final realToday = _norm(DateTime.now());

    if (day.isAfter(eff)) return false; // future day → blocked
    // The 20-min rule only applies to the ACTUAL calendar today, whose later
    // prayers may not have happened yet. In the after-midnight window the
    // effective day is yesterday — all of its prayers are already in the past,
    // so they must stay markable (don't compare them against today's times).
    if (day == realToday && !isPrayerTimeReached(prayerName, _prayerTimes)) {
      return false;
    }

    final ok = await _trackingService.recordPrayer(
      userId: getCurrentUserId(),
      prayerName: prayerName,
      date: day,
      prayedAt: DateTime.now(),
      status: status,
    );
    if (ok) _setStatus(day, prayerName, status, eff);
    return ok;
  }

  /// The ONE delete path. Removes the record for [date] only.
  Future<bool> unmarkDate(DateTime date, String prayerName) async {
    final day = _norm(date);
    final ok = await _trackingService.deletePrayerRecord(
      userId: getCurrentUserId(),
      prayerName: prayerName,
      date: day,
    );
    if (ok) _removeStatus(day, prayerName);
    return ok;
  }

  /// Mark/unmark for the effective Islamic day (home card + Prayer Times page).
  Future<bool> markToday(String prayerName, PrayerStatus status) =>
      markDate(computeEffectiveToday(), prayerName, status);

  Future<bool> unmarkToday(String prayerName) =>
      unmarkDate(computeEffectiveToday(), prayerName);

  void _setStatus(DateTime day, String prayerName, PrayerStatus status,
      [DateTime? eff]) {
    final newByDate =
        Map<DateTime, Map<String, PrayerStatus>>.from(state.byDate);
    final inner = Map<String, PrayerStatus>.from(newByDate[day] ?? const {});
    inner[prayerName] = status;
    newByDate[day] = inner;
    state = state.copyWith(
      byDate: newByDate,
      effectiveToday: eff ?? state.effectiveToday,
      loadedAt: DateTime.now(),
    );
  }

  void _removeStatus(DateTime day, String prayerName) {
    final newByDate =
        Map<DateTime, Map<String, PrayerStatus>>.from(state.byDate);
    final inner = Map<String, PrayerStatus>.from(newByDate[day] ?? const {});
    inner.remove(prayerName);
    if (inner.isEmpty) {
      newByDate.remove(day);
    } else {
      newByDate[day] = inner;
    }
    state = state.copyWith(byDate: newByDate, loadedAt: DateTime.now());
  }

  /// Optimistic-only update of today's status (no Firestore write).
  /// Used by the notification action handlers, which persist separately.
  void updatePrayer(String prayerName, PrayerStatus status) =>
      _setStatus(computeEffectiveToday(), prayerName, status);

  void removePrayer(String prayerName) =>
      _removeStatus(computeEffectiveToday(), prayerName);
}

final dailyPrayerStatusProvider =
    StateNotifierProvider<DailyPrayerStatusNotifier, DailyPrayerStatus>(
  (ref) => DailyPrayerStatusNotifier(ref),
);
