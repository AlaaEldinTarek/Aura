import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/models/prayer_record.dart';
import 'package:aura_app/core/utils/number_formatter.dart';

void main() {
  group('kPrayerNames', () {
    test('contains exactly 5 prayers', () {
      expect(kPrayerNames.length, 5);
    });

    test('contains expected prayer names in order', () {
      expect(kPrayerNames, ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']);
    });

    test('does not contain Sunrise', () {
      expect(kPrayerNames.contains('Sunrise'), isFalse);
    });
  });

  group('PrayerStatus', () {
    test('has expected values', () {
      expect(PrayerStatus.values.length, 4);
      expect(PrayerStatus.values, contains(PrayerStatus.onTime));
      expect(PrayerStatus.values, contains(PrayerStatus.late));
      expect(PrayerStatus.values, contains(PrayerStatus.missed));
      expect(PrayerStatus.values, contains(PrayerStatus.excused));
    });
  });

  group('PrayerRecord', () {
    test('creates with default values', () {
      final record = PrayerRecord(
        id: 'test-id',
        userId: 'user-1',
        prayerName: 'Fajr',
        date: DateTime(2026, 4, 10),
        prayedAt: DateTime(2026, 4, 10, 5, 30),
      );

      expect(record.id, 'test-id');
      expect(record.userId, 'user-1');
      expect(record.prayerName, 'Fajr');
      expect(record.status, PrayerStatus.onTime);
      expect(record.method, PrayerMethod.congregation);
      expect(record.notes, isNull);
    });

    test('creates with custom status', () {
      final record = PrayerRecord(
        id: 'test-id',
        userId: 'user-1',
        prayerName: 'Dhuhr',
        date: DateTime(2026, 4, 10),
        prayedAt: DateTime(2026, 4, 10, 13, 0),
        status: PrayerStatus.late,
      );

      expect(record.status, PrayerStatus.late);
    });

    test('creates with excused status', () {
      final record = PrayerRecord(
        id: 'test-id',
        userId: 'user-1',
        prayerName: 'Asr',
        date: DateTime(2026, 4, 10),
        prayedAt: DateTime(2026, 4, 10, 16, 0),
        status: PrayerStatus.excused,
      );

      expect(record.status, PrayerStatus.excused);
    });
  });

  group('DailyPrayerSummary', () {
    test('isComplete when all 5 prayers are not missed', () {
      final prayers = {
        for (final name in kPrayerNames) name: PrayerStatus.onTime,
      };
      final summary = DailyPrayerSummary(
        date: DateTime(2026, 4, 10),
        prayers: prayers,
      );

      expect(summary.isComplete, isTrue);
    });

    test('is not complete when any prayer is missed', () {
      final prayers = <String, PrayerStatus>{
        'Fajr': PrayerStatus.onTime,
        'Dhuhr': PrayerStatus.onTime,
        'Asr': PrayerStatus.missed,
        'Maghrib': PrayerStatus.onTime,
        'Isha': PrayerStatus.onTime,
      };
      final summary = DailyPrayerSummary(
        date: DateTime(2026, 4, 10),
        prayers: prayers,
      );

      expect(summary.isComplete, isFalse);
    });

    test('is complete when all prayers are onTime or excused', () {
      // excused is treated as "not missed" — counts toward completion
      final prayers = <String, PrayerStatus>{
        'Fajr': PrayerStatus.onTime,
        'Dhuhr': PrayerStatus.onTime,
        'Asr': PrayerStatus.excused,
        'Maghrib': PrayerStatus.onTime,
        'Isha': PrayerStatus.onTime,
      };
      final summary = DailyPrayerSummary(
        date: DateTime(2026, 4, 10),
        prayers: prayers,
      );

      expect(summary.isComplete, isTrue);
    });
  });

  group('NumberFormatter - Arabic numeral conversion', () {
    test('converts percentages correctly', () {
      expect(
        NumberFormatter.withArabicNumeralsByLanguage('85%', 'ar'),
        '٨٥%',
      );
    });

    test('converts large numbers', () {
      expect(
        NumberFormatter.withArabicNumeralsByLanguage('100', 'ar'),
        '١٠٠',
      );
    });

    test('converts decimal numbers', () {
      expect(
        NumberFormatter.withArabicNumeralsByLanguage('3.5', 'ar'),
        '٣.٥',
      );
    });

    test('handles mixed Arabic text with numbers', () {
      final result = NumberFormatter.withArabicNumeralsByLanguage(
        'يمكنك تسجيل Fajr بعد 5 دقيقة',
        'ar',
      );
      expect(result, contains('٥'));
      expect(result, contains('Fajr'));
    });
  });
}
