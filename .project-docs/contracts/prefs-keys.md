# Contract — SharedPreferences files & keys
Seeded from old CLAUDE.md on 2026-11-06. Full per-key table (`Name | Dart location | Kotlin location | Read/Write side |
Dynamic? | Confidence | Source`) is built in Step 2. Until then every entry is Confidence: Unknown, Source: CLAUDE.md.

## The rule
Flutter `shared_preferences` ≠ native Kotlin file. The plugin's real file is **`FlutterSharedPreferences`** with every key
prefixed **`flutter.`** — `${packageName}_preferences` is NOT it (reads return defaults; writes are invisible to Dart).
In Kotlin, use `FlutterPrefs.kt` for any setting Flutter saved (handles file name, key prefix, Long-stored ints).
The plugin caches in memory on the Dart side — after native writes call `prefs.reload()` before reading (see `_handleWidgetIntent`).

History: this mismatch caused Arabic text missing in full-screen azan, silent mode not working, azan/post-check/
daily-summary notifications always English, daily summary time reverting to 21:00, and the Jumu'ah toggle ignored after reboot.

## Files
| File | Used by | Contains |
| --- | --- | --- |
| `aura_prayer_times` | PrayerForegroundService, PrayerAlarmReceiver, AdhanFullScreenActivity, StopAdhanReceiver, DailySummaryReceiver, NativePrayerCalculator, JumuahReminderReceiver | Prayer times, next prayer, language, lat/lng + method, `prayer_status_{name}_{YYYY-MM-DD}` (pruned after 7 days by DailySummaryReceiver) |
| `aura_silent_mode` | SilentModeAutomation, PrayerAlarmReceiver, AdhanFullScreenActivity | `silent_mode_enabled`, `is_silent_active`, `saved_ringer_mode` |
| `aura_prefs` | AdhanPlayer | `adhan_enabled` |
| `aura_focus_mode` | FocusModeReceiver | `completed_task_id`, `completed_at` |
| `FlutterSharedPreferences` (`flutter.` prefix) | Flutter plugin + Kotlin via `FlutterPrefs` | All Dart-side prefs (below) |
| `${packageName}_preferences` | Focus Mode ONLY (FocusModeService/FocusModeActivity write, MainActivity reads via channel) — self-consistent native↔native handoff; do NOT use for anything else | `focus_completed_task_id`, `focus_task_was_completed` |

## Known keys — `aura_prayer_times`
- `fajr_time`, `dhuhr_time` (never `zuhr_time`), `asr_time`, `maghrib_time`, `isha_time` (+ sunrise UNKNOWN)
- `fajr_iqama_time`, `dhuhr_iqama_time`, `asr_iqama_time`, `maghrib_iqama_time`, `isha_iqama_time` (written by Flutter)
- `adhan_iqama_time` (absolute ms; 0 = none; written by PrayerAlarmReceiver)
- Dynamic: `prayer_status_{name}_{YYYY-MM-DD}` — written by post-prayer actions, read by DailySummaryReceiver + Flutter
  `_syncNativePrayerStatuses()`. Do not change format. Builder sites: Step 2.

## Known keys — `FlutterSharedPreferences` (Dart names, stored as `flutter.<name>`)
- Notifications: `prayer_tracking_notifications_enabled`, `daily_summary_time`, `jumua_reminder_enabled`,
  `task_notifications_enabled`, `task_reminder_minutes`
- Appearance/behavior: `theme_mode`, `silent_mode_duration`
- Widget handoff: `pending_complete_task_id`, `widget_open_task_form`, `widget_navigate_to_tab`
- Tasks: `task_sort_order`, `task_category_filter`, `task_streak_count`, `task_streak_date`, `focus_a11y_ever_enabled`
- Wird: `wird_settings` (JSON), `wird_streak_count`, `wird_streak_date` ("YYYY-MM-DD"), `wird_total_pages_read`,
  `wird_total_days_completed`, `wird_progress_history` (JSON list, pruned to 90 days)
- Tutorial-seen flags (names UNKNOWN; via `SharedPreferencesService.isTutorialXSeen()`)
