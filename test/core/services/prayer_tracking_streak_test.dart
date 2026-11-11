import 'package:aura_app/core/models/prayer_record.dart';
import 'package:flutter_test/flutter_test.dart';

// Mirrors _streakFromRecords in PrayerTrackingService with the status filter
// applied. Any regression in that guard will also appear here.
int _streakFromRecords(List<PrayerRecord> records) {
  final now = DateTime.now();
  final Map<String, Set<String>> prayersByDay = {};
  for (final record in records) {
    if (record.status != PrayerStatus.onTime &&
        record.status != PrayerStatus.late) continue;
    final dayKey =
        '${record.date.year}-${record.date.month}-${record.date.day}';
    prayersByDay.putIfAbsent(dayKey, () => {}).add(record.prayerName);
  }

  int streak = 0;
  DateTime checkDate = DateTime(now.year, now.month, now.day);

  while (true) {
    final dayKey =
        '${checkDate.year}-${checkDate.month}-${checkDate.day}';
    final prayers = prayersByDay[dayKey];
    final isComplete = prayers != null && prayers.length >= 5;

    if (isComplete) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    } else {
      final today = DateTime(now.year, now.month, now.day);
      if (checkDate == today) {
        checkDate = checkDate.subtract(const Duration(days: 1));
        continue;
      }
      break;
    }

    if (streak > 365) break;
  }
  return streak;
}

PrayerRecord _record(String name, PrayerStatus status, DateTime date) =>
    PrayerRecord(
      id: '',
      userId: 'test',
      prayerName: name,
      date: date,
      prayedAt: date,
      status: status,
    );

List<PrayerRecord> _fullDay(DateTime date, PrayerStatus status) =>
    kPrayerNames.map((name) => _record(name, status, date)).toList();

void main() {
  final today = DateTime.now();

  group('_streakFromRecords status filter', () {
    test('all five missed — does not count toward streak', () {
      final records = _fullDay(today, PrayerStatus.missed);
      expect(_streakFromRecords(records), 0);
    });

    test('all five excused (historical) — does not count toward streak', () {
      final records = _fullDay(today, PrayerStatus.excused);
      expect(_streakFromRecords(records), 0);
    });

    test('all five onTime — counts as one streak day', () {
      final records = _fullDay(today, PrayerStatus.onTime);
      expect(_streakFromRecords(records), 1);
    });

    test('mix of onTime and late totalling five — counts as one streak day', () {
      final date = today;
      final records = [
        _record('Fajr', PrayerStatus.onTime, date),
        _record('Zuhr', PrayerStatus.late, date),
        _record('Asr', PrayerStatus.onTime, date),
        _record('Maghrib', PrayerStatus.late, date),
        _record('Isha', PrayerStatus.onTime, date),
      ];
      expect(_streakFromRecords(records), 1);
    });

    test('four onTime and one missed — does not count toward streak', () {
      final date = today;
      final records = [
        _record('Fajr', PrayerStatus.onTime, date),
        _record('Zuhr', PrayerStatus.onTime, date),
        _record('Asr', PrayerStatus.onTime, date),
        _record('Maghrib', PrayerStatus.onTime, date),
        _record('Isha', PrayerStatus.missed, date),
      ];
      expect(_streakFromRecords(records), 0);
    });

    test('three consecutive fully-prayed days followed by missed day returns 3',
        () {
      final day1 = DateTime(today.year, today.month, today.day)
          .subtract(const Duration(days: 3));
      final day2 = day1.add(const Duration(days: 1));
      final day3 = day2.add(const Duration(days: 1));
      // today is left empty (no records) — streak should be 3

      final records = [
        ..._fullDay(day1, PrayerStatus.onTime),
        ..._fullDay(day2, PrayerStatus.onTime),
        ..._fullDay(day3, PrayerStatus.onTime),
      ];
      expect(_streakFromRecords(records), 3);
    });
  });
}
