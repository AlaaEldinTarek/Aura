import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_time.dart';
import '../utils/pre_prayer_reminder.dart';
import 'desktop_adhan_service.dart';
import 'desktop_notification_service.dart';
import 'desktop_tray_service.dart';

/// Payload emitted on [DesktopPrayerScheduler.prayerTimeStream] when a prayer time fires.
class DesktopPrayerEvent {
  final String name;
  final String nameAr;
  const DesktopPrayerEvent(this.name, this.nameAr);
}

/// Timer-based prayer scheduler for desktop (replaces native AlarmManager).
/// Schedules adhan playback, pre-prayer reminders, and post-prayer checks.
/// Only active while the app is running — pair with system tray (Phase 5) for background.
class DesktopPrayerScheduler {
  DesktopPrayerScheduler._();
  static final DesktopPrayerScheduler instance = DesktopPrayerScheduler._();

  final List<Timer> _timers = [];

  /// Pre-prayer reminder timers, kept apart so a tile or switch change can
  /// re-create only these and leave the adhan and post-check timers alone.
  final List<Timer> _reminderTimers = [];
  List<PrayerTime> _lastPrayerTimes = const [];

  @visibleForTesting
  int get reminderTimerCount => _reminderTimers.length;

  @visibleForTesting
  int get otherTimerCount => _timers.length;

  final StreamController<DesktopPrayerEvent> _prayerTimeController =
      StreamController<DesktopPrayerEvent>.broadcast();

  /// Fires when a prayer time is reached — subscribe in MainWrapperScreen
  /// to show the in-app overlay toast.
  Stream<DesktopPrayerEvent> get prayerTimeStream =>
      _prayerTimeController.stream;

  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Schedule adhan + pre-prayer reminder + post-prayer check timers for all
  /// of today's remaining prayers.
  Future<void> schedulePrayerTimers(List<PrayerTime> prayerTimes) async {
    if (!isDesktop) return;

    cancelAll();

    _lastPrayerTimes = prayerTimes;
    final prefs = await SharedPreferences.getInstance();
    final reminderMinutes =
        normalizeReminderMinutes(prefs.getInt(kReminderMinutesKey));
    final reminderOn = prefs.getBool('prayer_notifications_enabled') ?? true;
    final now = DateTime.now();

    for (final prayer in prayerTimes) {
      if (prayer.name == 'Sunrise') continue;
      if (!prayer.time.isAfter(now)) continue;

      _schedulePrayerTimers(prayer, now);
      if (reminderOn) _scheduleReminderTimer(prayer, now, reminderMinutes);
    }

    debugPrint(
        'DesktopPrayerScheduler: ${_timers.length} timers set for today');
  }

  /// Re-create only the pre-prayer reminder timers (tile or switch change).
  /// The adhan and post-prayer check timers are not touched.
  Future<void> rescheduleReminders() async {
    if (!isDesktop) return;
    for (final t in _reminderTimers) {
      t.cancel();
    }
    _reminderTimers.clear();
    final prefs = await SharedPreferences.getInstance();
    final reminderOn = prefs.getBool('prayer_notifications_enabled') ?? true;
    if (!reminderOn) return;
    final minutes = normalizeReminderMinutes(prefs.getInt(kReminderMinutesKey));
    final now = DateTime.now();
    for (final prayer in _lastPrayerTimes) {
      if (prayer.name == 'Sunrise') continue;
      if (!prayer.time.isAfter(now)) continue;
      _scheduleReminderTimer(prayer, now, minutes);
    }
    debugPrint(
        'DesktopPrayerScheduler: ${_reminderTimers.length} reminder timers re-created');
  }

  void _scheduleReminderTimer(
      PrayerTime prayer, DateTime now, int reminderMinutes) {
    final reminderTime =
        prayer.time.subtract(Duration(minutes: reminderMinutes));
    if (!reminderTime.isAfter(now)) return;
    _reminderTimers.add(Timer(reminderTime.difference(now), () async {
      debugPrint(
          '🔔 [DESKTOP] Pre-prayer reminder: ${prayer.name} in $reminderMinutes min');
      await DesktopNotificationService.instance.showPrePrayerNotification(
        prayer.name,
        prayer.nameAr,
        reminderMinutes,
      );
    }));
  }

  void _schedulePrayerTimers(PrayerTime prayer, DateTime now) {
    // Prayer time — play adhan + emit event (in-app overlay) + Windows toast
    final prayerDelay = prayer.time.difference(now);
    _timers.add(Timer(prayerDelay, () async {
      debugPrint('🕌 [DESKTOP] Prayer time: ${prayer.name}');
      _prayerTimeController.add(DesktopPrayerEvent(prayer.name, prayer.nameAr));
      await DesktopNotificationService.instance
          .showAdhanNotification(prayer.name, prayer.nameAr);
      await DesktopTrayService.instance.setAdhanPlaying(true);
      await DesktopAdhanService.instance.playAdhan(prayer.name);
      await DesktopTrayService.instance.setAdhanPlaying(false);
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

  /// Fire a test adhan popup immediately — use via tray menu to verify notifications.
  Future<void> fireTestAdhan() async {
    if (!isDesktop) return;
    _prayerTimeController.add(const DesktopPrayerEvent('Fajr', 'الفجر'));
    await DesktopNotificationService.instance
        .showAdhanNotification('Fajr', 'الفجر');
    await DesktopTrayService.instance.setAdhanPlaying(true);
    await DesktopAdhanService.instance.playAdhan('Fajr');
    await DesktopTrayService.instance.setAdhanPlaying(false);
  }

  void cancelAll() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    for (final t in _reminderTimers) {
      t.cancel();
    }
    _reminderTimers.clear();
    debugPrint('DesktopPrayerScheduler: All timers cancelled');
  }
}
