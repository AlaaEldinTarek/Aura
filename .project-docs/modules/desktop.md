# Windows desktop
Verified against code 2026-11-07 (reference/2026-11-07_DRIFT_REPORT.md). Scaling system: desktop-scaling.md.

## Build
```powershell
dart run msix:create --certificate-password <password>   # builds windows + wraps into MSIX (pubspec: certificate_path aura_signing.pfx, password omitted on purpose)
Add-AppxPackage -Path "build\windows\x64\runner\Release\aura_app.msix" -ForceApplicationShutdown
```

## MSIX versioning
- Every Windows build that replaces an installed package needs a strictly higher `msix_version` in `pubspec.yaml`
  (format `major.minor.patch.build`). Increment the last segment for each reinstall during development.
- Series `1.0.3.x`; current `1.0.3.114` (STATE.md tracks the live value).

## Desktop services
- `lib/core/services/desktop_notification_service.dart` — singleton (Windows/macOS/Linux) showing toasts via
  `local_notifier` (app name "Aura"; skips its own Start Menu shortcut under MSIX, deletes a stale `Aura.lnk`).
  Pre-prayer, post-prayer check, adhan, task, wird and daily-digest toasts; action buttons record prayer status /
  complete tasks through an attached `ProviderContainer`. In-process `Timer`s: task reminders (default 30 min before,
  9:00 without time), wird reminders (today's remaining times), digest 08:00 — not re-armed after sleep or next day (F52j).
  `notificationStream` feeds in-app banners; `showAchievementNotification` is a no-op.
- `lib/core/services/windows_startup_service.dart` — writes/removes HKCU `…\CurrentVersion\Run` value "Aura" via `reg`
  (`"<exe>" --startup`). Pref `windows_startup_enabled` defaults to **true** (F52m); `registerIfEnabled()` runs every
  launch (exe path changes per MSIX update). With `--startup`, `main.dart` starts hidden, tray only. Toggle: Settings →
  Desktop.
- Start-up prefs guard (F62): before the first prefs read (`registerIfEnabled`), `main.dart` calls
  `backUpUnreadablePrefsFile(getApplicationSupportDirectory())` (`prefs_file_recovery.dart`). An unreadable
  `shared_preferences.json` is renamed to `.unreadable-<timestamp>.bak` and logged `⚠️ [PREFS]`, so start-up reaches
  `runApp`; healthy files are untouched. Windows only. The window's X hides to the tray (process keeps running).
- Window size (F63): from the work area of the monitor under the cursor (`window_size.dart`), max 900 × 1400, centered;
  logged `📐 [DESKTOP] Work area: x,y WxH, window: WxH` (logical px; screen_retriever reports logical on Windows,
  VERIFIED 2026-11-09). Details: desktop-scaling.md.
- Sidebar layout (F65): `DesktopShellLayout` (`lib/features/main/desktop_shell_layout.dart`). Window width < 800 logical
  px (`kCompactSidebarBelow`): 72-px icon rail; ☰ opens the 260-px sidebar as an overlay from the start edge (left LTR,
  right RTL) with a scrim; content does not move. Closes on scrim, item, ☰, `Esc`, or the window becoming ≥ 800.
  ≥ 800 (and maximized): inline 260 / 72 sidebar, ☰ toggles inline. Open/collapsed state in memory only (no prefs).
  Device check S41 pending.
- Sleep-aware timers: only the prayer minute tick (prayer.md § Next-prayer logic) — gap > 3 min reschedules prayer timers.
- Tray, adhan, scheduler: `desktop_tray_service.dart`, `DesktopAdhanService`, `DesktopPrayerScheduler`
  (folder view `lib/core/services/README.md`).
