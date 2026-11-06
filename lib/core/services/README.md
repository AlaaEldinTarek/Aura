# Core Services Blueprint

## System Overview
Business logic and platform I/O (36 files, flat). Almost every service is a singleton (`XService.instance`, private
ctor); `PrayerTimesService` is constructed, and `QuranService`, `QuranSvgService`, `QuranBookmarkService`,
`PlatformChannelService`, `WindowsStartupService`, `IslamicEventsService` are static-only. Riverpod wrappers live in
[`../providers/README.md`](../providers/README.md). Cross-folder feature flows: `.project-docs/modules/*.md`.
Native names used here are contracts: [method-channels](/.project-docs/contracts/method-channels.md),
[notification-ids](/.project-docs/contracts/notification-ids.md), [prefs-keys](/.project-docs/contracts/prefs-keys.md),
[firestore-paths](/.project-docs/contracts/firestore-paths.md). Edit `prayer_times_service.dart` carefully (CLAUDE.md).

## Local Interface & Invariants

### Interface
| File | Main public API |
| --- | --- |
| `notification_service.dart` | `NotificationService`: `initialize`, permissions, prayer reminders (`schedulePrayerNotification`, `scheduleDailyPrayers`, `scheduleRemindMeAgain`), task reminders + daily summary/digest, wird reminders, achievement toast, post-prayer check, Jumu'ah, focus-mode + overlay/DND helpers |
| `prayer_alarm_service.dart` | `PrayerAlarmService`: native adhan/reminder/post-check alarms, `scheduleDailyPrayerAlarms`, exact-alarm permission, native status sync (`getNativePrayerStatuses`, `syncNativePrayerStatuses`), daily summary |
| `prayer_times_service.dart` | `PrayerTimesService()`: `getPrayerTimes`, `getNextPrayer`, `getCurrentPrayer`, `getTimeRemaining`, static `loadIqamaMinutes` |
| `prayer_tracking_service.dart` | `PrayerTrackingService`: `recordPrayer`, `deletePrayerRecord`, day/range/month reads, `watchDay` stream, `getStatistics`, `calculateCurrentStreak`, `cleanupFuturePrayerRecords` |
| `task_service.dart` | `TaskService`: task stream/once/paging, add/update/toggle/delete/reorder, `getStatistics`, guest migration, `rescheduleAllTaskReminders`; `TaskStatistics` |
| `wird_service.dart` | `WirdService`: settings, daily progress, juz/khatma, bookmark sync, streak/stats, reminders, `syncToFirestore` / `syncFromFirestore` |
| `achievement_service.dart` | `AchievementService`: `checkAndAward`, `getEarnedAchievements`, `newAchievements` stream |
| `dhikr_service.dart` | `DhikrService`: `recordSession`, range/recent reads, `getStatistics` |
| `auth_service.dart` | `AuthService`: email auth, Google sign-in (plugin on mobile, PKCE loopback on desktop), sign-out, delete account |
| `firestore_service.dart` | `FirestoreService`: `users/{uid}` CRUD, `updateUserFields`, `userExists` |
| `sync_service.dart` | `SyncService.syncPendingOperations` (wird push + offline-queue replay) |
| `offline_queue_service.dart` | `OfflineQueueService` (enqueue/dequeue/getQueue), `QueuedOperation` |
| `shared_preferences_service.dart` | `SharedPreferencesService` (`getInstance()` then sync `instance`): typed get/set for app prefs, tutorial/banner flags, `restorePreferences` |
| `background_service_manager.dart` | `BackgroundServiceManager`: start/stop/toggle foreground service, `updatePrayerTimes`, `cacheAccuratePrayerTimes` |
| `prayer_widget_service.dart` | `PrayerWidgetService.savePrayerTimes` (prayer home widgets) |
| `task_widget_service.dart` | `TaskWidgetService.saveTasks`, `refreshWidget` (tasks widget) |
| `adhan_player_service.dart` | `AdhanPlayerService`: play/stop adhan, enabled/vibration flags, custom adhan |
| `silent_mode_service.dart` | `SilentModeService`: `setEnabled`, `setDuration`, `cancelAll` (no importer found — findings F9) |
| `platform_channel_service.dart` | `PlatformChannelService` (static): battery-optimization + exact-alarm checks/settings |
| `location_service.dart` | `LocationService`: permission, GPS, manual location, `getBestLocation`; `LocationData`; top-level `getLocalizedCityName` |
| `geocoding_service.dart` | `GeocodingService`: `searchCity`, `getLocalizedCityName`; `CityResult` |
| `desktop_notification_service.dart` | `DesktopNotificationService`: toasts (pre-prayer, adhan, post-check, task, wird), timer-based task/wird/digest scheduling |
| `desktop_prayer_scheduler.dart` | `DesktopPrayerScheduler`: `schedulePrayerTimers`, `prayerTimeStream`, `fireTestAdhan`, `cancelAll` |
| `desktop_adhan_service.dart` | `DesktopAdhanService`: `playAdhan`, `stop`, `setEnabled` |
| `desktop_tray_service.dart` | `DesktopTrayService`: tray icon/menu, `updateNextPrayer`, `setAdhanPlaying`, hide-to-tray |
| `windows_startup_service.dart` | `WindowsStartupService` (static): auto-start registry entry |
| `quran_service.dart` | `QuranService` (static): Quran data, surah/juz/page lookup, `searchAyahs` |
| `quran_svg_service.dart` | `QuranSvgService` (static): Mushaf SVG page fetch + disk/memory cache |
| `quran_bookmark_service.dart` | `QuranBookmarkService` (static): bookmarks, reading progress |
| `daily_content_service.dart` | `DailyContentService.getToday` (hard-coded ayah/hadith list) |
| `islamic_events_service.dart` | `IslamicEventsService.getUpcomingEvents` |
| `analytics_service.dart` | `AnalyticsService`: Firebase Analytics events |
| `rating_service.dart` | `RatingService.maybeRequest` (in-app review) |
| `firebase_options.dart` | `DefaultFirebaseOptions.currentPlatform` (generated config; do not edit) |
| `google_oauth_config.dart` / `.template.dart` | desktop OAuth client constants (real file is git-ignored; copy the template) |

### Invariants
- **Guest** (`'guest_user'`): tasks and prayer records stay in local prefs and never touch Firestore
  (`TaskService`, `PrayerTrackingService`); dhikr, achievements and wird cloud sync are skipped. Guest migration
  (`migrateGuestTasksToFirestore`) batch-writes under new ids, then clears local data; on failure local data is kept.
- **Prayer names**: canonical `'Zuhr'`; native/widget keys map it to `dhuhr` (`PrayerWidgetService` key helpers).
  Several ID/request-code maps match only `'Zuhr'` (a `'Dhuhr'` name falls back to 0/1000).
- **Platform split**: Android-only code paths are guarded (`_isAndroid` / `defaultTargetPlatform`); desktop
  (`isDesktop`) uses the `Desktop*` services and Dart timers. `NotificationService.initialize` returns early on desktop, so the plugin is never initialized there.
- **Notification IDs / channels / request codes**: defined in `NotificationService` and `PrayerAlarmService`.
  Ranges and known overlaps: notification-ids contract + findings F4, F7, F8. Never change them.
- **Prayer times**: `package:adhan`; Makkah method adds +3 min to Dhuhr; other dates are today's times shifted by
  whole days. Iqama defaults: 15 min (Maghrib 5). Next prayer after Isha = tomorrow's Fajr built from today's Fajr.
- **Prayer records**: doc id `{prayerName}_{yyyy-MM-dd}` (re-marking overwrites). `getStatistics` keeps the last
  status per prayer per day. Streak counts a day as complete at 5 distinct prayers.
  `cleanupFuturePrayerRecords` deletes today's records whose `prayedAt` is earlier than adhan + 20 min (findings F19).
- **Native status sync**: `prayer_status_{name}_{yyyy-MM-dd}` with values `on_time` / `late` / `missed`, recorded as `PrayerMethod.alone`.
- **Tasks**: desktop polls Firestore every 15 s (no `snapshots()`); mobile streams. Reminder re-arm is throttled to once
  per 6 h and skipped on desktop. Statistics use the 100 newest tasks.
- **Wird**: history pruned to 90 days; `syncFromFirestore` overwrites local data (cloud wins, 5 s timeout);
  `wird_progress_history` is not synced; `_pushToCloud` runs fire-and-forget after each change.
- **Foreground service** does not start when `background_notification_enabled` is false.
- **Desktop**: tray close hides the window instead of quitting; prayer timers cover today only (callers reschedule);
  auto-start is on by default and re-registered on every launch (the MSIX path changes).
  `getBestLocation` order: manual → cached desktop IP location → Mecca default (desktop), GPS (mobile). See findings F17.
- **Prefs init**: `SharedPreferencesService.getInstance()` must complete before the sync `instance` is used.
- Every MethodChannel call is wrapped in try/catch, except `AdhanPlayerService.setCustomAdhan`.

### Side Effects
- **MethodChannels**: `prayer_alarms` (NotificationService ×2 objects, PrayerAlarmService, PlatformChannelService),
  `background_service`, `widgets`, `adhan`, `focus_mode`, `silent_mode` (no native handler). Methods: see the contract.
- **Local notifications**: `flutter_local_notifications` on mobile non-native paths; Windows toasts via `local_notifier`.
- **Firestore**: `users/{uid}` and its subcollections `tasks`, `prayer_records`, `achievements`, `dhikr_sessions`, `wird/data`,
  plus offline-queue replay to `{collection}` (the queue is never filled — findings F16).
- **SharedPreferences (Dart-only key groups)**: `guest_tasks`, `guest_prayer_records`, `wird_*`, `quran_bookmarks`,
  `quran_reading_progress`, `manual_*`, `desktop_ip_*`, `notify_<prayer>`,
  `task_snoozed_until_<id>`, `task_reminders_rearmed_at`, `offline_operation_queue`, `iqama_minutes`,
  `adhan_enabled`, `adhan_vibration_enabled`, `foreground_service_enabled`, `windows_startup_enabled`, `rating_prompt_shown`,
  `app_install_date`, tutorial flags. Cross-boundary keys: prefs contract.
- **Network**: Firebase Auth / Google OAuth (`oauth2.googleapis.com`), `nominatim.openstreetmap.org`, `ipapi.co` (code
  present, never called), `cdn.jsdelivr.net` (Mushaf SVGs, cached in `<appDocs>/quran_pages`), Firebase Analytics.
- **Device**: GPS + permission requests, audio playback, vibration, Windows registry `HKCU\...\Run`, tray, loopback HTTP
  server during desktop sign-in.

## Subdirectories & System Boundaries
- None (flat directory).

## Global Invariants
- Native keys sent from here are contracts: change Dart + Kotlin + `.project-docs/contracts/` together.
- Services are called from both providers and widgets (two DI systems — refactor hotspot); keep `instance` access stable.

## Global Side Effects
- Exact alarms, notifications, the foreground service, home widgets, Firestore, local prefs, Windows tray/registry.

## System Verification
- Run: `flutter test` (covers `prayer_times_service.dart` only); device scenarios:
  [device checklist](/.project-docs/reference/device-checklist.md).
