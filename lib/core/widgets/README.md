# Core Widgets Blueprint

## System Overview
Shared UI building blocks (20 files, flat) used by `lib/features/`. Most are presentational and only invoke callbacks;
the exceptions that read providers or call services are listed under Side Effects (`PermissionDialogHandler`,
`showDesktopLocationDialog`, `AuraBottomNavBar`, `OfflineBanner`, `GreetingWidget`). Theme tokens come from
`AppConstants` (`../constants/`); UI conventions (RTL, scaling, tutorial, `InfoTipIcon`):
`.project-docs/modules/ui-kit.md`. Behavior-preserving rule: no visual changes without an approved spec.

## Local Interface & Invariants

### Interface
| File | Public widgets / functions (key params) |
| --- | --- |
| `prayer_card.dart` | `PrayerCard(prayer, isNext, isCurrent, isCompleted, prayerStatus, wasExplicitlyMarked, onTap, onMarkPrayed, isWindowOpen)` |
| `prayer_time_card.dart` | `PrayerTimeCard(prayerTime, isSelected, isNext, isCurrent, onTap)` (no user found outside its file) |
| `prayer_status_dialog.dart` | `showPrayerStatusDialog(context, prayerName, isArabic)` → `PrayerStatus?`; `showUnmarkConfirmDialog(...)` → `bool?` |
| `circular_countdown.dart` | `CircularCountdownTimer(targetTime, prayerName, prayerTime, onComplete, size)`, `CompactCountdown(targetTime, label)` |
| `task_card.dart` | `TaskCard(task, onTap, onToggle, onDelete, onLongPress, onMenuTap, onPostpone, onExpand, isExpanded, isSelected)` |
| `permission_dialog.dart` | `PermissionDialogHandler(onDone)` + static `permissionsDone` future |
| `desktop_location_dialog.dart` | `showDesktopLocationDialog(context, ref)` |
| `bottom_nav_bar.dart` | `AuraBottomNavBar(currentIndex, onTap)`, static `navBarKey` |
| `tutorial_overlay.dart` | `TutorialStep(targetKey, titleKey, bodyKey)`, `TutorialOverlay`, `showTutorial(context, steps, onDone)` |
| `setting_tile.dart` | `SettingTile`, `SettingTileSwitch`, `SettingsSectionHeader`, `SettingsCard` |
| `greeting_widget.dart` | `GreetingWidget(userName, onTap)`, `SimpleGreeting(userName, style)` |
| `share_card.dart` | `ShareCard(repaintKey, type, count, lang)`, `ShareCardType` {prayerStreak, taskStreak, wirdStreak, khatm} |
| `offline_banner.dart` | `OfflineBanner()`, `ConnectivityWrapper(child)` |
| `shimmer_loading.dart` | `ShimmerLoading`, `ShimmerBox`, `ShimmerCard`, `ShimmerListTile`, `ShimmerWrapper`, screen skeletons (`ShimmerPrayerCard`, …) |
| `aura_button.dart` | `AuraButton(label, onPressed, variant, icon, loading, expanded)` (+ `.secondary`, `.ghost`) |
| `aura_chip.dart` | `AuraChip(label, onTap, variant, selected, pill)` (+ `.filled`, `.outlined`) |
| `aura_card.dart` / `app_card.dart` | `AuraCard(child, color, borderColor, radius, shadow, onTap)`; `AppCard(child, onTap)` (+ `small` / `medium` / `large`); overlapping roles |
| `empty_state.dart` | `EmptyState(icon \| iconEmoji, title, subtitle, actionLabel, onAction)`, `LoadingState(message)` |
| `info_tip_icon.dart` | `InfoTipIcon(titleKey, bodyKey)` (localization keys) |

### Invariants
- **Bottom-nav indices are fixed**: 0 Home, 1 Prayer, 2 Quran, 3 Tasks, 4 Profile, and stay the same when tabs are hidden by
  `appModeProvider`. Native `widget_target_tab` relies on 1 = Prayer and 3 = Tasks ([intent-extras](/.project-docs/contracts/intent-extras.md)).
  Prayer is hidden in `tasksOnly`, Quran shown only in `both` / `prayerOnly`, Tasks hidden in `prayerOnly`.
- **Prayer status UI**: `showPrayerStatusDialog` returns `onTime`, `late`, or **`excused` for the "Missed" option**;
  `PrayerCard` shows `excused` and `missed` alike as a red "Missed" badge. Stats treat them differently — findings F25.
- **Prayer names**: `PrayerCard` / `PrayerTimeCard` / `showPrayerStatusDialog` show the name they are given
  (`nameAr` / `name`); they do not call `getPrayerDisplayName`, so callers own Jumu'ah naming — findings F26.
- **20-minute rule**: `PrayerCard` shows the "Mark as prayed" button whenever `onMarkPrayed` is set. `isWindowOpen` only adds
  the `InfoTipIcon` explanation, so callers enforce the rule (`canMarkPrayer`).
- **Localization**: `.tr()` is used by `bottom_nav_bar`, `tutorial_overlay`, `desktop_location_dialog`,
  `offline_banner`, `info_tip_icon`. Most other widgets use inline `isArabic ? '…' : '…'` strings (UI hotspot).
  Arabic numerals via `NumberFormatter` only in `PrayerCard`, `CircularCountdownTimer`, `CompactCountdown`, `ShareCard`.
- **RTL**: detected with `languageCode == 'ar'` (no `Directionality` wrappers); `SettingTile` swaps the chevron icon.
- **Text scaling**: widgets scale with `MediaQuery.textScalerOf`. The nav bar caps it at 0.9–1.3, the greeting at 0.9–1.5.
  The tutorial uses a wider tooltip on desktop.
- **TaskCard swipe**: start-to-end calls `onToggle` (no dismiss); end-to-start dismisses only when `onDelete` is set.
- **Countdown**: the ring is full when 1 h or more remains; `onComplete` fires once per `targetTime`.
- **Permissions**: skipped on desktop; checks start 2 s after launch. The overlay/DND entries depend on `app_mode`
  (`prayer_only` hides the focus-mode group). `permissionsDone` completes once per app lifetime.
- **Greeting bands**: `GreetingWidget` 4–6 / 6–12 / 12–17 / 17–20 / night; `SimpleGreeting` has no 4–6 band.

### Side Effects
- `PermissionDialogHandler`: reads prefs `app_mode`; `PlatformChannelService` exact-alarm / battery checks + settings;
  `NotificationService.canDrawOverlays` / `requestOverlayPermission`; `permission_handler` requests; re-checks on resume.
- `showDesktopLocationDialog`: `LocationService` get/set/clear manual location, `getBestLocation`;
  `GeocodingService.searchCity` (network, 450 ms debounce); `ref.invalidate(prayerTimesProvider)` on save.
- `AuraBottomNavBar`: watches `appModeProvider`, `allTasksProvider` (overdue badge).
- `OfflineBanner` / `ConnectivityWrapper`: watch `isOnlineProvider`, `currentUserProvider`; read
  `OfflineQueueService.pendingCount` (not reactive; queue never filled — findings F16).
- `GreetingWidget`: watches `currentUserProvider` (avatar via `Image.network`).
- Timers / animations: `CircularCountdownTimer` (1 s tick), `ShimmerLoading`, `TutorialOverlay` (overlay entry, ensureVisible).

## Subdirectories & System Boundaries
- None (flat directory).

## Global Invariants
- Nav indices and the `PrayerStatus` values written by the status dialog are shared with native code and stored data.
  Changing them needs Dart + Kotlin + contracts updates and a spec.

## Global Side Effects
- None beyond the above (no prefs writes, no Firestore).

## System Verification
- Run: `flutter test` (`test/core/widgets/prayer_card_test.dart`); visual checks: device-checklist S13–S15, S21.
