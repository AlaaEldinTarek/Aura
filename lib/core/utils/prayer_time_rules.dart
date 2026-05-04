import 'package:flutter/material.dart';
import '../models/prayer_time.dart';
import 'number_formatter.dart';

/// Returns the correct prayer date for [now].
/// Islamic prayer day starts at Fajr, so between midnight and Fajr,
/// prayers still belong to the previous day.
DateTime getPrayerDate(DateTime now, {DateTime? fajrTime}) {
  if (fajrTime != null) {
    final todayFajr = DateTime(now.year, now.month, now.day, fajrTime.hour, fajrTime.minute);
    if (now.isBefore(todayFajr)) {
      final yesterday = now.subtract(const Duration(days: 1));
      return DateTime(yesterday.year, yesterday.month, yesterday.day);
    }
  }
  return DateTime(now.year, now.month, now.day);
}

/// Checks the 20-minute rule: user can only mark a prayer 20 minutes after adhan.
/// Returns true if allowed, false if denied (and shows a snackbar).
bool canMarkPrayer({
  required BuildContext context,
  required String prayerName,
  required List<PrayerTime> prayerTimes,
  required bool isArabic,
}) {
  final now = DateTime.now();
  final prayerTime = prayerTimes.where((p) => p.name == prayerName).firstOrNull;

  if (prayerTime != null) {
    final earliestMark = prayerTime.time.add(const Duration(minutes: 20));
    if (now.isBefore(earliestMark)) {
      final remaining = earliestMark.difference(now);
      final minutesLeft = remaining.inMinutes + 1;
      final minutesStr = NumberFormatter.withArabicNumeralsByLanguage('$minutesLeft', isArabic ? 'ar' : 'en');
      final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'يمكنك تسجيل $prayerName بعد $minutesStr دقيقة من وقت الأذان'
                : 'You can mark $prayerName in $minutesLeft minutes (20 min after adhan)',
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange,
          margin: const EdgeInsets.only(bottom: 82, left: 16, right: 16),
        ),
      );
      Future.delayed(const Duration(seconds: 3), snackCtrl.close);
      return false;
    }
  }
  return true;
}

const _prayerNamesAr = {
  'Fajr': 'الفجر',
  'Zuhr': 'الظهر',
  'Dhuhr': 'الظهر',
  'Asr': 'العصر',
  'Maghrib': 'المغرب',
  'Isha': 'العشاء',
  'Sunrise': 'الشروق',
};

/// Returns the localised display name for a prayer, including Jumu'ah on Fridays.
String getPrayerDisplayName(String name, {required bool isArabic}) {
  final isFriday = DateTime.now().weekday == DateTime.friday;
  final isZuhr = name == 'Zuhr' || name == 'Dhuhr';
  if (isFriday && isZuhr) return isArabic ? 'الجمعة' : "Jumu'ah";
  return isArabic ? (_prayerNamesAr[name] ?? name) : name;
}
