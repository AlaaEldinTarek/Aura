import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'desktop_prayer_scheduler.dart';
import 'prayer_alarm_service.dart';

/// Applies a change of the "Reminder Prayer" switch or the lead-time tile.
/// Touches only the pre-prayer reminders, never adhan or post-check alarms.
/// Spec: docs/designs/fix-prayer-reminder.md.
Future<void> applyPreReminderChange({required bool masterEnabled}) async {
  if (kIsWeb) return;
  try {
    if (Platform.isAndroid) {
      if (masterEnabled) {
        await PrayerAlarmService.instance.rearmReminderAlarms();
      } else {
        await PrayerAlarmService.instance.cancelReminderAlarms();
      }
    } else if (DesktopPrayerScheduler.isDesktop) {
      await DesktopPrayerScheduler.instance.rescheduleReminders();
    }
  } catch (e) {
    debugPrint('PreReminder: error applying change - $e');
  }
}
