import 'dart:async';
import 'dart:io' show Platform, File;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import '../models/prayer_record.dart';
import '../providers/daily_prayer_status_provider.dart';
import 'desktop_adhan_service.dart';
import 'prayer_tracking_service.dart';
import 'task_service.dart';

/// Payload for a desktop in-app notification banner.
class DesktopInAppNotif {
  final String title;
  final String? body;
  final String emoji;

  const DesktopInAppNotif({
    required this.title,
    this.body,
    this.emoji = '🔔',
  });
}

/// Windows/macOS/Linux in-app notification service.
/// Emits [DesktopInAppNotif] events to [notificationStream];
/// [MainWrapperScreen] listens and shows the in-app banner overlay.
/// Prayer-time popups are handled separately by the [DesktopPrayerScheduler]
/// overlay in MainWrapperScreen.
class DesktopNotificationService {
  DesktopNotificationService._();
  static final DesktopNotificationService instance =
      DesktopNotificationService._();

  final StreamController<DesktopInAppNotif> _notifController =
      StreamController<DesktopInAppNotif>.broadcast();

  /// Subscribe to this to display in-app banners.
  Stream<DesktopInAppNotif> get notificationStream => _notifController.stream;

  // Task reminder timers: taskId → Timer
  final Map<String, Timer> _taskTimers = {};

  // Wird reminder timers
  final List<Timer> _wirdTimers = [];

  // Daily task digest timer
  Timer? _digestTimer;

  // Riverpod container — attached by main.dart to allow recording prayer/task state.
  ProviderContainer? _container;

  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  int _notifSeq = 0;

  /// Attach a [ProviderContainer] so notification action buttons can update app state.
  void attachContainer(ProviderContainer container) {
    _container = container;
  }

  Future<void> initialize() async {
    if (!isDesktop) return;
    try {
      // 'Aura | هالة' contains '|' which is invalid in Windows filenames —
      // local_notifier uses appName as the .lnk shortcut filename, so the
      // shortcut was never created and notifications silently failed.
      // 'Aura' creates a valid Aura.lnk in the Start Menu.
      final exePath = Platform.resolvedExecutable.toLowerCase();
      final isMsix = exePath.contains('windowsapps');
      final policy =
          isMsix ? ShortcutPolicy.ignore : ShortcutPolicy.requireCreate;

      // If running as MSIX, remove any stale Aura.lnk left by debug runs
      // so only the MSIX Start Menu entry is visible.
      if (isMsix && Platform.isWindows) {
        final appData = Platform.environment['APPDATA'] ?? '';
        final stale = File(
            '$appData\\Microsoft\\Windows\\Start Menu\\Programs\\Aura.lnk');
        if (await stale.exists()) await stale.delete();
      }

      await localNotifier.setup(
        appName: 'Aura',
        shortcutPolicy: policy,
      );
      debugPrint('DesktopNotificationService: initialized (msix=$isMsix)');
    } catch (e) {
      debugPrint('DesktopNotificationService: init failed - $e');
    }
  }

  void _emit(String title, {String? body, String emoji = '🔔', String? identifier}) {
    if (!isDesktop) return;
    _notifController.add(DesktopInAppNotif(title: title, body: body, emoji: emoji));
    _showSystemToast(title, body, identifier: identifier);
    debugPrint('DesktopNotificationService: notif "$title"');
  }

  Future<void> _showSystemToast(
    String title,
    String? body, {
    String? identifier,
    bool isArabic = false,
    List<LocalNotificationAction>? actions,
    void Function(int)? onActionClick,
  }) async {
    try {
      final id = identifier ?? 'notif_${++_notifSeq}';
      final defaultLabel = isArabic ? 'فتح التطبيق' : 'Open Aura';
      final effectiveActions = actions ?? [LocalNotificationAction(text: defaultLabel)];
      debugPrint('🔔 [TOAST] show id=$id title="$title" actions=${effectiveActions.length}');
      final notif = LocalNotification(
        identifier: id,
        title: title,
        body: body,
        actions: effectiveActions,
      );
      notif.onClick = _bringToFront;
      notif.onClickAction = onActionClick ??
          (actionIndex) {
            if (actionIndex == 0) _bringToFront();
          };
      await notif.show();
      debugPrint('🔔 [TOAST] show() returned OK');
    } catch (e) {
      debugPrint('🔔 [TOAST] FAILED: $e');
    }
  }

  void _bringToFront() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  // ─── Prayer action helpers ────────────────────────────────────────────────

  Future<void> _recordPrayerStatus(String prayerName, PrayerStatus status) async {
    try {
      final userId = getCurrentUserId();
      final now = DateTime.now();
      await PrayerTrackingService.instance.initialize();
      await PrayerTrackingService.instance.recordPrayer(
        userId: userId,
        prayerName: prayerName,
        date: now,
        prayedAt: now,
        status: status,
      );
      _container
          ?.read(dailyPrayerStatusProvider.notifier)
          .updatePrayer(prayerName, status);
      debugPrint('DesktopNotificationService: Recorded $prayerName as ${status.name}');
    } catch (e) {
      debugPrint('DesktopNotificationService: Failed to record prayer: $e');
    }
  }

  Future<void> _completeTask(String taskId) async {
    try {
      final userId = getCurrentUserId();
      await TaskService.instance.updateTask(
        userId: userId,
        taskId: taskId,
        isCompleted: true,
      );
      debugPrint('DesktopNotificationService: Marked task $taskId done');
    } catch (e) {
      debugPrint('DesktopNotificationService: Failed to complete task: $e');
    }
  }

  // ─── Public show methods ──────────────────────────────────────────────────

  /// Show an immediate in-app banner (generic entry point).
  Future<void> show({
    required String title,
    String? body,
    String? identifier,
    String emoji = '🔔',
  }) async {
    _emit(title, body: body, emoji: emoji, identifier: identifier);
  }

  /// Show pre-prayer reminder banner (N minutes before adhan).
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
    final id = 'reminder_${prayerName.toLowerCase()}';
    if (!isDesktop) return;
    _notifController.add(DesktopInAppNotif(title: title, body: body, emoji: '🕌'));
    await _showSystemToast(title, body, identifier: id, isArabic: isArabic);
  }

  /// Show post-prayer check banner ("Did you pray X?") with On Time / Late / Missed buttons.
  Future<void> showPostPrayerCheck(
      String prayerName, String prayerNameAr) async {
    final prefs = await SharedPreferences.getInstance();
    final isArabic = (prefs.getString('language') ?? 'en') == 'ar';
    final prayerLabel = isArabic ? prayerNameAr : prayerName;
    final title = isArabic ? 'هل صليت $prayerLabel؟' : 'Did you pray $prayerLabel?';
    final body = isArabic
        ? 'افتح التطبيق لتسجيل صلاتك'
        : 'Open the app to log your prayer';
    final id = 'post_prayer_${prayerName.toLowerCase()}';
    if (!isDesktop) return;

    final onTimeLabel = isArabic ? 'في الوقت ✓' : 'On Time ✓';
    final lateLabel = isArabic ? 'متأخر ⏰' : 'Late ⏰';
    final missedLabel = isArabic ? 'فاتت ✗' : 'Missed ✗';

    _notifController.add(DesktopInAppNotif(title: title, body: body, emoji: '🕌'));
    await _showSystemToast(
      title, body,
      identifier: id,
      isArabic: isArabic,
      actions: [
        LocalNotificationAction(text: onTimeLabel),
        LocalNotificationAction(text: lateLabel),
        LocalNotificationAction(text: missedLabel),
      ],
      onActionClick: (idx) {
        if (idx == 0) _recordPrayerStatus(prayerName, PrayerStatus.onTime);
        if (idx == 1) _recordPrayerStatus(prayerName, PrayerStatus.late);
        if (idx == 2) _recordPrayerStatus(prayerName, PrayerStatus.missed);
      },
    );
  }

  /// Show Windows toast when the adhan fires (prayer time reached) with a "Prayed ✓" button.
  Future<void> showAdhanNotification(
      String prayerName, String prayerNameAr) async {
    final prefs = await SharedPreferences.getInstance();
    final isArabic = (prefs.getString('language') ?? 'en') == 'ar';
    final label = isArabic ? prayerNameAr : prayerName;
    final title = isArabic ? 'حان وقت $label' : 'Time for $prayerName';
    final body = isArabic ? 'حان وقت الصلاة' : 'Prayer time has arrived';

    final prayedLabel = isArabic ? 'صليت ✓' : 'Prayed ✓';
    final stopLabel = isArabic ? 'إيقاف الأذان' : 'Stop Adhan';

    await _showSystemToast(
      title,
      body,
      identifier: 'adhan_${prayerName.toLowerCase()}',
      isArabic: isArabic,
      actions: [
        LocalNotificationAction(text: prayedLabel),
        LocalNotificationAction(text: stopLabel),
      ],
      onActionClick: (idx) {
        if (idx == 0) _recordPrayerStatus(prayerName, PrayerStatus.onTime);
        if (idx == 1) DesktopAdhanService.instance.stop();
      },
    );
  }

  /// Achievement toast is already shown by MainWrapperScreen — no-op on desktop.
  Future<void> showAchievementNotification(
      String nameEn, String nameAr, String emoji, bool isArabic) async {}

  /// Show task reminder in-app banner with a "Mark Done ✓" button.
  Future<void> showTaskNotification({
    required String taskId,
    required String title,
    required String body,
  }) async {
    if (!isDesktop) return;
    _notifController.add(DesktopInAppNotif(title: title, body: body, emoji: '📋'));

    final prefs = await SharedPreferences.getInstance();
    final isArabic = (prefs.getString('language') ?? 'en') == 'ar';
    final doneLabel = isArabic ? 'تم ✓' : 'Mark Done ✓';
    final openLabel = isArabic ? 'فتح التطبيق' : 'Open App';

    await _showSystemToast(
      title, body,
      identifier: 'task_$taskId',
      actions: [
        LocalNotificationAction(text: doneLabel),
        LocalNotificationAction(text: openLabel),
      ],
      onActionClick: (idx) {
        if (idx == 0) _completeTask(taskId);
        if (idx == 1) _bringToFront();
      },
    );
    debugPrint('DesktopNotificationService: notif "$title"');
  }

  /// Show Wird (daily Quran reading) reminder banner.
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
    _emit(t, body: b, emoji: '📖', identifier: 'wird_reminder');
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
          'DesktopNotificationService: Task reminder already past for "$title"');
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
    final digestTime = DateTime(now.year, now.month, now.day, 8, 0);
    if (digestTime.isBefore(now)) return;

    final delay = digestTime.difference(now);
    _digestTimer = Timer(delay, () {
      _showDailyTaskDigest(todayCount, overdueCount);
      _digestTimer = null;
    });
    debugPrint(
        'DesktopNotificationService: Daily task digest in ${delay.inMinutes} min');
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
    _emit(title, body: body, emoji: '📋', identifier: 'daily_digest');
  }
}
