import 'number_formatter.dart';

/// Utility class for date formatting
class DateFormatter {
  DateFormatter._();

  /// Format date to readable string
  static String formatDate(DateTime date, {bool short = false}) {
    if (short) {
      return '${date.day}/${date.month}/${date.year}';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Format date with month name
  static String formatDateWithMonth(DateTime date, String languageCode) {
    final months = languageCode == 'ar' ? _arabicMonths : _englishMonths;
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Get day name
  static String getDayName(DateTime date, String languageCode) {
    final days = languageCode == 'ar' ? _arabicDays : _englishDays;
    return days[date.weekday - 1];
  }

  /// Format time range
  static String formatTimeRange(DateTime start, DateTime end) {
    return '${formatTime(start)} - ${formatTime(end)}';
  }

  /// Format time to 12-hour format with bilingual AM/PM and Arabic numerals
  static String formatTime(DateTime time, {String languageCode = 'en'}) {
    final hour24 = time.hour;
    final hour = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final minute = time.minute.toString().padLeft(2, '0');
    final isArabic = languageCode == 'ar';
    final period = hour24 < 12
        ? (isArabic ? 'ص' : 'AM')
        : (isArabic ? 'م' : 'PM');
    String result = '${hour.toString().padLeft(2, '0')}:$minute $period';
    if (isArabic) {
      result = NumberFormatter.withArabicNumeralsByLanguage(result, 'ar');
    }
    return result;
  }

  /// Format time to 24-hour format with optional Arabic numerals
  static String formatTime24(DateTime time, {String languageCode = 'en'}) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    String result = '$hour:$minute';
    if (languageCode == 'ar') {
      result = NumberFormatter.withArabicNumeralsByLanguage(result, 'ar');
    }
    return result;
  }

  // English months
  static const List<String> _englishMonths = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  // Arabic months
  static const List<String> _arabicMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];

  // English days
  static const List<String> _englishDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  // Arabic days
  static const List<String> _arabicDays = [
    'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'
  ];

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }

  /// Check if date is tomorrow
  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year &&
           date.month == tomorrow.month &&
           date.day == tomorrow.day;
  }

  /// Get relative date string (today, tomorrow, or date)
  static String getRelativeDateString(DateTime date, String languageCode) {
    if (isToday(date)) {
      return languageCode == 'ar' ? 'اليوم' : 'Today';
    }
    if (isTomorrow(date)) {
      return languageCode == 'ar' ? 'غداً' : 'Tomorrow';
    }
    return formatDate(date);
  }
}
