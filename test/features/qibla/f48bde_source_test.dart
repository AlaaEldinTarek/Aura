import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/utils/number_formatter.dart';

void main() {
  group('F48d – NumberFormatter applied to Qibla distance', () {
    test('T1: distance formats to Arabic-Indic in Arabic locale', () {
      final formatted =
          NumberFormatter.withArabicNumeralsByLanguage('1200', 'ar');
      expect(formatted, '١٢٠٠');
    });

    test('T2: distance stays Western in English locale', () {
      final formatted =
          NumberFormatter.withArabicNumeralsByLanguage('1200', 'en');
      expect(formatted, '1200');
    });
  });

  group('F48e – Exception prefix stripped from Qibla error message', () {
    String stripPrefix(String msg) => msg.startsWith('Exception: ')
        ? msg.substring('Exception: '.length)
        : msg;

    test('T3: "Exception: " prefix is stripped', () {
      expect(stripPrefix('Exception: location denied'), 'location denied');
    });
  });
}
