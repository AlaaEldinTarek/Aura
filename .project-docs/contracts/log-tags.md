# Contract — log tags & logcat filters
Verified 2026-11-06 at 4aa1022 (Step 2). Any logging change is verified by comparing captured `adb logcat` output
before/after for the same device-checklist scenarios (same filters, events, order).
Dart `print`/`debugPrint` appear in logcat under tag `flutter`; filters below grep message text, so they match both sides.

## Filters in use
```bash
adb logcat | grep -E "(PrayerAlarm|NotificationService|PrayerTimes|AdhanPlayer|SilentMode)"
adb logcat | grep "🕌"
```

## Filter term → where it matches
| Term | Kotlin `TAG` / `Log` | Dart log lines (grep `rint(`) | Confidence |
| --- | --- | --- | --- |
| `PrayerAlarm` | `PrayerAlarmReceiver` TAG (substring) | 17 | Verified |
| `NotificationService` | none | 24 | Partial (Dart only) |
| `PrayerTimes` | none | 8 | Partial (Dart only) |
| `AdhanPlayer` | `AdhanPlayer` TAG | 18 | Verified |
| `SilentMode` | `SilentMode` TAG (+ substring in `ToggleSilentMode`) | 9 | Verified |
| `🕌` | in log lines of `PrayerForegroundService`, `AdhanFullScreenActivity`, `JumuahReminderReceiver` | some of 18 Dart hits are UI strings, not logs | Partial |

## Kotlin TAGs (`private const val TAG`)
AdhanFullScreen, AdhanPlayer, AzkarAlarmReceiver, AzkarFullScreen, BackgroundServiceHandler, CombinedPrayerWidget,
DailyContentWidget, DailyRecalcReceiver, DailySummaryReceiver, FocusMode, FocusModeReceiver, FocusModeService,
JumuahReminder, NativeNotifReceiver, NativePrayerCalc, NextTaskWidget, PrayerAlarmReceiver, PrayerBootReceiver,
PrayerForegroundService, PrayerRecalcWorker, PrayerRescheduleService, SilentMode, SilentOffReceiver, StopAdhanReceiver,
TaskReminderReceiver, TasksWidget, ToggleSilentMode, WidgetUpdateService.
Inline literal tags in MainActivity: `MainActivity`, `PrayerChannel`, `FocusModeChannel`, `BackgroundService`, `AdhanChannel`.

## Emoji prefixes
Present on both sides: `🕌` prayer, `🔔` notifications/channels, `✅` success, `❌` error, `⏭️` skip, `📱`/`🔄`.
Bracketed sub-tags also used as filters in practice: `[CHANNEL]`, `[POST_CHECK]`, `[JUMUA]`.
Note: Git Bash `grep` cannot receive 4-byte emoji arguments on this machine. Device-checklist filters use tags; for
emoji use PowerShell `Select-String -Pattern '🕌' -Encoding utf8` on a saved capture.

Hotspot (initial survey): ~511 `print`/`debugPrint` calls, no levels.
