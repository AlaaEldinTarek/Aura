# Contract — notification IDs & channels
Verified 2026-11-06 at 4aa1022 by static grep (Step 2). Do NOT modify IDs. All IDs share one Android NotificationManager
(same package, null tag), so Dart `flutter_local_notifications` and Kotlin `NotificationManagerCompat` IDs collide if equal.

## Notification IDs
| ID / range | Purpose | Dart location | Kotlin location | Dynamic? | Confidence |
| --- | --- | --- | --- | --- | --- |
| 1–6 | Flutter prayer notifications (`_fajrNotificationId`…) | `notification_service.dart:74–79` | — | No | Partial (Dart only) |
| 1001–1006 | Adhan notification (Fajr, Sunrise, Dhuhr/Zuhr, Asr, Maghrib, Isha) | — | `PrayerAlarmReceiver.kt:48–53, getNotificationId :73` | No | Partial (Kotlin only) |
| 2001–2006 | Pre-prayer reminders | — | `PrayerAlarmReceiver.kt:56–61, :85` | No | Partial (Kotlin only) |
| 2000 | PrayerRescheduleService foreground notification | — | `PrayerRescheduleService.kt:30` | No | Partial (Kotlin only) |
| 3999 | Task daily summary | `notification_service.dart:805` | (`cancelNativeNotification` passthrough) | No | Verified |
| 4001 | Daily task digest (08:00) | `notification_service.dart:1021` | — | No | Partial — inside 4000–4999 (F8) |
| 4000–4999 | Task reminders, `4000 + hash % 1000` | `notification_service.dart:669` | via `scheduleNativeTaskReminder` | Yes (hash) | Verified |
| 5001–5006 | Flutter-side prayer notifications (`_getNotificationId + 5000`) | `notification_service.dart:431` | — | No | Partial |
| +5000 offset | "Remind again" re-schedule of a native notification | — | `NativeNotificationReceiver.kt:131` | Yes | Partial |
| 5100–5119 | Wird reminders (max 10 used) | `notification_service.dart:1105–1159` | via `scheduleNativeNotification` | Yes | Verified |
| 5996 | Focus Mode relaunch full-screen notification (cancelled on stop) | — | `FocusModeService` `relaunchActivity` | No | Partial (added 2026-11-07, F51f) |
| 5998 | Focus Mode foreground service | — | `FocusModeService.kt:32` | No | Partial |
| 5999 | Focus Mode end notification — never posted (dead path, F51q) | — | `FocusModeReceiver.kt:38` | No | Partial |
| 6001–6006 | Post-prayer "Did you pray?" checks | `notification_service.dart:1285,1341,1371` (`6000 + id`; scheduler at :1265 has no caller found — F12) | `PrayerAlarmReceiver.kt:65–70, :97` | No | Verified (both sides) |
| 7001 | Daily prayer summary | `_jumuahNotificationId = 7001` cancelled at `notification_service.dart:1390,1401` | `DailySummaryReceiver.kt:20` | No | Verified — collision F7 |
| 7100–8099 | Achievement unlocked, `7100 + hash % 1000` | `notification_service.dart:1171` | — | Yes (hash) | Verified — overlaps 8001 (F4) |
| 8001 | Jumu'ah reminder | — | `JumuahReminderReceiver.kt:19` | No | Partial (Kotlin only) |
| 8100 | Silent-mode control notification (vibrate-window action buttons) | — | `PrayerAlarmReceiver.kt (postSilentModeNotification)` | No | New (F68) |
| 9000–9006 | Post-prayer azkar (Fajr 9001 … Isha 9006; Dhuhr/Zuhr 9003) | — | `AzkarAlarmReceiver.getAzkarNotificationId` | No | Partial (added 2026-11-07) |
| 9999 | Prayer foreground service | — | `PrayerForegroundService.kt:32` | No | Partial |

PendingIntent request-code offsets (not notification IDs, but must stay unique): `PrayerAlarmReceiver` +1000/+2000
(`:147,:348,:372,:810`), `FocusModeReceiver` base 5000, `TasksWidget` widgetId +1000/+2000/+5000.
Added 2026-11-07 (Kotlin EGM): silent restore 3999 (`SilentOffReceiver`), azkar 3000–3006, daily summary 7001,
Jumu'ah 8001, daily recalc 9100, test adhan 9999, `NativeNotificationReceiver` / `TaskReminderReceiver` id, id+1, id+2 (+3),
Focus relaunch 5996. Foreground-service silent buttons 8001/8002 removed (dead code, F68).
Added 2026-11-11 (F68): silent-mode control 8100 (`PrayerAlarmReceiver.postSilentModeNotification → ToggleSilentModeReceiver`);
PendingIntent request codes 8100/8101. Full per-file list: `android/app/src/main/kotlin/com/aura/hala/README.md`.

## Channels
| Channel ID | Dart location | Kotlin location | Confidence |
| --- | --- | --- | --- |
| `prayer_foreground_channel_v4` | — | `PrayerForegroundService.kt:30` (old docs said `prayer_foreground_channel`) | Partial |
| `prayer_times` | `notification_service.dart:45` | `MainActivity.kt:116`, `PrayerAlarmReceiver.kt:798` | Verified |
| `prayer_tracking` | — | `MainActivity.kt:157`, `DailySummaryReceiver.kt:81`, `PrayerAlarmReceiver.kt:913` | Partial |
| `silent_mode_control` | — | `MainActivity.kt (createNotificationChannel)` | New (F68) |
| `prayer_check` | `notification_service.dart:70` | — | Partial |
| `task_reminders` | `notification_service.dart:50` | `TaskReminderReceiver.kt:37` | Verified |
| `jumuah_reminder` | `notification_service.dart:55` | `JumuahReminderReceiver.kt:20` | Verified |
| `wird_reminder` | `notification_service.dart:60` | via `NativeNotificationReceiver` extra `channel_id` | Partial |
| `achievement_unlocked` | `notification_service.dart:65` | — | Partial |
| `azkar_reminder` | — | `AzkarAlarmReceiver.kt:29` | Partial |
| `focus_mode` | — | `FocusModeReceiver.kt:37` | Partial |
| `focus_mode_service` | — | `FocusModeService.kt:31` | Partial |
| `prayer_reschedule` | — | `PrayerRescheduleService.kt:31` | Partial |
| `channel_id` | — | `NativeNotificationReceiver.kt:44` is the **extra key**, not a channel; channel comes from Dart | — |
