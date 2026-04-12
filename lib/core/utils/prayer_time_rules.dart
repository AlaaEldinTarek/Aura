import 'package:flutter/material.dart';
import '../models/prayer_time.dart';
import 'number_formatter.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'يمكنك تسجيل $prayerName بعد $minutesStr دقيقة من وقت الأذان'
                : 'You can mark $prayerName in $minutesLeft minutes (20 min after adhan)',
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }
  }
  return true;
}
