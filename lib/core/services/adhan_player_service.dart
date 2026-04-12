import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

/// Service for playing Adhan (Islamic call to prayer) audio
/// Uses native Android MediaPlayer through platform channel for reliable background playback
class AdhanPlayerService {
  AdhanPlayerService._();

  static final AdhanPlayerService _instance = AdhanPlayerService._();
  static AdhanPlayerService get instance => _instance;

  static const String _channelName = 'com.aura.hala/adhan';
  late final MethodChannel _channel;

  bool _isInitialized = false;
  bool _isEnabled = true;
  bool _vibrationEnabled = true;

  /// Initialize the adhan player service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _channel = const MethodChannel(_channelName);

    // Set up method call handler for native callbacks
    _channel.setMethodCallHandler(_handleMethodCall);

    // Load user preferences
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('adhan_enabled') ?? true;
    _vibrationEnabled = prefs.getBool('adhan_vibration_enabled') ?? true;

    // Check with native side
    try {
      final nativeEnabled = await _channel.invokeMethod('isAdhanEnabled');
      if (nativeEnabled is bool) {
        _isEnabled = nativeEnabled;
      }
    } catch (e) {
      debugPrint('AdhanPlayerService: Could not check native state: $e');
    }

    _isInitialized = true;
    debugPrint('AdhanPlayerService: Initialized (enabled: $_isEnabled)');
  }

  /// Handle method calls from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('AdhanPlayerService: Received call from native: ${call.method}');
    return null;
  }

  /// Play adhan for a specific prayer
  Future<void> playAdhan(String prayerName) async {
    if (!_isEnabled) {
      debugPrint('AdhanPlayerService: Adhan is disabled, not playing');
      return;
    }

    try {
      debugPrint('AdhanPlayerService: Requesting adhan for $prayerName');

      // Vibrate if Adhan vibration is enabled
      if (_vibrationEnabled && (await Vibration.hasVibrator() ?? false)) {
        await Vibration.vibrate(duration: 500, amplitude: 255);
        debugPrint('AdhanPlayerService: Vibrated for adhan');
      }

      await _channel.invokeMethod('playAdhan', {'prayerName': prayerName});
      debugPrint('AdhanPlayerService: Adhan started for $prayerName');
    } catch (e) {
      debugPrint('AdhanPlayerService: Error playing adhan: $e');
    }
  }

  /// Stop the currently playing adhan
  Future<void> stopAdhan() async {
    try {
      await _channel.invokeMethod('stopAdhan');
      debugPrint('AdhanPlayerService: Adhan stopped');
    } catch (e) {
      debugPrint('AdhanPlayerService: Error stopping adhan: $e');
    }
  }

  /// Set enabled state for adhan
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adhan_enabled', enabled);

    try {
      await _channel.invokeMethod('setAdhanEnabled', {'enabled': enabled});
    } catch (e) {
      debugPrint('AdhanPlayerService: Error setting enabled state: $e');
    }

    debugPrint('AdhanPlayerService: Enabled set to $enabled');
  }

  /// Get current enabled state
  bool get isEnabled => _isEnabled;

  /// Get Adhan vibration enabled state
  bool get isVibrationEnabled => _vibrationEnabled;

  /// Set Adhan vibration enabled state
  Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adhan_vibration_enabled', enabled);
    debugPrint('AdhanPlayerService: Vibration enabled set to $enabled');
  }

  /// Check if adhan is currently playing (native side only)
  Future<bool> isPlaying() async {
    // This would require a method call to native side
    // For now, return false as we don't track state locally
    return false;
  }

  /// Toggle adhan on/off
  Future<bool> toggleAdhan() async {
    final newState = !_isEnabled;
    await setEnabled(newState);
    return newState;
  }

  /// Set custom adhan file path
  Future<void> setCustomAdhan(String? path) async {
    if (path != null) {
      await _channel.invokeMethod('setCustomAdhan', {'path': path});
      debugPrint('AdhanPlayerService: Custom adhan set to $path');
    }
  }

  /// Get custom adhan file path
  Future<String?> getCustomAdhan() async {
    try {
      final path = await _channel.invokeMethod('getCustomAdhan');
      return path as String?;
    } catch (e) {
      debugPrint('AdhanPlayerService: Error getting custom adhan: $e');
      return null;
    }
  }

  /// Dispose of resources
  void dispose() {
    _isInitialized = false;
    debugPrint('AdhanPlayerService: Disposed');
  }
}
