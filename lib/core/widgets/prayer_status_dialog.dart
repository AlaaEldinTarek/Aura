import 'package:flutter/material.dart';
import '../models/prayer_record.dart';
import '../constants/app_constants.dart';
import '../theme/app_typography.dart';
/// Reusable dialog for selecting prayer status (On Time / Late / Missed)
/// Returns null if user cancels.
Future<PrayerStatus?> showPrayerStatusDialog({
  required BuildContext context,
  required String prayerName,
  required bool isArabic,
}) {
  return showDialog<PrayerStatus>(
    context: context,
    builder: (dialogContext) {
      final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
      final ts = MediaQuery.textScalerOf(dialogContext);
      return SimpleDialog(
      title: Row(
        children: [
          Icon(Icons.mosque, color: AppConstants.getPrimary(isDark)),
          SizedBox(width: ts.scale(8.0)),
          Expanded(
            child: Text(
              isArabic ? 'تسجيل $prayerName' : 'Record $prayerName',
            ),
          ),
        ],
      ),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, PrayerStatus.onTime),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: ts.scale(12.0)),
              Text(
                isArabic ? 'في الوقت' : 'On Time',
                style: AppTypography.bodyL.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, PrayerStatus.late),
          child: Row(
            children: [
              const Icon(Icons.schedule, color: Colors.orange),
              SizedBox(width: ts.scale(12.0)),
              Text(
                isArabic ? 'متأخر' : 'Late',
                style: AppTypography.bodyL.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, PrayerStatus.excused),
          child: Row(
            children: [
              const Icon(Icons.cancel, color: Colors.red),
              SizedBox(width: ts.scale(12.0)),
              Text(
                isArabic ? 'لم أصلّ' : 'Missed',
                style: AppTypography.bodyL.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
    },
  );
}

/// Reusable confirmation dialog for unmarking a prayer
/// Returns true if user confirms, false or null otherwise.
Future<bool?> showUnmarkConfirmDialog({
  required BuildContext context,
  required String prayerName,
  required bool isArabic,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(isArabic ? 'إلغاء التسجيل' : 'Unmark Prayer'),
      content: Text(
        isArabic
            ? 'هل أنت متأكد من إلغاء تسجيل $prayerName؟'
            : 'Are you sure you want to unmark $prayerName?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(isArabic ? 'لا' : 'No'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(isArabic ? 'نعم، إلغاء' : 'Yes, Unmark'),
        ),
      ],
    ),
  );
}
