/// Utility class for formatting numbers with Arabic numerals
class NumberFormatter {
  NumberFormatter._();

  // Arabic numeral characters
  static const Map<String, String> _arabicNumerals = {
    '0': '\u0660', // ٠
    '1': '\u0661', // ١
    '2': '\u0662', // ٢
    '3': '\u0663', // ٣
    '4': '\u0664', // ٤
    '5': '\u0665', // ٥
    '6': '\u0666', // ٦
    '7': '\u0667', // ٧
    '8': '\u0668', // ٨
    '9': '\u0669', // ٩
  };

  /// Convert numbers in a string to Arabic numerals
  static String withArabicNumerals(String text) {
    String result = text;
    _arabicNumerals.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    return result;
  }

  /// Convert numbers in a string to Arabic numerals based on language
  static String withArabicNumeralsByLanguage(String text, String languageCode) {
    if (languageCode == 'ar') {
      return withArabicNumerals(text);
    }
    return text;
  }
}
