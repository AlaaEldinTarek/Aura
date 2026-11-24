import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'prayer_alarm_service.dart';
import 'shared_preferences_service.dart';

/// F70 P3: called after a confirmed, successful sign-out (spec design step D3).
/// Never throws: each of the four steps runs in its own try-catch so a single
/// failure does not prevent the remaining steps from running.
///
/// Pass injectable overrides in tests; production callers use the defaults.
Future<void> logoutCleanup({
  Future<void> Function()? cancelNativeAlarms,
  Future<void> Function()? cancelPluginNotifications,
  Future<void> Function()? clearThrottle,
  Future<void> Function()? clearGuestFlag,
}) async {
  // 1. Native: cancels every Aura alarm, service, WorkManager job + clears the
  //    Android notification drawer (AlarmCleanup.cancelAll via channel).
  await _step('cancelNativeAlarms',
      cancelNativeAlarms ?? () => PrayerAlarmService.instance.cancelAllAppAlarms());

  // 2. Plugin store: flutter_local_notifications pending queue (C5, C6, C8).
  await _step('cancelPluginNotifications',
      cancelPluginNotifications ?? () => NotificationService.instance.cancelAllNotifications());

  // 3. Clear task-reminder throttle so the next login re-arms task reminders
  //    immediately (the 6-hour debounce would otherwise block re-arming).
  await _step('clearThrottle', clearThrottle ?? _clearThrottle);

  // 4. D1-C residual hole: a stale is_guest=true would keep the native
  //    SessionState gate open after logout. A signed-in user logging out has
  //    no guest session, so clearing is always correct here.
  await _step('clearGuestFlag',
      clearGuestFlag ?? () => SharedPreferencesService.instance.setGuest(false));
}

Future<void> _step(String name, Future<void> Function() fn) async {
  try {
    await fn();
  } catch (e) {
    debugPrint('❌ [LOGOUT] $name failed: $e');
  }
}

Future<void> _clearThrottle() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('task_reminders_rearmed_at');
}
