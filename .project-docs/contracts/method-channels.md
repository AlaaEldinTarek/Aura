# Contract — MethodChannels
Seeded 2026-11-06. Channel names in Kotlin: VERIFIED by grep (8 names). Dart sites, methods, and per-method direction:
Step 2. Old CLAUDE.md documented 7 channels; `app_control` was missing.

| Channel | Purpose (from old CLAUDE.md) | Native file (from old CLAUDE.md) | Confidence |
| --- | --- | --- | --- |
| `com.aura.hala/adhan` | Adhan audio playback | AdhanPlayer.kt | Partial (Kotlin name found) |
| `com.aura.hala/prayer_alarms` | Exact alarms + post-prayer checks + daily summary + Jumu'ah (`scheduleJumuahReminder`, `cancelJumuahReminder`) | PrayerAlarmReceiver.kt + DailySummaryReceiver.kt + JumuahReminderReceiver.kt | Partial |
| `com.aura.hala/background_service` | Foreground service control | PrayerForegroundService.kt | Partial |
| `com.aura.hala/widgets` | Widget data updates | WidgetUpdateService.kt | Partial |
| `com.aura.hala/ringer_mode` | Silent/vibrate mode | SilentModeAutomation.kt | Partial |
| `com.aura.hala/navigation` | Route tracking + post-prayer callbacks native→Flutter (`openPostPrayerPicker`, `openReminderPicker`, `updatePrayerStatus`) | MainActivity.kt | Partial |
| `com.aura.hala/focus_mode` | Focus scheduling, overlay/DND, service control (`getFocusCompletedTaskId`) | FocusModeService.kt | Partial |
| `com.aura.hala/app_control` | UNKNOWN — undocumented (findings F5, UNVERIFIED) | UNKNOWN | Partial (Kotlin name found only) |

Hotspot (initial survey): 14 `MethodChannel(` constructions in Dart for these channels.
