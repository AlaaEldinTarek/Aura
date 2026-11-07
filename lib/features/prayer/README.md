# Prayer Feature Blueprint

## System Overview
The prayer UI: the Prayer tab (`prayer_screen.dart`, bottom-nav index 1) with its settings page, the tracking
calendar (`prayer_tracking_screen.dart`) and the 60-day report (`prayer_report_screen.dart`). Prayer times come
from `prayerTimesProvider`. Statuses are read and written through `dailyPrayerStatusProvider`, and the report
reads `PrayerTrackingService` directly (`../../core/`). Native alarms, notifications and adhan are owned by core
services. Cross-folder views: `.project-docs/modules/prayer.md`, `.project-docs/modules/prayer-tracking.md`
(partly out of date, see Invariants), `.project-docs/modules/notifications-native.md`. Behavior-preserving rule:
no UI or logic change without an approved spec.

## Local Interface & Invariants

### Interface
| File | Public symbols / entry points |
| --- | --- |
| `prayer_screen.dart` | `PrayerScreen()` (tab 1; also desktop route `/prayer`); `PrayerSettingsPage()` (opened only from the Prayer tab AppBar). Private: `_ToolkitAction` |
| `prayer_tracking_screen.dart` | `PrayerTrackingScreen()`: route `/prayer_tracking` (Prayer tab AppBar) |
| `prayer_report_screen.dart` | `PrayerReportScreen()`: route `/prayer_report` (tracking AppBar, toolkit), 2 tabs (Overview, Details), `fl_chart` bar chart |

Navigation out: `/qibla`, `/prayer_tracking`, toolkit (`/qibla`, `/azkar`, `/dhikr`, `/prayer_report`),
`/adhan_downloads`, `/iqama_settings`. Desktop: the location header opens `showDesktopLocationDialog`.

### Invariants
- **Prayer tab data is a local copy**: `_loadPrayerTimes` (in `initState` and on pull-to-refresh) copies
  `prayerTimesProvider` into local fields, then calls `loadPrayerTimes(DateTime.now())`. The screen never watches the
  provider, so later provider changes (countdown refresh, desktop location change) do not reach it (findings F36).
  The date is always today. Location, calculation method and platform handling live in the provider.
- **Marking (Prayer tab)**: tapping a card toggles. A prayer in `_explicitlyMarked` → `showUnmarkConfirmDialog` →
  `unmarkToday`; otherwise `canMarkPrayer` (20-minute rule) → `showPrayerStatusDialog` → `markToday`. Sunrise cannot be
  marked. The status list is filtered by `isPrayerTimeReached`, and every record that passes goes into
  `_explicitlyMarked` (including `missed` / `excused`). Missing status = `missed`; `isCompleted = status != missed`.
- **Prayer names**: cards, countdown and snackbars use `nameAr` / `name` or the raw key; `getPrayerDisplayName` is not
  used in this folder (no Jumu'ah; findings F26).
- **Tracking screen**: month data comes from `dailyPrayerStatusProvider.loadMonth(_focusedDay, forceRefresh: true)`
  (`ref.watch`, no local month map). The streak comes from `PrayerTrackingService.calculateCurrentStreak`. Today's
  statuses are filtered by `isPrayerTimeReached`; past days are shown as stored. A prayer with no record is `null`
  (grey "Not Prayed"), never `missed`. Day complete = all 5 present and none `missed` (so `excused` counts; F25).
  Any past day can be edited. Only the real today applies `canMarkPrayer`; tapping a future day, including the real
  today before Fajr, is rejected. Stats cover the real current month: completed = `onTime` + `late`, over days × 5.
- **After midnight**: `_togglePrayerStatus` records to the tapped date (no remap); the snackbar says "for yesterday"
  when that date is the effective day. Cross-folder rules: `modules/prayer-tracking.md` (rewritten 2026-11-07, F36d).
- **Report**: data is `getPrayersForDateRange(now − 60 d, now)` + `calculateCurrentStreak`; main stats use the last
  30 days. `excused` is counted as Excused and left out of the completion denominator. `totalMissed` is derived
  (`150 − logged`), not counted. Per-prayer rows are keyed by `kPrayerNames` (`'Zuhr'`) with a fixed total of 30. The
  weekly chart has 4 rolling 7-day buckets; the monthly comparison is this month vs last month. All digits go through
  `_n` (`NumberFormatter`).
- **Settings page**: reminder toggle, foreground "Prayer Notification" toggle (starts/stops the service), tracking
  reminders + daily summary time (`HH:mm`, default 21:00), adhan sound, adhan downloads, auto silent mode + duration
  (10/15/20/25/30, default 20), iqama, calculation method + Asr madhab. Most toggles only write prefs; nothing is
  rescheduled here. Method/madhab changes write prefs and pop, with no recalculation.
- **Calculation values**: the UI stores `AdhanCalculationMethod.value` / `AsrMadhab.value` (`'MuslimWorldLeague'`,
  `'Hanafi'` …). `prayerTimesProvider` matches the lowercase `prayer_settings.dart` enums, so `'Hanafi'` falls back
  to Shafi and three methods fall back to MWL (findings F36). The same writer exists in `settings_screen.dart`.
- **Localization**: almost all strings are inline `isArabic ? '…' : '…'` (only `prayer_times_title`, tutorial and
  InfoTip keys are translated). Arabic numerals via `NumberFormatter` in dates, countdown, report, silent duration.

### Side Effects
- `prayerTimesProvider.notifier.loadPrayerTimes`; `dailyPrayerStatusProvider.notifier`: `load(fajrTime:)`,
  `markToday` / `unmarkToday` (Prayer tab), `computeEffectiveToday`, `loadMonth`, `markDate` / `unmarkDate` (tracking).
- `PrayerTrackingService`: `calculateCurrentStreak`, `getPrayersForDateRange` (Firestore or guest local, inside the service).
- Settings page: `BackgroundServiceManager.startForegroundService` / `stopForegroundService` (no try-catch, no platform
  guard); `AdhanPlayerService.setEnabled` / `stopAdhan`; `prayerTrackingEnabledProvider.setEnabled`,
  `dailySummaryTimeProvider.setTime`.
- SharedPreferences writes (settings page): `prayer_notifications_enabled`, `background_notification_enabled`,
  `silent_mode_enabled`, `silent_mode_duration`, `calculation_method`, `asr_madhab`. Tutorial flag via
  `SharedPreferencesService.isTutorialPrayerSeen` / `setTutorialPrayerSeen`.
- Haptics on mark/unmark; no MethodChannel calls in this folder.

## Subdirectories & System Boundaries
- None (flat directory).

## Global Invariants
- The prefs keys above are contracts ([prefs-keys](/.project-docs/contracts/prefs-keys.md)). Native reads its own
  `prayer_asr_madhab` (`NativePrayerCalculator.kt`), which Dart sends as the provider's lowercase enum name.
- Prayer statuses are written only through `dailyPrayerStatusProvider` here; the stored `PrayerStatus` values are
  shared with native notifications and stats (F25).

## Global Side Effects
- Prayer records (via the provider) and the Android foreground service; everything else is local prefs or reads.

## System Verification
- Run: `flutter test` (`test/` covers core prayer rules, not these screens). Manual checks:
  `.project-docs/reference/device-checklist.md` S05–S12, S21.
- Known issues: findings F36 (verified) and F37 (scout backlog).
