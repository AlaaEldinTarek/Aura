import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for controlling silent mode automation
/// This service communicates with native Android code via MethodChannel
class SilentModeService {
  SilentModeService._();

  static final SilentModeService _instance = SilentModeService._();
  static SilentModeService get instance => _instance;

  static const String _channelName = 'com.aura.hala/silent_mode';
  late final MethodChannel _channel;

  bool _isInitialized = false;
  bool _isEnabled = true;
  int _durationMinutes = 20;

  /// Initialize the silent mode service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _channel = const MethodChannel(_channelName);

    // Set up method call handler for native callbacks
    _channel.setMethodCallHandler(_handleMethodCall);

    // Load user preferences
    final prefs = await _getSharedPreferences();
    _isEnabled = prefs.getBool('silent_mode_enabled') ?? true;
    _durationMinutes = prefs.getInt('silent_mode_duration') ?? 20;

    _isInitialized = true;
    debugPrint('SilentModeService: Initialized (enabled: $_isEnabled, duration: $_durationMinutes min)');
  }

  /// Handle method calls from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('SilentModeService: Received call from native: ${call.method}');
    return null;
  }

  /// Get shared preferences helper
  Future<dynamic> _getSharedPreferences() async {
    // Use the shared_preferences package
    final prefs = await (const MethodChannel('flutter/plugins/shared_preferences'))
        .invokeMethod('getAll');
    return prefs;
  }

  /// Enable or disable silent mode automation
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    debugPrint('SilentModeService: Silent mode enabled set to $enabled');

    // Save to preferences
    try {
      await _channel.invokeMethod('setEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('SilentModeService: Error setting enabled state: $e');
    }
  }

  /// Set the duration of silent mode in minutes
  Future<void> setDuration(int minutes) async {
    _durationMinutes = minutes;
    debugPrint('SilentModeService: Silent mode duration set to $minutes minutes');

    // Save to preferences
    try {
      await _channel.invokeMethod('setDuration', {'duration': minutes});
    } catch (e) {
      debugPrint('SilentModeService: Error setting duration: $e');
    }
  }

  /// Get current enabled state
  bool get isEnabled => _isEnabled;

  /// Get current duration in minutes
  int get durationMinutes => _durationMinutes;

  /// Cancel all silent mode (dismiss notification, restore ringer)
  Future<void> cancelAll() async {
    try {
      await _channel.invokeMethod('cancelAll');
      debugPrint('SilentModeService: Cancelled all silent mode');
    } catch (e) {
      debugPrint('SilentModeService: Error cancelling silent mode: $e');
    }
  }

  /// Dispose of resources
  void dispose() {
    _isInitialized = false;
    debugPrint('SilentModeService: Disposed');
  }
}
