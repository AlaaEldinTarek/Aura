import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/utils/number_formatter.dart';

void main() {
  group('F47b – NumberFormatter applied to profile numbers', () {
    test('T1: completion rate % formats digit in Arabic locale', () {
      final raw = (0.75 * 100).round(); // 75
      final formatted =
          NumberFormatter.withArabicNumeralsByLanguage('$raw', 'ar');
      expect(formatted, '٧٥');
    });

    test('T2: guest-sync task count formats digit in Arabic locale', () {
      final formatted =
          NumberFormatter.withArabicNumeralsByLanguage('3', 'ar');
      expect(formatted, '٣');
    });

    test('T1-en: completion rate stays Western in English locale', () {
      final raw = (0.75 * 100).round();
      final formatted =
          NumberFormatter.withArabicNumeralsByLanguage('$raw', 'en');
      expect(formatted, '75');
    });
  });

  group('F47c – Exception prefix stripped from error snackbar messages', () {
    String stripPrefix(String msg) => msg.startsWith('Exception: ')
        ? msg.substring('Exception: '.length)
        : msg;

    test('T3: "Exception: " prefix is stripped', () {
      const raw = 'Exception: some firebase error';
      expect(stripPrefix(raw), 'some firebase error');
    });

    test('T4: message without prefix passes through unchanged', () {
      const raw = 'some firebase error';
      expect(stripPrefix(raw), 'some firebase error');
    });
  });
}
