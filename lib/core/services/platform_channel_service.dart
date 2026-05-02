import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for platform-specific operations via MethodChannel
class PlatformChannelService {
  PlatformChannelService._();

  static const MethodChannel _prayerChannel = MethodChannel('com.aura.hala/prayer_alarms');

  /// Check if battery optimization is disabled
  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final result = await _prayerChannel.invokeMethod('isIgnoringBatteryOptimizations');
      return result as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if exact alarms can be scheduled (Android 12+)
  static Future<bool> canScheduleExactAlarms() async {
    try {
      final result = await _prayerChannel.invokeMethod('canScheduleExactAlarms');
      return result as bool? ?? true;
    } catch (e) {
      return true;
    }
  }

  /// Open battery optimization settings
  static Future<void> openBatteryOptimizationSettings() async {
    try {
      await _prayerChannel.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      debugPrint('⚠️ [PLATFORM] Failed to open battery optimization via channel: $e');
      // Fallback: open app settings where user can disable battery optimization
      await openAppSettings();
    }
  }

  /// Open exact alarm settings
  static Future<void> openExactAlarmSettings() async {
    try {
      await _prayerChannel.invokeMethod('openExactAlarmSettings');
    } catch (e) {
      // Ignore error
    }
  }
}
