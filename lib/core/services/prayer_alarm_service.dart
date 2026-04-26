import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/prayer_time.dart';
import '../models/prayer_record.dart';
import 'background_service_manager.dart';
import 'notification_service.dart';
import 'prayer_tracking_service.dart';

/// Service for scheduling native Android alarms at exact prayer times
/// These alarms trigger adhan playback via PrayerAlarmReceiver
class PrayerAlarmService {
  PrayerAlarmService._();

  static final PrayerAlarmService _instance = PrayerAlarmService._();
  static PrayerAlarmService get instance => _instance;

  static const String _channelName = 'com.aura.hala/prayer_alarms';
  late final MethodChannel _channel;

  bool _isInitialized = false;

  /// Initialize the prayer alarm service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _channel = const MethodChannel(_channelName);

    // Set up method call handler for native callbacks
    _channel.setMethodCallHandler(_handleMethodCall);

    _isInitialized = true;
    debugPrint('PrayerAlarmService: Initialized');
  }

  /// Handle method calls from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('PrayerAlarmService: Received call from native: ${call.method}');

    // Handle prayer alarm triggered from native Android
    if (call.method == 'onPrayerAlarmTriggered') {
      final arguments = call.arguments as Map<dynamic, dynamic>?;
      if (arguments != null) {
        final prayerName = arguments['prayerName'] as String?;
        final prayerNameAr = arguments['prayerNameAr'] as String?;
        final language = arguments['language'] as String? ?? 'en';

        if (prayerName != null && prayerNameAr != null) {
          debugPrint('🔔 [PRAYER_ALARM] Alarm triggered for $prayerName');

          // Show notification at exact prayer time
          try {
            await NotificationService.instance.showPrayerTimeNotification(
              prayerName: prayerName,
              prayerNameAr: prayerNameAr,
              language: language,
            );
          } catch (e) {
            debugPrint('❌ [PRAYER_ALARM] Error showing notification: $e');
          }
        }
      }
    }

    return null;
  }

  /// Schedule a native alarm for a specific prayer time
  /// This will trigger adhan playback at the exact prayer time
  Future<void> schedulePrayerAlarm({
    required String prayerName,
    required String prayerNameAr,
    required DateTime prayerTime,
    required int requestCode,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final timeMillis = prayerTime.millisecondsSinceEpoch;

      await _channel.invokeMethod('schedulePrayerAlarm', {
        'prayerName': prayerName,
        'prayerNameAr': prayerNameAr,
        'prayerTime': timeMillis,
        'requestCode': requestCode,
      });

      debugPrint('PrayerAlarmService: Scheduled alarm for $prayerName at ${prayerTime.toLocal()}');
    } catch (e) {
      debugPrint('PrayerAlarmService: Error scheduling alarm for $prayerName - $e');
    }
  }

  /// Schedule a 10-minute reminder alarm before prayer time
  /// This will show a notification 10 minutes before the prayer
  Future<void> scheduleReminderAlarm({
    required String prayerName,
    required String prayerNameAr,
    required DateTime prayerTime,
    required int requestCode,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await _channel.invokeMethod('scheduleReminderAlarm', {
        'prayerName': prayerName,
        'prayerNameAr': prayerNameAr,
        'prayerTime': prayerTime.millisecondsSinceEpoch,
        'requestCode': requestCode,
      });

      debugPrint('PrayerAlarmService: Scheduled reminder alarm for $prayerName (10 min before ${prayerTime.toLocal()})');
    } catch (e) {
      debugPrint('PrayerAlarmService: Error scheduling reminder alarm for $prayerName - $e');
    }
  }

  /// Schedule native alarms for all prayer times
  Future<void> scheduleDailyPrayerAlarms(List<PrayerTime> prayerTimes) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Start foreground service to keep app alive for prayer alerts
    try {
      await BackgroundServiceManager.instance.startForegroundService();
      debugPrint('✅ [PRAYER ALARMS] Foreground service started for prayer alerts');
    } catch (e) {
      debugPrint('⚠️ [PRAYER ALARMS] Could not start foreground service: $e');
    }

    debugPrint('🔔 [PRAYER ALARMS] Scheduling alarms for ${prayerTimes.length} prayers');

    // Notification IDs for each prayer (must match native IDs)
    const notificationIds = {
      'Fajr': 1001,
      'Sunrise': 1002,
      'Zuhr': 1003,
      'Asr': 1004,
      'Maghrib': 1005,
      'Isha': 1006,
    };

    final now = DateTime.now();

    for (final prayer in prayerTimes) {
      // Skip Sunrise for notifications and reminders
      if (prayer.name == 'Sunrise') continue;

      final requestCode = notificationIds[prayer.name] ?? 1000;

      // Only schedule if prayer time is in the future
      if (prayer.time.isAfter(now)) {
        // Schedule the prayer time alarm (for adhan)
        await schedulePrayerAlarm(
          prayerName: prayer.name,
          prayerNameAr: prayer.nameAr,
          prayerTime: prayer.time,
          requestCode: requestCode,
        );

        // Schedule the 10-minute reminder alarm
        await scheduleReminderAlarm(
          prayerName: prayer.name,
          prayerNameAr: prayer.nameAr,
          prayerTime: prayer.time,
          requestCode: requestCode,
        );
      } else {
        debugPrint('⏭️ [PRAYER ALARMS] Skipping ${prayer.name} - time has passed');
      }
    }
  }

  /// Test adhan playback immediately (for debugging)
  Future<void> testAdhanNow(String prayerName) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      debugPrint('🧪 [PRAYER ALARMS] Testing adhan for $prayerName NOW');
      await _channel.invokeMethod('testAdhanNow', {'prayerName': prayerName});
    } catch (e) {
      debugPrint('❌ [PRAYER ALARMS] Error testing adhan - $e');
    }
  }

  /// Check if exact alarm permission is granted
  Future<bool> canScheduleExactAlarms() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final result = await _channel.invokeMethod('canScheduleExactAlarms');
      return result == true;
    } catch (e) {
      debugPrint('❌ [PRAYER ALARMS] Error checking exact alarm permission - $e');
      return false;
    }
  }

  /// Open exact alarm settings for the user
  Future<void> openExactAlarmSettings() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await _channel.invokeMethod('openExactAlarmSettings');
    } catch (e) {
      debugPrint('❌ [PRAYER ALARMS] Error opening settings - $e');
    }
  }

  /// Cancel all prayer alarms
  Future<void> cancelAllAlarms() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await _channel.invokeMethod('cancelAllPrayerAlarms');
      debugPrint('PrayerAlarmService: All alarms cancelled');
    } catch (e) {
      debugPrint('PrayerAlarmService: Error cancelling alarms - $e');
    }
  }

  /// Get prayer statuses saved by native side (from notification action buttons)
  /// Returns map like {"prayer_status_Zuhr_2026-04-26": "on_time", ...}
  Future<Map<String, String>> getNativePrayerStatuses() async {
    if (!_isInitialized) await initialize();
    try {
      final result = await _channel.invokeMethod('getNativePrayerStatuses');
      if (result is Map) {
        return result.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (e) {
      debugPrint('PrayerAlarmService: Error getting native statuses - $e');
    }
    return {};
  }

  /// Clear a specific native prayer status after syncing
  Future<void> clearNativePrayerStatus(String key) async {
    if (!_isInitialized) await initialize();
    try {
      await _channel.invokeMethod('clearNativePrayerStatus', {'key': key});
    } catch (e) {
      debugPrint('PrayerAlarmService: Error clearing native status - $e');
    }
  }

  /// Sync native prayer statuses to Firestore
  /// Called on app resume to pick up any statuses saved while app was in background
  Future<void> syncNativePrayerStatuses(String userId) async {
    try {
      final statuses = await getNativePrayerStatuses();
      if (statuses.isEmpty) return;

      debugPrint('🔄 [SYNC] Found ${statuses.length} native prayer statuses to sync');

      for (final entry in statuses.entries) {
        final key = entry.key; // e.g. "prayer_status_Zuhr_2026-04-26"
        final status = entry.value; // "on_time", "late", "missed"

        // Parse: prayer_status_{name}_{date}
        final parts = key.replaceFirst('prayer_status_', '').split('_');
        if (parts.length < 2) continue;

        final dateStr = parts.last; // "2026-04-26"
        final prayerName = parts.sublist(0, parts.length - 1).join('_'); // "Zuhr"

        // Map status to PrayerStatus
        final prayerStatus = status == 'on_time'
            ? PrayerStatus.onTime
            : status == 'late'
                ? PrayerStatus.late
                : PrayerStatus.missed;

        final date = DateTime.parse(dateStr);

        await PrayerTrackingService.instance.recordPrayer(
          userId: userId,
          prayerName: prayerName,
          date: date,
          prayedAt: DateTime.now(),
          status: prayerStatus,
          method: PrayerMethod.alone,
          notes: 'Logged via notification reminder',
        );

        // Clear the native key after successful sync
        await clearNativePrayerStatus(key);
      }

      debugPrint('✅ [SYNC] Native prayer statuses synced to Firestore');
    } catch (e) {
      debugPrint('❌ [SYNC] Error syncing native prayer statuses - $e');
    }
  }

  /// Dispose of resources
  void dispose() {
    _isInitialized = false;
    debugPrint('PrayerAlarmService: Disposed');
  }
}
