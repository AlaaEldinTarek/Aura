import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../models/prayer_time.dart';
import 'desktop_adhan_service.dart';

/// System-tray icon + minimize-to-tray for Windows/macOS/Linux.
/// Shows next prayer in the tray menu and intercepts the window close
/// button to hide the app instead of quitting it.
class DesktopTrayService with TrayListener, WindowListener {
  DesktopTrayService._();
  static final instance = DesktopTrayService._();

  bool _initialized = false;
  String? _nextLabel;
  bool _adhanPlaying = false;
  bool _isHidden = false;

  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  Future<void> initialize() async {
    if (!isDesktop || _initialized) return;
    try {
      trayManager.addListener(this);
      windowManager.addListener(this);

      // Intercept OS close button → hide to tray instead
      await windowManager.setPreventClose(true);

      await trayManager.setIcon(_iconPath());
      await trayManager.setToolTip('Aura | هالة');
      await _rebuildMenu();

      _initialized = true;
      debugPrint('✅ [TRAY] System tray initialized');
    } catch (e) {
      debugPrint('⚠️ [TRAY] Init error: $e');
    }
  }

  String _iconPath() {
    // Flutter bundles assets under {exe_dir}/data/flutter_assets/
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return '$exeDir/data/flutter_assets/assets/tray_icon.ico';
  }

  /// Update tray menu label when prayer times change.
  Future<void> updateNextPrayer(PrayerTime? nextPrayer) async {
    if (!isDesktop || !_initialized) return;
    if (nextPrayer == null) {
      _nextLabel = 'No more prayers today';
    } else {
      _nextLabel = 'Next: ${nextPrayer.name} at ${_fmt(nextPrayer.time)}';
    }
    await _rebuildMenu();
  }

  String _fmt(DateTime t) {
    final h = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour >= 12 ? "PM" : "AM"}';
  }

  /// Call when adhan starts/stops to show or hide the Stop Adhan menu item.
  Future<void> setAdhanPlaying(bool playing) async {
    if (_adhanPlaying == playing) return;
    _adhanPlaying = playing;
    await _rebuildMenu();
  }

  Future<void> _rebuildMenu() async {
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(
        key: 'next_prayer',
        label: _nextLabel ?? 'Loading prayer times…',
        disabled: true,
      ),
      MenuItem.separator(),
      if (_adhanPlaying)
        MenuItem(key: 'stop_adhan', label: '🔇 Stop Adhan'),
      if (_adhanPlaying)
        MenuItem.separator(),
      MenuItem(key: 'open', label: 'Open Aura'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit'),
    ]));
  }

  void dispose() {
    if (!isDesktop) return;
    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }

  // ── TrayListener ──────────────────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() => _showWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'stop_adhan':
        DesktopAdhanService.instance.stop();
        setAdhanPlaying(false);
        break;
      case 'open':
        showWindow();
        break;
      case 'quit':
        _quit();
        break;
    }
  }

  /// True when the window is hidden to the system tray (user pressed X).
  bool get isHidden => _isHidden;

  // ── WindowListener ────────────────────────────────────────────────────────

  @override
  void onWindowClose() async {
    _isHidden = true;
    windowManager.hide();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Bring the window to front (called from tray click or notification body tap).
  Future<void> showWindow() => _showWindow();

  Future<void> _showWindow() async {
    _isHidden = false;
    if (!await windowManager.isVisible()) await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quit() async {
    try {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } catch (_) {}
    exit(0);
  }
}
