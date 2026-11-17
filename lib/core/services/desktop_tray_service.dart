import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart'
    show getApplicationSupportDirectory;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../models/prayer_time.dart';
import 'desktop_adhan_service.dart';
import 'desktop_prayer_scheduler.dart';

/// Lets an action through once: [tryAcquire] is true on the first call and
/// false on every later call. Used by the tray Quit, which the tray plugin
/// triggers twice per click (item `onClick` + `onTrayMenuItemClick`).
@visibleForTesting
class RunOnceGuard {
  bool _acquired = false;

  bool tryAcquire() {
    if (_acquired) return false;
    _acquired = true;
    return true;
  }
}

/// Lets a click through once per event-loop turn, per key. The tray plugin
/// calls a menu item's `onClick` and then `onTrayMenuItemClick` in the same
/// synchronous run (`tray_manager` `tray_manager.dart:61-64`), so both calls
/// of ONE click share a turn; the next real click comes in a later turn.
/// (Unlike [RunOnceGuard], which blocks every call after the first.)
@visibleForTesting
class SameTurnGuard {
  final Set<String> _busy = {};

  bool tryAcquire(String key) {
    if (!_busy.add(key)) return false;
    Timer.run(() => _busy.remove(key));
    return true;
  }
}

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
  final RunOnceGuard _quitGuard = RunOnceGuard();
  final SameTurnGuard _clickGuard = SameTurnGuard();

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

  // ── Menu items ────────────────────────────────────────────────────────────
  // Created ONCE and reused in every rebuild, so their ids never change. A
  // click is matched to an item by id only; a menu already on screen keeps the
  // ids it was built with, so new ids on a rebuild made every click find no
  // item (docs/designs/tray-quit-fix.md, "T3 result and T2b").

  static const _loadingLabel = 'Loading prayer times…';

  late final MenuItem _nextPrayerItem = MenuItem(
    key: 'next_prayer',
    label: _loadingLabel,
    disabled: true,
  );
  late final MenuItem _stopAdhanItem = MenuItem(
    key: 'stop_adhan',
    label: '🔇 Stop Adhan',
    onClick: (_) => _stopAdhanFromMenu(),
  );
  late final MenuItem _openItem = MenuItem(
    key: 'open',
    label: 'Open Aura',
    onClick: (_) => showWindow(),
  );
  late final MenuItem _testNotifItem = MenuItem(
    key: 'test_notif',
    label: '🔔 Test Notification',
    onClick: (_) {
      debugPrint('🔔 [TRAY] test_notif onClick fired');
      _fireTestAdhanFromMenu();
    },
  );
  late final MenuItem _quitItem = MenuItem(
    key: 'quit',
    label: 'Quit',
    onClick: (_) => _quit(),
  );
  late final MenuItem _sepAfterNextPrayer = MenuItem.separator();
  late final MenuItem _sepAfterStopAdhan = MenuItem.separator();
  late final MenuItem _sepAfterOpen = MenuItem.separator();
  late final MenuItem _sepAfterTestNotif = MenuItem.separator();

  // What the last menu sent to the tray showed; null until the first send.
  String? _sentLabel;
  bool? _sentAdhanPlaying;

  /// The tray menu for the given state, built from the reused items. Only the
  /// label of the disabled next-prayer item changes between builds. The Test
  /// Notification item and its separator are in the menu only when
  /// [includeTestItem] is true, and it defaults to [kDebugMode], so only debug
  /// builds show the item.
  @visibleForTesting
  Menu buildMenu({
    required String? nextLabel,
    required bool adhanPlaying,
    bool includeTestItem = kDebugMode,
  }) {
    _nextPrayerItem.label = nextLabel ?? _loadingLabel;
    return Menu(items: [
      _nextPrayerItem,
      _sepAfterNextPrayer,
      if (adhanPlaying) _stopAdhanItem,
      if (adhanPlaying) _sepAfterStopAdhan,
      _openItem,
      _sepAfterOpen,
      if (includeTestItem) _testNotifItem,
      if (includeTestItem) _sepAfterTestNotif,
      _quitItem,
    ]);
  }

  Future<void> _rebuildMenu() async {
    final label = _nextLabel ?? _loadingLabel;
    final adhanPlaying = _adhanPlaying;
    // Nothing visible changed since the last send: do not resend.
    if (_sentLabel == label && _sentAdhanPlaying == adhanPlaying) return;
    await trayManager.setContextMenu(
      buildMenu(nextLabel: _nextLabel, adhanPlaying: adhanPlaying),
    );
    _sentLabel = label;
    _sentAdhanPlaying = adhanPlaying;
    debugPrint('🔁 [TRAY] menu rebuilt: $label');
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
    debugPrint('🖱️ [TRAY] menu click: ${menuItem.key}');
    switch (menuItem.key) {
      case 'stop_adhan':
        _stopAdhanFromMenu();
        break;
      case 'open':
        showWindow();
        break;
      case 'test_notif':
        _fireTestAdhanFromMenu();
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
    await windowManager.setSkipTaskbar(false);
    if (!await windowManager.isVisible()) await windowManager.show();
    await windowManager.focus();
  }

  /// "Stop Adhan" from the tray menu. The plugin reports one click twice
  /// (item `onClick` + `onTrayMenuItemClick`); only the first runs.
  void _stopAdhanFromMenu() {
    if (!_clickGuard.tryAcquire('stop_adhan')) {
      debugPrint('⚠️ [TRAY] stop_adhan: second call ignored');
      return;
    }
    DesktopAdhanService.instance.stop();
    setAdhanPlaying(false);
  }

  /// "Test Notification" from the tray menu. Same double report as above;
  /// without the guard one click showed two toasts and played the adhan twice.
  void _fireTestAdhanFromMenu() {
    if (!_clickGuard.tryAcquire('test_notif')) {
      debugPrint('⚠️ [TRAY] test_notif: second call ignored');
      return;
    }
    DesktopPrayerScheduler.instance.fireTestAdhan();
  }

  /// Orderly quit with a hard fallback (docs/designs/tray-quit-fix.md,
  /// Decision, Option B). Runs once; a second call is ignored.
  Future<void> _quit() async {
    if (!_quitGuard.tryAcquire()) {
      debugPrint('⚠️ [TRAY] Quit: second call ignored');
      return;
    }
    debugPrint('🚪 [TRAY] Quit requested');
    await _resolveQuitLogPath();
    _writeQuitLog('quit clicked');

    // Let the tray menu close first.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    debugPrint('⏳ [TRAY] Quit: menu wait done');

    // Started BEFORE the awaited steps so a step that never returns cannot
    // block it.
    Timer(const Duration(seconds: 2), () {
      debugPrint('⏰ [TRAY] Quit: fallback timer fired, calling exit(0)');
      _writeQuitLog('fallback fired');
      exit(0);
    });
    debugPrint('⏲️ [TRAY] Quit: fallback timer started (2 s)');

    try {
      await trayManager.destroy();
      debugPrint('✅ [TRAY] Quit: tray icon destroyed');
      _writeQuitLog('tray destroyed');
    } catch (e) {
      debugPrint('⚠️ [TRAY] Quit: tray destroy error: $e');
    }

    try {
      await windowManager.setPreventClose(false);
      debugPrint('✅ [TRAY] Quit: preventClose off');
    } catch (e) {
      debugPrint('⚠️ [TRAY] Quit: setPreventClose error: $e');
    }

    try {
      debugPrint('🚪 [TRAY] Quit: window destroy called');
      await windowManager.destroy();
      debugPrint('✅ [TRAY] Quit: window destroy returned');
      _writeQuitLog('window destroyed');
    } catch (e) {
      debugPrint('⚠️ [TRAY] Quit: window destroy error: $e');
    }
  }

  // ── TEMPORARY quit file log ───────────────────────────────────────────────
  // TEMPORARY: remove this block and its `_writeQuitLog` calls once the owner
  // confirms the Quit fix works. See docs/designs/tray-quit-fix.md, Follow-ups
  // ("Remove the temporary file log").

  static const _quitLogFileName = 'tray_quit_log.txt';
  String? _quitLogPath;

  /// Finds the log file path once and prints it. Bounded by a timeout and
  /// never throws, so it cannot stop the quit.
  Future<void> _resolveQuitLogPath() async {
    try {
      final dir = await getApplicationSupportDirectory()
          .timeout(const Duration(seconds: 1));
      _quitLogPath = '${dir.path}${Platform.pathSeparator}$_quitLogFileName';
      debugPrint('📝 [TRAY] Quit log file: $_quitLogPath');
    } catch (e) {
      debugPrint('⚠️ [TRAY] Quit log path error: $e');
    }
  }

  /// Appends "<timestamp> <step>" and flushes at once. Synchronous on
  /// purpose: the line is on disk before the next quit step starts.
  void _writeQuitLog(String step) {
    final path = _quitLogPath;
    if (path == null) return;
    try {
      File(path).writeAsStringSync(
        '${DateTime.now().toIso8601String()} $step\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      debugPrint('⚠️ [TRAY] Quit log write error: $e');
    }
  }
}
