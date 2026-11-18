import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/utils/pre_prayer_reminder.dart';

void main() {
  group('normalizeReminderMinutes', () {
    test('keeps the four offered values', () {
      for (final v in [5, 10, 15, 30]) {
        expect(normalizeReminderMinutes(v), v);
      }
    });

    test('0, negative, unlisted and null read as 10', () {
      for (final v in [0, -5, 7, 45, 1000]) {
        expect(normalizeReminderMinutes(v), 10);
      }
      expect(normalizeReminderMinutes(null), 10);
    });
  });

  group('reminder text (same strings as the Kotlin builder)', () {
    test('titles', () {
      expect(reminderTitle(isArabic: false), 'Prayer reminder');
      expect(reminderTitle(isArabic: true), 'تذكير بالصلاة');
    });

    test('English body', () {
      expect(
        reminderBody(
            prayerName: 'Zuhr', prayerNameAr: 'الظهر', minutes: 10, isArabic: false),
        'Zuhr in 10 minutes',
      );
    });

    test('Arabic body: Eastern numerals, unit chosen by N', () {
      String ar(int n) => reminderBody(
          prayerName: 'Asr', prayerNameAr: 'العصر', minutes: n, isArabic: true);
      expect(ar(5), 'أذان العصر بعد ٥ دقائق');
      expect(ar(10), 'أذان العصر بعد ١٠ دقائق');
      expect(ar(15), 'أذان العصر بعد ١٥ دقيقة');
      expect(ar(30), 'أذان العصر بعد ٣٠ دقيقة');
    });

    test('a bad N falls back to 10 in the text', () {
      expect(
        reminderBody(
            prayerName: 'Zuhr', prayerNameAr: 'الظهر', minutes: 0, isArabic: false),
        'Zuhr in 10 minutes',
      );
    });
  });

  group('arabicMinuteUnit', () {
    test('5 and 10 are plural, 15 and 30 are singular form', () {
      expect(arabicMinuteUnit(5), 'دقائق');
      expect(arabicMinuteUnit(10), 'دقائق');
      expect(arabicMinuteUnit(15), 'دقيقة');
      expect(arabicMinuteUnit(30), 'دقيقة');
    });
  });
}
