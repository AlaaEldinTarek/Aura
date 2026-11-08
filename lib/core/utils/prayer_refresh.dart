// Pure helpers for the prayer-times refresh in PrayerTimesNotifier (FX-0).
// No Flutter and no platform calls, so they are unit-tested directly
// (test/core/utils/prayer_refresh_test.dart).
import '../models/prayer_settings.dart';
import '../models/prayer_time.dart';

/// Input fingerprint for the prayer-derived side effects.
///
/// Joins today's date, method, madhab, iqama minutes and the epoch ms of every
/// prayer in [days]. Any change in these (method, madhab, iqama, location or a
/// code-level adjustment that moves a time) gives a different string, so the
/// alarms, widgets and native data are refreshed.
String sideEffectsFingerprint({
  required DateTime today,
  required CalculationMethod method,
  required AsrMadhab madhab,
  required Map<String, int> iqama,
  required List<List<PrayerTime>> days,
}) {
  final iqamaKeys = iqama.keys.toList()..sort();
  return [
    '${today.year}-${today.month}-${today.day}',
    method.name,
    madhab.name,
    iqamaKeys.map((k) => '$k:${iqama[k]}').join(','),
    for (final day in days)
      day.map((p) => '${p.name}=${p.time.millisecondsSinceEpoch}').join(','),
  ].join('|');
}

/// The [count] calendar days starting at [now]'s date.
///
/// Uses calendar arithmetic (`DateTime(y, m, d + i)`), not
/// `add(Duration(days: i))`, so a DST change cannot skip or repeat a date.
List<DateTime> cacheDays(DateTime now, {int count = 7}) => [
      for (var i = 0; i < count; i++)
        DateTime(now.year, now.month, now.day + i),
    ];

/// Native cache entries: `cached_{yyyy-MM-dd}_{name}` → epoch ms as string.
///
/// `Zuhr` is written as `dhuhr` (native key). Contract:
/// .project-docs/contracts/prefs-keys.md.
Map<String, String> buildNativeCache(List<(DateTime, List<PrayerTime>)> days) {
  final cache = <String, String>{};
  for (final (d, dayTimes) in days) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final prefix = 'cached_${d.year}-$mm-$dd';
    for (final p in dayTimes) {
      // Native reads "dhuhr"; PrayerTime.name is "Zuhr".
      final n = p.name == 'Zuhr' ? 'dhuhr' : p.name.toLowerCase();
      cache['${prefix}_$n'] = p.time.millisecondsSinceEpoch.toString();
    }
  }
  return cache;
}

/// The next occurrence of each of the five prayers (no Sunrise): today's time
/// if it is after [now], else tomorrow's.
///
/// Scheduling every prayer at its next occurrence replaces the old alarm with
/// the same request code, so no stale alarm stays armed and no cancel is needed.
List<PrayerTime> nextOccurrences(
  List<PrayerTime> today,
  List<PrayerTime> tomorrow,
  DateTime now,
) {
  final result = <PrayerTime>[];
  for (final p in today) {
    if (p.name == 'Sunrise') continue;
    if (p.time.isAfter(now)) {
      result.add(p);
    } else {
      final next = tomorrow.where((t) => t.name == p.name);
      if (next.isNotEmpty) result.add(next.first);
    }
  }
  return result;
}

/// Prayers (no Sunrise) whose post-prayer check (time + 30 min) is still after
/// [now]. Checks already past are not rescheduled; their old alarm is kept.
List<PrayerTime> postChecksToSchedule(
        List<PrayerTime> today, DateTime now) =>
    today
        .where((p) =>
            p.name != 'Sunrise' &&
            p.time.add(const Duration(minutes: 30)).isAfter(now))
        .toList();

/// Write gate for overlapping refresh runs: only the latest run writes.
bool isLatest(int run, int latest) => run == latest;
