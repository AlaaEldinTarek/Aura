import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_time.dart';
import 'desktop_adhan_service.dart';
import 'desktop_notification_service.dart';

/// Timer-based prayer scheduler for desktop (replaces native AlarmManager).
/// Schedules adhan playback, pre-prayer reminders, and post-prayer checks.
/// Only active while the app is running — pair with system tray (Phase 5) for background.
class DesktopPrayerScheduler {
  DesktopPrayerScheduler._();
  static final DesktopPrayerScheduler instance = DesktopPrayerScheduler._();

  final List<Timer> _timers = [];

  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Schedule adhan + pre-prayer reminder + post-prayer check timers for all
  /// of today's remaining prayers.
  Future<void> schedulePrayerTimers(List<PrayerTime> prayerTimes) async {
    if (!isDesktop) return;

    cancelAll();

    final prefs = await SharedPreferences.getInstance();
    final reminderMinutes =
        prefs.getInt('notification_reminder_minutes') ?? 10;
    final now = DateTime.now();

    for (final prayer in prayerTimes) {
      if (prayer.name == 'Sunrise') continue;
      if (!prayer.time.isAfter(now)) continue;

      _schedulePrayerTimers(prayer, now, reminderMinutes);
    }

    debugPrint(
        'DesktopPrayerScheduler: ${_timers.length} timers set for today');
  }

  void _schedulePrayerTimers(
      PrayerTime prayer, DateTime now, int reminderMinutes) {
    // Pre-prayer reminder (N minutes before)
    final reminderTime =
        prayer.time.subtract(Duration(minutes: reminderMinutes));
    if (reminderTime.isAfter(now)) {
      final reminderDelay = reminderTime.difference(now);
      _timers.add(Timer(reminderDelay, () async {
        debugPrint(
            '🔔 [DESKTOP] Pre-prayer reminder: ${prayer.name} in $reminderMinutes min');
        await DesktopNotificationService.instance.showPrePrayerNotification(
          prayer.name,
          prayer.nameAr,
          reminderMinutes,
        );
      }));
    }

    // Prayer time — play adhan + show notification
    final prayerDelay = prayer.time.difference(now);
    _timers.add(Timer(prayerDelay, () async {
      debugPrint('🕌 [DESKTOP] Prayer time: ${prayer.name}');
      await Future.wait([
        DesktopAdhanService.instance.playAdhan(prayer.name),
        DesktopNotificationService.instance
            .showPrayerTimeNotification(prayer.name, prayer.nameAr),
      ]);
    }));

    // Post-prayer check (30 min after adhan, or 1 h if no iqama)
    final checkTime = prayer.iqamaTime != null
        ? prayer.iqamaTime!.add(const Duration(minutes: 30))
        : prayer.time.add(const Duration(hours: 1));
    if (checkTime.isAfter(now)) {
      final checkDelay = checkTime.difference(now);
      _timers.add(Timer(checkDelay, () async {
        debugPrint('✅ [DESKTOP] Post-prayer check: ${prayer.name}');
        await DesktopNotificationService.instance
            .showPostPrayerCheck(prayer.name, prayer.nameAr);
      }));
    }
  }

  void cancelAll() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    debugPrint('DesktopPrayerScheduler: All timers cancelled');
  }
}
