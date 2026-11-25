import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/utils/number_formatter.dart';

void main() {
  group('F49d NumberFormatter – settings digit formatting', () {
    test('T1: Arabic locale converts digits to Arabic-Indic', () {
      expect(NumberFormatter.withArabicNumeralsByLanguage('20', 'ar'), '٢٠');
    });

    test('T2: withArabicNumerals converts time digits', () {
      expect(NumberFormatter.withArabicNumerals('21:00'), '٢١:٠٠');
    });

    test('T3: English locale leaves digits unchanged', () {
      expect(NumberFormatter.withArabicNumeralsByLanguage('20', 'en'), '20');
    });
  });
}
