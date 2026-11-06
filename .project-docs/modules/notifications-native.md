# Notifications & native Android
Relocated from CLAUDE.md on 2026-11-06; not yet re-verified (Step 2). IDs/channels: contracts/notification-ids.md.
Invariant (never launch MainActivity from native code): CLAUDE.md Rules.

## Three-layer notification system
1. **Flutter `NotificationService`** (`flutter_local_notifications`): 10-min pre-prayer reminders + "Remind Me Again"
   (5 min before) + daily 8 AM task digest + achievement unlock notifications (achievements.md).
2. **Native `PrayerAlarmReceiver`**: exact AlarmManager at prayer time → adhan audio + **minimal** notification (no
   action buttons, `setTimeoutAfter(3000)` auto-dismisses) + `setFullScreenIntent` → `AdhanFullScreenActivity`. The
   notification exists only because Android needs a posted notification to fire `setFullScreenIntent` on locked/doze screens.
3. **Post-prayer + daily summary**: prayer-tracking.md § Native status sync.

## Native files (`android/app/src/main/kotlin/com/aura/hala/`)
- `MainActivity.kt` — FlutterActivity, MethodChannel handlers, notification channels (CLAUDE.md said "8 handlers")
- `PrayerAlarmReceiver.kt` — fires at prayer times → adhan + notification + silent mode + post-prayer check (30 min after).
  Do NOT modify its notification IDs. All controls live in `AdhanFullScreenActivity`. After Fajr/Isha calls `NativePrayerCalculator`.
- `DailySummaryReceiver.kt` — at configurable daily time reads `prayer_status_{name}_{date}` from `aura_prayer_times`,
  shows summary, reschedules tomorrow, prunes status keys after 7 days; creates channel `prayer_tracking` (IMPORTANCE_DEFAULT) if absent. Don't change key format.
- `JumuahReminderReceiver.kt` — see Jumu'ah below
- `AdhanPlayer.kt` — singleton MediaPlayer, per-prayer audio, vibration, thread-safe (custom Adhan audio)
- `SilentModeAutomation.kt` — AudioManager silent mode, configurable duration (default 20 min)
- `PrayerForegroundService.kt` — see Foreground service below
- `NativePrayerCalculator.kt` — pure-Kotlin calculator (no libs). Reads lat/lng + method from `aura_prayer_times`,
  Julian Day → solar position → hour angles, saves results, reschedules alarms
- `AdhanFullScreenActivity.kt` — full-screen intent over lock screen. During adhan: pulse animation. After audio: live
  iqama countdown (polls `AdhanPlayer.isPlaying()` every 500 ms via `Handler`, reads `adhan_iqama_time`). Top-right ✕ is
  the only dismiss. "Stop Vibrate"/"Keep Vibrate" pair only when silent mode is active; "Keep Vibrate" is a no-op.
- `PrayerBootReceiver.kt` — reschedules all alarms after boot/app update (incl. `rescheduleJumuahReminder()`)
- `StopAdhanReceiver.kt` / `ToggleSilentModeReceiver.kt` / `SilentOffReceiver.kt` — broadcast receivers
- Widgets: widgets.md · Focus Mode: focus-mode.md
- Not yet documented (found by file count, 30 `.kt` files vs 22 documented): e.g. `FlutterPrefs.kt`,
  `NativeNotificationReceiver.kt`, `TaskReminderReceiver.kt` — UNKNOWN, Step 2

## Jumu'ah reminder
- Every Friday 30 min before Zuhr; bilingual; reads `dhuhr_time` from `aura_prayer_times`; weekly auto-reschedule.
- Flutter control: `scheduleJumuahReminder` / `cancelJumuahReminder` on `com.aura.hala/prayer_alarms`.

## Foreground service notification (`PrayerForegroundService`)
- START_STICKY; next-prayer countdown. Channel `prayer_foreground_channel`, IMPORTANCE_HIGH, VISIBILITY_PUBLIC,
  PRIORITY_MAX, CATEGORY_ALARM. Channel deletion guarded (catches `SecurityException` while active).
- 4 layouts: `notification_large` (LTR), `notification_large_rtl`, `notification_large_dark`, `notification_large_dark_rtl`.
- Timer `HH:MM` (no seconds); Arabic uses Eastern numerals. RTL: `notification_until` before `notification_time` in XML;
  time uses `textDirection="ltr"`.
- Icon by **phone clock hour** (NOT prayer times): 0–4 Isha, 5–6 Fajr, 7–15 Dhuhr, 16–17 Asr, 18–19 Maghrib, 20–23 Isha.
- Stale or missing times: `requestFlutterUpdate()` calls `NativePrayerCalculator.calculateAndSave()` then
  `loadPrayerTimes()` — does NOT launch MainActivity (VERIFIED 2026-11-06, `PrayerForegroundService.kt:212-224, 857-866`).
  The only `MainActivity` reference is the notification's tap `PendingIntent` (`createNotification()`, user-initiated).

## Gotchas
- Notification channel importance: Android won't downgrade; call `deleteNotificationChannel()` before recreating.
  Cannot delete while a foreground service is active — wrap in try-catch `SecurityException`.
- `AndroidManifest.xml`: CLAUDE.md said 18 permissions, 11 receivers, 3 services, 3 activities (UNVERIFIED count).
- Backup layouts live at `android/app/src/main/layout-backup/` — outside `res/` (inside `res/` breaks the resource merger).
- Foreground service exists for background prayer alerts; control channel `com.aura.hala/background_service`.
