# Android Native (`com.aura.hala`)

## Overview
All native Android code (30 Kotlin files, flat, plus the `adhan/` subfolder): the Flutter host activity and its
MethodChannels, exact-alarm receivers (adhan, reminders, post-prayer check, daily summary, Jumu'ah, azkar, tasks,
Focus Mode), the prayer foreground service, a pure-Kotlin prayer calculator (`adhan/`: line-by-line port of the adhan
package, see its README), home-screen widgets, and full-screen activities shown over the lock screen. Cross-folder feature flows: [notifications-native](/.project-docs/modules/notifications-native.md),
[widgets](/.project-docs/modules/widgets.md), [focus-mode](/.project-docs/modules/focus-mode.md),
[prayer-tracking](/.project-docs/modules/prayer-tracking.md). Shared names are contracts:
[method-channels](/.project-docs/contracts/method-channels.md), [prefs-keys](/.project-docs/contracts/prefs-keys.md),
[notification-ids](/.project-docs/contracts/notification-ids.md), [intent-extras](/.project-docs/contracts/intent-extras.md),
[log-tags](/.project-docs/contracts/log-tags.md). Edit `PrayerAlarmReceiver.kt` and `DailySummaryReceiver.kt` carefully (CLAUDE.md).

## Interface
| File | Main API (what other files use) |
| --- | --- |
| `MainActivity.kt` | `MainActivity` (`FlutterFragmentActivity`): registers all channels in `configureFlutterEngine` (`adhan`, `prayer_alarms`, `background_service`, `widgets`, `navigation`, `focus_mode`, `ringer_mode`, `app_control`); creates channels `prayer_times` (HIGH) and `prayer_tracking` (DEFAULT); turns launch extras into `navigation` calls and `widget_navigate_to_tab`; schedules `PrayerRecalcWorker`. All members private |
| `PrayerAlarmReceiver.kt` | `PrayerAlarmReceiver`: adhan / 45-min reminder / post-prayer check receiver. Companion: `schedulePrayerAlarm`, `scheduleReminderAlarm`, `scheduleDelayedReminder`, `schedulePostPrayerCheck`, `cancelPostPrayerCheck`, `cancelAllAlarms`, `markPrayerTracked`, ID helpers `getNotificationId` / `getReminderNotificationId` / `getPostCheckNotificationId`, `EXTRA_*` and `ACTION_*` constants |
| `PrayerForegroundService.kt` | `PrayerForegroundService`: persistent next-prayer notification (9999). Companion: `startService`, `stopService`, `updatePrayerTimes`, `nudge`, `getInstance`, `requestFlutterUpdateStatic` (despite the name: native recalc only) |
| `NativePrayerCalculator.kt` | `NativePrayerCalculator.calculateAndSave(context)`: uses Dart's `cached_{date}_*` times (today … +6) when all 6 exist, else `calculate(lat, lng, y, m, d, zone, method, madhab)` (adhan port in `adhan/`, logs the fallback); saves `*_time` + `next_prayer_*`; schedules adhan alarms. Unknown method → MWL with a warning |
| `DailyRecalcReceiver.kt` | `DailyRecalcReceiver.schedule`: 00:05 daily recalc (`DAILY_RECALC`, rc 9100), then starts the foreground service |
| `PrayerRecalcWorker.kt` | `PrayerRecalcWorker.schedule`: WorkManager unique periodic work `aura_periodic_prayer_recalc` (6 h, KEEP) |
| `PrayerBootReceiver.kt` | `PrayerBootReceiver`: after boot / package replace (30 s delay) starts `PrayerRescheduleService`, daily summary, Jumu'ah, foreground service, daily recalc, worker |
| `PrayerRescheduleService.kt` | `PrayerRescheduleService`: short foreground service (2000) that re-arms adhan alarms for still-future stored times |
| `AdhanPlayer.kt` | `AdhanPlayer` (object): `play`, `stop`, `isPlaying`, `getCurrentPrayer`, `previewAdhan` (settings-bridge: reads `adhan_enabled` + `selected_adhan_id` from `FlutterPrefs`; resolves reciter via `AdhanFiles`) |
| `AdhanFiles.kt` | `AdhanFiles` (object): `resolve(selectedId, adhansDir)` — validates id `[a-z0-9_]+`, checks `adhan_<id>.mp3` exists; `adhansDir(context)` |
| `AdhanFullScreenActivity.kt` | `AdhanFullScreenActivity.getIntent`: lock-screen adhan UI, iqama countdown, silent-mode buttons, then launches azkar |
| `AzkarAlarmReceiver.kt` | `AzkarAlarmReceiver.schedule` / `cancel`: post-prayer azkar alarm (rc 3000–3006, notification 9000–9006) |
| `AzkarFullScreenActivity.kt` | `AzkarFullScreenActivity.getIntent`: hard-coded post-prayer azkar with in-memory counters |
| `StopAdhanReceiver.kt` | `StopAdhanReceiver` (action `STOP_ADHAN`): stops audio, re-posts the adhan notification |
| `ToggleSilentModeReceiver.kt` | `ToggleSilentModeReceiver` (`ENABLE_SILENT` / `DISMISS_SILENT` / `EXTEND_SILENT`) and `SilentOffReceiver` (rc 3999 restore) |
| `SilentModeAutomation.kt` | `SilentModeScheduler` (object): `cancelAll`, `cancelSilentOffAlarm`, `triggerSilentMode` (no-op) |
| `DailySummaryReceiver.kt` | `DailySummaryReceiver.schedule(ctx, "HH:mm")` / `cancel`: untracked-prayer summary (7001), prunes old status keys |
| `JumuahReminderReceiver.kt` | `JumuahReminderReceiver.schedule` / `cancel`: Friday reminder 30 min before stored `dhuhr_time` (8001) |
| `NativeNotificationReceiver.kt` | `NativeNotificationReceiver.schedule` / `cancel`: generic exact-alarm notification (Dart id/channel/text), optional daily repeat, "mark prayed" / "remind again" actions |
| `TaskReminderReceiver.kt` | `TaskReminderReceiver.schedule` / `cancel`: task reminder on `task_reminders`, 30-min snooze |
| `FocusModeReceiver.kt` | `FocusModeReceiver.scheduleFocusAlarm` / `cancelFocusAlarm` (rc `5000 + hash % 1000`): starts service + activity |
| `FocusModeService.kt` | `FocusModeService.start` / `stop` / `blockTouch` / `allowTouch`, `isRunning`: overlay, DND, relaunch monitor (5998) |
| `FocusModeActivity.kt` | `FocusModeActivity`: lock-task countdown screen; `isActivityVisible` read by the service |
| `PrayerWidgets.kt` | `AllPrayersWidget.updateAppWidget` (+ `AllPrayersWidgetReceiver` 60 s tick): next prayer / timeline tabs |
| `TasksWidget.kt` | `TasksWidget`, `NextTaskWidget` (+ receivers, 30-min tick): render `aura_tasks_widget`, complete / add hand-off |
| `DailyContentWidget.kt` | `DailyContentWidget.updateAppWidget`, `scheduleWidgetUpdate`: hard-coded 20-item ayah/hadith list |
| `FlutterPrefs.kt` | `FlutterPrefs` (object): typed get/put on `FlutterSharedPreferences` with the `flutter.` prefix (ints stored as Long) |
| `BackgroundServiceHandler.kt` | duplicate `background_service` handler; never instantiated (findings F10) |
| `WidgetUpdateService.kt` | widget refresh service; not declared in the manifest, never started (findings F51) |
| `AuraAccessibilityService.kt` | removed service; not declared in the manifest (findings F51) |
| `RingProgressView.kt` | ring progress `View`; no references (findings F51) |

## Invariants
- **Never launch `MainActivity` from native code** at adhan time or for stale times; only notification tap
  `PendingIntent`s open it. Stale/missing times → `NativePrayerCalculator.calculateAndSave()` (`DailyRecalcReceiver`,
  `PrayerRecalcWorker`, `PrayerForegroundService`, `PrayerAlarmReceiver` after Fajr/Isha).
- **Flutter settings** are read only through `FlutterPrefs` (`silent_mode_enabled`, and after the settings-bridge fix
  also `adhan_enabled`, `selected_adhan_id`, `background_notification_enabled`). Native state lives in `aura_prayer_times`,
  `aura_silent_mode` (native state only: `is_silent_active`, `saved_ringer_mode`, `silent_end_time`),
  `aura_tasks_widget`; `${packageName}_preferences` is Focus Mode only.
- **Dhuhr/Zuhr**: ID maps (`getNotificationId` & co., `AzkarAlarmReceiver`, `AdhanPlayer` files) accept both; the
  prefs key is always `dhuhr_time` and the cache key `cached_{date}_dhuhr`. Status keys, `updateNextPrayer`,
  `DailySummaryReceiver.PRAYER_NAMES` and the widget timeline use the raw name and match only `'Zuhr'`.
- **Calculator inputs** (`prayer_calc_method`, `prayer_asr_madhab`) are Dart `CalculationMethod` / `AsrMadhab` enum
  `.name` values; unknown values silently fall back to Muslim World League / Shafi. Only `makkah` adds Dhuhr +3 min.
- **Foreground service restart** (`PrayerForegroundService`): boot, daily recalc, and swipe-away restart use
  `startServiceIfAllowed(context, reason)`, which checks `flutter.background_notification_enabled` via `FlutterPrefs`
  and skips start when the setting is off; `shouldAutoRestart` also checks `fg_user_stopped`. `onStartCommand` with
  null intent (START_STICKY recreation) likewise checks the setting and calls `stopSelf()` when disabled.
- **Adhan guards** (`PrayerAlarmReceiver`): Sunrise never plays adhan; a Fajr at/after sunrise is dropped; the same
  prayer cannot fire twice within 6 h (`last_adhan_fired_<name>`, except test alarms); `AdhanPlayer.play` returns
  early when `flutter.adhan_enabled` is false (via `FlutterPrefs`) and always stops the previous player first.
- **Request codes must stay unique** (PendingIntent, not notification IDs): adhan = caller code (1001–1006),
  reminder +1000, post-check +2000, silent restore 3999, azkar 3000–3006, focus 5000–5999, daily summary 7001,
  Jumu'ah 8001, foreground-service silent buttons 8001/8002 (broadcast), daily recalc 9100, test adhan 9999. Full list:
  notification-ids contract.
- **Status keys** `prayer_status_{name}_{yyyy-MM-dd}` are written with `Locale.US` dates; MainActivity sync marks
  them `synced` instead of deleting (the summary checks presence). `DailySummaryReceiver` builds its keys with the
  device locale (findings F51a).
- **Next prayer** is a cached scalar (`next_prayer_*`) written by MainActivity, the calculator, `PrayerAlarmReceiver`
  and the foreground service; widgets read it without re-deriving (memory "next-prayer architecture"; findings F51h).
- MethodChannel handlers always reply (`success` / `error` / `notImplemented`).

## Side Effects
- **Exact alarms** (`setExactAndAllowWhileIdle`) for every receiver above; a 60 s / 30 min / daily repeating `RTC`
  tick for widgets; WorkManager periodic recalc.
- **Notifications**: channels `prayer_times`, `prayer_tracking`, `prayer_foreground_channel_v4`, `prayer_reschedule`,
  `task_reminders`, `jumuah_reminder`, `azkar_reminder`, `focus_mode_service`, plus Dart-named channels via
  `NativeNotificationReceiver`. IDs: contract.
- **Device state**: ringer → vibrate at adhan and restore; DND interruption filter and lock task (Focus Mode);
  full-screen activities over the lock screen with wake locks; system overlay; adhan audio, vibration and a
  `MediaSession` that takes the volume keys while playing.
- **Prefs**: files and keys per the prefs contract; old `prayer_status_*` keys pruned after 7 days.
- **Services**: `PrayerForegroundService` (START_STICKY, self-restart alarm unless `fg_user_stopped`),
  `PrayerRescheduleService`, `FocusModeService` (self-restarts until the timer ends).

## Verification
- Kotlin unit tests: `android/app/src/test/kotlin/com/aura/hala/NativePrayerCalculatorParityTest.kt` (JUnit 4,
  test-only dependency) — run `./gradlew :app:testDebugUnitTest` in `android/`. Build: `flutter build apk --release --obfuscate
  --split-debug-info=build/debug-info`; behavior: [device checklist](/.project-docs/reference/device-checklist.md) and
  the logcat filters in the log-tags contract.
