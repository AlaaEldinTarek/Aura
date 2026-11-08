# Contract — SharedPreferences files & keys
Verified 2026-11-06 at 4aa1022 by static grep (Step 2). Source for every row: grep of `lib/` + `android/app/src/main/kotlin/`.
Confidence: `Verified` = both sides found and read; `Partial` = one side only or dynamic; `Unknown` = not found.

## The rule
Flutter `shared_preferences` ≠ native Kotlin file. The plugin's real file is **`FlutterSharedPreferences`** with every key
prefixed **`flutter.`** — `${packageName}_preferences` is NOT it (reads return defaults; writes are invisible to Dart).
In Kotlin, use `FlutterPrefs.kt` for any setting Flutter saved (handles file name, key prefix, Long-stored ints).
The plugin caches in memory on the Dart side — after native writes call `prefs.reload()` before reading (see `_handleWidgetIntent`).
VERIFIED: the only Kotlin access to `FlutterSharedPreferences` is through `FlutterPrefs.kt` (no raw `"flutter."` literals).

History: this mismatch caused Arabic text missing in full-screen azan, silent mode not working, azan/post-check/
daily-summary notifications always English, daily summary time reverting to 21:00, and the Jumu'ah toggle ignored after reboot.

## Files (Kotlin `getSharedPreferences` call counts)
| File | Sites | Used by | Confidence |
| --- | --- | --- | --- |
| `aura_prayer_times` | 44 | PrayerForegroundService, PrayerAlarmReceiver, AdhanFullScreenActivity, StopAdhanReceiver, DailySummaryReceiver, NativePrayerCalculator, JumuahReminderReceiver, PrayerWidgets, DailyContentWidget, MainActivity (channel writes) | Verified |
| `aura_silent_mode` | 8 (+`ToggleSilentModeReceiver.PREFS_NAME`) | SilentModeAutomation, PrayerAlarmReceiver, AdhanFullScreenActivity, ToggleSilentModeReceiver, PrayerForegroundService | Verified (native only; `silent_mode_enabled` has no writer — findings F49a) |
| `aura_prefs` | 5 (`MainActivity.kt:369,375`, `AdhanPlayer.kt:180`, `PrayerBootReceiver.kt:59`, `ToggleSilentModeReceiver.kt:254`) | MainActivity adhan channel (W/R `adhan_enabled`), AdhanPlayer (R `adhan_enabled`), PrayerBootReceiver (R `notifications_enabled`), ToggleSilentModeReceiver (R `language`) | Verified. Custom adhan is NOT stored here (in-memory only — findings F49b) |
| `aura_tasks_widget` | 3 (`TasksWidget.kt:19,261`, `MainActivity.kt:323`) | TasksWidget, MainActivity `updateTasksWidget` | Partial — undocumented before Step 2 |
| `aura_focus_state` | 2 (`FocusModeService.kt:33`) | FocusModeService (`duration_minutes`, `started_at`, …) | Partial — undocumented before Step 2 |
| `aura_focus_mode` | 1 | FocusModeReceiver (`completed_task_id`, `completed_at`) | Partial |
| `FlutterSharedPreferences` (`flutter.`) | via `FlutterPrefs.kt` | Flutter plugin + Kotlin | Verified |
| `${packageName}_preferences` | 3 (`FocusModeActivity.kt:455`, `FocusModeService.kt:172`, `MainActivity.kt:760`) | Focus Mode ONLY: native writes, MainActivity reads for `getFocusCompletedTaskId` — do NOT use for anything else | Verified |

## Cross-boundary keys — `FlutterSharedPreferences` (Dart name; stored as `flutter.<name>`)
| Name | Dart location | Kotlin location | Read/Write | Dynamic? | Confidence |
| --- | --- | --- | --- | --- | --- |
| `prayer_tracking_notifications_enabled` | `shared_preferences_service.dart` | `DailySummaryReceiver.kt:90`, `PrayerAlarmReceiver.kt:580`, `PrayerBootReceiver.kt:97` | Dart W / Kotlin R | No | Verified |
| `daily_summary_time` | `shared_preferences_service.dart` | `DailySummaryReceiver.kt:151`, `PrayerBootReceiver.kt:99` | Dart W / Kotlin R | No | Verified |
| `jumua_reminder_enabled` | `preferences_provider.dart`, `notification_service.dart` | `JumuahReminderReceiver.kt:24,105` | Dart W / Kotlin R | No | Verified |
| `silent_mode_duration` | `shared_preferences_service.dart`, `app_constants.dart` | `PrayerAlarmReceiver.kt:722`, `ToggleSilentModeReceiver.kt:102` (getInt, Long-safe) | Dart W / Kotlin R | No | Verified |
| `theme_mode` (`AppConstants.keyThemeMode`) | `app_constants.dart:56` | `PrayerForegroundService.kt:662` | Dart W / Kotlin R | No | Verified |
| `widget_navigate_to_tab` | `main_wrapper_screen.dart` | `MainActivity.kt:57` (putInt) | Kotlin W / Dart R | No | Verified (resolves D7) |
| `pending_complete_task_id` | `main_wrapper_screen.dart` | `TasksWidget.kt:52,290` | Kotlin W / Dart R | No | Verified |
| `widget_open_task_form` | `main_wrapper_screen.dart` | `TasksWidget.kt:63` | Kotlin W / Dart R | No | Verified |

## Cross-boundary keys — `aura_prayer_times` (Dart writes via channel args → MainActivity)
| Name | Dart location | Kotlin location | Read/Write | Dynamic? | Confidence |
| --- | --- | --- | --- | --- | --- |
| `fajr_time`, `sunrise_time`, `dhuhr_time` (never `zuhr_time`), `asr_time`, `maghrib_time`, `isha_time` | channel `updatePrayerTimes` | W `NativePrayerCalculator.kt:73–78` + MainActivity; R receivers/widgets, `JumuahReminderReceiver.kt:32` | both W, Kotlin R | No | Verified |
| `next_prayer_name`, `next_prayer_name_ar`, `next_prayer_time` | channel `updatePrayerWidgets` | W `MainActivity.kt:293–295`, `NativePrayerCalculator.kt:82`; R ×8 | both W, Kotlin R | No | Verified (cached scalar — see memory "next-prayer architecture") |
| `language`, `location_name`, `themeMode` | `prayer_widget_service.dart` args | W `MainActivity.kt:285–287`; R ×20 (`language`), `DailyContentWidget.kt:80` (`themeMode`) | Dart→Kotlin | No | Verified |
| `{prayer}_iqama_time` (fajr/dhuhr/asr/maghrib/isha) | built by `_getIqamaKey` in `prayer_widget_service.dart:51` | W `MainActivity.kt:297–299` (map passthrough); R `PrayerAlarmReceiver.kt:545–549` | Dart→Kotlin | Yes | Verified |
| `cached_{yyyy-MM-dd}_{name}` | `prayer_times_provider.dart` → `buildNativeCache` (`prayer_refresh.dart`) → `BackgroundServiceManager.cacheAccuratePrayerTimes` (`background_service_manager.dart:121–127`) | W `MainActivity.kt:698–704` (drops old `cached_*`); R `NativePrayerCalculator.kt:177–190` (`readCached`) | Dart→Kotlin | Yes | Verified. Days today … +6 (FX-0; 42 keys); `{name}` = fajr, sunrise, dhuhr, asr, maghrib, isha |
| `prayer_latitude`, `prayer_longitude`, `prayer_calc_method`, `prayer_asr_madhab` | channel args | 3 sites each | Dart→Kotlin | No | Partial (Dart arg site per key not mapped) |
| `prayer_calc_method` values | `CalculationMethod.name` (`prayer_settings.dart`), mapped from the stored `calculation_method` by `calculationMethodFromPref` | `NativePrayerCalculator.kt` method table | Dart→Kotlin | No | Contract strings (FX-0): `muslimWorldLeague`, `isna`, `egyptian`, `makkah`, `karachi`, `tehran`, `kuwait`, `fixedAngle`, `proportional`, `qatar`, `dubai`, `turkey`, `singapore`, `moonsightingCommittee`. Change Dart, Kotlin and this file in one commit |
| `prayer_asr_madhab` values | `AsrMadhab.name`, mapped from the stored `asr_madhab` ('Shafi' / 'Hanafi', any case) by `asrMadhabFromPref` | `NativePrayerCalculator.kt` (`"hanafi"` → shadow 2, else Shafi) | Dart→Kotlin | No | Contract strings: `shafi`, `hanafi` |
| `prayer_status_{name}_{YYYY-MM-DD}` | R only via `getNativePrayerStatuses` → parsed `prayer_alarm_service.dart:317–321`; cleared via `clearNativePrayerStatus` | W `PrayerAlarmReceiver.kt:389`, `NativeNotificationReceiver.kt:120`; R `PrayerAlarmReceiver.kt:419`, `DailySummaryReceiver.kt:100,168` (prune), `MainActivity.kt:543` (skips value `synced`) | Kotlin W / Dart R | Yes | Verified. Dart sync: `PrayerAlarmService.syncNativePrayerStatuses(userId)` (`prayer_alarm_service.dart:309`), called by `_syncThenLoadPrayerStatus()` (`main_wrapper_screen.dart:125,249`), which replaced `_syncNativePrayerStatuses()` in 088d2cb |

## Native-only keys (Kotlin ↔ Kotlin; listed so refactors don't drop them)
- `aura_prayer_times`: `adhan_active`, `adhan_end_time`, `adhan_iqama_time` (abs ms, 0 = none), `adhan_prayer_name(_ar)`,
  `reminder_active`, `reminder_prayer_name(_ar)`, `reminder_prayer_time`, `combined_widget_tab_{widgetId}`,
  `last_adhan_fired_{name}` (6 h duplicate guard, `PrayerAlarmReceiver`), `fg_user_stopped` (`PrayerForegroundService`;
  cleared by `startService`, so boot ignores it — findings F51i).
- `aura_focus_state` (`FocusModeService`): write-only, no reader. `aura_focus_mode` (`FocusModeReceiver`): written
  only on a dead path, no reader (findings F51q).
- `aura_silent_mode`: `is_silent_active`, `saved_ringer_mode`, `silent_end_time`. `silent_mode_enabled` is read
  (`PrayerAlarmReceiver.kt:497–498`, `AdhanFullScreenActivity.kt:292–294`, default `true`) but no Kotlin or Dart code
  writes it here; the Dart toggle writes `flutter.silent_mode_enabled` in `FlutterSharedPreferences` (findings F49a).
- `aura_tasks_widget`: `task_count`, `tasks_done`, `tasks_total`, `streak`, `language`, `task_{i}_{id|title|time|category|priority|overdue|subtaskDone|subtaskTotal}`.
- `aura_prefs`: `adhan_enabled` (W `MainActivity.kt:369–370` via adhan channel `setAdhanEnabled`; R `MainActivity.kt:375`,
  `AdhanPlayer.kt:180–181`). Read with no writer found (default used): `notifications_enabled`
  (`PrayerBootReceiver.kt:59–60`, default `true`; dead check — findings F49i), `language` (`ToggleSilentModeReceiver.kt:254–255`, default `"en"` —
  findings F49h). No custom adhan key: `AdhanPlayer.customAdhanPath` is an in-memory `var` set by channel
  `setCustomAdhan` (`MainActivity.kt:379–383`) and lost when the process dies (findings F49b).
- `${packageName}_preferences`: `focus_completed_task_id`, `focus_task_was_completed`.

## Dart-only keys (FlutterSharedPreferences; no Kotlin reader found)
- Tasks: `task_notifications_enabled`, `task_reminder_minutes` (also desktop), `task_sort_order`, `task_category_filter`,
  `task_streak_count`, `task_streak_date`.
- Wird: `wird_settings` (JSON), `wird_streak_count`, `wird_streak_date`, `wird_total_pages_read`,
  `wird_total_days_completed`, `wird_progress_history` (JSON, pruned to 90 days), `wird_completed_juz` (JSON list),
  `wird_khatm_count`, `wird_khatm_dates` (JSON list) — all in `wird_service.dart`.
- Auth / guest: `is_guest` (`AppConstants.keyIsGuest`; via `SharedPreferencesService.isGuest` / `setGuest`; written by
  `login_screen.dart` and `auth_provider.dart`, read by Splash routing and `_syncUserData`), `pending_guest_migration_uid`
  (String uid; written in `auth_provider.dart` `_syncUserData` when a guest with local tasks signs in; read and removed by `guest_migration_provider.dart`).
- Azkar: `azkar_state` (JSON `AzkarState`, `dateKey` = today), `azkar_streak_date` (`yyyy-MM-dd`) — `azkar_provider.dart`.
- Dhikr: `custom_dhikr_presets` (JSON list of `DhikrPreset`) — `dhikr_screen.dart` `_customPresetsKey`.
- Quran: `quran_bookmarks` (JSON list), `quran_reading_progress` (JSON) — `quran_bookmark_service.dart`.
- `focus_a11y_ever_enabled`: **removed** in bc765f6 ("Remove accessibility service") with `AuraAccessibilityService`
  (manifest comment `AndroidManifest.xml:340`); no replacement key. Old installs may still hold it — orphan, harmless.
- Tutorial-seen flags (`app_constants.dart` `keyTutorial*`, via `SharedPreferencesService`): `tutorial_completed`,
  `tutorial_prayer_seen`, `tutorial_quran_seen`, `tutorial_tasks_seen`, `tutorial_juz_seen`, `tutorial_bookmarks_seen`,
  `tutorial_wird_seen`, `tutorial_reader_seen`.
