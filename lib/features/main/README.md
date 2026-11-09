# Main Shell Blueprint

## System Overview
The app shell after login/onboarding: one file, `main_wrapper_screen.dart`. It hosts the 5 tabs, the mobile bottom
nav or the desktop sidebar, and the desktop nested navigator with its route table. It also runs the app-level
lifecycle work: resume refresh, widget intent hand-off, native navigation callbacks, untracked-prayer prompt,
achievement toasts and desktop popups/adhan overlay. It owns no data; everything goes through `../../core/` services
and providers. Native contracts: [method-channels](/.project-docs/contracts/method-channels.md),
[intent-extras](/.project-docs/contracts/intent-extras.md), [prefs-keys](/.project-docs/contracts/prefs-keys.md).
Cross-folder views: `.project-docs/modules/notifications-native.md`, `.project-docs/modules/desktop.md`.
Behavior-preserving rule: no UI or logic change without an approved spec.

## Local Interface & Invariants

### Interface
| File | Public symbols / entry points |
| --- | --- |
| `main_wrapper_screen.dart` | `MainWrapperScreen({int initialIndex = 0})`; `desktopSidebarVisibleProvider` (`StateProvider<bool>`, set by `quran_reader_screen.dart`). Private: `_DesktopShell` (+ `_generateDesktopRoute`), `_DesktopSidebar`, `_AdhanOverlay`, `_NotifPopup` (data), `_AchievementToast` (scale from `desktopTextScale`, `core/utils/window_size.dart`) |

- **MethodChannel `com.aura.hala/navigation`** — Dart → native: `setCurrentRoute {route: '/home' | '/tab/<i>'}` on
  every tab change. Native → Dart (handler registered on Android only): `navigateToRoute {route}`,
  `openReminderPicker` / `openPostPrayerPicker {prayerName, prayerNameAr, prayerTime ms}`,
  `updatePrayerStatus {prayerName, status}`.
- **MethodChannel `com.aura.hala/prayer_alarms`** — `scheduleReminderAlarm` (requestCode `7000 + delayMinutes`) and
  `schedulePostPrayerCheck` (requestCode `9000 + delayMinutes`) from the remind-later pickers.
- **Desktop routes** (`_generateDesktopRoute`): `/prayer`, `/prayer_tracking`, `/prayer_report`, `/dhikr`,
  `/dhikr_stats`, `/achievements`, `/task_form` (`Task?` passed as `arguments`), `/task_stats`, `/settings`,
  `/iqama_settings`, `/adhan_downloads`, `/qibla`, `/daily_content`, `/azkar`, `/quran`, `/quran_stats`,
  `/islamic_events`. Any other name renders the tab PageView. Mobile routes live in `main.dart`
  `onGenerateRoute` (the same names plus `/`, auth/onboarding, `/home`, `/profile`, `/khatma_dua`); keep both tables in sync.
- Watches: `languageProvider`, `taskWidgetSyncProvider` (keeps the tasks home widget in sync), `appModeProvider`
  and `allTasksProvider` (sidebar badge), `desktopSidebarVisibleProvider`. Listens to `tabNavigationProvider`
  (requests from child screens; reset to -1 after use).

### Invariants
- **Tabs**: the PageView always holds all 5 pages in fixed order (0 Home, 1 Prayer, 2 Quran, 3 Tasks, 4 Profile);
  app mode only hides nav items, and indices never shift (native `widget_target_tab` relies on 1 and 3).
  Mobile allows swiping (default physics); desktop disables it and uses the sidebar. `_handleTabTap` ignores the
  current index, then sets state, the `TabController`, `jumpToPage` and `_updateCurrentRoute`.
- **Back** (`_onWillPop`, `PopScope(canPop: false)`): on a non-Home tab it goes to Home (not the previous tab); on
  Home a second press within 2 s calls `SystemNavigator.pop()`, otherwise it shows `press_again_to_exit`.
- **Layout split** (`_isDesktop` = Windows/macOS/Linux): desktop → `_DesktopShell` (sidebar 72/260 px, collapses
  under 166 px, hidden when `desktopSidebarVisibleProvider` is false; content has a scaled text scaler of 0.9–1.8 (`desktopTextScale`, F63 A-1)
  and a nested `Navigator`; a sidebar tap pops to the first route). Mobile → `Scaffold` + `AuraBottomNavBar`.
  Desktop sidebar rules: Home and Profile always shown; Prayer hidden in `tasksOnly`; Quran only in
  `both`/`prayerOnly`; Tasks hidden in `prayerOnly`.
- **Resume order** (`didChangeAppLifecycleState`): `_checkUntrackedPrayers` → read the Fajr time → invalidate
  `prayerTimesProvider`, `tasksProvider(const TaskFilterParams())`, `allTasksProvider` → `_handleWidgetIntent` →
  `_syncThenLoadPrayerStatus(fajr)` → (mobile) `TaskService.rescheduleAllTaskReminders`. On pause (mobile):
  `dailyPrayerStatusProvider.stopLiveSync`.
- **Startup** (`initState` + post-frame): prayer-status sync is a 30 s forced reload on desktop and `startLiveSync`
  plus a 3 min re-subscribe on Android. Then the `tabNavigationProvider` listener, `_handleWidgetIntent`,
  `_scheduleDailySummaryOnStartup`, guest migration (+1 s), status sync (+2 s), untracked check and task
  reminder re-arm (+3 s). Cold start has no resume event, so the status sync runs here too.
- **Widget hand-off** (`_handleWidgetIntent`): `prefs.reload()` (Kotlin writes the file directly), then it consumes
  `pending_complete_task_id` (toggle task), `widget_open_task_form` (push `/task_form`) and `widget_navigate_to_tab`
  (switch tab). Each key is removed after use.
- **Untracked prayers**: needs tracking enabled and a signed-in user. Past prayers (not Sunrise, adhan time passed)
  are compared by lowercase name with today's `PrayerTrackingService.getPrayersForDate`. The sheet records
  `on_time` / `late` / `missed` through `_recordPrayerStatusFromNotification` → `dailyPrayerStatusProvider.markToday`.
  There is no 20-minute check here (findings F34).
- **Remind-later pickers**: before adhan the options are 5/10/15/20/25/30 min; after the prayer they are
  5/10/15/20/30 min. In both cases only options before the next adhan are shown; when none fit, nothing is shown.
- **Achievements**: desktop shows the in-app toast and a desktop notification. Phone shows the toast when resumed,
  otherwise `NotificationService.showAchievementNotification`. The toast lasts 3.2 s.
- **Desktop popups**: a FIFO queue, one at a time. The window turns into a bottom-right toast (always on top,
  without a title bar), then is restored to 900×1400, centered. Auto-dismiss is 5 min for adhan and 8 s otherwise.
  While a popup is active, `build` returns only the popup and the shell is unmounted (findings F34). Popup "Prayed"
  calls `DesktopNotificationService.recordPrayerOnTime` + `DesktopAdhanService.stop`; "Dismiss" does not stop the audio.
- **Localization**: the guest-sync dialog, `press_again_to_exit` and the sidebar labels use `.tr()`. The popup,
  adhan overlay, pickers and untracked sheet use inline `isArabic ? '…' : '…'`, with a local `_toArabicNumerals`.

### Side Effects
- Services: `TaskService` (`toggleTaskCompletion`, `rescheduleAllTaskReminders`); `PrayerAlarmService`
  (`syncNativePrayerStatuses`, `scheduleDailySummary`); `PrayerTrackingService.getPrayersForDate`;
  `SharedPreferencesService` (`isPrayerTrackingEnabled`, `getDailySummaryTime`); `AchievementService.newAchievements`;
  `NotificationService.showAchievementNotification`; desktop: `DesktopNotificationService` (stream, achievement,
  `recordPrayerOnTime`), `DesktopPrayerScheduler.prayerTimeStream`, `DesktopAdhanService.stop`, `windowManager`.
- Providers: `dailyPrayerStatusProvider` (`load`, `startLiveSync`, `stopLiveSync`, `markToday`), `guestMigrationProvider`
  (`refresh` before the dialog check, `markDialogShown`, `migrate`), and the resume invalidations above.
- SharedPreferences: read + remove the 3 widget hand-off keys. Native alarms through `prayer_alarms` (above).
- Timers / overlays: the status-sync timer, popup auto-dismiss, the adhan overlay (`OverlayEntry`, 5 min) and the
  achievement toast; haptics on mobile swipe and back.

## Subdirectories & System Boundaries
- None (flat directory).

## Global Invariants
- Channel names, method names, argument keys, requestCode bases (7000 / 9000) and the 3 widget prefs keys are native
  contracts: change Dart + Kotlin + `contracts/` together. Tab indices are shared with native widgets.
- This file never launches native activities. Prayer statuses are written through `dailyPrayerStatusProvider`, except
  the desktop popup "Prayed" button (`DesktopNotificationService.recordPrayerOnTime`).

## Global Side Effects
- Native alarms and the navigation route reported to `MainActivity`; on desktop, window size/position/always-on-top.
- Task completion and prayer statuses (via services/providers); guest-to-account migration.

## System Verification
- Run: `flutter test` (no tests for this folder yet). Manual checks: `.project-docs/reference/device-checklist.md`
  S06–S10 (statuses, pickers, summary route), S14–S15 (widget tab / task hand-off), S20 (guest migration),
  S21; desktop popups and adhan overlay: `.project-docs/modules/desktop.md`.
- Known issues: findings F34 (verified) and F35 (scout backlog).
