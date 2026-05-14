import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'desktop_adhan_service.dart';

/// Windows/macOS/Linux notification service using local_notifier.
/// Handles pre-prayer reminders, post-prayer checks, achievement, and task toasts.
/// Prayer-time popups are handled by the in-app overlay in MainWrapperScreen.
class DesktopNotificationService {
  DesktopNotificationService._();
  static final DesktopNotificationService instance =
      DesktopNotificationService._();

  bool _initialized = false;

  // Task reminder timers: taskId → Timer
  final Map<String, Timer> _taskTimers = {};

  // Wird reminder timers
  final List<Timer> _wirdTimers = [];

  // Daily task digest timer
  Timer? _digestTimer;

  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  Future<void> initialize() async {
    if (!isDesktop || _initialized) return;
    try {
      final isMsix = Platform.resolvedExecutable.contains('WindowsApps');
      await localNotifier.setup(
        appName: 'Aura',
        shortcutPolicy:
            isMsix ? ShortcutPolicy.ignore : ShortcutPolicy.requireCreate,
      );
      _initialized = true;
      debugPrint('DesktopNotificationService: Initialized');
    } catch (e) {
      debugPrint('DesktopNotificationService: Init error - $e');
    }
  }

  /// Show an immediate notification (pre-prayer, achievement, task, etc.)
  Future<void> show({
    required String title,
    String? body,
    String? identifier,
  }) async {
    if (!isDesktop) return;
    if (!_initialized) {
      debugPrint('DesktopNotificationService: Not initialized, skipping');
      return;
    }
    try {
      final notification = LocalNotification(
        identifier: identifier,
        title: title,
        body: body,
      );
      await notification.show();
      debugPrint('DesktopNotificationService: Showed "$title"');
    } catch (e) {
      debugPrint('DesktopNotificationService: Error showing notification - $e');
    }
  }

  /// Show prayer-time notification with a Stop Adhan action button.
  Future<void> showPrayerTimeNotification(
      String prayerName, String prayerNameAr) async {
    if (!isDesktop || !_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final isArabic = (prefs.getString('language') ?? 'en') == 'ar';
    final title = isArabic ? prayerNameAr : prayerName;
    final body =
        isArabic ? 'حان موعد صلاة $title' : "It's time for $title prayer";
    try {
      final notification = LocalNotification(
        identifier: 'prayer_$prayerName',
        title: title,
        body: body,
        actions: [
          LocalNotificationAction(
            text: isArabic ? 'إيقاف الأذان' : 'Stop Adhan',
          ),
        ],
      );
      notification.onClickAction = (actionIndex) {
        DesktopAdhanService.instance.stop();
        debugPrint('DesktopNotificationService: Stop Adhan clicked');
      };
      await notification.show();
      debugPrint(
          'DesktopNotificationService: Showed prayer notification "$title"');
    } catch (e) {
      debugPrint(
          'DesktopNotificationService: Error showing prayer notification - $e');
    }
  }

  /// Show pre-prayer reminder notification (X minutes before adhan).
  Future<void> showPrePrayerNotification(
      String prayerName, String prayerNameAr, int minutesBefore) async {
    final prefs = await SharedPreferences.getInstance();
    final masterEnabled =
        prefs.getBool('prayer_notifications_enabled') ?? true;
    if (!masterEnabled) return;
    final perPrayerEnabled =
        prefs.getBool('notify_${prayerName.toLowerCase()}') ?? true;
    if (!perPrayerEnabled) return;

    final isArabic = (prefs.getString('language') ?? 'en') == 'ar';
    final title = isArabic ? prayerNameAr : prayerName;
    final body = isArabic
        ? 'الصلاة بعد $minutesBefore دقائق'
        : 'Prayer in $minutesBefore minutes';
    await show(
        title: title, body: body, identifier: 'pre_prayer_$prayerName');
  }

  /// Show post-prayer check notification ("Did you pray X?").
  Future<void> showPostPrayerCheck(
      String prayerName, String prayerNameAr) async {
    final prefs = await SharedPreferences.getInstance();
    final isArabic = (prefs.getString('language') ?? 'en') == 'ar';
    final prayerLabel = isArabic ? prayerNameAr : prayerName;
    await show(
      title: isArabic ? 'هل صليت $prayerLabel؟' : 'Did you pray $prayerLabel?',
      body: isArabic
          ? 'افتح التطبيق لتسجيل صلاتك'
          : 'Open the app to log your prayer',
      identifier: 'post_check_$prayerName',
    );
  }

  /// Show achievement unlocked notification.
  Future<void> showAchievementNotification(
      String nameEn, String nameAr, String emoji, bool isArabic) async {
    final title =
        isArabic ? '$emoji إنجاز جديد!' : '$emoji Achievement Unlocked!';
    final body = isArabic ? nameAr : nameEn;
    await show(title: title, body: body, identifier: 'achievement_$nameEn');
  }

  /// Show task reminder notification.
  Future<void> showTaskNotification({
    required String taskId,
    required String title,
    required String body,
  }) async {
    await show(title: title, body: body, identifier: 'task_$taskId');
  }

  /// Show Wird (daily Quran reading) reminder.
  Future<void> showWirdReminder(
      int dailyGoal, bool isArabic, bool isJuzMode) async {
    final t = isArabic ? 'تذكير الورد' : 'Wird Reminder';
    final b = isArabic
        ? (isJuzMode
            ? 'اقرأ وردك اليومي'
            : 'اقرأ وردك اليومي — $dailyGoal صفحة')
        : (isJuzMode
            ? 'Read your daily Wird'
            : 'Read your daily Wird — $dailyGoal pages');
    await show(title: t, body: b, identifier: 'wird_reminder');
  }

  // ─── Task Reminder Scheduling ─────────────────────────────────────────────

  /// Schedule a timer-based task reminder (desktop equivalent of zonedSchedule).
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required DateTime dueDate,
    bool hasDueTime = false,
    String language = 'en',
  }) async {
    if (!isDesktop) return;

    final isArabic = language == 'ar';
    final now = DateTime.now();
    DateTime reminderTime;
    String body;

    if (hasDueTime) {
      final prefs = await SharedPreferences.getInstance();
      final reminderMinutes = prefs.getInt('task_reminder_minutes') ?? 30;
      final reminderBefore =
          dueDate.subtract(Duration(minutes: reminderMinutes));
      reminderTime = reminderBefore.isAfter(now) ? reminderBefore : dueDate;
      body = isArabic
          ? (reminderBefore.isAfter(now)
              ? 'موعد المهمة بعد $reminderMinutes دقيقة'
              : 'حان موعد المهمة الآن')
          : (reminderBefore.isAfter(now)
              ? 'Task due in $reminderMinutes minutes'
              : 'Task is due now');
    } else {
      reminderTime =
          DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);
      body =
          isArabic ? 'لديك مهمة مستحقة اليوم' : 'You have a task due today';
    }

    final delay = reminderTime.difference(now);
    if (delay <= Duration.zero) {
      debugPrint(
          'DesktopNotificationService: Task reminder time already passed for "$title"');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('task_notifications_enabled') ?? true)) return;

    _taskTimers[taskId]?.cancel();
    _taskTimers[taskId] = Timer(delay, () {
      showTaskNotification(taskId: taskId, title: title, body: body);
      _taskTimers.remove(taskId);
    });
    debugPrint(
        'DesktopNotificationService: Task reminder "$title" in ${delay.inMinutes} min');
  }

  /// Cancel task reminder timer.
  void cancelTaskReminder(String taskId) {
    _taskTimers[taskId]?.cancel();
    _taskTimers.remove(taskId);
    debugPrint('DesktopNotificationService: Cancelled task reminder $taskId');
  }

  // ─── Wird Reminder Scheduling ─────────────────────────────────────────────

  /// Schedule timer-based Wird reminders for today's remaining configured times.
  Future<void> scheduleWirdReminders({
    required List<String> reminderTimes,
    required int dailyGoal,
    bool isJuzMode = false,
  }) async {
    if (!isDesktop) return;
    cancelWirdReminders();

    final prefs = await SharedPreferences.getInstance();
    final isArabic = (prefs.getString('language') ?? 'en') == 'ar';
    final now = DateTime.now();

    for (final timeStr in reminderTimes) {
      final parts = timeStr.split(':');
      if (parts.length < 2) continue;
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;

      final scheduled =
          DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduled.isBefore(now)) continue;

      final delay = scheduled.difference(now);
      _wirdTimers.add(Timer(delay, () {
        showWirdReminder(dailyGoal, isArabic, isJuzMode);
      }));
    }
    debugPrint(
        'DesktopNotificationService: ${_wirdTimers.length} Wird timers set');
  }

  /// Cancel all Wird reminder timers.
  void cancelWirdReminders() {
    for (final t in _wirdTimers) {
      t.cancel();
    }
    _wirdTimers.clear();
  }

  // ─── Daily Task Digest ────────────────────────────────────────────────────

  /// Schedule a timer-based daily task digest at 8:00 AM (if not yet past).
  Future<void> scheduleDailyTaskDigest(
      int todayCount, int overdueCount) async {
    if (!isDesktop) return;
    _digestTimer?.cancel();
    _digestTimer = null;

    final now = DateTime.now();
    final digestTime =
        DateTime(now.year, now.month, now.day, 8, 0);
    if (digestTime.isBefore(now)) return;

    final delay = digestTime.difference(now);
    _digestTimer = Timer(delay, () {
      _showDailyTaskDigest(todayCount, overdueCount);
      _digestTimer = null;
    });
    debugPrint(
        'DesktopNotificationService: Daily task digest timer set (in ${delay.inMinutes} min)');
  }

  Future<void> _showDailyTaskDigest(
      int todayCount, int overdueCount) async {
    final prefs = await SharedPreferences.getInstance();
    final isArabic = (prefs.getString('language') ?? 'en') == 'ar';
    final title = isArabic ? 'ملخص مهامك اليوم' : "Today's Tasks";
    String body;
    if (overdueCount > 0 && todayCount > 0) {
      body = isArabic
          ? '$todayCount مهمة اليوم · $overdueCount متأخرة'
          : '$todayCount tasks today · $overdueCount overdue';
    } else if (todayCount > 0) {
      body = isArabic
          ? 'لديك $todayCount مهمة اليوم — ابدأ يومك!'
          : "You have $todayCount tasks today — let's go!";
    } else {
      body = isArabic
          ? 'يوم نظيف! لا مهام اليوم 🎉'
          : 'Clean day! No tasks due today 🎉';
    }
    await show(title: title, body: body, identifier: 'daily_task_digest');
  }
}
