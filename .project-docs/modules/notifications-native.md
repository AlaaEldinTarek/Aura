# Notifications & native Android
Verified against code 2026-11-07 (reference/2026-11-07_DRIFT_REPORT.md). IDs/channels: contracts/notification-ids.md.
Folder view: `android/app/src/main/kotlin/com/aura/hala/README.md`. Invariant (never launch MainActivity from native
code): CLAUDE.md Rules.

## Three-layer notification system
1. **Flutter `NotificationService`** schedules; on Android most deliveries go native (`scheduleNativeNotification` on
   `com.aura.hala/prayer_alarms` → `NativeNotificationReceiver`, EMUI workaround): pre-prayer reminder
   (`notification_reminder_minutes`, default 10), "Remind Me Again" (5 min before), daily task summary (3999, repeats),
   wird reminders. Task reminders → native `scheduleNativeTaskReminder` → `TaskReminderReceiver` (`task_reminder_minutes`,
   default 30; no time → 9 AM; snooze 30 min). Still plugin-based on Android: daily task digest 4001 (8:00, one-shot,
   re-armed by prayer side effects; duplicates 3999, F52e) and achievement notifications (achievements.md).
2. **Native `PrayerAlarmReceiver`**: exact AlarmManager at prayer time → adhan audio + **minimal** notification (channel
   `prayer_times`, no actions, `setTimeoutAfter(3000)`) with `setFullScreenIntent`, and also a direct
   `startActivity(AdhanFullScreenActivity)`.
3. **Post-prayer + daily summary**: prayer-tracking.md § Native status sync.

## Native files (`android/app/src/main/kotlin/com/aura/hala/`, 30 `.kt`)
- `MainActivity.kt` — FlutterActivity; registers 8 MethodChannels (contracts/method-channels.md); notification channels.
  Dart also calls `com.aura.hala/silent_mode`, which has no handler (F9).
- `PrayerAlarmReceiver.kt` — prayer alarm → adhan + notification + vibrate window (`RINGER_MODE_VIBRATE`, duration from
  FlutterPrefs `silent_mode_duration`, default 20) + post-prayer check (30 min) + azkar alarm. Do NOT modify its
  notification IDs. After Fajr/Isha → `PrayerForegroundService.requestFlutterUpdateStatic` → `NativePrayerCalculator`.
- `DailySummaryReceiver.kt` — configurable daily time; reads `prayer_status_{name}_{date}` from `aura_prayer_times`,
  shows summary, reschedules, prunes keys > 7 days; creates channel `prayer_tracking` if absent. Don't change key format.
- `DailyRecalcReceiver.kt` — exact alarm 00:05: native recalculation, reschedules itself. `PrayerRecalcWorker.kt` —
  WorkManager backup recalculation (scheduled from `MainActivity` and `PrayerBootReceiver`).
- `NativePrayerCalculator.kt` — pure-Kotlin calculator. Reads lat/lng + method from `aura_prayer_times`, saves results,
  reschedules alarms.
- `AdhanPlayer.kt` — singleton MediaPlayer, per-prayer / custom audio, vibration. Only `play()` is `@Synchronized`
  (`stop` / `releasePlayer` / `isPlaying` are not; F51 backlog).
- `AdhanFullScreenActivity.kt` — over lock screen. Pulse during adhan; then iqama countdown (polls
  `AdhanPlayer.isPlaying()` every 500 ms, reads `adhan_iqama_time`). Exits: ✕, Back, auto-finish at iqama (or 3 s when
  none) → launches `AzkarFullScreenActivity`; volume keys stop audio. "Stop Vibrate"/"Keep Vibrate" only when the
  vibrate window is active and `aura_silent_mode.silent_mode_enabled` (F49a); "Keep Vibrate" is a no-op, "Stop
  Vibrate" does not close the screen.
- `AzkarAlarmReceiver.kt` (iqama + 10 min, or adhan + 15 min; IDs 9001–9006) → `AzkarFullScreenActivity.kt`
  (post-prayer azkar counters; extra items at Fajr/Maghrib). Double launch: F51j.
- `JumuahReminderReceiver.kt` — see Jumu'ah below.
- `PrayerBootReceiver.kt` — after boot/update: `PrayerRescheduleService` (dataSync foreground service), recalc worker,
  `rescheduleJumuahReminder()`, foreground service (F51i, F51l).
- `ToggleSilentModeReceiver.kt` (also contains `SilentOffReceiver`) — vibrate-window actions.
  `StopAdhanReceiver.kt` — declared, nothing sends `STOP_ADHAN` (F51q).
- `NativeNotificationReceiver.kt`, `TaskReminderReceiver.kt` — native delivery for Flutter-scheduled notifications
  (layer 1); set `widget_target_tab`.
- `FlutterPrefs.kt` — read/write `FlutterSharedPreferences` with `flutter.` prefix (`putInt` stores Long).
- Dead (F51q / F52o): `SilentModeAutomation.kt` (`SilentModeScheduler` only), `BackgroundServiceHandler.kt`,
  `RingProgressView.kt`, `AuraAccessibilityService.kt`, `WidgetUpdateService.kt`.
- Widgets: widgets.md · Focus Mode: focus-mode.md

## Jumu'ah reminder
- Fridays 30 min before Zuhr (fallback 11:30 if `dhuhr_time` missing); gate FlutterPrefs `jumua_reminder_enabled`;
  channel `jumuah_reminder` (HIGH), ID 8001; bilingual; weekly reschedule. Uses the last stored `dhuhr_time`, not
  Friday's (F51p).
- Flutter control: `scheduleJumuahReminder` / `cancelJumuahReminder` on `com.aura.hala/prayer_alarms`.

## Foreground service notification (`PrayerForegroundService`)
- START_STICKY; 60 s tick. Channel `prayer_foreground_channel_v4`, IMPORTANCE_HIGH, VISIBILITY_PUBLIC, PRIORITY_MAX,
  CATEGORY_ALARM; deleted and recreated only when its importance is below HIGH (F51p).
- 4 layouts: `notification_large` (LTR), `notification_large_rtl`, `notification_large_dark`, `notification_large_dark_rtl`.
  RTL: `notification_until` before `notification_time` in XML; time uses `textDirection="ltr"`.
- Normal mode: "1h 45m" / "45m" ("Xس Yد" in Arabic, Eastern numerals). Adhan mode: "Iqama in Xm Ys" + 2 action buttons.
- Normal-mode icon by **phone clock hour** (NOT prayer times): 0–4 Isha, 5–6 Fajr, 7–15 Dhuhr, 16–17 Asr, 18–19 Maghrib,
  20–23 Isha. Adhan and reminder modes use `ic_mosque`.
- Stale or missing times: `requestFlutterUpdate()` calls `NativePrayerCalculator.calculateAndSave()` then
  `loadPrayerTimes()` — does NOT launch MainActivity. The only `MainActivity` reference is the notification's tap
  `PendingIntent` (user-initiated). Control channel `com.aura.hala/background_service` (handled in `MainActivity`).

## Gotchas
- Notification channel importance: Android won't downgrade; call `deleteNotificationChannel()` before recreating.
  Cannot delete while a foreground service is active — wrap in try-catch `SecurityException`.
- `AndroidManifest.xml`: 24 `<uses-permission>` (23 unique, INTERNET twice), 20 receivers, 3 services, 4 activities.
- Old backup layouts were removed (116547e). Never put backup layouts inside `res/` (breaks the resource merger); junk
  folders with shell-command names are still tracked under `res/` (F52o).
