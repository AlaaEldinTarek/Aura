# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Aura (هالة)** is a 2-in-1 productivity and spiritual app combining **Islamic Prayer System** and **Task Management**. Built with Flutter and Firebase. Version **1.0.2+3**, package `com.aura.hala`.

**Key Features:**
- Accurate Islamic prayer times with 9 calculation methods (MWL, ISNA, Egyptian, Makkah, Karachi, Tehran, Kuwait, FixedAngle, Proportional)
- Location-based prayer time calculations using Adhan library
- Custom Adhan audio playback with native Android MediaPlayer integration
- Silent mode automation during prayer times (configurable duration, default 20 min)
- Two home screen widgets (NextPrayerWidget, AllPrayersWidget) with light/dark/LTR/RTL variants
- Qibla compass pointing to Kaaba
- Digital Dhikr/Tasbeeh counter with 6 presets + custom, haptic feedback
- Prayer tracking (on-time/late/missed/excused) with daily stats
- Daily Islamic content (Hadith, Ayah, Dua) from Firestore
- Task management with priorities, categories, due dates, subtasks, pin-to-top, recurring tasks, and Firestore sync
- Multi-language support (English/Arabic) with full RTL support
- Firebase authentication (Email/Password, Google Sign-In) + guest mode
- Hijri date display with Gregorian-to-Hijri conversion
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
| `authStateNotifierProvider` | `auth_provider.dart` | Auth state, sign-in/up/out, Firestore user sync |
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

### Complete Feature Structure
```
lib/
├── main.dart                          # Entry point, Firebase init, 12 named routes
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
│   │   └── daily_islamic_content.dart # DailyContent (hadith/ayah/dua) + DailyContentService
│   ├── providers/
│   │   ├── auth_provider.dart         # Auth state, login/signup/signout, user data sync
│   │   ├── preferences_provider.dart  # Theme, language, guest mode, vibration, silent mode
│   │   ├── prayer_times_provider.dart # Prayer times state, next/current prayer, auto-refresh
│   │   ├── connectivity_provider.dart # Network connectivity monitoring
│   │   ├── background_service_provider.dart # Foreground service
│   │   └── task_provider.dart         # Task streams, filters, statistics
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
│   │   ├── analytics_service.dart     # Firebase Analytics wrapper
│   │   ├── navigation_service.dart    # MethodChannel route tracking
│   │   ├── silent_mode_service.dart   # MethodChannel silent mode control
│   │   ├── platform_channel_service.dart # Battery optimization + alarm permission checks
│   │   ├── task_service.dart          # Firestore task CRUD, pagination, caching
│   │   ├── prayer_tracking_service.dart # Firestore prayer records with daily cache
│   │   └── firebase_options.dart      # Firebase platform config
│   ├── theme/
│   │   └── app_theme.dart             # Light/dark Material 3, primary #007DFF, cyan #00BCD4
│   ├── utils/
│   │   ├── date_formatter.dart        # Bilingual date formatting, month/day names
│   │   ├── number_formatter.dart      # Arabic-Hindi numeral conversion
│   │   ├── time_formatter.dart        # Duration/time bilingual formatting
│   │   ├── hijri_date.dart            # Gregorian → Hijri conversion with month names
│   │   └── haptic_feedback.dart       # Light/medium/heavy/selection with enable/simplified
│   └── widgets/
│       ├── bottom_nav_bar.dart        # 4-tab nav: Home, Prayer, Tasks, Profile
│       ├── greeting_widget.dart       # Time-based greeting (bilingual)
│       ├── permission_dialog.dart     # Battery optimization + exact alarm dialogs
│       ├── app_card.dart              # Reusable card wrapper with .large()
│       ├── empty_state.dart           # Empty state with icon/title/subtitle
│       ├── prayer_time_card.dart      # Gradient card with emoji + countdown
│       ├── prayer_card.dart           # Detailed prayer row with iqamah + mark-as-prayed
│       ├── setting_tile.dart          # Settings list tile
│       ├── shimmer_loading.dart       # ShimmerBox, ShimmerListTile, ShimmerCard
│       ├── offline_banner.dart        # ConnectivityWrapper + yellow offline banner
│       ├── circular_countdown.dart    # CircularCountdownTimer + CompactCountdown
│       └── task_card.dart             # Task card with priority/category badges
└── features/
    ├── splash/                        # Lottie splash, auth check → login/onboarding/home
    ├── auth/                          # LoginScreen, SignupScreen
    ├── onboarding/                    # PreferenceScreen (language + theme)
    ├── main/                          # MainWrapperScreen (4-tab PageView, back-to-exit)
    ├── home/                          # HomeScreen, CombinedHomeScreen (dashboard + stats)
    ├── prayer/                        # PrayerScreen, PrayerTrackingScreen
    ├── profile/                       # ProfileScreen
    ├── settings/                      # SettingsScreen, IqamaSettingsScreen, AdhanDownloadsScreen
    │                                  # AdhanCalculationMethod, AsrMadhabSelection, PrayerCalculationSettingsDialog
    ├── qibla/                         # QiblaScreen (compass to Kaaba 21.4225, 39.8262)
    ├── tasks/                         # TaskFormScreen, TaskStatsScreen
    ├── dhikl/                         # DhikrScreen (tasbeeh counter with haptic + animations)
    └── daily_content/                 # DailyIslamicContentScreen (Hadith, Ayah, Dua)
```

### Platform Channel Architecture (6 MethodChannels)

| Channel Name | Purpose | Flutter Service | Native Kotlin File |
|--------------|---------|-----------------|-------------------|
| `com.aura.hala/adhan` | Adhan audio playback | AdhanPlayerService | AdhanPlayer.kt |
| `com.aura.hala/prayer_alarms` | Schedule exact prayer alarms | PrayerAlarmService | PrayerAlarmReceiver.kt |
| `com.aura.hala/background_service` | Foreground service control | BackgroundServiceManager | PrayerForegroundService.kt |
| `com.aura.hala/widgets` | Widget data updates | PrayerWidgetService | WidgetUpdateService.kt |
| `com.aura.hala/ringer_mode` | Silent/vibrate mode control | SilentModeService | SilentModeAutomation.kt |
| `com.aura.hala/navigation` | Route tracking | NavigationService | MainActivity.kt |

### Native Android Architecture (13 Kotlin files)

Located at `android/app/src/main/kotlin/com/aura/hala/`:

| File | Purpose |
|------|---------|
| `MainActivity.kt` | FlutterActivity, 7 MethodChannel handlers, notification channels |
| `PrayerAlarmReceiver.kt` | BroadcastReceiver at prayer times, triggers adhan + notification + silent mode. Notification IDs: 1001-1006 (prayers), 2001-2006 (reminders) |
| `AdhanPlayer.kt` | Singleton MediaPlayer adhan playback, per-prayer audio, vibration, thread-safe |
| `SilentModeAutomation.kt` | AudioManager silent mode scheduling with configurable duration |
| `PrayerForegroundService.kt` | START_STICKY foreground service with next prayer countdown, updates every second |
| `PrayerWidgets.kt` | NextPrayerWidget + AllPrayersWidget, light/dark/LTR/RTL layouts |
| `WidgetUpdateService.kt` | Updates widget views from SharedPreferences prayer data |
| `AdhanFullScreenActivity.kt` | Full-screen intent over lock screen when adhan fires |
| `PrayerBootReceiver.kt` | Reschedules alarms after device boot or app update |
| `PrayerRescheduleService.kt` | Service for post-boot alarm rescheduling |
| `StopAdhanReceiver.kt` | Stops adhan from notification action button |
| `ToggleSilentModeReceiver.kt` | Toggles silent mode from adhan notification |
| `BackgroundServiceHandler.kt` | Handler for background service operations |

**AndroidManifest.xml declares:**
- 16 permissions (location, internet, vibration, wake lock, boot, exact alarms, notifications, foreground service, audio, battery, DND, storage)
- 7 receivers, 2 services, 2 activities (MainActivity + AdhanFullScreenActivity with lock screen)
- 70+ drawable XMLs, 10 layout XMLs, widget info XMLs

---

## Key Patterns and Conventions

### App Initialization Flow (main.dart)
1. `Firebase.initializeApp()` (with error handling)
2. `AnalyticsService.initialize()`
3. `EasyLocalization.ensureInitialized()`
4. `SharedPreferencesService` injected into Riverpod via ProviderScope override
5. `PrayerWidgetService.initialize()`
6. `NotificationService.initialize()`
7. `AdhanPlayerService.initialize()`
8. `PrayerAlarmService.initialize()`
9. `BackgroundServiceManager.initialize()`
10. `runApp()` → ProviderScope > AuraApp > EasyLocalization > AuraAppMaterial

### Routes (13 named routes in `_generateRoute`)
`/` (splash), `/login`, `/signup`, `/onboarding`, `/home`, `/prayer`, `/prayer_tracking`, `/task_form`, `/task_stats`, `/profile`, `/iqama_settings`, `/adhan_downloads`, `/daily_content`

### Prayer Time Calculation Flow
1. `LocationService.getBestLocation()` — Gets GPS (via geolocator) or manual location
2. `PrayerTimesService.getPrayerTimes()` — Calculates 6 prayer times using Adhan library with selected method + Asr madhab
3. `PrayerTimesNotifier.loadPrayerTimes()` — Loads, caches, and distributes prayer times
4. `getNextPrayer()` / `getCurrentPrayer()` — Determines next/current prayer with day transition handling
5. `NotificationService` schedules 10-minute reminder notifications
6. `PrayerAlarmService` schedules native exact alarms via MethodChannel
7. `PrayerWidgetService` updates home screen widgets

### Critical: Next Prayer Logic
The `getNextPrayer()` method in `PrayerTimesService` handles a critical edge case:
- When Fajr passes, it must return the NEXT prayer TODAY (Sunrise/Dhuhr/etc.)
- NOT tomorrow's Fajr (which would show 24-hour countdown)
- This is done by checking `prayer.time.isAfter(now)` for each prayer
- Only if ALL prayers have passed does it return tomorrow's Fajr
- PrayerTimesProvider auto-refreshes every minute via timer

### Notification Architecture (Dual System)
1. **Flutter NotificationService** — 10-minute reminder notifications BEFORE prayer via `flutter_local_notifications` with timezone support and "Remind Me Again" action (5 min before)
2. **Native PrayerAlarmReceiver** — Exact prayer time notifications via AlarmManager, triggers adhan playback, full-screen intent, and optional silent mode

### Foreground Service Notification (PrayerForegroundService)
- **Channel**: `prayer_foreground_channel`, `IMPORTANCE_HIGH`, `VISIBILITY_PUBLIC`
- **Priority**: `PRIORITY_MAX`, `CATEGORY_ALARM` — always top notification, visible on lock screen
- **Layout**: Custom `RemoteViews` with 4 variants: `notification_large` (LTR), `notification_large_rtl` (RTL), `notification_large_dark`, `notification_large_dark_rtl`
- **Timer format**: Digital clock `HH:MM` (no seconds, no emoji). Arabic uses Eastern numerals (٠١٢...)
- **Icon**: 48dp prayer icon selected by time period (reverse chronological order with `break`):
  - After Isha → moon, After Maghrib → maghrib, After Asr → afternoon, After Dhuhr/Sunrise → dhuhr, After Fajr → fajr
- **Day transition**: Detects stale prayer times, launches `MainActivity` with `refresh_prayer_times` extra to trigger Flutter recalculation
- **Layout dimensions**: Root padding 4dp top/bottom, 16dp sides; header 14dp icon + 11sp text; 1dp divider; 48dp prayer icon with 12dp gap to text

### State Sync Pattern
- **Firestore ↔ SharedPreferences**: Bidirectional sync for logged-in users
- **Sync on login**: Firestore data → SharedPreferences (returning users)
- **Sync on change**: SharedPreferences → Firestore (logged-in users)
- **Guest mode**: SharedPreferences-only, migrated to Firestore on account creation
- **Collections**: `users` (user data, settings), tasks, prayer_records

### Localization Pattern
- All UI strings use `.tr()` from `easy_localization`
- 184 translation keys in both `en.json` and `ar.json`
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
| `aura_prayer_times` | PrayerForegroundService, PrayerAlarmReceiver, AdhanFullScreenActivity, StopAdhanReceiver | Prayer times, next prayer name/Arabic/time, language |
| `aura_silent_mode` | SilentModeAutomation, PrayerAlarmReceiver, AdhanFullScreenActivity | silent_mode_enabled, is_silent_active, saved_ringer_mode |
| `aura_prefs` | AdhanPlayer | adhan_enabled |
| `${packageName}_preferences` | Flutter's shared_preferences package | Default Flutter prefs |

**NEVER use `${packageName}_preferences` in Kotlin code** — Flutter writes to it but native should read from the `aura_*` files above. This was the root cause of Arabic text not showing in full-screen azan and silent mode not working.

### Task System
- **Categories**: work, personal, shopping, health, study, prayer, other
- **Priorities**: low, medium, high
- **Recurrence**: none, daily, weekly, monthly — on completion auto-generates next occurrence via `completeRecurringTask()`
- **Subtasks**: `SubTask` model (id/title/isCompleted) nested inside Task; `subtaskProgress` (0.0–1.0) and `completedSubtasks` are computed properties
- **Pin to top**: `isPinned` field; `_applySort()` in TasksScreen always floats pinned tasks above all sort orders
- **Firestore-backed** with pagination, caching, and statistics
- **Computed properties**: isOverdue, isDueToday, isRecurring, subtaskProgress, completedSubtasks
- Stream-based Riverpod provider with family modifier
- **TasksScreen sections**: Today / Upcoming (next 7 days) / All Tasks — split client-side from `allTasksProvider`
- **TaskStatsScreen** at `/task_stats` — streak tracking via SharedPreferences (`task_streak_count`, `task_streak_date`)
- **Quick-add sheet**: implemented as `_QuickAddSheet` StatefulWidget (not `StatefulBuilder`) so `TextEditingController` is disposed by Flutter after dismiss animation, avoiding `_dependents.isEmpty` assertion crash

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
| UI | table_calendar, flutter_animate, lottie, wakelock_plus | various |
| Utilities | shared_preferences, path_provider, dio, url_launcher, share_plus, connectivity_plus, timezone, permission_handler, vibration | various |

---

## Important File Notes

### Configuration Files
- **pubspec.yaml**: Dependencies and app configuration (version 1.0.2+3)
- **analysis_options.yaml**: Dart analyzer settings
- **android/app/build.gradle**: Android build configuration
- **android/app/src/main/AndroidManifest.xml**: 16 permissions, 7 receivers, 2 services, 2 activities

### Critical Services (Edit Carefully)
- **`lib/core/services/prayer_times_service.dart`**: Prayer time calculations — handles day transitions, next/current prayer logic
- **`lib/core/services/location_service.dart`**: GPS/manual location with 50+ city translations
- **`lib/core/providers/prayer_times_provider.dart`**: State management, auto-refresh timer, alarm/notification/widget scheduling
- **`android/.../PrayerAlarmReceiver.kt`**: Native alarm handling — DO NOT modify notification IDs (1001-1006, 2001-2006)

### Native Code Gotchas
- **RemoteViews limitations**: Cannot use `<View>` elements (crashes on Android 10). Use `<FrameLayout>` for dividers instead.
- **Backup files**: Original notification layouts and PrayerForegroundService are backed up at `android/app/src/main/layout-backup/` (outside `res/` — backup folders inside `res/` break the Android resource merger).
- **Notification channel importance**: Android won't downgrade an existing channel's importance. Use `deleteNotificationChannel()` before recreating when upgrading importance.
- **Dhuhr/Zuhr naming**: SharedPreferences key is always `dhuhr_time`, but UI uses "Zuhr". All switch/map lookups must handle both names.

### Translation Files
- **`assets/translations/en.json`**: 184 English strings
- **`assets/translations/ar.json`**: 184 Arabic strings
- **When adding new strings, add to BOTH files**

### Assets
- **`assets/animations/splash_logo.json`**: Lottie splash animation
- **`assets/audio/adhan.mp3`**: Default adhan audio
- **`assets/fonts/`**: Roboto (Regular/Bold), Cairo (Regular/Bold)
- **`assets/images/`**: logo.png, logo-0.png, SVG design file

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
- **Light**: Primary blue (#007DFF), cyan secondary (#00BCD4), white/light surfaces
- **Dark**: Same primary colors, dark surfaces (#1A1B1E, #111317)
- Material 3 with custom ColorScheme, CardTheme, ElevatedButtonTheme, InputDecorationTheme
- Two font families: Roboto (English) and Cairo (Arabic)

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
- Verify `PrayerWidgetService` is initialized in main.dart
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
