// Spec: docs/designs/fix-prayer-reminder.md. A tile or switch change re-creates
// only the reminder timers; adhan and post-check timers stay.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aura_app/core/models/prayer_time.dart';
import 'package:aura_app/core/services/desktop_prayer_scheduler.dart';

List<PrayerTime> _times(DateTime now) => [
      PrayerTime(
          name: 'Asr',
          nameAr: 'العصر',
          time: now.add(const Duration(hours: 3))),
      PrayerTime(
          name: 'Isha',
          nameAr: 'العشاء',
          time: now.add(const Duration(hours: 6))),
    ];

void main() {
  final s = DesktopPrayerScheduler.instance;

  setUp(() => s.cancelAll());
  tearDown(() => s.cancelAll());

  test('reminder timers: one per future prayer, default 10 minutes', () async {
    if (!DesktopPrayerScheduler.isDesktop) return;
    SharedPreferences.setMockInitialValues({});
    await s.schedulePrayerTimers(_times(DateTime.now()));
    expect(s.reminderTimerCount, 2);
    expect(s.otherTimerCount, greaterThanOrEqualTo(4)); // adhan + post-check
  });

  test('0 or a bad stored value reads as 10 and still arms', () async {
    if (!DesktopPrayerScheduler.isDesktop) return;
    SharedPreferences.setMockInitialValues(
        {'notification_reminder_minutes': 0});
    await s.schedulePrayerTimers(_times(DateTime.now()));
    expect(s.reminderTimerCount, 2);
  });

  test('master off: no reminder timers, adhan and post-check timers stay',
      () async {
    if (!DesktopPrayerScheduler.isDesktop) return;
    SharedPreferences.setMockInitialValues(
        {'prayer_notifications_enabled': false});
    await s.schedulePrayerTimers(_times(DateTime.now()));
    expect(s.reminderTimerCount, 0);
    expect(s.otherTimerCount, greaterThanOrEqualTo(4));
  });

  test('rescheduleReminders touches only the reminder timers', () async {
    if (!DesktopPrayerScheduler.isDesktop) return;
    SharedPreferences.setMockInitialValues({});
    await s.schedulePrayerTimers(_times(DateTime.now()));
    final others = s.otherTimerCount;
    SharedPreferences.setMockInitialValues(
        {'prayer_notifications_enabled': false});
    await s.rescheduleReminders();
    expect(s.reminderTimerCount, 0);
    expect(s.otherTimerCount, others);
    SharedPreferences.setMockInitialValues(
        {'notification_reminder_minutes': 5});
    await s.rescheduleReminders();
    expect(s.reminderTimerCount, 2);
    expect(s.otherTimerCount, others);
  });
}
