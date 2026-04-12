import 'package:flutter/material.dart';
import '../models/prayer_record.dart';
import '../constants/app_constants.dart';

/// Reusable dialog for selecting prayer status (On Time / Late / Missed)
/// Returns null if user cancels.
Future<PrayerStatus?> showPrayerStatusDialog({
  required BuildContext context,
  required String prayerName,
  required bool isArabic,
}) {
  return showDialog<PrayerStatus>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Row(
        children: [
          Icon(Icons.mosque, color: AppConstants.primaryColor),
          const SizedBox(width: 8),
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
              const SizedBox(width: 12),
              Text(
                isArabic ? 'في الوقت' : 'On Time',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, PrayerStatus.late),
          child: Row(
            children: [
              const Icon(Icons.schedule, color: Colors.orange),
              const SizedBox(width: 12),
              Text(
                isArabic ? 'متأخر' : 'Late',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, PrayerStatus.excused),
          child: Row(
            children: [
              const Icon(Icons.cancel, color: Colors.red),
              const SizedBox(width: 12),
              Text(
                isArabic ? 'لم أصلّ' : 'Missed',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    ),
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
