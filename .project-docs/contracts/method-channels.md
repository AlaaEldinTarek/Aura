# Contract — MethodChannels
Verified 2026-11-06 at 4aa1022 by static grep of `lib/` and `android/app/src/main/kotlin/` (Step 2). All Kotlin handlers
are registered in `MainActivity.configureFlutterEngine` unless noted. Confidence: `Verified` = both sides found and read;
`Partial` = one side only or dynamic; `Unknown`. "Not found" ≠ unused (dynamic names, reflection) — see findings F9–F11.

## Channels
| Channel | Dart location | Kotlin location | Confidence |
| --- | --- | --- | --- |
| `com.aura.hala/adhan` | `adhan_player_service.dart:15` (+ `setMethodCallHandler` :30) | `MainActivity.kt:28,353` | Verified |
| `com.aura.hala/prayer_alarms` | `prayer_alarm_service.dart:18` (handler :31), `notification_service.dart:42,1382`, `platform_channel_service.dart:10`, `main_wrapper_screen.dart:848,1047` | `MainActivity.kt:29,394` | Verified |
| `com.aura.hala/background_service` | `background_service_manager.dart:13`, `main_wrapper_screen.dart:847` | `MainActivity.kt:30,638`; duplicate handler in `BackgroundServiceHandler.kt:12` (no instantiation found — F10) | Verified |
| `com.aura.hala/widgets` | `prayer_widget_service.dart:14`, `task_widget_service.dart:11` | `MainActivity.kt:27,270` | Verified |
| `com.aura.hala/navigation` | `main_wrapper_screen.dart:104` (handler :255) | `MainActivity.kt:26,246` | Verified |
| `com.aura.hala/focus_mode` | `notification_service.dart:1411` | `MainActivity.kt:31,714` | Verified |
| `com.aura.hala/ringer_mode` | none found | `MainActivity.kt:24,204` | Partial (Kotlin only — F10) |
| `com.aura.hala/app_control` | none found | `MainActivity.kt:25,225` (`openUrl`) | Partial (Kotlin only — F5/F10) |
| `com.aura.hala/silent_mode` | `silent_mode_service.dart:14` | none found | Partial (Dart only — F9) |
| `flutter/vibration` | `haptic_feedback.dart:14` (`vibrate`) | none in `android/`; not a Flutter engine channel → no-op (F23) | Partial (Dart only) |

Old CLAUDE.md said `ringer_mode` ↔ `SilentModeAutomation.kt`; the handler is in MainActivity and Dart uses a different
channel name (`silent_mode`). Silent-mode automation actually runs natively from `PrayerAlarmReceiver` + prefs (see prefs-keys).

## Methods — Dart → Kotlin
| Channel | Method | Dart caller | Kotlin handler | Confidence |
| --- | --- | --- | --- | --- |
| adhan | `playAdhan`, `stopAdhan`, `setAdhanEnabled`, `isAdhanEnabled`, `setCustomAdhan`, `getCustomAdhan` | `adhan_player_service.dart:73,83,97,39,136,144` | `MainActivity.kt:355–385` | Verified |
| prayer_alarms | `schedulePrayerAlarm`, `scheduleReminderAlarm`, `testAdhanNow`, `cancelAllPrayerAlarms`, `schedulePostPrayerCheck`, `cancelPostPrayerCheck`, `markPrayerTracked`, `getNativePrayerStatuses`, `clearNativePrayerStatus`, `scheduleDailySummary`, `cancelDailySummary` | `prayer_alarm_service.dart:84,110,181,222,238,257,273,287,301,361,371`; also `main_wrapper_screen.dart:859` (reminder), `:1048` (post-check) | `MainActivity.kt:396–593` | Verified |
| prayer_alarms | `canScheduleExactAlarms`, `openExactAlarmSettings` | `platform_channel_service.dart:28,50`, `prayer_alarm_service.dart:194,209` | `MainActivity.kt:561,569` | Verified |
| prayer_alarms | `isIgnoringBatteryOptimizations`, `openBatteryOptimizationSettings` | `platform_channel_service.dart:17,39` | `MainActivity.kt:605,608` | Verified |
| prayer_alarms | `scheduleNativeTaskReminder`, `cancelNativeTaskReminder`, `scheduleNativeNotification`, `cancelNativeNotification` | `notification_service.dart:731,793,364/465/848/1104,901/913/1159` | `MainActivity.kt:498–533` | Verified |
| prayer_alarms | `scheduleJumuahReminder`, `cancelJumuahReminder` | `notification_service.dart:1391,1402` | `MainActivity.kt:597,601` | Verified |
| background_service | `startForegroundService`, `stopForegroundService`, `isForegroundServiceRunning`, `updatePrayerTimes`, `cacheAccuratePrayerTimes` | `background_service_manager.dart:56,73,33,102,127` | `MainActivity.kt:640–698` | Verified |
| widgets | `updatePrayerWidgets`, `updateTasksWidget` | `prayer_widget_service.dart:70`, `task_widget_service.dart:96` | `MainActivity.kt:272,316` | Verified |
| navigation | `setCurrentRoute` | `main_wrapper_screen.dart:761` | `MainActivity.kt:249` | Verified |
| focus_mode | `scheduleFocusAlarm`, `cancelFocusAlarm`, `canDrawOverlays`, `requestOverlayPermission`, `getFocusCompletedTaskId`, `hasDndAccess`, `requestDndAccess`, `startFocusService`, `stopFocusService`, `isFocusServiceRunning` | `notification_service.dart:1424–1545` | `MainActivity.kt:716–813` | Verified |
| focus_mode | `isAccessibilityServiceEnabled`, `requestAccessibilityPermission` | none found | `MainActivity.kt:767,771` | Partial (F10) |
| ringer_mode | `getRingerMode`, `setRingerMode` | none found | `MainActivity.kt:206,210` | Partial (F10) |
| app_control | `openUrl` | none found | `MainActivity.kt:227` | Partial (F10) |
| silent_mode | `setEnabled`, `setDuration`, `cancelAll` | `silent_mode_service.dart:58,71,86` (class has no importers found) | none found | Partial (F9) |

## Methods — Kotlin → Dart
| Channel | Method | Kotlin sender | Dart handler | Confidence |
| --- | --- | --- | --- | --- |
| navigation | `navigateToRoute`, `openReminderPicker`, `updatePrayerStatus`, `openPostPrayerPicker` | `MainActivity.kt:66,76,89,102` (from intent extras, see intent-extras) | `main_wrapper_screen.dart:256,261,279,270` | Verified |
| prayer_alarms | `onPrayerAlarmTriggered` | none found | `prayer_alarm_service.dart:42` | Partial (F11) |

Hotspot: 13 `MethodChannel(` constructions + 3 `_channelName` constants in Dart for 9 app channels.
