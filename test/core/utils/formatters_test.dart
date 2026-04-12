import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/utils/number_formatter.dart';
import 'package:aura_app/core/utils/time_formatter.dart';

void main() {
  group('NumberFormatter', () {
    test('withArabicNumerals converts English numbers to Arabic', () {
      expect(
        NumberFormatter.withArabicNumeralsByLanguage('123', 'ar'),
        '١٢٣',
      );
      expect(
        NumberFormatter.withArabicNumeralsByLanguage('2024', 'ar'),
        '٢٠٢٤',
      );
      expect(
        NumberFormatter.withArabicNumeralsByLanguage('5:30 PM', 'ar'),
        '٥:٣٠ PM',
      );
    });

    test('withArabicNumerals keeps English for non-Arabic locale', () {
      expect(
        NumberFormatter.withArabicNumeralsByLanguage('123', 'en'),
        '123',
      );
      expect(
        NumberFormatter.withArabicNumeralsByLanguage('2024', 'fr'),
        '2024',
      );
    });

    test('withArabicNumerals handles zero', () {
      expect(
        NumberFormatter.withArabicNumeralsByLanguage('0', 'ar'),
        '٠',
      );
    });

    test('withArabicNumerals handles mixed text', () {
      expect(
        NumberFormatter.withArabicNumeralsByLanguage('Prayer at 5:30 PM', 'ar'),
        'Prayer at ٥:٣٠ PM',
      );
    });

    test('withArabicNumerals handles all digits 0-9', () {
      expect(
        NumberFormatter.withArabicNumeralsByLanguage('0123456789', 'ar'),
        '٠١٢٣٤٥٦٧٨٩',
      );
    });

    test('withArabicNumerals handles empty string', () {
      expect(
        NumberFormatter.withArabicNumeralsByLanguage('', 'ar'),
        '',
      );
    });

    test('withArabicNumerals handles string without numbers', () {
      expect(
        NumberFormatter.withArabicNumeralsByLanguage('No numbers here', 'ar'),
        'No numbers here',
      );
    });

    test('converts percentages for stats display', () {
      expect(
        NumberFormatter.withArabicNumeralsByLanguage('85%', 'ar'),
        '٨٥%',
      );
    });

    test('converts streak numbers', () {
      expect(
        NumberFormatter.withArabicNumeralsByLanguage('15', 'ar'),
        '١٥',
      );
    });

    test('converts date format dd/mm/yyyy', () {
      expect(
        NumberFormatter.withArabicNumeralsByLanguage('10/4/2026', 'ar'),
        '١٠/٤/٢٠٢٦',
      );
    });

    test('withArabicNumerals direct method works', () {
      expect(NumberFormatter.withArabicNumerals('42'), '٤٢');
      expect(NumberFormatter.withArabicNumerals('100'), '١٠٠');
    });
  });

  group('TimeFormatter', () {
    test('formatRemaining formats hours and minutes in English', () {
      expect(
        TimeFormatter.formatRemaining(const Duration(hours: 2, minutes: 30), 'en'),
        '2h 30m',
      );
    });

    test('formatRemaining formats single hour and minute in English', () {
      expect(
        TimeFormatter.formatRemaining(const Duration(hours: 1, minutes: 1), 'en'),
        '1h 1m',
      );
    });

    test('formatRemaining formats only minutes in English', () {
      expect(
        TimeFormatter.formatRemaining(const Duration(minutes: 45), 'en'),
        '45m',
      );
    });

    test('formatRemaining formats single minute in English', () {
      expect(
        TimeFormatter.formatRemaining(const Duration(minutes: 1), 'en'),
        '1m',
      );
    });

    test('formatRemaining handles zero duration', () {
      expect(
        TimeFormatter.formatRemaining(const Duration(minutes: 0), 'en'),
        '0s',
      );
    });

    test('formatRemaining handles large durations', () {
      expect(
        TimeFormatter.formatRemaining(const Duration(hours: 23, minutes: 59), 'en'),
        '23h 59m',
      );
    });

    test('formatRemaining handles negative duration', () {
      expect(
        TimeFormatter.formatRemaining(const Duration(minutes: -5), 'en'),
        'Time passed',
      );
    });

    test('formatDuration formats days', () {
      expect(
        TimeFormatter.formatDuration(const Duration(days: 3), 'en'),
        '3d',
      );
    });

    test('formatDuration formats hours', () {
      expect(
        TimeFormatter.formatDuration(const Duration(hours: 5), 'en'),
        '5h',
      );
    });

    test('formatDuration formats minutes', () {
      expect(
        TimeFormatter.formatDuration(const Duration(minutes: 30), 'en'),
        '30m',
      );
    });

    test('formatDuration formats seconds', () {
      expect(
        TimeFormatter.formatDuration(const Duration(seconds: 45), 'en'),
        '45s',
      );
    });

    test('formatTime12h formats correctly for AM', () {
      final time = DateTime(2026, 4, 10, 5, 30);
      expect(TimeFormatter.formatTime12h(time), '5:30 AM');
    });

    test('formatTime12h formats correctly for PM', () {
      final time = DateTime(2026, 4, 10, 14, 30);
      expect(TimeFormatter.formatTime12h(time), '2:30 PM');
    });

    test('formatTime12h formats midnight as 12 AM', () {
      final time = DateTime(2026, 4, 10, 0, 0);
      expect(TimeFormatter.formatTime12h(time), '12:00 AM');
    });

    test('formatTime12h formats noon as 12 PM', () {
      final time = DateTime(2026, 4, 10, 12, 0);
      expect(TimeFormatter.formatTime12h(time), '12:00 PM');
    });

    test('formatTime24h formats correctly', () {
      final time = DateTime(2026, 4, 10, 14, 5);
      expect(TimeFormatter.formatTime24h(time), '14:05');
    });

    test('parseTime parses valid time string', () {
      final result = TimeFormatter.parseTime('14:30');
      expect(result, isNotNull);
      expect(result!.hour, 14);
      expect(result.minute, 30);
    });

    test('parseTime returns null for invalid input', () {
      expect(TimeFormatter.parseTime('invalid'), isNull);
      expect(TimeFormatter.parseTime(''), isNull);
    });
  });
}
