import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

/// Service for platform-specific operations via MethodChannel
class PlatformChannelService {
  PlatformChannelService._();

  static const MethodChannel _prayerChannel = MethodChannel('com.aura.hala/prayer_alarms');
  static bool get _isAndroid =>
      debugIsAndroid ?? (!kIsWeb && Platform.isAndroid);

  /// Test hooks: force the platform check, and replace `openAppSettings`.
  @visibleForTesting
  static bool? debugIsAndroid;
  @visibleForTesting
  static Future<bool> Function()? debugOpenAppSettings;

  static Future<void> _openAppSettings() async {
    final override = debugOpenAppSettings;
    if (override != null) {
      await override();
    } else {
      await openAppSettings();
    }
  }

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

  /// True on a Huawei (EMUI) phone, by the manufacturer name, so the "App launch"
  /// tile can be shown. Always false off Android and on error.
  static Future<bool> isEmuiDevice() async {
    if (!_isAndroid) return false;
    try {
      final result = await _prayerChannel.invokeMethod<bool>('isEmuiDevice');
      return result ?? false;
    } catch (e) {
      debugPrint('⚠️ [PLATFORM] isEmuiDevice failed: $e');
      return false;
    }
  }

  /// Open Aura's app details screen (the "Open app details" button of the App
  /// launch dialog). Dart only, no channel call; no-op off Android.
  static Future<void> openAppDetails() async {
    if (!_isAndroid) return;
    await _openAppSettings();
  }

  /// Open the EMUI "App launch" screen (Kotlin tries the EMUI screens, then the app
  /// details screen). When the channel fails, or nothing opened, open app settings.
  static Future<void> openAutoLaunchSettings() async {
    if (!_isAndroid) return;
    try {
      final opened = await _prayerChannel.invokeMethod<bool>('openAutoLaunchSettings');
      if (opened == false) await _openAppSettings();
    } catch (e) {
      debugPrint('⚠️ [PLATFORM] Failed to open auto-launch settings via channel: $e');
      await _openAppSettings();
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
