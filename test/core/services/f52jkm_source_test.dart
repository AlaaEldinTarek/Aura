import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final desktopSvc = File(
    'lib/core/services/desktop_notification_service.dart',
  ).readAsStringSync();
  final prayerProv = File(
    'lib/core/providers/prayer_times_provider.dart',
  ).readAsStringSync();
  final homeScreen = File(
    'lib/features/home/home_screen.dart',
  ).readAsStringSync();
  final startupSvc = File(
    'lib/core/services/windows_startup_service.dart',
  ).readAsStringSync();

  // ── F52j — Desktop timers drift after sleep / today-only ─────────────────

  // T1: digest schedules for NEXT 8:00 AM when today's has passed
  test('T1 F52j: scheduleDailyTaskDigest targets next 8 AM when today\'s is past', () {
    expect(
      desktopSvc,
      contains('todayDigest.isBefore(now)'),
      reason: 'must check if today\'s 8 AM has passed',
    );
    expect(
      desktopSvc,
      contains('add(const Duration(days: 1))'),
      reason: 'must schedule for tomorrow when today\'s 8 AM has passed',
    );
    // Old early-return must be gone
    expect(
      desktopSvc,
      isNot(contains('if (digestTime.isBefore(now)) return;')),
      reason: 'early-return for past 8 AM must be removed',
    );
  });

  // T2: scheduleWirdReminders stores its params for later reschedule
  test('T2 F52j: scheduleWirdReminders stores params in _wirdReminderTimes etc.', () {
    expect(desktopSvc, contains('_wirdReminderTimes'),
        reason: 'stored wird times field must exist');
    expect(desktopSvc, contains('List.unmodifiable(reminderTimes)'),
        reason: 'wird times must be stored as unmodifiable copy');
    expect(desktopSvc, contains('_wirdDailyGoal = dailyGoal'),
        reason: 'wird daily goal must be stored');
    expect(desktopSvc, contains('_wirdIsJuzMode = isJuzMode'),
        reason: 'wird juz mode must be stored');
  });

  // T3: rescheduleAfterWake re-arms wird and digest
  test('T3 F52j: rescheduleAfterWake is defined and re-arms both timers', () {
    expect(desktopSvc, contains('Future<void> rescheduleAfterWake()'),
        reason: 'rescheduleAfterWake method must exist');
    final wakeIdx = desktopSvc.indexOf('Future<void> rescheduleAfterWake()');
    expect(wakeIdx, greaterThan(0));
    final wakeBody = desktopSvc.substring(wakeIdx, wakeIdx + 400);
    expect(wakeBody, contains('scheduleWirdReminders('),
        reason: 'rescheduleAfterWake must call scheduleWirdReminders');
    expect(wakeBody, contains('scheduleDailyTaskDigest('),
        reason: 'rescheduleAfterWake must call scheduleDailyTaskDigest');
  });

  // T3b: prayer_times_provider calls rescheduleAfterWake on wake detection
  test('T3b F52j: prayer_times_provider calls rescheduleAfterWake on sleep/wake', () {
    expect(
      prayerProv,
      contains('rescheduleAfterWake()'),
      reason: 'wake detection block must call DesktopNotificationService.rescheduleAfterWake',
    );
    // Both reschedule calls must be in the same gap-detection block
    final gapIdx = prayerProv.indexOf('gap > const Duration(minutes: 3)');
    expect(gapIdx, greaterThan(0));
    final blockEnd = prayerProv.indexOf('\n      }\n', gapIdx);
    final block = prayerProv.substring(gapIdx, blockEnd > gapIdx ? blockEnd : gapIdx + 500);
    expect(block, contains('rescheduleAfterWake()'));
  });

  // ── F52k — Home countdown stops on desktop focus loss ────────────────────

  // T4: inactive cancel is guarded with !_isDesktop
  test('T4 F52k: inactive lifecycle cancel is guarded with !_isDesktop', () {
    expect(
      homeScreen,
      contains('inactive && !_isDesktop'),
      reason: 'inactive must only cancel on non-desktop',
    );
    // Must NOT unconditionally cancel on inactive
    expect(
      homeScreen,
      isNot(contains('AppLifecycleState.inactive)\n      _countdownTimer?.cancel()')),
      reason: 'unconditional inactive cancel must be removed',
    );
  });

  // T5: paused still cancels the countdown
  test('T5 F52k: paused lifecycle state still cancels the countdown timer', () {
    final lifecycleIdx = homeScreen.indexOf('didChangeAppLifecycleState');
    expect(lifecycleIdx, greaterThan(0));
    final lifecycleBody = homeScreen.substring(lifecycleIdx, lifecycleIdx + 300);
    expect(lifecycleBody, contains('AppLifecycleState.paused'),
        reason: 'paused must still trigger timer cancel');
    expect(lifecycleBody, contains('_countdownTimer?.cancel()'),
        reason: 'cancel must be present in lifecycle handler');
  });

  // ── F52m — "Start with Windows" opt-in ───────────────────────────────────

  // T6: isEnabled() returns false as the default (no pref set)
  test('T6 F52m: WindowsStartupService.isEnabled() defaults to false', () {
    expect(
      startupSvc,
      contains("?? false"),
      reason: 'isEnabled must default to false (opt-in)',
    );
    expect(
      startupSvc,
      isNot(contains("?? true")),
      reason: 'old opt-out default ?? true must be gone',
    );
  });
}
