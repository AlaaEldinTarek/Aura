# Core Providers Blueprint

## System Overview
Riverpod state layer for the whole app (12 files, flat, no subdirectories). Providers wrap the singleton services in
`lib/core/services/` (`XService.instance`) and expose state to `lib/features/`. Most notifiers are `StateNotifier`s that
load from SharedPreferences / Firestore in an async `_init()` and write through on every setter.
`prayer_times_provider.dart` is also the **scheduling hub**: each change of the prayer-times inputs fans out to native alarms,
widgets, the foreground service and desktop timers. Edit it carefully (CLAUDE.md).

## Local Interface & Invariants

### Interface
| File | Public providers / types | Main public methods |
| --- | --- | --- |
| `auth_provider.dart` | `firestoreServiceProvider`, `sharedPreferencesServiceProvider`, `authServiceProvider`, `authStateProvider` (stream), `AuthStateNotifier` / `authStateNotifierProvider`, `isLoggedInProvider`, `currentUserProvider` | `signInWithEmail`, `signUpWithEmail`, `signInWithGoogle`, `signOut`, `sendPasswordResetEmail` |
| `prayer_times_provider.dart` | `PrayerTimesState`, `PrayerTimesNotifier` / `prayerTimesProvider`, `prayerTimesServiceProvider`, `locationServiceProvider` | `loadPrayerTimes(date, {method, madhab})`, `updateNextPrayer()`, `setCalculationMethod`, `setAsrMadhab` |
| `daily_prayer_status_provider.dart` | `DailyPrayerStatus`, `DailyPrayerStatusNotifier` / `dailyPrayerStatusProvider` | `computeEffectiveToday`, `load`, `loadMonth`, `markDate` / `unmarkDate`, `markToday` / `unmarkToday`, `updatePrayer` / `removePrayer`, `startLiveSync` / `stopLiveSync` |
| `preferences_provider.dart` | Notifier + provider pairs: theme mode, language, first launch, guest mode, vibration (enabled / simplified), silent mode (enabled / duration), dynamic color, task notifications, Jumu'ah reminder, task reminder minutes, app mode, prayer tracking, daily summary time; `AppMode` enum; `tabNavigationProvider` (-1), `showTutorialProvider` | one setter each (`setThemeMode`, `setLanguage`, `setEnabled`, `setMinutes`, `setMode`, `setTime`, …) |
| `task_provider.dart` | `taskServiceProvider`, `currentUserIdProvider`, `tasksProvider` (family by `TaskFilterParams`), `allTasksProvider`, `taskWidgetSyncProvider`, `taskStatisticsProvider`, `todayTasksProvider`, `upcomingTasksProvider`, `highPriorityTasksProvider`, `TaskFilterParams` | — (stream / derived) |
| `guest_migration_provider.dart` | `GuestMigrationState`, `GuestMigrationNotifier` / `guestMigrationProvider` | `refresh()`, `migrate()`, `markDialogShown()` |
| `wird_provider.dart` | `quranStatsProvider`, `WirdNotifier` / `wirdStateProvider` | goals, reminders, `recordPagesRead`, `markComplete` / `undoComplete`, juz + bookmark sync, khatma, `resetAllProgress` |
| `quran_provider.dart` | `quranDataProvider`, `surahListProvider`, `juzListProvider`, `quranBookmarksProvider`, `quranReadingProgressProvider`, `quranSearchProvider`, `surahAyahsProvider` | `addBookmark`, `removeBookmark`, `replaceBookmark`, `saveProgress` |
| `azkar_provider.dart` | `AzkarNotifier` / `azkarProvider` | `toggleItem(id, category)`, `resetDay()` |
| `connectivity_provider.dart` | `ConnectivityStatus` {online, offline}, `ConnectivityNotifier` / `connectivityProvider`, `isOnlineProvider` | — |
| `background_service_provider.dart` | `backgroundServiceProvider`, `foregroundServiceRunningProvider`, `backgroundServiceInitProvider` | — |
| `islamic_events_provider.dart` | `islamicEventsProvider` | — |

### Invariants
- **Guest id** is `'guest_user'` (`task_provider.dart:currentUserIdProvider`, `models/prayer_record.dart:getCurrentUserId`).
  Firestore sync and live sync are skipped for it (`WirdNotifier._init`, `DailyPrayerStatusNotifier.startLiveSync`).
- **Login prefs direction** (`AuthStateNotifier._syncUserData`): returning user → device theme/language pushed **to**
  Firestore (never pulled); new user → `createUserData` with local prefs. Each Firestore call has a 5 s timeout, and errors are swallowed
  so login still succeeds. Guest tasks are **not** auto-migrated: a `pending_guest_migration_uid` flag is set and
  `GuestMigrationNotifier.migrate()` runs on user confirmation. `refresh()` re-reads the flag; the offer is pending
  only when the signed-in uid equals the flag uid (otherwise flag and local tasks are kept; F60).
- **Start flags** (`FirstLaunchNotifier`, `GuestModeNotifier`): start as `loading` until the first prefs read, then
  `data` (or `error`), so Splash cannot route on a default (F50b; `test/core/providers/start_flags_test.dart`).
- **Effective prayer day** (`DailyPrayerStatusNotifier.computeEffectiveToday`): before Fajr counts as yesterday.
  `markDate` blocks days after the effective day, and for the real calendar day it requires `isPrayerTimeReached` (adhan + 20 min, `utils/prayer_time_rules.dart`).
  Local state changes only if the service write returns `true`. `updatePrayer` / `removePrayer` are optimistic-only (no
  Firestore write). State is stale after 30 s or a day change.
- **Prayer side effects run when the inputs change** (`PrayerTimesNotifier.loadPrayerTimes`, FX-0): an input
  fingerprint (`sideEffectsFingerprint` in `utils/prayer_refresh.dart`: wall-clock date, method, madhab, iqama, the
  times of 7 calendar days) is compared with `_lastFingerprint` and stored synchronously; each run takes a number from
  the static `_generation` (reset in tests with `resetGenerationForTest()`) and stops before any platform write once a
  newer run has started. The order is fixed and every step is try/catch-isolated: widgets → desktop timers →
  foreground service (`updatePrayerTimes`) → 7-day accurate-times cache (`buildNativeCache`) → adhan alarms at next
  occurrence (`nextOccurrences`) → post-prayer checks (`postChecksToSchedule`, never cancelled). Task digest → prayer-record
  cleanup run after them once per wall-clock day (`_lastDailyEffectsDate`).
- **Day transition**: a 1-minute timer (`_quickUpdateNextPrayer`) only flips next/current flags. A full
  `loadPrayerTimes` runs when the next prayer falls on a later date. `updateNextPrayer` reloads for the next prayer's date.
  On desktop, a wall-clock gap of more than 3 min (sleep) re-runs `DesktopPrayerScheduler.schedulePrayerTimers`.
- **Platform split**: `_isDesktop` (Windows/macOS/Linux) uses the desktop services. Every other platform uses the
  Android-native paths (`PrayerAlarmService`, `BackgroundServiceManager`).
- **Dhuhr/Zuhr keys**: iqama key for Zuhr is `dhuhr_iqama_time`; the accurate-times cache maps Zuhr → `dhuhr`
  (`cached_YYYY-MM-DD_<name>`, today + 2 days). ⚠ The foreground-service map uses `'${name.toLowerCase()}_time'`, which
  gives **`zuhr_time`** (in `loadPrayerTimes`). See findings F15.
- Post-prayer check request codes are 1001–1006 (Sunrise skipped, future prayers only). Native adds +2000.
- Calculation method defaults to `muslimWorldLeague` (legacy names mapped); Asr madhab defaults to `shafi`; location is cached 15 min.
- Theme/language setters: save locally → set state → refresh widgets → Firestore `updateUserFields` only if logged in
  (3 s timeout, errors swallowed). A failure saving locally rethrows.
- Defaults: daily summary `'21:00'`, silent duration 20, task reminder 30 min, Jumu'ah on, app mode `both`
  (stored as `both` / `prayer_only` / `tasks_only`). Wird page goal is clamped 1–604, juz goal 1–30, at most 10 reminders.

### Side Effects
- **SharedPreferences (literal keys in this folder)**: `calculation_method`, `asr_madhab`, `language` (read),
  `jumua_reminder_enabled`, `task_reminder_minutes`, `app_mode`, `azkar_state`, `azkar_streak_date`,
  `pending_guest_migration_uid`. Other keys are written through `SharedPreferencesService`
  (see [prefs contract](/.project-docs/contracts/prefs-keys.md)).
- **Native (via services)**: `PrayerAlarmService.schedulePostPrayerCheck` / `scheduleDailyPrayerAlarms` /
  `scheduleDailySummary`; `BackgroundServiceManager.updatePrayerTimes` / `cacheAccuratePrayerTimes`;
  `NotificationService.scheduleDailyTaskDigest`; `PrayerWidgetService.savePrayerTimes`, `TaskWidgetService.saveTasks` /
  `refreshWidget`. Channel contracts: [method-channels](/.project-docs/contracts/method-channels.md).
- **Firestore (via services)**: `FirestoreService.userExists` / `createUserData` / `updateUserFields`;
  `PrayerTrackingService` record / delete / month reads, `watchDay` realtime subscription, `cleanupFuturePrayerRecords`;
  `TaskService.getTasksStream` / `getTasksOnce` / `migrateGuestTasksToFirestore`; `WirdService` sync.
- **Desktop**: `DesktopPrayerScheduler`, `DesktopAdhanService`, `DesktopTrayService`, `DesktopNotificationService`.
- **Other**: GPS via `LocationService.getBestLocation`; a `Timer.periodic` (1 min) and stream subscriptions (connectivity,
  `watchDay`), cancelled in `dispose`; going from offline to online triggers `SyncService.syncPendingOperations()`.

## Subdirectories & System Boundaries
- None (flat directory).

## Global Invariants
- Native keys sent from here are contracts: change Dart + Kotlin + `.project-docs/contracts/` together.
- `prayerTimesProvider` is read by `dailyPrayerStatusProvider` (Fajr time) and by the theme/language notifiers
  (widget refresh). Changing prayer state shape affects all three.

## Global Side Effects
- Writes to Android `aura_prayer_times` prefs (through channels), home-screen widgets, the foreground notification, exact alarms,
  Firestore `users/{uid}/…`, and desktop timers / tray.

## System Verification
- Run: `flutter test` (no tests cover this folder yet; device scenarios: [device checklist](/.project-docs/reference/device-checklist.md)).
