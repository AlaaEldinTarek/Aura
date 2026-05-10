import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform, File;
import 'package:path_provider/path_provider.dart';

/// Plays adhan audio on Windows/macOS/Linux using audioplayers
class DesktopAdhanService {
  DesktopAdhanService._();
  static final DesktopAdhanService instance = DesktopAdhanService._();

  final AudioPlayer _player = AudioPlayer();
  bool _isEnabled = true;
  bool _isInitialized = false;

  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  Future<void> initialize() async {
    if (!isDesktop || _isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('adhan_enabled') ?? true;
    _isInitialized = true;
    debugPrint('DesktopAdhanService: Initialized (enabled: $_isEnabled)');
  }

  Future<void> playAdhan(String prayerName) async {
    if (!isDesktop) return;
    if (!_isEnabled) {
      debugPrint('DesktopAdhanService: Adhan disabled, skipping');
      return;
    }

    try {
      await _player.stop();

      // Try downloaded adhan file first (same path audioplayers would use on desktop)
      final docDir = await getApplicationDocumentsDirectory();
      final downloadedFile = File('${docDir.path}/adhans/$prayerName.mp3');
      if (await downloadedFile.exists()) {
        await _player.play(DeviceFileSource(downloadedFile.path));
        debugPrint('DesktopAdhanService: Playing downloaded adhan for $prayerName');
        return;
      }

      // Fallback to bundled adhan asset
      await _player.play(AssetSource('audio/adhan.mp3'));
      debugPrint('DesktopAdhanService: Playing bundled adhan for $prayerName');
    } catch (e) {
      debugPrint('DesktopAdhanService: Error playing adhan - $e');
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  void dispose() {
    _player.dispose();
  }
}
