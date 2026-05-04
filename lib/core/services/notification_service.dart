import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement.dart';
import '../models/prayer_time.dart';
import '../models/prayer_record.dart' show kPrayerNames, PrayerStatus, PrayerMethod, getCurrentUserId;
import '../constants/app_constants.dart';
import '../providers/daily_prayer_status_provider.dart';
import 'prayer_tracking_service.dart';
import 'task_service.dart';
import 'package:flutter/services.dart';
import '../utils/prayer_time_rules.dart';
import '../providers/prayer_times_provider.dart';

/// Service for managing prayer time notifications
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  SharedPreferences? _prefs;

  ProviderContainer? _container;
  void attachContainer(ProviderContainer container) => _container = container;

  // Store prayer times for "remind me again" feature
  final Map<String, DateTime> _scheduledPrayerTimes = {};

  // Notification channels
  static const String _prayerChannelId = 'prayer_times';
  static const String _prayerChannelName = 'Prayer Times';
  static const String _prayerChannelDescription = 'Notifications for prayer times';

  // Task notification channel
  static const String _taskChannelId = 'task_reminders';
  static const String _taskChannelName = 'Task Reminders';
  static const String _taskChannelDescription = 'Reminders for upcoming tasks';

  // Jumu'ah notification channel
  static const String _jumuahChannelId = 'jumuah_reminder';
  static const String _jumuahChannelName = "Jumu'ah Reminder";
  static const int _jumuahNotificationId = 7001;

  // Wird reminder channel
  static const String _wirdChannelId = 'wird_reminder';
  static const String _wirdChannelName = 'Wird Reminder';
  static const String _wirdChannelDescription = 'Daily Quran reading reminders';

  // Achievement notification channel
  static const String _achievementChannelId = 'achievement_unlocked';
  static const String _achievementChannelName = 'Achievements';
  static const String _achievementChannelDescription = 'Notifications when you earn a new achievement';

  // Post-prayer check channel (asks did you pray after prayer time)
  static const String _postCheckChannelId = 'post_prayer_check';
  static const String _postCheckChannelName = 'Prayer Check';

  // Notification IDs
  static const int _fajrNotificationId = 1;
  static const int _sunriseNotificationId = 2;
  static const int _dhuhrNotificationId = 3;
  static const int _asrNotificationId = 4;
  static const int _maghribNotificationId = 5;
  static const int _ishaNotificationId = 6;

  /// Initialize the notification service
  Future<void> initialize() async {
    tz_data.initializeTimeZones();

    final AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('═══════════════════════════════════════');
        debugPrint('🔔 [NOTIFICATION] Action received: ${response.actionId}');
        debugPrint('🔔 [NOTIFICATION] Payload: ${response.payload}');

        // Handle "Remind Me Again" action
        if (response.actionId == 'remind_again' && response.payload != null) {
          _handleRemindMeAgain(response.payload!);
        } else if (response.actionId == 'mark_prayed' && response.payload != null) {
          _handleMarkPrayed(response.payload!);
        } else if (response.actionId != null && response.actionId!.startsWith('mark_prayed_') && response.payload != null) {
          // Handle prayer check "Yes, I prayed" action (mark_prayed_fajr, mark_prayed_zuhr, etc.)
          _handleMarkPrayed(response.payload!);
        } else if (response.actionId != null && response.actionId!.startsWith('post_done_') && response.payload != null) {
          _handlePostPrayerAction(response.payload!, PrayerStatus.onTime);
        } else if (response.actionId != null && response.actionId!.startsWith('post_late_') && response.payload != null) {
          _handlePostPrayerAction(response.payload!, PrayerStatus.late);
        } else if (response.actionId != null && response.actionId!.startsWith('post_miss_') && response.payload != null) {
          _handlePostPrayerAction(response.payload!, PrayerStatus.missed);
        } else if (response.actionId != null && response.actionId!.startsWith('task_done_')) {
          // Handle task "Mark Done" action
          _handleTaskDone(response.actionId!.replaceFirst('task_done_', ''));
        } else if (response.actionId != null && response.actionId!.startsWith('task_snooze_')) {
          // Handle task "Remind Later" action
          _handleTaskSnooze(response.actionId!.replaceFirst('task_snooze_', ''));
        } else if (response.actionId == null || response.actionId == '') {
          // Notification was tapped (not an action button)
          debugPrint('🔔 [NOTIFICATION] Notification tapped by user');
        }
        debugPrint('═══════════════════════════════════════');
      },
    );

    // Create notification channels for Android
    await _createNotificationChannels();

    _prefs = await SharedPreferences.getInstance();

    // Schedule Jumu'ah reminder if enabled
    final jumuahEnabled = _prefs!.getBool('jumua_reminder_enabled') ?? true;
    if (jumuahEnabled) {
      await scheduleJumuahReminder();
    }

    debugPrint('NotificationService: Initialized');
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _prayerChannelId,
      _prayerChannelName,
      description: _prayerChannelDescription,
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );

    const AndroidNotificationChannel prayerCheckChannel = AndroidNotificationChannel(
      'prayer_check',
      'Prayer Check',
      description: 'Reminders to check if you prayed',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(prayerCheckChannel);

    const AndroidNotificationChannel taskChannel = AndroidNotificationChannel(
      _taskChannelId,
      _taskChannelName,
      description: _taskChannelDescription,
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(taskChannel);

    const AndroidNotificationChannel jumuahChannel = AndroidNotificationChannel(
      _jumuahChannelId,
      _jumuahChannelName,
      description: 'Weekly Friday prayer reminder',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(jumuahChannel);

    const AndroidNotificationChannel postCheckChannel = AndroidNotificationChannel(
      _postCheckChannelId,
      _postCheckChannelName,
      description: 'Asks if you prayed after prayer time passes',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(postCheckChannel);

    const AndroidNotificationChannel wirdChannel = AndroidNotificationChannel(
      _wirdChannelId,
      _wirdChannelName,
      description: _wirdChannelDescription,
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(wirdChannel);

    const AndroidNotificationChannel achievementChannel = AndroidNotificationChannel(
      _achievementChannelId,
      _achievementChannelName,
      description: _achievementChannelDescription,
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(achievementChannel);
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    debugPrint('═══════════════════════════════════════');
    debugPrint('🔔 [PERMISSION] requestPermissions called');

    // Android 13+ requires POST_NOTIFICATIONS permission
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      debugPrint('📱 [PERMISSION] Notification permission status: $status');
      if (!status.isGranted) {
        debugPrint('❌ [PERMISSION] Notification permission denied');
        return false;
      }
      debugPrint('✅ [PERMISSION] Notification permission granted');
    }

    // For exact alarm permission on Android 12+
    if (defaultTargetPlatform == TargetPlatform.android) {
      final exactAlarmStatus = await Permission.scheduleExactAlarm.request();
      debugPrint('⏰ [PERMISSION] Exact alarm permission status: $exactAlarmStatus');
      if (!exactAlarmStatus.isGranted) {
        debugPrint('⚠️ [PERMISSION] Exact alarm permission denied');
      } else {
        debugPrint('✅ [PERMISSION] Exact alarm permission granted');
      }
    }

    debugPrint('✅ [PERMISSION] All permissions completed');
    debugPrint('═══════════════════════════════════════');
    return true;
  }

  /// Schedule a notification for a specific prayer time
  Future<void> schedulePrayerNotification(PrayerTime prayer) async {
    if (_prefs == null) return;

    debugPrint('═══════════════════════════════════════');
    debugPrint('🔔 [NOTIFICATION] schedulePrayerNotification called for ${prayer.name}');

    // Check if prayer notifications are master enabled
    final masterEnabled = _prefs!.getBool(AppConstants.keyPrayerNotificationsEnabled) ?? true;
    if (!masterEnabled) {
      debugPrint('❌ [NOTIFICATION] Prayer notifications are DISABLED in settings');
      return;
    }

    // Check if notifications are enabled for this prayer
    if (!_isNotificationEnabled(prayer.name)) {
      debugPrint('❌ [NOTIFICATION] Notifications disabled for ${prayer.name}');
      return;
    }

    final notificationId = _getNotificationId(prayer.name);
    final scheduledTime = prayer.time;
    final now = DateTime.now();

    // Schedule notification X minutes before prayer time
    final reminderMinutes = _prefs?.getInt(AppConstants.keyNotificationReminderMinutes) ?? 10;
    final reminderTime = scheduledTime.subtract(Duration(minutes: reminderMinutes));

    debugPrint('📅 [NOTIFICATION] Current time: $now');
    debugPrint('📅 [NOTIFICATION] Prayer time: ${prayer.time} (${prayer.name})');
    debugPrint('📅 [NOTIFICATION] Reminder time: $reminderTime ($reminderMinutes min before)');

    // If reminder time has passed, don't schedule
    if (reminderTime.isBefore(now)) {
      debugPrint('❌ [NOTIFICATION] ${prayer.name} reminder time has passed - SKIPPING');
      debugPrint('═══════════════════════════════════════');
      return;
    }

    debugPrint('✅ [NOTIFICATION] Scheduling notification for ${prayer.name}...');

    final isArabic = await _getLanguagePreference() == 'ar';
    final title = isArabic ? prayer.nameAr : prayer.name;
    final body = isArabic ? 'الصلاة بعد $reminderMinutes دقائق' : 'Prayer in $reminderMinutes minutes';

    // Create "Remind Me Again" and "Mark as Prayed" action buttons
    final remindAgainLabel = isArabic ? 'ذكرني مرة أخرى' : 'Remind Me Again';
    final markPrayedLabel = isArabic ? 'أديت الصلاة' : 'Mark as Prayed';
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _prayerChannelId,
      _prayerChannelName,
      channelDescription: _prayerChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      // Add action buttons
      actions: [
        AndroidNotificationAction(
          'mark_prayed',
          markPrayedLabel,
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          'remind_again',
          remindAgainLabel,
          showsUserInterface: false,
        ),
      ],
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
      reminderTime,
      tz.local,
    );

    await _notifications.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledDate,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: '${prayer.name}|${prayer.nameAr}|${prayer.time.millisecondsSinceEpoch}', // Store prayer info
    );

    // Store prayer time for "remind me again" feature
    _scheduledPrayerTimes[prayer.name] = prayer.time;

    debugPrint('NotificationService: Scheduled ${prayer.name} notification for $scheduledDate');
  }

  /// Schedule all prayer notifications for the day
  Future<void> scheduleDailyPrayers(List<PrayerTime> prayers) async {
    debugPrint('═══════════════════════════════════════');
    debugPrint('🔔 [NOTIFICATION] scheduleDailyPrayers called with ${prayers.length} prayers');
    for (final prayer in prayers) {
      if (prayer.name != 'Sunrise') {
        await schedulePrayerNotification(prayer);
      }
    }
    debugPrint('✅ [NOTIFICATION] Finished scheduling daily prayers');
    debugPrint('═══════════════════════════════════════');
  }

  /// Schedule prayer check reminders - 30 min before each prayer,
  /// check if the PREVIOUS prayer was completed, if not remind the user.
  /// Uses notification IDs 3001-3006 to avoid conflicts.
  Future<void> schedulePrayerCheckReminders(List<PrayerTime> prayers, Map<String, bool> completedPrayers) async {
    debugPrint('═══════════════════════════════════════');
    debugPrint('🔔 [PRAYER_CHECK] Scheduling prayer check reminders');

    // Prayer order for determining "previous" prayer (skip Sunrise)
    final trackablePrayers = prayers.where((p) => p.name != 'Sunrise').toList();

    for (int i = 0; i < trackablePrayers.length; i++) {
      final currentPrayer = trackablePrayers[i];

      // Find the previous trackable prayer
      if (i == 0) continue; // No previous prayer for Fajr (first of day)
      final previousPrayer = trackablePrayers[i - 1];
      final previousCompleted = completedPrayers[previousPrayer.name] ?? false;

      // If already completed, no need to remind
      if (previousCompleted) {
        debugPrint('✅ [PRAYER_CHECK] ${previousPrayer.name} already completed, skipping reminder');
        continue;
      }

      // Schedule 30 minutes before current prayer time
      final reminderTime = currentPrayer.time.subtract(const Duration(minutes: 30));
      final now = DateTime.now();

      if (reminderTime.isBefore(now)) {
        debugPrint('❌ [PRAYER_CHECK] ${currentPrayer.name} reminder time has passed - skipping');
        continue;
      }

      final isArabic = await _getLanguagePreference() == 'ar';
      final prevName = isArabic ? previousPrayer.nameAr : previousPrayer.name;
      final title = isArabic ? 'تذكير الصلاة' : 'Prayer Reminder';
      final body = isArabic
          ? 'هل صليت $prevName؟ حان موعد ${isArabic ? currentPrayer.nameAr : currentPrayer.name} بعد 30 دقيقة'
          : 'Did you pray $prevName? ${currentPrayer.name} is in 30 minutes';

      final notificationId = 3000 + _getNotificationId(currentPrayer.name);

      final androidDetails = AndroidNotificationDetails(
        'prayer_check',
        'Prayer Check',
        channelDescription: 'Reminders to check if you prayed',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        actions: [
          AndroidNotificationAction(
            'mark_prayed_${previousPrayer.name.toLowerCase()}',
            isArabic ? 'نعم، صليت' : 'Yes, I prayed',
            showsUserInterface: false,
          ),
        ],
      );

      final platformDetails = NotificationDetails(android: androidDetails);

      final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);

      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'prayer_check|${previousPrayer.name}|${previousPrayer.nameAr}',
      );

      debugPrint('✅ [PRAYER_CHECK] Scheduled: "Did you pray ${previousPrayer.name}?" 30 min before ${currentPrayer.name}');
    }

    debugPrint('═══════════════════════════════════════');
  }

  /// Schedule a "remind me again" notification (5 minutes before prayer)
  /// This is called when user taps "Remind Me Again" on the 10-minute notification
  Future<void> scheduleRemindMeAgain(String prayerName, String prayerNameAr, DateTime prayerTime) async {
    debugPrint('═══════════════════════════════════════');
    debugPrint('🔔 [REMIND_AGAIN] Scheduling remind again for $prayerName');

    final notificationId = _getNotificationId(prayerName) + 5000; // 5001-5006: avoid conflict with native IDs (1001-1006, 2001-2006, 3001-3006)
    final now = DateTime.now();

    // Schedule notification 5 minutes before prayer time
    final reminderTime = prayerTime.subtract(const Duration(minutes: 5));

    debugPrint('📅 [REMIND_AGAIN] Current time: $now');
    debugPrint('📅 [REMIND_AGAIN] Prayer time: $prayerTime');
    debugPrint('📅 [REMIND_AGAIN] Reminder time: $reminderTime (5 min before)');

    // If reminder time has passed, don't schedule
    if (reminderTime.isBefore(now)) {
      debugPrint('❌ [REMIND_AGAIN] Reminder time has passed - too late to remind again');
      debugPrint('═══════════════════════════════════════');
      return;
    }

    final isArabic = await _getLanguagePreference() == 'ar';
    final title = isArabic ? prayerNameAr : prayerName;
    final body = isArabic ? 'الصلاة بعد 5 دقائق' : 'Prayer in 5 minutes';

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _prayerChannelId,
      _prayerChannelName,
      channelDescription: _prayerChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
      reminderTime,
      tz.local,
    );

    await _notifications.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledDate,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint('✅ [REMIND_AGAIN] Scheduled remind-again notification for $title at $scheduledDate');
    debugPrint('═══════════════════════════════════════');
  }

  /// Handle "Remind Me Again" button tap
  /// Handle "Mark as Prayed" action from notification
  Future<void> _handleMarkPrayed(String payload) async {
    debugPrint('═══════════════════════════════════════');
    debugPrint('✅ [MARK_PRAYED] Handling mark as prayed request');
    debugPrint('📦 [MARK_PRAYED] Payload: $payload');

    final parts = payload.split('|');
    if (parts.isEmpty) {
      debugPrint('❌ [MARK_PRAYED] Invalid payload format');
      return;
    }

    // Handle both payload formats:
    // Regular: "Fajr|الفجر|timestamp"
    // Prayer check: "prayer_check|Fajr|الفجر"
    String prayerName;
    if (parts[0] == 'prayer_check' && parts.length >= 2) {
      prayerName = parts[1]; // prayer_check|Fajr|الفجر → Fajr
    } else {
      prayerName = parts[0]; // Fajr|الفجر|timestamp → Fajr
    }
    debugPrint('🕌 [MARK_PRAYED] Prayer: $prayerName');

    try {
      final userId = getCurrentUserId();
      final now = DateTime.now();
      final fajrTime = _container?.read(prayerTimesProvider).prayerTimes
          .where((p) => p.name == 'Fajr').firstOrNull?.time;
      final success = await PrayerTrackingService.instance.recordPrayer(
        userId: userId,
        prayerName: prayerName,
        date: getPrayerDate(now, fajrTime: fajrTime),
        prayedAt: DateTime.now(),
        status: PrayerStatus.onTime,
        method: PrayerMethod.congregation,
      );
      debugPrint(success
          ? '✅ [MARK_PRAYED] Successfully recorded $prayerName from notification'
          : '❌ [MARK_PRAYED] Failed to record $prayerName');
    } catch (e) {
      debugPrint('❌ [MARK_PRAYED] Error: $e');
    }
    debugPrint('═══════════════════════════════════════');
  }

  Future<void> _handleRemindMeAgain(String payload) async {
    debugPrint('═══════════════════════════════════════');
    debugPrint('🔄 [REMIND_AGAIN] Handling remind me again request');
    debugPrint('📦 [REMIND_AGAIN] Payload: $payload');

    // Parse payload: "prayerName|prayerNameAr|timestamp"
    final parts = payload.split('|');
    if (parts.length != 3) {
      debugPrint('❌ [REMIND_AGAIN] Invalid payload format');
      return;
    }

    final prayerName = parts[0];
    final prayerNameAr = parts[1];
    final prayerTimeMillis = int.tryParse(parts[2]);

    if (prayerTimeMillis == null) {
      debugPrint('❌ [REMIND_AGAIN] Invalid timestamp in payload');
      return;
    }

    final prayerTime = DateTime.fromMillisecondsSinceEpoch(prayerTimeMillis);
    debugPrint('🕌 [REMIND_AGAIN] Prayer: $prayerName ($prayerNameAr) at $prayerTime');

    // Schedule remind again notification (5 minutes before) - await to ensure it completes
    await scheduleRemindMeAgain(prayerName, prayerNameAr, prayerTime);

    debugPrint('═══════════════════════════════════════');
  }

  // ─── Task Notification Actions ────────────────────────────────────────────

  Future<void> _handleTaskDone(String taskId) async {
    debugPrint('✅ [TASK_DONE] Marking task $taskId as done from notification');
    try {
      final userId = getCurrentUserId();
      if (userId.isEmpty) return;
      await TaskService.instance.toggleTaskCompletion(
        userId: userId,
        taskId: taskId,
      );
      await cancelTaskNotification(taskId);
      debugPrint('✅ [TASK_DONE] Task $taskId completed');
    } catch (e) {
      debugPrint('❌ [TASK_DONE] Error: $e');
    }
  }

  Future<void> _handleTaskSnooze(String taskId) async {
    debugPrint('⏰ [TASK_SNOOZE] Snoozing task $taskId for 30 minutes');
    try {
      // Cancel current notification
      await _notifications.cancel(_taskNotificationId(taskId));

      // Get task details to reschedule
      final userId = getCurrentUserId();
      if (userId.isEmpty) return;

      // Schedule a new reminder 30 minutes from now
      final snoozeTime = DateTime.now().add(const Duration(minutes: 30));
      final prefs = await SharedPreferences.getInstance();
      final language = prefs.getString('language') ?? 'en';
      final isArabic = language == 'ar';

      final notifId = _taskNotificationId(taskId);
      final androidDetails = AndroidNotificationDetails(
        _taskChannelId,
        _taskChannelName,
        channelDescription: _taskChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'task_done_$taskId',
            isArabic ? 'إتمام' : 'Mark Done',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'task_snooze_$taskId',
            isArabic ? 'ذكرني لاحقاً' : 'Remind Later',
            showsUserInterface: true,
          ),
        ],
      );

      final details = NotificationDetails(android: androidDetails);
      final scheduledDate = tz.TZDateTime.from(snoozeTime, tz.local);

      await _notifications.zonedSchedule(
        notifId,
        isArabic ? 'تذكير بمهمة' : 'Task Reminder',
        isArabic ? 'لا تزال المهمة معلقة' : 'Your task is still pending',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'task|$taskId',
      );

      debugPrint('⏰ [TASK_SNOOZE] Rescheduled for $snoozeTime');
    } catch (e) {
      debugPrint('❌ [TASK_SNOOZE] Error: $e');
    }
  }

  // ─── Task Notifications ───────────────────────────────────────────────────

  /// Convert task ID (Firestore string) to a notification ID in range 4000-4999
  int _taskNotificationId(String taskId) => 4000 + (taskId.hashCode.abs() % 1000);

  /// Schedule a reminder notification for a task with a due date.
  /// Fires 30 minutes before the due time (or at the due time if < 30 min away).
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required DateTime dueDate,
    bool hasDueTime = false,
    String language = 'en',
  }) async {
    final isArabic = language == 'ar';
    final now = DateTime.now();

    DateTime reminderTime;
    String body;

    if (hasDueTime) {
      // Specific time set — remind X minutes before (user setting)
      final prefs2 = await SharedPreferences.getInstance();
      final reminderMinutes = prefs2.getInt('task_reminder_minutes') ?? 30;
      final reminderBefore = dueDate.subtract(Duration(minutes: reminderMinutes));
      reminderTime = reminderBefore.isAfter(now) ? reminderBefore : dueDate;
      body = isArabic
          ? (reminderBefore.isAfter(now) ? 'موعد المهمة بعد $reminderMinutes دقيقة' : 'حان موعد المهمة الآن')
          : (reminderBefore.isAfter(now) ? 'Task due in $reminderMinutes minutes' : 'Task is due now');
    } else {
      // No specific time — remind at 9:00 AM on the due date
      reminderTime = DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);
      body = isArabic ? 'لديك مهمة مستحقة اليوم' : 'You have a task due today';
    }

    if (reminderTime.isBefore(now)) {
      debugPrint('TaskNotification: Reminder time already passed for "$title" — skipping');
      return;
    }

    // Check if task notifications are enabled
    final prefs = await SharedPreferences.getInstance();
    final notifEnabled = prefs.getBool('task_notifications_enabled') ?? true;
    if (!notifEnabled) {
      debugPrint('TaskNotification: Task notifications disabled — skipping "$title"');
      return;
    }

    final notifId = _taskNotificationId(taskId);
    await _notifications.cancel(notifId);

    final androidDetails = AndroidNotificationDetails(
      _taskChannelId,
      _taskChannelName,
      channelDescription: _taskChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'task_done_$taskId',
          isArabic ? 'إتمام' : 'Mark Done',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'task_snooze_$taskId',
          isArabic ? 'ذكرني لاحقاً' : 'Remind Later',
          showsUserInterface: true,
        ),
      ],
    );

    final details = NotificationDetails(android: androidDetails);
    final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);

    await _notifications.zonedSchedule(
      notifId,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'task|$taskId',
    );

    debugPrint('TaskNotification: Scheduled "$title" at $scheduledDate (id=$notifId)');
  }

  /// Cancel the reminder for a specific task
  Future<void> cancelTaskNotification(String taskId) async {
    final notifId = _taskNotificationId(taskId);
    await _notifications.cancel(notifId);
    debugPrint('TaskNotification: Cancelled notification for task $taskId (id=$notifId)');
  }

  // ─── Daily Task Summary ───────────────────────────────────────────────────

  static const int _dailySummaryId = 3999;

  /// Schedule a daily morning notification summarizing today's tasks.
  /// Called from TaskService when tasks change, or from app init.
  Future<void> scheduleDailyTaskSummary({
    required int todayCount,
    required int overdueCount,
    String language = 'en',
    int hour = 8,
    int minute = 0,
  }) async {
    final isArabic = language == 'ar';

    // Cancel existing summary
    await _notifications.cancel(_dailySummaryId);

    String title;
    String body;
    if (todayCount == 0 && overdueCount == 0) {
      title = isArabic ? 'لا مهام لليوم' : 'No tasks today';
      body = isArabic ? 'يومك حر! استمتع بوقتك' : 'Your day is free! Enjoy.';
    } else {
      title = isArabic ? 'ملخص مهام اليوم' : "Today's Tasks";
      final parts = <String>[];
      if (todayCount > 0) {
        parts.add(isArabic ? '$todayCount مهام لليوم' : '$todayCount task${todayCount > 1 ? "s" : ""} today');
      }
      if (overdueCount > 0) {
        parts.add(isArabic ? '$overdueCount متأخرة' : '$overdueCount overdue');
      }
      body = parts.join(isArabic ? '، ' : ', ');
    }

    final androidDetails = AndroidNotificationDetails(
      _taskChannelId,
      _taskChannelName,
      channelDescription: _taskChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(android: androidDetails);

    // Schedule for today at the specified time, or tomorrow if already past
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    final tzScheduled = tz.TZDateTime.from(scheduled, tz.local);

    await _notifications.zonedSchedule(
      _dailySummaryId,
      title,
      body,
      tzScheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'daily_summary',
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily
    );

    debugPrint('TaskSummary: Scheduled daily at $hour:$minute — $todayCount today, $overdueCount overdue');
  }

  /// Cancel the daily task summary notification
  Future<void> cancelDailyTaskSummary() async {
    await _notifications.cancel(_dailySummaryId);
  }

  /// Cancel a specific prayer notification
  Future<void> cancelPrayerNotification(String prayerName) async {
    final notificationId = _getNotificationId(prayerName);
    await _notifications.cancel(notificationId);
    debugPrint('NotificationService: Cancelled $prayerName notification');
  }

  /// Cancel all prayer notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    debugPrint('NotificationService: Cancelled all notifications');
  }

  /// Show immediate notification (useful for testing)
  Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _prayerChannelId,
      _prayerChannelName,
      channelDescription: _prayerChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notifications.show(
      0,
      'Test Notification',
      'This is a test prayer notification',
      platformChannelSpecifics,
    );
  }

  /// Show notification at exact prayer time (when adhan plays)
  Future<void> showPrayerTimeNotification({
    required String prayerName,
    required String prayerNameAr,
    required String language,
  }) async {
    final isArabic = language == 'ar';
    final title = isArabic ? prayerNameAr : prayerName;
    final body = isArabic ? 'حان الآن موعد صلاة $title' : 'It\'s time for $title prayer';

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _prayerChannelId,
      _prayerChannelName,
      channelDescription: _prayerChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final notificationId = _getNotificationId(prayerName);

    await _notifications.show(
      notificationId,
      title,
      body,
      platformChannelSpecifics,
    );

    debugPrint('🔔 [NOTIFICATION] Showed prayer time notification for $prayerName');
  }

  /// Check if notification is enabled for a prayer
  bool _isNotificationEnabled(String prayerName) {
    if (_prefs == null) return true;
    return _prefs!.getBool('notify_${prayerName.toLowerCase()}') ?? true;
  }

  /// Get notification ID for prayer
  int _getNotificationId(String prayerName) {
    switch (prayerName) {
      case 'Fajr':
        return _fajrNotificationId;
      case 'Sunrise':
        return _sunriseNotificationId;
      case 'Zuhr':
        return _dhuhrNotificationId;
      case 'Asr':
        return _asrNotificationId;
      case 'Maghrib':
        return _maghribNotificationId;
      case 'Isha':
        return _ishaNotificationId;
      default:
        return 0;
    }
  }

  /// Schedule a daily morning task digest at 8:00 AM
  Future<void> scheduleDailyTaskDigest({
    required int todayCount,
    required int overdueCount,
  }) async {
    const notificationId = 4001;
    try {
      final isArabic = await _getLanguagePreference() == 'ar';

      final title = isArabic ? 'ملخص مهامك اليوم' : "Today's Tasks";
      String body;
      if (overdueCount > 0 && todayCount > 0) {
        body = isArabic
            ? '$todayCount مهمة اليوم · $overdueCount متأخرة'
            : '$todayCount tasks today · $overdueCount overdue';
      } else if (todayCount > 0) {
        body = isArabic
            ? 'لديك $todayCount مهمة اليوم — ابدأ يومك!'
            : 'You have $todayCount tasks today — let\'s go!';
      } else {
        body = isArabic ? 'يوم نظيف! لا مهام اليوم 🎉' : 'Clean day! No tasks due today 🎉';
      }

      await _notifications.cancel(notificationId);

      final now = DateTime.now();
      var scheduledTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 0);
      if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      final androidDetails = AndroidNotificationDetails(
        'task_digest',
        'Daily Task Digest',
        channelDescription: 'Morning summary of your tasks',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      );

      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledTime,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('✅ [DIGEST] Scheduled daily task digest at 8 AM — $todayCount today, $overdueCount overdue');
    } catch (e) {
      debugPrint('❌ [DIGEST] Error scheduling digest: $e');
    }
  }

  // ─── Wird Reminders ──────────────────────────────────────────────────────

  /// Schedule daily Wird reminders at the given times.
  /// Notification IDs: 5100-5119 (max 20 slots).
  Future<void> scheduleWirdReminders({
    required List<String> reminderTimes,
    required int dailyPageGoal,
  }) async {
    // Cancel all existing wird notifications
    await cancelWirdReminders();

    final isArabic = await _getLanguagePreference() == 'ar';
    final now = DateTime.now();

    for (int i = 0; i < reminderTimes.length && i < 20; i++) {
      final parts = reminderTimes[i].split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      final title = isArabic ? 'تذكير الورد' : 'Wird Reminder';
      final body = isArabic
          ? 'اقرأ وردك اليومي — $dailyPageGoal صفحة اليوم'
          : 'Read your daily Wird — $dailyPageGoal pages today';

      final androidDetails = AndroidNotificationDetails(
        _wirdChannelId,
        _wirdChannelName,
        channelDescription: _wirdChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );

      final details = NotificationDetails(android: androidDetails);
      final scheduledDate = tz.TZDateTime.from(scheduled, tz.local);

      await _notifications.zonedSchedule(
        5100 + i,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'wird_reminder',
      );

      debugPrint('📖 [WIRD] Scheduled reminder #$i at $scheduled');
    }
  }

  /// Cancel all wird reminder notifications
  Future<void> cancelWirdReminders() async {
    for (int i = 0; i < 20; i++) {
      await _notifications.cancel(5100 + i);
    }
  }

  // ─── Achievement Notifications ────────────────────────────────────────────

  /// Show a system notification when an achievement is unlocked.
  /// Notification IDs: 7100–8099 (hash-based per achievement, no collisions between types).
  Future<void> showAchievementNotification(Achievement achievement, bool isArabic) async {
    try {
      final id = 7100 + (achievement.id.hashCode.abs() % 1000);
      final title = isArabic ? '🏆 إنجاز جديد!' : '🏆 Achievement Unlocked!';
      final body = '${achievement.iconEmoji} ${isArabic ? achievement.nameAr : achievement.nameEn}';

      const androidDetails = AndroidNotificationDetails(
        _achievementChannelId,
        _achievementChannelName,
        channelDescription: _achievementChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      await _notifications.show(
        id,
        title,
        body,
        const NotificationDetails(android: androidDetails),
        payload: 'achievement:${achievement.id}',
      );

      debugPrint('🏆 [ACHIEVEMENT] Notification shown: ${achievement.id}');
    } catch (e) {
      debugPrint('❌ [ACHIEVEMENT] Error showing notification: $e');
    }
  }

  /// Get language preference
  Future<String> _getLanguagePreference() async {
    if (_prefs == null) return 'en';
    return _prefs!.getString('language') ?? 'en';
  }

  /// Toggle notification for a prayer
  Future<void> togglePrayerNotification(String prayerName, bool enabled) async {
    if (_prefs != null) {
      await _prefs!.setBool('notify_${prayerName.toLowerCase()}', enabled);
      if (enabled) {
        // Re-schedule notifications if enabled
        debugPrint('NotificationService: Enabled notifications for $prayerName');
      } else {
        // Cancel if disabled
        await cancelPrayerNotification(prayerName);
        debugPrint('NotificationService: Disabled notifications for $prayerName');
      }
    }
  }

  /// Check if notification permission is granted
  Future<bool> areNotificationsEnabled() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await Permission.notification.isGranted;
    }
    return true;
  }

  /// Open app notification settings
  Future<void> openNotificationSettings() async {
    // This would require a platform-specific implementation
    // For now, just log it
    debugPrint('NotificationService: Opening notification settings');
  }

  /// Debug method to check notification status
  Future<void> debugCheckNotificationStatus() async {
    debugPrint('═══════════════════════════════════════');
    debugPrint('🔔 [DEBUG] Notification Status Check');
    debugPrint('═══════════════════════════════════════');

    // Check permissions
    final hasPermission = await areNotificationsEnabled();
    debugPrint('📱 Permission granted: $hasPermission');

    // Check notification enabled for each prayer
    final prayers = kPrayerNames;
    for (final prayer in prayers) {
      final enabled = _isNotificationEnabled(prayer);
      debugPrint('🕌 $prayer notifications: ${enabled ? "ENABLED" : "DISABLED"}');
    }

    // Get pending notifications
    final pendingNotifications = await _notifications.getNotificationAppLaunchDetails();
    debugPrint('📋 Notification launched from: ${pendingNotifications?.didNotificationLaunchApp ?? false}');

    debugPrint('═══════════════════════════════════════');
  }

  // ─── Post-Prayer Check ───────────────────────────────────────────────────

  /// Schedule a notification AFTER each prayer asking "Did you pray?"
  /// Timing:
  ///   - If iqama is set  → 30 min after iqama time
  ///   - No iqama         → 1 hour after prayer time
  /// Buttons: Done ✅ / Late ⏰ / Missed ❌
  Future<void> schedulePostPrayerCheck(List<PrayerTime> prayers) async {
    final isArabic = await _getLanguagePreference() == 'ar';
    final now = DateTime.now();

    for (final prayer in prayers) {
      if (prayer.name == 'Sunrise') continue;

      // Determine trigger time
      final DateTime triggerTime;
      if (prayer.iqamaTime != null) {
        triggerTime = prayer.iqamaTime!.add(const Duration(minutes: 30));
      } else {
        triggerTime = prayer.time.add(const Duration(hours: 1));
      }

      if (triggerTime.isBefore(now)) {
        debugPrint('⏭️ [POST_CHECK] ${prayer.name} trigger already passed — skipping');
        continue;
      }

      final notifId = 6000 + _getNotificationId(prayer.name);
      final prayerLabel = isArabic ? prayer.nameAr : prayer.name;
      final title = isArabic ? 'هل صليت $prayerLabel؟' : 'Did you pray $prayerLabel?';
      final body = isArabic
          ? 'سجّل صلاتك الآن'
          : 'Log your prayer now';

      final lowerName = prayer.name.toLowerCase();

      final androidDetails = AndroidNotificationDetails(
        _postCheckChannelId,
        _postCheckChannelName,
        channelDescription: 'Asks if you prayed after prayer time passes',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        actions: [
          AndroidNotificationAction(
            'post_done_$lowerName',
            isArabic ? '✅ صليت' : '✅ Done',
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            'post_late_$lowerName',
            isArabic ? '⏰ متأخراً' : '⏰ Late',
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            'post_miss_$lowerName',
            isArabic ? '❌ فاتتني' : '❌ Missed',
            showsUserInterface: false,
          ),
        ],
      );

      final scheduledDate = tz.TZDateTime.from(triggerTime, tz.local);

      await _notifications.zonedSchedule(
        notifId,
        title,
        body,
        scheduledDate,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'post_check|${prayer.name}|${prayer.nameAr}',
      );

      debugPrint('✅ [POST_CHECK] Scheduled "${prayer.name}" check at $triggerTime');
    }
  }

  /// Cancel all post-prayer check notifications (e.g. if user tracked manually)
  Future<void> cancelPostPrayerCheck(String prayerName) async {
    final notifId = 6000 + _getNotificationId(prayerName);
    await _notifications.cancel(notifId);
  }

  Future<void> _handlePostPrayerAction(String payload, PrayerStatus status) async {
    debugPrint('✅ [POST_CHECK] Handling action — status: $status, payload: $payload');
    try {
      final parts = payload.split('|');
      if (parts.length < 2) return;
      final prayerName = parts[1]; // post_check|Fajr|الفجر → Fajr

      final userId = getCurrentUserId();
      if (userId.isEmpty) return;

      final now = DateTime.now();
      final fajrTime = _container?.read(prayerTimesProvider).prayerTimes
          .where((p) => p.name == 'Fajr').firstOrNull?.time;
      await PrayerTrackingService.instance.recordPrayer(
        userId: userId,
        prayerName: prayerName,
        date: getPrayerDate(now, fajrTime: fajrTime),
        prayedAt: now,
        status: status,
        method: PrayerMethod.alone,
      );

      // Update shared provider so home screen + prayer cards refresh immediately
      _container?.read(dailyPrayerStatusProvider.notifier).updatePrayer(prayerName, status);

      // Cancel the notification after action taken
      final notifId = 6000 + _getNotificationId(prayerName);
      await _notifications.cancel(notifId);

      debugPrint('✅ [POST_CHECK] Recorded $prayerName as $status');
    } catch (e) {
      debugPrint('❌ [POST_CHECK] Error: $e');
    }
  }

  // ─── Jumu'ah Reminder ────────────────────────────────────────────────────

  static const _prayerAlarmsChannel = MethodChannel('com.aura.hala/prayer_alarms');

  /// Schedule weekly Friday Jumu'ah reminder via native AlarmManager (survives reboots).
  /// Fires 30 min before the stored Zuhr prayer time.
  Future<void> scheduleJumuahReminder() async {
    try {
      // Cancel any old Flutter-scheduled Jumu'ah notification (legacy cleanup)
      await _notifications.cancel(_jumuahNotificationId);
      await _prayerAlarmsChannel.invokeMethod('scheduleJumuahReminder');
      debugPrint("✅ [JUMUA] Jumu'ah reminder scheduled via native");
    } catch (e) {
      debugPrint("❌ [JUMUA] Error scheduling Jumu'ah reminder: $e");
    }
  }

  Future<void> cancelJumuahReminder() async {
    try {
      await _notifications.cancel(_jumuahNotificationId);
      await _prayerAlarmsChannel.invokeMethod('cancelJumuahReminder');
      debugPrint("✅ [JUMUA] Jumu'ah reminder cancelled");
    } catch (e) {
      debugPrint("❌ [JUMUA] Error cancelling Jumu'ah reminder: $e");
    }
  }

  // ─── Focus Mode ─────────────────────────────────────────────────────────

  static const _focusChannel = MethodChannel('com.aura.hala/focus_mode');

  /// Schedule a focus mode alarm at task time via native MethodChannel
  Future<void> scheduleFocusMode({
    required String taskId,
    required String title,
    String description = '',
    required DateTime triggerTime,
    required int durationMinutes,
    String language = 'en',
  }) async {
    try {
      await _focusChannel.invokeMethod('scheduleFocusAlarm', {
        'taskId': taskId,
        'taskTitle': title,
        'taskDesc': description,
        'triggerTime': triggerTime.millisecondsSinceEpoch,
        'durationMinutes': durationMinutes,
        'language': language,
      });
      debugPrint('FocusMode: Scheduled focus for "$title" at $triggerTime');
    } on PlatformException catch (e) {
      debugPrint('FocusMode: Error scheduling - ${e.message}');
    }
  }

  /// Cancel a focus mode alarm
  Future<void> cancelFocusMode(String taskId) async {
    try {
      await _focusChannel.invokeMethod('cancelFocusAlarm', {
        'taskId': taskId,
      });
      debugPrint('FocusMode: Cancelled focus alarm for task $taskId');
    } on PlatformException catch (e) {
      debugPrint('FocusMode: Error cancelling - ${e.message}');
    }
  }

  // Accessibility service removed — screen pinning handled by user tapping OK

  /// Check if overlay permission is granted
  Future<bool> canDrawOverlays() async {
    try {
      return await _focusChannel.invokeMethod('canDrawOverlays') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Request overlay permission (opens system settings)
  Future<void> requestOverlayPermission() async {
    try {
      await _focusChannel.invokeMethod('requestOverlayPermission');
    } on PlatformException catch (e) {
      debugPrint('FocusMode: Error requesting overlay - ${e.message}');
    }
  }

  /// Check if DND access is granted
  Future<bool> hasDndAccess() async {
    try {
      return await _focusChannel.invokeMethod('hasDndAccess') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Request DND access (opens system settings)
  Future<void> requestDndAccess() async {
    try {
      await _focusChannel.invokeMethod('requestDndAccess');
    } on PlatformException catch (e) {
      debugPrint('FocusMode: Error requesting DND - ${e.message}');
    }
  }

  /// Start focus mode foreground service immediately
  Future<bool> startFocusService({
    required String taskId,
    required String taskTitle,
    String taskDesc = '',
    required int durationMinutes,
    String language = 'en',
  }) async {
    try {
      return await _focusChannel.invokeMethod('startFocusService', {
        'taskId': taskId,
        'taskTitle': taskTitle,
        'taskDesc': taskDesc,
        'durationMinutes': durationMinutes,
        'language': language,
      }) ?? false;
    } on PlatformException catch (e) {
      debugPrint('FocusMode: Error starting service - ${e.message}');
      return false;
    }
  }

  /// Stop focus mode foreground service
  Future<bool> stopFocusService() async {
    try {
      return await _focusChannel.invokeMethod('stopFocusService') ?? false;
    } on PlatformException catch (e) {
      debugPrint('FocusMode: Error stopping service - ${e.message}');
      return false;
    }
  }

  /// Check if focus mode service is running
  Future<bool> isFocusServiceRunning() async {
    try {
      return await _focusChannel.invokeMethod('isFocusServiceRunning') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Check if a focus task was completed while app was in background.
  /// Returns the task ID if completed, null otherwise.
  /// Call this from the tasks screen on resume to sync completion state.
  Future<String?> checkFocusTaskCompleted() async {
    try {
      // Read directly from native SharedPreferences via MethodChannel — bypasses Flutter cache
      final taskId = await _focusChannel.invokeMethod<String?>('getFocusCompletedTaskId');
      if (taskId != null) {
        debugPrint('FocusMode: Found completed task via native: $taskId');
      }
      return taskId;
    } on PlatformException catch (e) {
      debugPrint('FocusMode: Error checking completed task - ${e.message}');
      return null;
    }
  }
}
