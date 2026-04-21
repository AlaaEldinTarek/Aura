import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing foreground service to keep app alive in background
/// This is critical for prayer time alerts and adhan playback
class BackgroundServiceManager {
  BackgroundServiceManager._();

  static final BackgroundServiceManager instance = BackgroundServiceManager._();

  static const MethodChannel _channel = MethodChannel('com.aura.hala/background_service');

  bool _isServiceRunning = false;
  bool _isInitialized = false;

  /// Initialize the background service manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _isServiceRunning = prefs.getBool('foreground_service_enabled') ?? false;

    _isInitialized = true;
    debugPrint('BackgroundServiceManager: Initialized (running: $_isServiceRunning)');

    // Check if service is actually running on native side
    try {
      final isRunning = await _channel.invokeMethod('isForegroundServiceRunning');
      if (isRunning is bool) {
        _isServiceRunning = isRunning;
        debugPrint('BackgroundServiceManager: Native service running: $isRunning');
      }
    } catch (e) {
      debugPrint('BackgroundServiceManager: Could not check native state: $e');
    }
  }

  /// Start the foreground service
  /// Call this when user enables prayer alerts
  Future<bool> startForegroundService() async {
    try {
      // Check if background notification is enabled
      final prefs = await SharedPreferences.getInstance();
      final backgroundNotificationEnabled = prefs.getBool('background_notification_enabled') ?? true;

      if (!backgroundNotificationEnabled) {
        debugPrint('BackgroundServiceManager: Background notification disabled, skipping service start');
        return false;
      }

      await _channel.invokeMethod('startForegroundService');
      _isServiceRunning = true;

      await prefs.setBool('foreground_service_enabled', true);

      debugPrint('BackgroundServiceManager: Foreground service started');
      return true;
    } catch (e) {
      debugPrint('BackgroundServiceManager: Error starting service: $e');
      return false;
    }
  }

  /// Stop the foreground service
  /// Call this when user disables prayer alerts
  Future<bool> stopForegroundService() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
      _isServiceRunning = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('foreground_service_enabled', false);

      debugPrint('BackgroundServiceManager: Foreground service stopped');
      return true;
    } catch (e) {
      debugPrint('BackgroundServiceManager: Error stopping service: $e');
      return false;
    }
  }

  /// Update prayer times in the foreground service
  /// Call this when prayer times change or when moving to the next prayer
  Future<void> updatePrayerTimes({
    required Map<String, String> prayerTimes,
    required String? nextPrayerName,
    required String? nextPrayerNameAr,
    required int? nextPrayerTime,
    required String language,
    Map<String, String>? iqamaTimes,
  }) async {
    try {
      await _channel.invokeMethod('updatePrayerTimes', {
        'prayerTimes': prayerTimes,
        'nextPrayerName': nextPrayerName,
        'nextPrayerNameAr': nextPrayerNameAr,
        'nextPrayerTime': nextPrayerTime,
        'language': language,
        if (iqamaTimes != null) 'iqamaTimes': iqamaTimes,
      });
      debugPrint('BackgroundServiceManager: Prayer times updated for notification');
    } catch (e) {
      debugPrint('BackgroundServiceManager: Error updating prayer times: $e');
    }
  }

  /// Check if the foreground service is running
  bool get isRunning => _isServiceRunning;

  /// Toggle foreground service
  Future<bool> toggle() async {
    if (_isServiceRunning) {
      return await stopForegroundService();
    } else {
      return await startForegroundService();
    }
  }
}
