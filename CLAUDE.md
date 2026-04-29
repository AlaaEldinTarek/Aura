# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Aura (هالة)** is a 2-in-1 productivity and spiritual app combining **Islamic Prayer System** and **Task Management**. Built with Flutter and Firebase. Version **1.0.2+3**, package `com.aura.hala`.

**Key Features:**
- Accurate Islamic prayer times with 9 calculation methods (MWL, ISNA, Egyptian, Makkah, Karachi, Tehran, Kuwait, FixedAngle, Proportional)
- Location-based prayer time calculations using Adhan library
- Custom Adhan audio playback with native Android MediaPlayer integration
- Silent mode automation during prayer times (configurable duration, default 20 min)
- Three home screen widgets (CombinedPrayerWidget, TasksWidget, DailyContentWidget) with light/dark/LTR/RTL variants. CombinedPrayerWidget uses ViewFlipper tabs for Next Prayer + Timeline views
- Qibla compass pointing to Kaaba
- Digital Dhikr/Tasbeeh counter with 6 presets + custom, haptic feedback, stats tracking
- Prayer tracking (on-time/late/missed/excused) with daily stats and prayer reports
- Achievements system with unlockable badges
- Daily Islamic content (Hadith, Ayah, Dua) from Firestore with home screen widget
- Task management with priorities, categories, due dates, subtasks, pin-to-top, recurring tasks, task notifications, and Firestore sync
- Multi-language support (English/Arabic) with full RTL support
- Firebase authentication (Email/Password, Google Sign-In, Forgot Password) + guest mode + offline queue
- Hijri date display with Gregorian-to-Hijri conversion
- Jumu'ah (Friday) reminder notification 30 min before Zuhr, with bilingual message and weekly auto-reschedule
- Foreground service for reliable background prayer alerts

---

## Development Commands

### Building and Running
```bash
# Run the app in debug mode
flutter run

# Run on specific device
flutter run -d <device_id>

# Build APK
flutter build apk --release

# Build app bundle for Play Store
flutter build appbundle --release
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart
flutter test test/core/utils/formatters_test.dart

# Run tests with coverage
flutter test --coverage
```

### Code Quality
```bash
# Analyze code for issues
flutter analyze

# Format code
dart format .

# Check for outdated dependencies
flutter pub outdated

# Clean build cache
flutter clean
```

### Android-Specific
```bash
# Clean Android build
cd android && ./gradlew clean && ./gradlew build

# Install APK directly to connected device
adb install build/app/outputs/flutter-apk/app-debug.apk
```

---

## Architecture Overview

### State Management: Riverpod
The app uses `flutter_riverpod` for reactive state management with these key providers:

| Provider | File | Purpose |
|----------|------|---------|
| `authStateNotifierProvider` | `auth_provider.dart` | Auth state, sign-in/up/out, Firestore user sync, `sendPasswordResetEmail()` |
| `themeModeProvider` | `preferences_provider.dart` | Theme (light/dark/system) synced with Firestore |
| `languageProvider` | `preferences_provider.dart` | Language (en/ar) synced with Firestore |
| `firstLaunchProvider` | `preferences_provider.dart` | First launch detection |
| `guestModeProvider` | `preferences_provider.dart` | Guest mode toggle |
| `vibrationEnabledProvider` | `preferences_provider.dart` | Haptic feedback toggle |
| `vibrationSimplifiedProvider` | `preferences_provider.dart` | Simplified vibration mode |
| `silentModeEnabledProvider` | `preferences_provider.dart` | Silent mode during prayer |
| `silentModeDurationProvider` | `preferences_provider.dart` | Silent mode duration |
| `prayerTimesProvider` | `prayer_times_provider.dart` | Prayer times, next/current prayer, alarms, widgets |
| `connectivityProvider` | `connectivity_provider.dart` | Online/offline monitoring |
| `backgroundServiceProvider` | `background_service_provider.dart` | Foreground service management |
| `tasksProvider` | `task_provider.dart` | Stream-based task CRUD with family modifier |
| `taskStatisticsProvider` | `task_provider.dart` | Task completion statistics |
| `todayTasksProvider` | `task_provider.dart` | Today's tasks |
| `upcomingTasksProvider` | `task_provider.dart` | Upcoming tasks |
| `highPriorityTasksProvider` | `task_provider.dart` | High priority tasks |
| `taskNotificationsEnabledProvider` | `preferences_provider.dart` | Task reminder notifications toggle (key: `task_notifications_enabled`) |
| `dailyPrayerStatusProvider` | `daily_prayer_status_provider.dart` | Daily prayer tracking status (on-time/late/missed/excused) |

### Complete Feature Structure
```
lib/
├── main.dart                          # Entry point, Firebase init, 20 named routes
├── core/
│   ├── constants/
│   │   └── app_constants.dart         # Colors, spacing, animation durations, pref keys
│   ├── models/
│   │   ├── prayer_time.dart           # PrayerTime (name, nameAr, time, iqama, isNext, isCurrent, emoji)
│   │   ├── prayer_settings.dart       # CalculationMethod (9 methods), AsrMadhab (Shafi/Hanafi)
│   │   ├── prayer_record.dart         # PrayerRecord, PrayerStatus, PrayerMethod, DailyPrayerSummary, PrayerStatistics
│   │   ├── user_data.dart             # UserData with Firestore serialization
│   │   ├── task.dart                  # Task, TaskPriority (low/med/high), TaskCategory (7 types)
│   │   ├── dhikr.dart                 # DhikrSession, DhikrPreset (6 built-in), DhikrStatistics
│   │   ├── achievement.dart           # Achievement model with unlockable badges
│   │   └── daily_content.dart         # DailyContent (hadith/ayah/dua) model
│   ├── providers/
│   │   ├── auth_provider.dart         # Auth state, login/signup/signout, user data sync
│   │   ├── preferences_provider.dart  # Theme, language, guest mode, vibration, silent mode
│   │   ├── prayer_times_provider.dart # Prayer times state, next/current prayer, auto-refresh
│   │   ├── connectivity_provider.dart # Network connectivity monitoring
│   │   ├── background_service_provider.dart # Foreground service
│   │   ├── task_provider.dart         # Task streams, filters, statistics
│   │   └── daily_prayer_status_provider.dart # Daily prayer tracking status
│   ├── services/
│   │   ├── prayer_times_service.dart  # Adhan library calc, iqama offsets, next/current logic
│   │   ├── location_service.dart      # GPS + manual location, 50+ city name translations
│   │   ├── geocoding_service.dart     # OpenStreetMap Nominatim API for city names
│   │   ├── shared_preferences_service.dart # Singleton prefs (theme, language, guest, etc.)
│   │   ├── auth_service.dart          # Firebase Auth (email, Google, sign-out, delete)
│   │   ├── firestore_service.dart     # Firestore CRUD on users collection
│   │   ├── notification_service.dart  # Flutter local notifications, 10-min reminders
│   │   ├── adhan_player_service.dart  # MethodChannel → native AdhanPlayer.kt
│   │   ├── prayer_alarm_service.dart  # MethodChannel → native PrayerAlarmReceiver.kt
│   │   ├── background_service_manager.dart # MethodChannel → native ForegroundService
│   │   ├── prayer_widget_service.dart # MethodChannel → native WidgetUpdateService.kt
│   │   ├── task_widget_service.dart   # MethodChannel → native TasksWidget.kt
│   │   ├── analytics_service.dart     # Firebase Analytics wrapper
│   │   ├── navigation_service.dart    # MethodChannel route tracking
│   │   ├── silent_mode_service.dart   # MethodChannel silent mode control
│   │   ├── platform_channel_service.dart # Battery optimization + alarm permission checks
│   │   ├── task_service.dart          # Firestore task CRUD, pagination, caching
│   │   ├── prayer_tracking_service.dart # Firestore prayer records with daily cache
│   │   ├── daily_content_service.dart # Daily Islamic content (hadith/ayah/dua) from Firestore
│   │   ├── achievement_service.dart   # Achievement unlock logic and badge management
│   │   ├── dhikr_service.dart         # Dhikr session persistence and statistics
│   │   ├── offline_queue_service.dart # Offline operation queue for Firestore writes
│   │   ├── sync_service.dart          # Data sync coordination service
│   │   └── firebase_options.dart      # Firebase platform config
│   ├── theme/
│   │   └── app_theme.dart             # Light/dark/amoled Material 3, primary #B5821B (light) / #F5B301 (dark), secondary #D4A43A
│   ├── utils/
│   │   ├── date_formatter.dart        # Bilingual date formatting, month/day names
│   │   ├── number_formatter.dart      # Arabic-Hindi numeral conversion
│   │   ├── time_formatter.dart        # Duration/time bilingual formatting
│   │   ├── hijri_date.dart            # Gregorian → Hijri conversion with month names
│   │   ├── haptic_feedback.dart       # Light/medium/heavy/selection with enable/simplified
│   │   └── prayer_time_rules.dart     # Prayer time validation and rule logic
│   └── widgets/
│       ├── bottom_nav_bar.dart        # 4-tab nav: Home, Prayer, Tasks, Profile
│       ├── greeting_widget.dart       # Time-based greeting (bilingual)
│       ├── permission_dialog.dart     # Battery optimization + exact alarm dialogs
│       ├── app_card.dart              # Reusable card wrapper with .large()
│       ├── empty_state.dart           # Empty state with icon/title/subtitle
│       ├── prayer_time_card.dart      # Gradient card with emoji + countdown
│       ├── prayer_card.dart           # Detailed prayer row with iqamah + mark-as-prayed
│       ├── prayer_status_dialog.dart  # Prayer status selection dialog (on-time/late/missed/excused)
│       ├── setting_tile.dart          # Settings list tile
│       ├── shimmer_loading.dart       # ShimmerBox, ShimmerListTile, ShimmerCard
│       ├── offline_banner.dart        # ConnectivityWrapper + yellow offline banner
│       ├── circular_countdown.dart    # CircularCountdownTimer + CompactCountdown
│       └── task_card.dart             # Task card with priority/category badges
└── features/
    ├── splash/                        # Lottie splash, auth check → login/onboarding/home
    ├── auth/                          # LoginScreen (with forgot password dialog), SignupScreen
    ├── onboarding/                    # PreferenceScreen (language + theme), ModeSelectionScreen
    ├── main/                          # MainWrapperScreen (4-tab PageView, back-to-exit)
    ├── home/                          # HomeScreen (with daily content card + Jumu'ah banner), CombinedHomeScreen
    ├── prayer/                        # PrayerScreen, PrayerTrackingScreen, PrayerReportScreen
    ├── profile/                       # ProfileScreen (with task stats summary cards)
    ├── settings/                      # SettingsScreen, IqamaSettingsScreen, AdhanDownloadsScreen
    │                                  # AdhanCalculationMethod, AsrMadhabSelection, PrayerCalculationSettingsDialog
    ├── qibla/                         # QiblaScreen (compass to Kaaba 21.4225, 39.8262)
    ├── tasks/                         # TaskFormScreen, TaskStatsScreen, _TaskSettingsSheet (notification toggle)
    ├── achievements/                  # AchievementsScreen (unlockable badge grid)
    ├── dhikl/                         # DhikrScreen, DhikrStatsScreen, CustomZikrFormScreen
    └── daily_content/                 # DailyContentScreen (Hadith, Ayah, Dua)
```

### Platform Channel Architecture (7 MethodChannels)

| Channel Name | Purpose | Flutter Service | Native Kotlin File |
|--------------|---------|-----------------|-------------------|
| `com.aura.hala/adhan` | Adhan audio playback | AdhanPlayerService | AdhanPlayer.kt |
| `com.aura.hala/prayer_alarms` | Schedule exact prayer alarms + post-prayer checks + daily summary + Jumu'ah reminder | PrayerAlarmService + NotificationService | PrayerAlarmReceiver.kt + DailySummaryReceiver.kt + JumuahReminderReceiver.kt |
| `com.aura.hala/background_service` | Foreground service control | BackgroundServiceManager | PrayerForegroundService.kt |
| `com.aura.hala/widgets` | Widget data updates | PrayerWidgetService | WidgetUpdateService.kt |
| `com.aura.hala/ringer_mode` | Silent/vibrate mode control | SilentModeService | SilentModeAutomation.kt |
| `com.aura.hala/navigation` | Route tracking + post-prayer/reminder picker callbacks (native→Flutter) | NavigationService | MainActivity.kt |
| `com.aura.hala/focus_mode` | Focus mode scheduling, overlay/DND permissions, service control | NotificationService | FocusModeService.kt |

### Native Android Architecture (22 Kotlin files)

Located at `android/app/src/main/kotlin/com/aura/hala/`:

| File | Purpose |
|------|---------|
| `MainActivity.kt` | FlutterActivity, 8 MethodChannel handlers (including Jumu'ah reminder schedule/cancel), notification channels |
| `PrayerAlarmReceiver.kt` | BroadcastReceiver at prayer times, triggers adhan + notification + silent mode. Also handles post-prayer check alarms (30 min after prayer). Notification IDs: 1001-1006 (prayers), 2001-2006 (reminders), 6001-6006 (post-prayer checks) |
| `DailySummaryReceiver.kt` | BroadcastReceiver firing at configurable daily time. Reads `prayer_status_{name}_{date}` keys from `aura_prayer_times` prefs. If any untracked prayers exist, shows summary notification (ID 7001). Reschedules itself for tomorrow. |
| `JumuahReminderReceiver.kt` | BroadcastReceiver firing every Friday 30 min before Zuhr. Shows bilingual "Jumu'ah Mubarak" notification (ID 8001, channel `jumuah_reminder`). Reads Zuhr time from `aura_prayer_times` prefs, auto-reschedules weekly. Rescheduled on boot by `PrayerBootReceiver`. |
| `AdhanPlayer.kt` | Singleton MediaPlayer adhan playback, per-prayer audio, vibration, thread-safe |
| `SilentModeAutomation.kt` | AudioManager silent mode scheduling with configurable duration |
| `PrayerForegroundService.kt` | START_STICKY foreground service with next prayer countdown, updates every second |
| `PrayerWidgets.kt` | CombinedPrayerWidget (AllPrayersWidget class) with ViewFlipper tabs (Next Prayer + Timeline), light/dark/LTR/RTL layouts |
| `TasksWidget.kt` | Home screen tasks widget with task count and next due task |
| `WidgetUpdateService.kt` | Updates widget views from SharedPreferences prayer data |
| `DailyContentWidget.kt` | Home screen widget for daily Islamic content (ayah/hadith) |
| `RingProgressView.kt` | Custom circular progress view for prayer/dhikr counters |
| `AdhanFullScreenActivity.kt` | Full-screen intent over lock screen when adhan fires |
| `FocusModeService.kt` | START_STICKY foreground service with system overlay (TYPE_APPLICATION_OVERLAY) for inescapable focus mode. Blocks notification shade via second overlay. Shows countdown timer, task completion prompt, and restart options. Restores sound mode on timer end. Uses full-screen intent notification to relaunch when user escapes to recent apps |
| `FocusModeActivity.kt` | Full-screen activity for focus mode. Uses startLockTask() for complete phone lockdown. No stopLockTask() at timer end so completion/restart UI stays locked. Only unlocks via finishFocusMode(). DND restored unconditionally on timer end |
| `AuraAccessibilityService.kt` | Accessibility service that auto-accepts the Android "Screen pinned" dialog by detecting "Screen pinned" text and clicking OK silently. User enables once via permissions page. Prevents users from seeing the system screen pinning dialog |
| `FocusModeReceiver.kt` | BroadcastReceiver for focus mode alarm, starts FocusModeService |
| `PrayerBootReceiver.kt` | Reschedules all alarms (prayer + daily summary + Jumu'ah reminder) after device boot or app update |
| `PrayerRescheduleService.kt` | Service for post-boot alarm rescheduling |
| `StopAdhanReceiver.kt` | Stops adhan from notification action button |
| `ToggleSilentModeReceiver.kt` | Toggles silent mode from adhan notification |
| `SilentOffReceiver.kt` | Auto-restores ringer mode after silent mode timer expires |
| `BackgroundServiceHandler.kt` | Handler for background service operations |

**AndroidManifest.xml declares:**
- 18 permissions (location, internet, vibration, wake lock, boot, exact alarms, notifications, foreground service, audio, battery, DND, storage, SYSTEM_ALERT_WINDOW, REORDER_TASKS)
- 11 receivers (10 existing + JumuahReminderReceiver), 3 services, 3 activities (MainActivity + AdhanFullScreenActivity + FocusModeActivity with lock screen)
- 109 drawable XMLs, 20 layout XMLs, 5 widget info XMLs

---

## Key Patterns and Conventions

### App Initialization Flow (main.dart)
1. `Firebase.initializeApp()` (with error handling)
2. `AnalyticsService.initialize()`
3. `EasyLocalization.ensureInitialized()`
4. `SharedPreferencesService` injected into Riverpod via ProviderScope override
5. Parallel initialization of all services:
   - `PrayerWidgetService.initialize()`
   - `TaskWidgetService.initialize()`
   - `NotificationService.initialize()`
   - `AdhanPlayerService.initialize()`
   - `PrayerAlarmService.initialize()`
   - `BackgroundServiceManager.initialize()`
   - `OfflineQueueService.initialize()`
   - `TaskService.initialize()`
6. `runApp()` → ProviderScope > AuraApp > EasyLocalization > AuraAppMaterial

### Routes (20 named routes in `_generateRoute`)
`/` (splash), `/login`, `/signup`, `/onboarding`, `/mode_selection`, `/home`, `/prayer`, `/prayer_tracking`, `/prayer_report`, `/dhikr`, `/dhikr_stats`, `/achievements`, `/task_form`, `/task_stats`, `/profile`, `/iqama_settings`, `/adhan_downloads`, `/qibla`, `/daily_content`

### Prayer Time Calculation Flow
1. `LocationService.getBestLocation()` — Gets GPS (via geolocator) or manual location. **Location cached for 15 minutes** (`_locationCacheTTL`) to avoid GPS on every minute tick.
2. `PrayerTimesService.getPrayerTimes()` — Calculates 6 prayer times using Adhan library with selected method + Asr madhab
3. `PrayerTimesNotifier.loadPrayerTimes()` — Loads, caches, and distributes prayer times. **Side effects run once per day** (guarded by `_lastSideEffectsDate` — set synchronously before the async block to prevent concurrent runs).
4. `getNextPrayer()` / `getCurrentPrayer()` — Determines next/current prayer with day transition handling
5. Side effects (fire-and-forget, skipped if already ran today):
   - `PrayerAlarmService.schedulePostPrayerCheck()` — native alarm 30 min after each future prayer
   - `NotificationService.scheduleDailyTaskDigest()` — 8 AM task count notification
   - `PrayerAlarmService.scheduleDailyPrayerAlarms()` — native exact alarms for adhan
   - `PrayerWidgetService.savePrayerTimes()` — updates home screen widgets
   - `BackgroundServiceManager.updatePrayerTimes()` — updates foreground service notification

### Critical: Next Prayer Logic
The `getNextPrayer()` method in `PrayerTimesService` handles a critical edge case:
- When Fajr passes, it must return the NEXT prayer TODAY (Sunrise/Dhuhr/etc.)
- NOT tomorrow's Fajr (which would show 24-hour countdown)
- This is done by checking `prayer.time.isAfter(now)` for each prayer
- Only if ALL prayers have passed does it return tomorrow's Fajr
- PrayerTimesProvider auto-refreshes every minute via timer

### Notification Architecture (Three-Layer System)
1. **Flutter NotificationService** — 10-minute reminder notifications BEFORE prayer via `flutter_local_notifications` with timezone support and "Remind Me Again" action (5 min before). Also schedules daily 8 AM task digest.
2. **Native PrayerAlarmReceiver** — Exact prayer time notifications via AlarmManager, triggers adhan playback, full-screen intent, and optional silent mode.
3. **Post-prayer check + daily summary** — Native alarms track whether each prayer was marked:
   - 30 min after adhan: `PrayerAlarmReceiver` fires with `is_post_check=true` → notification with Done/Late/Missed/Later actions (IDs 6001-6006). User's tap writes `prayer_status_{name}_{date}` to `aura_prayer_times` SharedPrefs.
   - At configurable daily time (default 21:00): `DailySummaryReceiver` fires (ID 7001) → counts untracked prayers → shows summary notification → reschedules itself for tomorrow.
   - On app resume: `MainWrapperScreen._syncNativePrayerStatuses()` calls `PrayerAlarmService.syncNativePrayerStatuses()` → reads native statuses → syncs each to Firestore via `PrayerTrackingService.recordPrayer()` → clears native key.
   - The navigation channel (`com.aura.hala/navigation`) receives `openPostPrayerPicker` / `openReminderPicker` / `updatePrayerStatus` callbacks from notification action buttons to drive Flutter UI.

**Notification channel**: `prayer_tracking` (IMPORTANCE_DEFAULT) — created by `DailySummaryReceiver` if absent (receiver fires without app open). Used for post-prayer check (6001-6006) and daily summary (7001) notifications.

### Jumu'ah Reminder Notification (JumuahReminderReceiver)
- **Channel**: `jumuah_reminder`, **Notification ID**: 8001
- **Trigger**: Every Friday, 30 minutes before Zuhr prayer time (reads `dhuhr_time` from `aura_prayer_times` SharedPrefs)
- **Scheduling**: Advances calendar to next Friday if not already Friday; auto-reschedules weekly after firing
- **Boot reschedule**: `PrayerBootReceiver.rescheduleJumuahReminder()` reschedules on device boot
- **Flutter control**: `scheduleJumuahReminder` / `cancelJumuahReminder` methods on `com.aura.hala/prayer_alarms` channel
- **Bilingual**: English "Jumu'ah Mubarak 🕌" / Arabic "جمعة مباركة 🕌"

### Foreground Service Notification (PrayerForegroundService)
- **Channel**: `prayer_foreground_channel`, `IMPORTANCE_HIGH`, `VISIBILITY_PUBLIC`
- **Priority**: `PRIORITY_MAX`, `CATEGORY_ALARM` — always top notification, visible on lock screen
- **Layout**: Custom `RemoteViews` with 4 variants: `notification_large` (LTR), `notification_large_rtl` (RTL), `notification_large_dark`, `notification_large_dark_rtl`
- **Timer format**: Digital clock `HH:MM` (no seconds, no emoji). Arabic uses Eastern numerals (٠١٢...)
- **Icon**: 42dp prayer icon selected by phone clock hour (not prayer times):
  - 0–4 → Isha (night), 5–6 → Fajr (dawn), 7–11 → Dhuhr (morning), 12–15 → Dhuhr (afternoon), 16–17 → Asr (late afternoon), 18–19 → Maghrib (evening), 20–23 → Isha (night)
- **Day transition**: Detects stale prayer times, launches `MainActivity` with `refresh_prayer_times` extra to trigger Flutter recalculation
- **Layout dimensions**: Root padding 4dp top/bottom, 16dp sides; header 14dp icon + 11sp text; 1dp divider; 42dp prayer icon with 12dp gap to text
- **RTL layout**: `notification_until` listed before `notification_time` in XML so Arabic reading order is correct; time uses `textDirection="ltr"` to prevent numeral reordering

### State Sync Pattern
- **Firestore ↔ SharedPreferences**: Bidirectional sync for logged-in users
- **Sync on login**: Firestore data → SharedPreferences (returning users)
- **Sync on change**: SharedPreferences → Firestore (logged-in users)
- **Guest mode**: SharedPreferences-only, migrated to Firestore on account creation
- **Collections**: `users` (user data, settings), tasks, prayer_records

### Localization Pattern
- All UI strings use `.tr()` from `easy_localization`
- Translation keys in both `en.json` and `ar.json` (kept in sync)
- Arabic numeral conversion via `NumberFormatter.withArabicNumeralsByLanguage()`
- RTL support via `context.locale.languageCode == 'ar'`
- AM/PM replaced with Arabic equivalents (ص/م)
- Arabic fonts: Cairo family for Arabic text, Roboto for English
- LocationService includes 50+ city name translations (EN/AR)

### Platform Channel Communication
- Flutter → Native: MethodChannel `invokeMethod()` calls
- Native → Flutter: Result callbacks and broadcast intents
- **Always use try-catch** around platform channel calls
- **Log extensively** with emoji prefixes for easy filtering (e.g., `🕌`, `📱`, `🔔`, `✅`, `🔄`)

### Critical: Native SharedPreferences File Names
Flutter `shared_preferences` does NOT use the same file as native Kotlin. Native code must use these specific file names:

| SharedPreferences File | Used By | Contains |
|------------------------|---------|----------|
| `aura_prayer_times` | PrayerForegroundService, PrayerAlarmReceiver, AdhanFullScreenActivity, StopAdhanReceiver, DailySummaryReceiver | Prayer times, next prayer name/Arabic/time, language. Also stores `prayer_status_{name}_{YYYY-MM-DD}` keys written by post-prayer check action buttons; read by DailySummaryReceiver and synced to Firestore on resume. |
| `aura_silent_mode` | SilentModeAutomation, PrayerAlarmReceiver, AdhanFullScreenActivity | silent_mode_enabled, is_silent_active, saved_ringer_mode |
| `aura_prefs` | AdhanPlayer | adhan_enabled |
| `aura_focus_mode` | FocusModeReceiver | completed_task_id, completed_at |
| `${packageName}_preferences` | Flutter's shared_preferences package, FocusModeService (writes `focus_completed_task_id`, `focus_task_was_completed`) | Default Flutter prefs + focus task completion |

**NEVER use `${packageName}_preferences` in Kotlin code** — Flutter writes to it but native should read from the `aura_*` files above. This was the root cause of Arabic text not showing in full-screen azan and silent mode not working.

### Task System
- **Categories**: work, personal, shopping, health, study, prayer, other
- **Priorities**: low, medium, high
- **Recurrence**: none, daily, weekly, monthly — on completion auto-generates next occurrence via `completeRecurringTask()`
- **Subtasks**: `SubTask` model (id/title/isCompleted) nested inside Task; `subtaskProgress` (0.0–1.0) and `completedSubtasks` are computed properties
- **Pin to top**: `isPinned` field; `_applySort()` in TasksScreen always floats pinned tasks above all sort orders
- **Due time**: `hasDueTime` boolean + `TimeOfDay` stored within `dueDate` DateTime; `_DueDateBadge` shows 12h format with ص/م for Arabic
- **Firestore-backed** with pagination, caching, and statistics
- **Computed properties**: isOverdue, isDueToday, isUpcoming, isRecurring, subtaskProgress, completedSubtasks
- Stream-based Riverpod provider with family modifier
- **TasksScreen sections**: Overdue / Today / Upcoming / All Tasks / Completed (collapsible) — split client-side from `allTasksProvider`. Midnight timer fires at 00:00 to refresh sections. Resume date-change detection refreshes if day changed while app was in background
- **Category filter chips**: horizontal scroll with persistence via SharedPreferences (`task_category_filter`)
- **Tag filter chips**: auto-generated from all task tags
- **Sort**: dateDesc, dateAsc, priority, title — persisted via SharedPreferences (`task_sort_order`). Pinned tasks always float to top
- **Search**: live filtering across title, description, tags
- **Calendar view**: `TableCalendar` with day markers, day selection shows tasks for that day
- **Context menu**: 3-dot icon (⋮) on each card opens Edit, Duplicate, Change Priority, Pin/Unpin, Toggle Complete, Delete. Uses `onMenuTap` callback (separate from `onLongPress` which is reserved for drag-to-reorder in Custom Order mode)
- **Bulk select mode**: multi-select with bottom action bar for Complete/Delete
- **Clear completed**: button in completed section header with confirmation dialog
- **Quick-add sheet**: priority/category/date/time chips with `StatefulBuilder`
- **Undo delete**: snackbar with undo action, 2-second floating duration
- **Celebration overlay**: shown when all today's tasks completed; uses `AnimationController` (not flutter_animate)
- **Task streak**: tracked via SharedPreferences (`task_streak_count`, `task_streak_date`); incremented on home screen when last today task completed
- **Daily summary notification**: ID 3999, scheduled via `matchDateTimeComponents: DateTimeComponents.time`
- **Task statistics screen** at `/task_stats` — 2 tabs (Overview/Details), 7-day bar chart, category/priority breakdown, streak, time stats
- **Task notifications**: `scheduleTaskReminder()` in `NotificationService` — tasks with time get 30-min-before reminder; tasks without time get 9:00 AM reminder on due date. Controlled by `task_notifications_enabled` pref. Toggled via `_TaskSettingsSheet` (gear icon in TasksScreen AppBar)
- **Focus Mode**: System overlay + `startLockTask()` for complete phone lockdown. Flow: alarm fires → `FocusModeReceiver` → starts `FocusModeService` → overlay covers screen → `FocusModeActivity` calls `startLockTask()`. `AuraAccessibilityService` auto-clicks OK on the "Screen pinned" dialog silently. After timer: DND restored unconditionally, touch blocker removed, shows "Did you complete?" prompt. Yes → marks task done via native MethodChannel (`getFocusCompletedTaskId`) — bypasses Flutter SharedPreferences cache. No → restart options (5/10/15/25/45/60 min + custom). Task completion detected in `TasksScreen.didChangeAppLifecycleState`. `focus_a11y_ever_enabled` SharedPreferences flag prevents re-asking for accessibility permission on Huawei EMUI which kills services between sessions. Requires `SYSTEM_ALERT_WINDOW` permission + `BIND_ACCESSIBILITY_SERVICE`. Task fields: `focusMode` (bool), `focusDurationMinutes` (int, default 25)
- **App resume** (`MainWrapperScreen.didChangeAppLifecycleState`): calls `_checkUntrackedPrayers()` (shows post-prayer dialog if any prayer passed without tracking), `ref.invalidate(prayerTimesProvider)`, `ref.invalidate(tasksProvider)`, `_handleWidgetIntent()`, `_syncNativePrayerStatuses()` (syncs any statuses tapped in notifications to Firestore). On cold start: `_scheduleDailySummaryOnStartup()` and `_checkUntrackedPrayers()` after 3s delay.
- **Search scope**: covers title, description, tags, and subtask titles
- **Profile stats**: `_buildTaskStatsSummary()` in ProfileScreen shows Today/Done/Pending cards from `taskStatisticsProvider`

### Dhikr/Tasbeeh System
- **6 built-in presets**: SubhanAllah, Alhamdulillah, Allahu Akbar, La ilaha illallah, Astaghfirullah, Custom
- Haptic feedback on each tap (with enable/simplified modes)
- Session tracking with count and target
- Statistics persistence

---

## Key Dependencies

| Category | Package | Version |
|----------|---------|---------|
| State Management | flutter_riverpod | 2.4.9 |
| Firebase | firebase_core, firebase_auth, cloud_firestore, firebase_storage, firebase_analytics, google_sign_in | various |
| Prayer | adhan | 2.0.0+1 |
| Location | geolocator, geocoding | 10.1.0, 3.0.0 |
| Sensors | flutter_compass, sensors_plus | 0.8.0, 4.0.2 |
| Notifications | flutter_local_notifications | 17.0.0 |
| Audio | audioplayers | 6.0.0 |
| Localization | easy_localization, intl | 3.0.3, 0.20.2 |
| UI | table_calendar, flutter_animate, lottie, wakelock_plus, dynamic_color | various |
| Utilities | shared_preferences, path_provider, dio, url_launcher, share_plus, connectivity_plus, timezone, permission_handler, vibration | various |

---

## Important File Notes

### Configuration Files
- **pubspec.yaml**: Dependencies and app configuration (version 1.0.2+3)
- **analysis_options.yaml**: Dart analyzer settings
- **android/app/build.gradle**: Android build configuration
- **android/app/src/main/AndroidManifest.xml**: 18 permissions, 8 receivers, 3 services, 3 activities

### Critical Services (Edit Carefully)
- **`lib/core/services/prayer_times_service.dart`**: Prayer time calculations — handles day transitions, next/current prayer logic
- **`lib/core/services/location_service.dart`**: GPS/manual location with 50+ city translations
- **`lib/core/providers/prayer_times_provider.dart`**: State management, auto-refresh timer, alarm/notification/widget scheduling
- **`android/.../PrayerAlarmReceiver.kt`**: Native alarm handling — DO NOT modify notification IDs (1001-1006 prayers, 2001-2006 reminders, 6001-6006 post-prayer checks)
- **`android/.../DailySummaryReceiver.kt`**: Daily summary — ID 7001. Reads `prayer_status_*` keys from `aura_prayer_times` prefs; do not change key format.

### Native Code Gotchas
- **RemoteViews limitations**: Cannot use `<View>` elements (crashes on Android 10). Use `<FrameLayout>` for dividers instead.
- **Backup files**: Original notification layouts and PrayerForegroundService are backed up at `android/app/src/main/layout-backup/` (outside `res/` — backup folders inside `res/` break the Android resource merger).
- **Notification channel importance**: Android won't downgrade an existing channel's importance. Use `deleteNotificationChannel()` before recreating when upgrading importance.
- **Dhuhr/Zuhr naming**: SharedPreferences key is always `dhuhr_time`, but UI uses "Zuhr". All switch/map lookups must handle both names.
- **Language switching**: `MainWrapperScreen.build()` must call `ref.watch(languageProvider)` — without it, bottom nav labels and screen AppBar titles won't rebuild when the locale changes.

### Translation Files
- **`assets/translations/en.json`**: 392 English strings
- **`assets/translations/ar.json`**: 392 Arabic strings
- **When adding new strings, add to BOTH files**

### Assets
- **`assets/animations/splash_logo.json`**: Lottie splash animation
- **`assets/audio/adhan.mp3`**: Default adhan audio
- **`assets/fonts/`**: Roboto (Regular/Bold), Cairo (Regular/Bold), HafsSmart_08.ttf (Hafs Quran font for Ayah display)
- **`assets/images/`**: logo.png, logo-0.png, logo_dark.png, logo-0_dark.png, SVG design file
- **`assets/data/`**: Offline data files (hadith/ayah/dua)

### Test Files
- **`test/widget_test.dart`**: Basic smoke test
- **`test/core/utils/formatters_test.dart`**: Number and time formatter tests

---

## Firebase Configuration

- **Project**: com-aura-hala
- **Configuration**: `lib/core/services/firebase_options.dart`
- **Collections**: `users` (user data, settings), tasks, prayer_records
- **Authentication**: Email/Password + Google Sign-In
- **Analytics**: Firebase Analytics tracking enabled
- **Storage**: Firebase Storage for adhan audio files

---

## Theme System

Defined in `lib/core/theme/app_theme.dart`:
- **Visual Identity Color**: `#F5B301` (bright gold) — used everywhere as `AppConstants.primaryColor`
- **Light**: Primary `#B5821B` (warm gold), warm cream surfaces `#FFF8EB`, cards `#FFF3D6`, borders `#E8D5A8`, text `#2A2418`/`#7A6E5A`
- **Dark**: Primary `#F5B301` (bright gold), dark surfaces (#1A1B1E, #111317)
- **AMOLED**: True black surfaces for OLED screens, same `#F5B301` primary
- **Dynamic color**: Optional Material You dynamic colors via `dynamic_color` package
- Material 3 with custom ColorScheme, CardTheme, ElevatedButtonTheme, InputDecorationTheme
- Two font families: Roboto (English) and Cairo (Arabic)

### Color Palette (Amber/Gold)

| Role | Light | Dark |
|------|-------|------|
| Primary | `#B5821B` | `#F5B301` |
| AppConstants.primaryColor | `#F5B301` (used everywhere in Flutter) | Same |
| Native Primary | `#B5821B` | `#F5B301` |
| Primary Container | `#FFEACC` | `#F5B301` |
| Secondary/Accent | `#D4A43A` | `#D4A43A` |
| Background | `#FFF8EB` (warm cream) | `#111317` |
| Surface/Card | `#FFF3D6` | `#1A1B1E` |
| Text Primary | `#2A2418` | `#FFFFFF` |
| Text Secondary | `#7A6E5A` | `#B0B0B0` |
| Border | `#E8D5A8` | `#3A3A3A` |

---

## Common Issues and Solutions

### Prayer Times Not Updating
- Check if location permission is granted
- Verify GPS is enabled or manual location is set
- Look for `🔄 [PRAYER_TIMES]` logs in console

### Adhan Not Playing
- Check `AdhanPlayerService: Initialized` log
- Verify adhan_enabled preference is true
- Test with "Test Adhan" button in prayer settings
- Check if `assets/audio/adhan.mp3` exists

### Notifications Not Showing
- Check notification permission in Android Settings (Android 13+)
- Verify notification channel "prayer_times" exists
- Look for `✅ [NOTIFICATION] Notification SUCCESSFULLY SHOWN` log
- Check exact alarm permission (Android 12+)

### Background Service Issues
- Check battery optimization settings (should be disabled)
- Verify exact alarm permission (Android 12+)
- Look for foreground service logs
- Check `PrayerForegroundService` is START_STICKY

### Widgets Not Updating
- Verify `PrayerWidgetService` and `TaskWidgetService` are initialized in main.dart
- Check SharedPreferences has prayer data
- Look for widget update logs

---

## Adding New Features

### Adding a New Prayer Setting
1. Add to SharedPreferencesService (getter/setter)
2. Add provider in `lib/core/providers/preferences_provider.dart`
3. Add UI in settings screen
4. Handle in native code if needed (e.g., for silent mode)
5. Add translations to both en.json and ar.json

### Adding a New Screen
1. Create in appropriate `lib/features/` subdirectory
2. Add route in `main.dart` `_generateRoute()`
3. Add navigation logic where needed
4. Add to bottom nav in `lib/core/widgets/bottom_nav_bar.dart` if main section
5. Add translations to both en.json and ar.json

### Adding a New Translation Key
1. Add key to `assets/translations/en.json`
2. Add same key with Arabic translation to `assets/translations/ar.json`
3. Use `key.tr()` in code

### Modifying Prayer Calculation Logic
- **WARNING**: Be extremely careful with `PrayerTimesService`
- Test thoroughly with different times of day
- Verify next prayer transitions work correctly (especially midnight crossover)
- Check both manual and GPS location modes
- Test with all 9 calculation methods

### Adding a New Native Feature
1. Create Kotlin handler in `android/.../kotlin/com/aura/hala/`
2. Register MethodChannel in `MainActivity.kt`
3. Create Flutter service in `lib/core/services/` with try-catch
4. Add provider if state management needed
5. Register in `main.dart` initialization

---

## Testing Prayer Time Features

### Manual Testing Checklist
1. **Location Change**: Test GPS vs manual location switching
2. **Time Change**: Manually set device time to test prayer transitions
3. **Day Transition**: Test around midnight (Fajr to Isha to next Fajr)
4. **Adhan Playback**: Test each prayer's adhan audio
5. **Silent Mode**: Verify silent mode enables/disables correctly
6. **Notifications**: Test 10-minute reminders and exact prayer time notifications
7. **Widgets**: Verify NextPrayerWidget and AllPrayersWidget update correctly
8. **Calculation Methods**: Test all 9 calculation methods
9. **Asr Madhab**: Test both Shafi and Hanafi
10. **Language**: Test both English and Arabic with RTL
11. **Widgets**: Verify TasksWidget and DailyContentWidget update correctly
12. **Achievements**: Verify badge unlock triggers and display correctly

### Quick Test Commands
```bash
# Run specific test
flutter test test/core/utils/formatters_test.dart

# Build and install
flutter build apk --release && adb install build/app/outputs/flutter-apk/app-release.apk

# View logs
adb logcat | grep -E "(PrayerAlarm|NotificationService|PrayerTimes|AdhanPlayer|SilentMode)"

# View specific prayer logs
adb logcat | grep "🕌"
```

---

## Git Commit Guidelines

### Commit Rules
- **One commit per logical change** — never bundle unrelated changes together
- **Clear, descriptive messages** — explain what was changed AND why
- **Use imperative mood** — "Fix Zuhr prayer skipped" not "Fixed Zuhr prayer"
- **Always include Co-Authored-By** — `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`

### Commit Message Format
```
Short summary of what changed (under 72 chars)

Detailed explanation of what was changed, why, and which files
are affected. Reference specific function names or files.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

### Examples of Good Commits
- `Fix Zuhr prayer being skipped in alarm scheduling` — one specific bug, one commit
- `Add custom notification layout with big prayer icons and RTL support` — one feature
- `Fix prayer progress showing all prayers as tracked` — one bug fix

### Examples of Bad Commits
- `Update stuff` — too vague
- `Fix bugs and add features and update UI` — too many changes in one commit
- `Changes` — meaningless

### Dhuhr → Zuhr Naming Convention
After renaming "Dhuhr" to "Zuhr" in the UI, the Adhan library still uses `.dhuhr`. All switch statements must handle both:
- Flutter: `case 'dhuhr': case 'zuhr':`
- Kotlin: `"Dhuhr", "Zuhr" ->`
- SharedPreferences key: always use `dhuhr_time`
- `kPrayerNames` uses `'Zuhr'` as canonical name
