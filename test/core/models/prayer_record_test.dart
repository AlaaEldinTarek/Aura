import 'package:aura_app/core/models/prayer_record.dart';
import 'package:flutter_test/flutter_test.dart';

DailyPrayerSummary _summary(Map<String, PrayerStatus> prayers) =>
    DailyPrayerSummary(date: DateTime(2025, 1, 1), prayers: prayers);

void main() {
  group('DailyPrayarSummary.completedCount', () {
    test('all five onTime returns 5', () {
      final s = _summary({
        for (final name in kPrayerNames) name: PrayerStatus.onTime,
      });
      expect(s.completedCount, 5);
    });

    test('one missed returns 4', () {
      final s = _summary({
        'Fajr': PrayerStatus.missed,
        'Zuhr': PrayerStatus.onTime,
        'Asr': PrayerStatus.onTime,
        'Maghrib': PrayerStatus.onTime,
        'Isha': PrayerStatus.onTime,
      });
      expect(s.completedCount, 4);
    });

    test('one excused (historical) returns 4', () {
      final s = _summary({
        'Fajr': PrayerStatus.excused,
        'Zuhr': PrayerStatus.onTime,
        'Asr': PrayerStatus.onTime,
        'Maghrib': PrayerStatus.onTime,
        'Isha': PrayerStatus.onTime,
      });
      expect(s.completedCount, 4);
    });
  });

  group('DailyPrayarSummary.isComplete', () {
    test('returns false when any prayer is excused', () {
      final s = _summary({
        'Fajr': PrayerStatus.excused,
        'Zuhr': PrayerStatus.onTime,
        'Asr': PrayerStatus.onTime,
        'Maghrib': PrayerStatus.onTime,
        'Isha': PrayerStatus.onTime,
      });
      expect(s.isComplete, false);
    });

    test('returns true when all five are onTime or late', () {
      final s = _summary({
        'Fajr': PrayerStatus.onTime,
        'Zuhr': PrayerStatus.late,
        'Asr': PrayerStatus.onTime,
        'Maghrib': PrayerStatus.late,
        'Isha': PrayerStatus.onTime,
      });
      expect(s.isComplete, true);
    });
  });
}
