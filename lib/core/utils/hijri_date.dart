/// Accurate Hijri (Islamic) date utility
class HijriDate {
  /// Get Hijri date for a given Gregorian date
  /// Using the most accurate conversion algorithm
  static Map<String, dynamic> toHijri(DateTime date) {
    // Get day, month, year
    final int d = date.day;
    final int m = date.month;
    final int y = date.year;

    // Calculate Julian Day Number for Gregorian date
    int a = (14 - m) ~/ 12;
    int y1 = y + 4800 - a;
    int m1 = m + 12 * a - 3;

    int jd = d + ((153 * m1 + 2) ~/ 5) + 365 * y1 + (y1 ~/ 4) - (y1 ~/ 100) + (y1 ~/ 400) - 32045;

    // Convert Julian Day to Hijri
    // Hijri epoch: July 16, 622 CE (Julian) = JD 1948439.5
    const int hijriEpoch = 1948439;

    // Days since Hijri epoch
    int daysSinceEpoch = jd - hijriEpoch;

    // Calculate Hijri year, month, day
    // Average Hijri year is 354.37 days
    const double yearLength = 354.36667;

    int hYear = (daysSinceEpoch / yearLength).floor() + 1;
    int remainingDays = daysSinceEpoch - ((hYear - 1) * yearLength).floor();

    // Calculate month and day
    // Hijri months alternate: 30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29 (or 30 in leap years)
    // Leap years occur in a 30-year cycle: years 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29

    final int cyclePosition = hYear % 30;
    final bool isLeapYear = [2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29].contains(cyclePosition);

    int hMonth = 1;
    int hDay = remainingDays;

    // Month lengths in a normal year
    final List<int> monthLengths = [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29];

    // Adjust for leap year (Dhu al-Hijjah has 30 days)
    List<int> currentMonthLengths = List.from(monthLengths);
    if (isLeapYear) {
      currentMonthLengths[11] = 30;
    }

    // Find the month and day
    for (int i = 0; i < 12; i++) {
      if (hDay <= currentMonthLengths[i]) {
        hMonth = i + 1;
        break;
      }
      hDay -= currentMonthLengths[i];
    }

    return {
      'year': hYear.toString(),
      'month': hMonth,
      'day': hDay.toString(),
    };
  }

  /// Get Hijri month name in Arabic
  static String getMonthNameAr(int month) {
    const months = [
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الآخر',
      'جمادى الأولى',
      'جمادى الآخرة',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
    ];
    return months[(month - 1) % 12];
  }

  /// Get Hijri month name in English
  static String getMonthNameEn(int month) {
    const months = [
      'Muharram',
      'Safar',
      'Rabi al-Awwal',
      'Rabi al-Thani',
      'Jumada al-Awwal',
      'Jumada al-Thani',
      'Rajab',
      'Shaban',
      'Ramadan',
      'Shawwal',
      'Dhu al-Qadah',
      'Dhu al-Hijjah',
    ];
    return months[(month - 1) % 12];
  }

  /// Format Hijri date in Arabic
  static String formatAr(Map<String, dynamic> hijri) {
    return '${hijri['day']} ${getMonthNameAr(hijri['month'])} ${hijri['year']}';
  }

  /// Format Hijri date in English
  static String formatEn(Map<String, dynamic> hijri) {
    return '${hijri['day']} ${getMonthNameEn(hijri['month'])} ${hijri['year']}';
  }
}
