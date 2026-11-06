# Architecture
Relocated from old CLAUDE.md on 2026-11-06; routes and counts re-checked where marked VERIFIED.

## Features
- Islamic prayer system: 9 calculation methods, location-based times, custom Adhan audio (native MediaPlayer), silent
  mode automation (default 20 min), Qibla compass, Hijri date, Jumu'ah reminder 30 min before Zuhr, foreground service
  for background alerts, prayer tracking (on-time/late/missed/excused).
- Task management: priorities, categories, due dates, subtasks, pin-to-top, recurring tasks, Focus Mode, Firestore sync.
- Quran reader (604 SVG pages), Wird, Dhikr/Tasbeeh (6 presets + custom), Azkar, daily content (Hadith/Ayah/Dua),
  Islamic events, achievements (filtered by app mode), interactive tutorials, InfoTipIcon help.
- Three home widgets; English/Arabic with full RTL; Firebase auth (Email/Password, Google, guest, offline queue).

## State management — `flutter_riverpod` 2.4.9 (`lib/core/providers/`)
- `authStateNotifierProvider`, `prayerTimesProvider`, `tasksProvider`, `dailyPrayerStatusProvider`,
  `quranDataProvider` / `surahListProvider` / `juzListProvider` / `quranBookmarksProvider` / `quranSearchProvider`,
  `wirdStateProvider`, `preferences_provider.dart`. Details in the matching module.

## Folders
```
lib/
├── main.dart                 # Firebase init, named routes
├── core/
│   ├── constants/app_constants.dart
│   ├── models/               # prayer_time, prayer_settings, prayer_record, task, dhikr, achievement, daily_content, quran_models, wird
│   ├── providers/            # auth, preferences, prayer_times, connectivity, background_service, task, quran, daily_prayer_status, wird
│   ├── services/             # prayer_times, location, geocoding, shared_preferences, auth, firestore, notification, adhan_player,
│   │                         # prayer_alarm, background_service_manager, prayer_widget, task_widget, analytics, navigation,
│   │                         # silent_mode, platform_channel, task, prayer_tracking, daily_content, achievement, dhikr,
│   │                         # offline_queue, sync, quran, quran_bookmark, quran_svg, wird, firebase_options, desktop_notification, windows_startup
│   ├── theme/app_theme.dart  # light/dark/AMOLED Material 3
│   ├── utils/                # date_formatter, number_formatter, time_formatter, hijri_date, haptic_feedback, prayer_time_rules
│   └── widgets/              # see modules/ui-kit.md
└── features/                 # splash auth onboarding main home prayer profile settings qibla tasks achievements
                              # dhikl azkar daily_content quran islamic_events (list from old CLAUDE.md + routes; Step 2 verifies)
```

## Routes — 25 `case` entries in `lib/main.dart` (VERIFIED 2026-11-06)
`/` splash, `/login`, `/signup`, `/onboarding`, `/mode_selection`, `/home`, `/prayer`, `/prayer_tracking`, `/prayer_report`,
`/dhikr`, `/dhikr_stats`, `/achievements`, `/task_stats`, `/task_form`, `/profile`, `/settings`, `/iqama_settings`,
`/adhan_downloads`, `/qibla`, `/daily_content`, `/quran`, `/azkar`, `/quran_stats`, `/islamic_events`, `/khatma_dua`.

## Init flow (`main.dart`)
1. `Firebase.initializeApp()` → `AnalyticsService.initialize()` → `EasyLocalization.ensureInitialized()`
2. `SharedPreferencesService` injected into Riverpod via ProviderScope override
3. Parallel: `PrayerWidgetService`, `TaskWidgetService`, `NotificationService`, `AdhanPlayerService`, `PrayerAlarmService`,
   `BackgroundServiceManager`, `OfflineQueueService`, `TaskService`
4. `runApp()` → ProviderScope > AuraApp > EasyLocalization > AuraAppMaterial

## Native Android
- 30 `.kt` files in `android/app/src/main/kotlin/com/aura/hala/` (VERIFIED count). Roster: modules/notifications-native.md,
  widgets.md, focus-mode.md. MethodChannels: contracts/method-channels.md.

## Key dependencies
`flutter_riverpod` 2.4.9, Firebase (core/auth/firestore/storage/analytics + google_sign_in), `adhan` 2.0.0+1,
`geolocator` 10.1.0, `flutter_local_notifications` 17.0.0, `audioplayers` 6.0.0, `easy_localization` 3.0.3,
`flutter_svg` 2.0.0, `dio` 5.0.0, `table_calendar`, `flutter_animate`, `lottie`, `shared_preferences`, `timezone`,
`permission_handler`, `wakelock_plus`, `dynamic_color`. (Versions from old CLAUDE.md; `pubspec.lock` is the truth.)

## Assets
- `assets/translations/en.json` + `ar.json`; `assets/fonts/uthmanic_hafs_v20.ttf`; `assets/data/hafsData_v2-0.json`
  (modules/quran-wird.md). SVG mushaf pages are not bundled (CDN + cache).
