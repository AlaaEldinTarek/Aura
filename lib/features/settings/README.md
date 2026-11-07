# Settings Feature

## Overview
App-wide settings UI: the main Settings screen (route `/settings`, opened from Profile), Iqama offsets
(`/iqama_settings`), downloadable adhan reciters (`/adhan_downloads`), and the calculation method / Asr madhab
dialog with its two option enums (also used by the Prayer screen's own settings page). Most values are plain
SharedPreferences keys read later by providers, services and native code ([providers](../../core/providers/README.md),
[services](../../core/services/README.md), `.project-docs/contracts/prefs-keys.md`). Cross-folder views:
`.project-docs/modules/prayer.md`, `.project-docs/modules/notifications-native.md`. Behavior-preserving rule: no UI
or logic change without an approved spec.

## Interface
| File | Public symbols / entry points |
| --- | --- |
| `settings_screen.dart` | `SettingsScreen()` (route `/settings`). Private: `_SettingsScreenState` (pickers for silent duration, task reminder minutes, language, theme, daily summary time) |
| `prayer_calculation_settings_dialog.dart` | `PrayerCalculationSettingsDialog.show({context, currentMethod, currentMadhab, onMethodChanged, onMadhabChanged})` (`StatelessWidget`); callers: `settings_screen.dart`, `prayer/prayer_screen.dart` |
| `adhan_calculation_method.dart` | `enum AdhanCalculationMethod` (12 values, `.value` strings e.g. `'MuslimWorldLeague'`, `'UmmAlQura'`), `getLocalizedName`, `fromValue` (fallback MWL) |
| `asr_madhab_selection.dart` | `enum AsrMadhab` (`shafi` / `hanafi`, `.value` `'Shafi'` / `'Hanafi'`), `getLocalizedName`, `fromValue` — a different type from `core/models/prayer_settings.dart` `AsrMadhab` |
| `iqama_settings_screen.dart` | `IqamaSettingsScreen()` (route `/iqama_settings`) |
| `adhan_downloads_screen.dart` | `AdhanDownloadsScreen()` (route `/adhan_downloads`); `AdhanReciter`, `availableAdhans` (5 reciters, jsDelivr URLs), `downloadProvider` / `DownloadNotifier` (`downloadAdhan`, `deleteAdhan`, `isDownloaded`, `getDownloadedPath`, `checkDownloadedStatus`), `DownloadStatus`, `DownloadInfo` |

## Invariants
- **Calculation method / madhab** are stored as the settings enums' `.value` strings (`calculation_method`,
  `asr_madhab` via `AppConstants.keyCalculationMethod` / `keyAsrMadhab`). `prayer_times_provider.dart` maps them to
  the core enums; `'Hanafi'` and three methods do not map (findings F36a, FX-0). `SettingsScreen` recalculates
  (`prayerTimesProvider.loadPrayerTimes`) after each change; its tile subtitle shows the raw stored strings.
- **Dialog state is fixed at open**: `PrayerCalculationSettingsDialog` is stateless, so the radio selection does not
  move after a tap until it is reopened; the content is a non-scrolling `Column` of 14 tiles.
- **Silent mode** toggle / duration write `silent_mode_enabled` / `silent_mode_duration` in Flutter prefs. Native
  reads the duration from Flutter prefs but the enabled flag from `aura_silent_mode` (findings F49).
- **Prayer tracking** toggle writes `prayer_tracking_notifications_enabled` (read natively at fire time); the daily
  summary time writes `daily_summary_time` and calls `PrayerAlarmService.scheduleDailySummary`.
- **Jumu'ah** switch: `jumuahReminderEnabledProvider.setEnabled` then schedule / cancel through `NotificationService`.
- **Platform sections**: Android only — Exact Alarms / Battery Optimization links (`PlatformChannelService`);
  Windows only — Start with Windows (`WindowsStartupService`).
- **Iqama**: minutes per prayer (keys `Fajr`, `Zuhr`, `Asr`, `Maghrib`, `Isha`; legacy `Dhuhr` accepted on load),
  0–60, saved as `"Fajr:15,Zuhr:15,…"` in `iqama_minutes`; read by `PrayerTimesService.loadIqamaMinutes` on the next
  prayer-time load (no recalculation on save).
- **Adhan downloads**: files go to `<app documents>/adhans/<fileName>` with Dio (30 s connect / 120 s receive);
  selection is `selected_adhan_id` in prefs plus `AdhanPlayerService.setCustomAdhan(path)`. Native keeps that path in
  memory only; `setCustomAdhan(null)` sends nothing; preview also calls `setCustomAdhan` (findings F49).
- **Localization / numbers**: inline EN/AR strings throughout; several minute counts and times are raw digits.

## Side Effects
- SharedPreferences: `calculation_method`, `asr_madhab`, `silent_mode_enabled`, `silent_mode_duration`,
  `prayer_tracking_notifications_enabled`, `daily_summary_time`, `iqama_minutes`, `selected_adhan_id`, Windows
  startup pref; theme / language / task-reminder / Jumu'ah through their providers.
- Native: daily-summary alarm, Jumu'ah reminder, exact-alarm / battery settings intents, `setCustomAdhan` and adhan
  preview via `AdhanPlayerService` (MethodChannel), Windows startup registration.
- Network + disk: adhan MP3 download / delete; prayer-time recalculation.

## Verification
- Run: `flutter test` (no tests for this folder). Device: S01 (adhan), S10 (daily summary), S11 (Jumu'ah),
  S12 (silent mode). Known issues: findings F36a, F49.
