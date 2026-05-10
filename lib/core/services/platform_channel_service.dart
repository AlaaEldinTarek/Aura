import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

/// Service for platform-specific operations via MethodChannel
class PlatformChannelService {
  PlatformChannelService._();

  static const MethodChannel _prayerChannel = MethodChannel('com.aura.hala/prayer_alarms');
  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  /// Check if battery optimization is disabled
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!_isAndroid) return true;
    try {
      final result = await _prayerChannel.invokeMethod('isIgnoringBatteryOptimizations');
      return result as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if exact alarms can be scheduled (Android 12+)
  static Future<bool> canScheduleExactAlarms() async {
    if (!_isAndroid) return true;
    try {
      final result = await _prayerChannel.invokeMethod('canScheduleExactAlarms');
      return result as bool? ?? true;
    } catch (e) {
      return true;
    }
  }

  /// Open battery optimization settings
  static Future<void> openBatteryOptimizationSettings() async {
    if (!_isAndroid) return;
    try {
      await _prayerChannel.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      debugPrint('⚠️ [PLATFORM] Failed to open battery optimization via channel: $e');
      await openAppSettings();
    }
  }

  /// Open exact alarm settings
  static Future<void> openExactAlarmSettings() async {
    if (!_isAndroid) return;
    try {
      await _prayerChannel.invokeMethod('openExactAlarmSettings');
    } catch (e) {
      // Ignore error
    }
  }
}
