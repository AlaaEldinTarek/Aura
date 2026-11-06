# Contract — notification IDs & channels
Seeded from old CLAUDE.md on 2026-11-06; Confidence: Unknown until Step 2. Do NOT modify IDs.

## IDs
| ID / range | Purpose | Owner |
| --- | --- | --- |
| 1001–1006 | Prayer alarms (adhan notification) | PrayerAlarmReceiver.kt |
| 2001–2006 | Prayer reminders | PrayerAlarmReceiver.kt |
| 6001–6006 | Post-prayer checks (30 min after adhan) | PrayerAlarmReceiver.kt |
| 7001 | Daily prayer summary | DailySummaryReceiver.kt |
| 8001 | Jumu'ah reminder | JumuahReminderReceiver.kt |
| 3999 | Task daily summary (`matchDateTimeComponents: time`) | Flutter NotificationService |
| 5100–5119 | Wird reminders (max 10 used) | Flutter NotificationService |
| 7100–8099 | Achievement unlocked (hash-based per achievement ID) | Flutter NotificationService |

⚠ 7100–8099 contains 8001 (Jumu'ah) — possible collision, see reference/findings.md (UNVERIFIED).

## Channels
| Channel | Importance / notes | Owner |
| --- | --- | --- |
| `prayer_foreground_channel` | IMPORTANCE_HIGH, VISIBILITY_PUBLIC, PRIORITY_MAX, CATEGORY_ALARM | PrayerForegroundService.kt |
| `prayer_tracking` | IMPORTANCE_DEFAULT; created by DailySummaryReceiver if absent | DailySummaryReceiver.kt |
| `jumuah_reminder` | — | JumuahReminderReceiver.kt |
| `wird_reminder` | — | Flutter NotificationService |
| `achievement_unlocked` | — | Flutter NotificationService |
| Others created in MainActivity | UNKNOWN | MainActivity.kt |
