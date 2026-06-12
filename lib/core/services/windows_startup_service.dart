import 'dart:io' show Platform, Process;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the "start with Windows" registry entry (HKCU Run key).
/// The entry is re-registered on every launch (exe path changes across MSIX
/// updates), but only while the user has the setting enabled.
class WindowsStartupService {
  WindowsStartupService._();

  static const String prefKey = 'windows_startup_enabled';
  static const String _runKey =
      r'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';
  static const String _valueName = 'Aura';

  static bool get _isWindows => !kIsWeb && Platform.isWindows;

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, enabled);
    if (enabled) {
      await register();
    } else {
      await unregister();
    }
  }

  /// Called on every Windows launch — keeps the registry entry current
  /// across MSIX updates, unless the user disabled auto-start.
  static Future<void> registerIfEnabled() async {
    if (!_isWindows) return;
    if (await isEnabled()) await register();
  }

  static Future<void> register() async {
    if (!_isWindows) return;
    try {
      final exePath = Platform.resolvedExecutable;
      final result = await Process.run('reg', [
        'add', _runKey,
        '/v', _valueName,
        '/t', 'REG_SZ',
        '/d', '"$exePath" --startup',
        '/f',
      ]);
      if (result.exitCode == 0) {
        debugPrint('✅ [STARTUP] Windows startup registered: $exePath');
      } else {
        debugPrint('⚠️ [STARTUP] reg add failed: ${result.stderr}');
      }
    } catch (e) {
      debugPrint('⚠️ [STARTUP] Failed to register Windows startup: $e');
    }
  }

  static Future<void> unregister() async {
    if (!_isWindows) return;
    try {
      final result =
          await Process.run('reg', ['delete', _runKey, '/v', _valueName, '/f']);
      if (result.exitCode == 0) {
        debugPrint('✅ [STARTUP] Windows startup entry removed');
      } else {
        // Exit code 1 = value did not exist — already unregistered
        debugPrint('ℹ️ [STARTUP] reg delete: ${result.stderr}');
      }
    } catch (e) {
      debugPrint('⚠️ [STARTUP] Failed to remove Windows startup: $e');
    }
  }
}
