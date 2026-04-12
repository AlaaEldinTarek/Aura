import 'package:flutter/services.dart';
import 'package:flutter/services.dart' as flutter;
import 'package:shared_preferences/shared_preferences.dart';

/// Utility class for haptic feedback
/// Provides consistent haptic feedback across the app
///
/// Simplified mode (Option C): Only important vibrations enabled by default
/// - Everyday interactions (navigation, buttons, toggles) → no vibration
/// - Important feedback (errors, adhan, notifications) → vibration
class HapticFeedback {
  HapticFeedback._();

  static const MethodChannel _channel = MethodChannel('flutter/vibration');

  /// SharedPreferences key for vibration enabled setting
  static const String _keyVibrationEnabled = 'vibration_enabled';
  static const String _keySimplifiedMode = 'vibration_simplified';

  /// Check if vibration is enabled
  static Future<bool> isVibrationEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyVibrationEnabled) ?? false; // Default OFF
    } catch (e) {
      return false;
    }
  }

  /// Check if simplified mode is enabled (only important vibrations)
  static Future<bool> isSimplifiedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keySimplifiedMode) ?? true; // Default ON
    } catch (e) {
      return true;
    }
  }

  /// Light haptic feedback for subtle feedback
  /// Only vibrates if vibration is enabled AND NOT in simplified mode
  static Future<void> light() async {
    try {
      if (await _shouldVibrate()) {
        await flutter.HapticFeedback.lightImpact();
      }
    } catch (e) {
      // Silently fail if haptic feedback is not available
    }
  }

  /// Medium haptic feedback for standard interactions
  /// Only vibrates for important feedback (errors, warnings)
  static Future<void> medium() async {
    try {
      // Medium is used for important feedback - always vibrate if enabled
      if (await isVibrationEnabled()) {
        await flutter.HapticFeedback.mediumImpact();
      }
    } catch (e) {
      // Silently fail if haptic feedback is not available
    }
  }

  /// Heavy haptic feedback for important actions
  /// Always vibrates (error feedback is critical)
  static Future<void> heavy() async {
    try {
      // Heavy is for critical feedback - always vibrate
      await flutter.HapticFeedback.heavyImpact();
    } catch (e) {
      // Silently fail if haptic feedback is not available
    }
  }

  /// Selection feedback for UI interactions
  /// Only vibrates if vibration is enabled AND NOT in simplified mode
  static Future<void> selection() async {
    try {
      if (await _shouldVibrate()) {
        await flutter.HapticFeedback.selectionClick();
      }
    } catch (e) {
      // Silently fail if haptic feedback is not available
    }
  }

  /// Vibrate for notification style feedback
  /// Always vibrates (notifications are important)
  static Future<void> notify() async {
    try {
      await _channel.invokeMethod('vibrate', [50]);
    } catch (e) {
      // Silently fail if vibration is not available
    }
  }

  /// Success feedback pattern
  /// Simplified: just a single light vibration (not double)
  static Future<void> success() async {
    await light();
  }

  /// Error feedback pattern
  /// Always vibrates (error feedback is critical)
  static Future<void> error() async {
    await heavy();
    await Future.delayed(const Duration(milliseconds: 100));
    await heavy();
  }

  /// Warning feedback pattern
  /// Uses medium which will vibrate only if enabled
  static Future<void> warning() async {
    await medium();
    await Future.delayed(const Duration(milliseconds: 50));
  }

  /// Button press feedback
  static Future<void> buttonPress() async {
    await light();
  }

  /// Toggle switch feedback
  static Future<void> toggle() async {
    await light();
  }

  /// Card tap feedback
  static Future<void> cardTap() async {
    await selection();
  }

  /// Check if vibration should happen for everyday interactions
  static Future<bool> _shouldVibrate() async {
    final vibrationEnabled = await isVibrationEnabled();
    final simplifiedMode = await isSimplifiedMode();

    // Vibrate only if enabled AND not in simplified mode
    return vibrationEnabled && !simplifiedMode;
  }
}
