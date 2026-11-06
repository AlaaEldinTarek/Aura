# Contract — intent extras, actions & handoff flags
Verified 2026-11-06 at 4aa1022 by static grep (Step 2). Kotlin-only unless noted; Dart sees these via the navigation
channel or FlutterSharedPreferences.

## MainActivity launch extras
| Name | Type | Writer | Reader | Confidence |
| --- | --- | --- | --- | --- |
| `widget_target_tab` | Int (1 Prayer, 3 Tasks) | `PrayerWidgets.kt:424`, `TasksWidget.kt:210,378`, `TaskReminderReceiver.kt:116`, `NativeNotificationReceiver.kt:150` (tap_tab) | `MainActivity.kt:55` → `FlutterPrefs.putInt("widget_navigate_to_tab")` :57 → Dart `main_wrapper_screen.dart` | Verified |
| `route` | String | `DailySummaryReceiver.kt:123` | `MainActivity.kt:63` → `navigateToRoute` | Verified |
| `open_reminder_picker`, `reminder_prayer_name`, `reminder_prayer_name_ar`, `reminder_prayer_time` | Bool/String/Long | none found (no `putExtra`, no constant; F13) | `MainActivity.kt:71–76` → `openReminderPicker` | Partial |
| `update_prayer_status`, `prayer_name`, `prayer_status` | Bool/String | none found (F13) | `MainActivity.kt:85–89` → `updatePrayerStatus` | Partial |
| `open_post_prayer_picker`, `prayer_name`, `prayer_name_ar`, `prayer_time` | Bool/String/Long | none found (F13) | `MainActivity.kt:97–102` → `openPostPrayerPicker` | Partial |
| `complete_task_id`, `open_task_form` | String/Bool | `TasksWidget.kt:50–66,288–293` | `TasksWidget` itself → FlutterPrefs `pending_complete_task_id` / `widget_open_task_form` | Verified |
| `tab_index` + action `com.aura.hala.ACTION_SWITCH_TAB` | Int | `PrayerWidgets.kt:164,173` | `PrayerWidgets.kt:57` (widget-internal tab switch) | Verified |
| `refresh_prayer_times` | — | none | none (Dart + Kotlin grep: 0 hits) | Verified absent — stale doc claim (findings D5) |

## Receiver extras (`const val EXTRA_*`, Kotlin ↔ Kotlin)
`body`, `channel_id`, `channel_name`, `duration_minutes`, `is_arabic`, `is_post_check`, `is_reminder`, `is_test`,
`language`, `notification_id`, `prayer_name`, `prayer_name_ar`, `prayer_time`, `prayer_time_ms`, `repeat_daily`,
`started_at`, `tap_tab`, `task_desc`, `task_id`, `task_title`, `title`. Per-constant owner map: Step 2.4 READMEs.

## Broadcast actions (AndroidManifest.xml)
`com.aura.hala.PRAYER_TIME_ALARM`, `STOP_ADHAN`, `TOGGLE_SILENT`, `DAILY_PRAYER_SUMMARY`, `DAILY_RECALC`, `AZKAR_ALARM`,
`FOCUS_MODE_ALARM`, `ACTION_SWITCH_TAB`; system: `BOOT_COMPLETED`, `ACTION_BOOT_COMPLETED`, `QUICKBOOT_POWERON` (+HTC),
`REBOOT`, `MY_PACKAGE_REPLACED`, `APPWIDGET_UPDATE`.

Other widget handoff flags (`pending_complete_task_id`, `widget_open_task_form`, `widget_navigate_to_tab`): prefs-keys.md.
