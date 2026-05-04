# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Aura (هالة)** is a 2-in-1 productivity and spiritual app combining **Islamic Prayer System** and **Task Management**. Built with Flutter and Firebase. Version **1.0.0+4**, package `com.aura.hala`.

**Key Features:**
- 9 prayer calculation methods (MWL, ISNA, Egyptian, Makkah, Karachi, Tehran, Kuwait, FixedAngle, Proportional)
- Location-based prayer times via Adhan library; custom Adhan audio via native Android MediaPlayer
- Silent mode automation during prayer times (configurable duration, default 20 min)
- Three home screen widgets (CombinedPrayerWidget, TasksWidget, DailyContentWidget) with light/dark/LTR/RTL variants
- Qibla compass, Digital Dhikr/Tasbeeh counter (6 presets + custom), prayer tracking (on-time/late/missed/excused)
- Achievements system, daily Islamic content (Hadith, Ayah, Dua) from Firestore
- Task management: priorities, categories, due dates, subtasks, pin-to-top, recurring tasks, Firestore sync
- Multi-language (English/Arabic) with full RTL; Firebase auth (Email/Password, Google, guest mode, offline queue)
- Hijri date display; Jumu'ah reminder 30 min before Zuhr; Foreground service for background prayer alerts
- Bookmarks: delete icon per item with confirmation dialog + undo Snackbar (NOT long-press delete)
- Wird (daily Quran reading commitment): two tracking modes (pages or juz), custom goal, streak tracking, bookmark color auto-sync, multiple configurable daily reminders, 4 achievements

---

## Development Commands

```bash
flutter run                          # debug
flutter build apk --release          # release APK
flutter build appbundle --release    # Play Store bundle
flutter test                         # run all tests
flutter analyze && dart format .     # lint + format
adb logcat | grep -E "(PrayerAlarm|NotificationService|PrayerTimes|AdhanPlayer|SilentMode)"
adb logcat | grep "🕌"
```

---

## Architecture Overview

**State Management**: `flutter_riverpod` 2.4.9. Key providers in `lib/core/providers/`:
- `authStateNotifierProvider` — auth state, sign-in/up/out, Firestore user sync
- `prayerTimesProvider` — prayer times, next/current prayer, alarms, widgets (auto-refreshes every minute)
- `tasksProvider` — stream-based task CRUD with family modifier
- `dailyPrayerStatusProvider` — daily prayer tracking (on-time/late/missed/excused)
- `quranDataProvider` / `surahListProvider` / `juzListProvider` / `quranBookmarksProvider` / `quranSearchProvider`
- `wirdStateProvider` — Wird settings, daily progress, streak count, reminder scheduling
- `preferences_provider.dart` — theme, language, guest mode, vibration, silent mode, task notifications

### Feature Structure
```
lib/
├── main.dart                     # Firebase init, 20 named routes
├── core/
│   ├── constants/app_constants.dart
│   ├── models/                   # prayer_time, prayer_settings, prayer_record, task, dhikr, achievement, daily_content, quran_models, wird
│   ├── providers/                # auth, preferences, prayer_times, connectivity, background_service, task, quran, daily_prayer_status, wird
│   ├── services/                 # prayer_times, location, geocoding, shared_preferences, auth, firestore, notification,
│   │                             # adhan_player, prayer_alarm, background_service_manager, prayer_widget, task_widget,
│   │                             # analytics, navigation, silent_mode, platform_channel, task, prayer_tracking,
│   │                             # daily_content, achievement, dhikr, offline_queue, sync, quran, quran_bookmark,
│   │                             # quran_svg (CDN download + local cache for SVG pages), wird, firebase_options
│   ├── theme/app_theme.dart      # Light/dark/AMOLED Material 3
│   ├── utils/                    # date_formatter, number_formatter, time_formatter, hijri_date, haptic_feedback, prayer_time_rules
│   └── widgets/                  # bottom_nav_bar, prayer_time_card, prayer_card, prayer_status_dialog, task_card, shimmer_loading, etc.
└── features/
    ├── splash/ auth/ onboarding/ main/ home/ prayer/ profile/ settings/
    ├── qibla/ tasks/ achievements/ dhikl/ daily_content/
    └── quran/                    # QuranScreen (4 tabs: Surahs, Juz, Bookmarks, Wird), QuranReaderScreen (604 SVG pages, CDN + local cache), QuranSearchScreen
```

**Routes (20):** `/` splash, `/login`, `/signup`, `/onboarding`, `/mode_selection`, `/home`, `/prayer`, `/prayer_tracking`, `/prayer_report`, `/dhikr`, `/dhikr_stats`, `/achievements`, `/task_form`, `/task_stats`, `/profile`, `/iqama_settings`, `/adhan_downloads`, `/qibla`, `/daily_content`, `/quran`

### Platform Channel Architecture (7 MethodChannels)

| Channel | Purpose | Native File |
|---------|---------|-------------|
| `com.aura.hala/adhan` | Adhan audio playback | AdhanPlayer.kt |
| `com.aura.hala/prayer_alarms` | Exact alarms + post-prayer checks + daily summary + Jumu'ah | PrayerAlarmReceiver.kt + DailySummaryReceiver.kt + JumuahReminderReceiver.kt |
| `com.aura.hala/background_service` | Foreground service control | PrayerForegroundService.kt |
| `com.aura.hala/widgets` | Widget data updates | WidgetUpdateService.kt |
| `com.aura.hala/ringer_mode` | Silent/vibrate mode | SilentModeAutomation.kt |
| `com.aura.hala/navigation` | Route tracking + post-prayer callbacks (native→Flutter) | MainActivity.kt |
| `com.aura.hala/focus_mode` | Focus mode scheduling, overlay/DND, service control | FocusModeService.kt |

### Native Android (`android/app/src/main/kotlin/com/aura/hala/`, 22 Kotlin files)

| File | Purpose |
|------|---------|
| `MainActivity.kt` | FlutterActivity, 8 MethodChannel handlers, notification channels |
| `PrayerAlarmReceiver.kt` | BroadcastReceiver at prayer times → adhan + notification + silent mode + post-prayer check (30 min after). IDs: 1001-1006 (prayers), 2001-2006 (reminders), 6001-6006 (post-prayer checks) |
| `DailySummaryReceiver.kt` | Fires at configurable daily time, reads `prayer_status_{name}_{date}` from `aura_prayer_times` prefs, shows summary (ID 7001), reschedules tomorrow |
| `JumuahReminderReceiver.kt` | Every Friday 30 min before Zuhr, bilingual notification (ID 8001, channel `jumuah_reminder`), weekly auto-reschedule |
| `AdhanPlayer.kt` | Singleton MediaPlayer, per-prayer audio, vibration, thread-safe |
| `SilentModeAutomation.kt` | AudioManager silent mode with configurable duration |
| `PrayerForegroundService.kt` | START_STICKY, next prayer countdown every second. Channel deletion guarded — catches `SecurityException` when active |
| `PrayerWidgets.kt` | CombinedPrayerWidget (AllPrayersWidget) with ViewFlipper tabs (Next Prayer + Timeline), 4 layout variants |
| `TasksWidget.kt` / `WidgetUpdateService.kt` / `DailyContentWidget.kt` | Home screen widgets |
| `AdhanFullScreenActivity.kt` | Full-screen intent over lock screen. During adhan: pulse animation. After audio ends: live iqama countdown (polls `AdhanPlayer.isPlaying()` every 500 ms via `Handler`, reads `adhan_iqama_time` from `aura_prayer_times`). Top-right ✕ (only way to dismiss). Bottom "Stop Vibrate"/"Keep Vibrate" pair shown only when silent mode active — "Keep Vibrate" is a no-op (screen stays open, vibration continues). |
| `FocusModeService.kt` | START_STICKY, system overlay (TYPE_APPLICATION_OVERLAY), blocks notification shade, countdown timer, restores sound on end |
| `FocusModeActivity.kt` | `startLockTask()` for complete lockdown; no `stopLockTask()` at timer end; DND restored unconditionally |
| `AuraAccessibilityService.kt` | Auto-clicks OK on "Screen pinned" dialog silently |
| `PrayerBootReceiver.kt` | Reschedules all alarms after boot or app update |
| `FocusModeReceiver.kt` / `StopAdhanReceiver.kt` / `ToggleSilentModeReceiver.kt` / `SilentOffReceiver.kt` | Broadcast receivers |

**AndroidManifest.xml**: 18 permissions, 11 receivers, 3 services, 3 activities. Backup layouts at `android/app/src/main/layout-backup/` (outside `res/` — inside `res/` breaks Android resource merger).

---

## Key Patterns and Conventions

### App Initialization Flow (main.dart)
1. `Firebase.initializeApp()` → `AnalyticsService.initialize()` → `EasyLocalization.ensureInitialized()`
2. `SharedPreferencesService` injected into Riverpod via ProviderScope override
3. Parallel: `PrayerWidgetService`, `TaskWidgetService`, `NotificationService`, `AdhanPlayerService`, `PrayerAlarmService`, `BackgroundServiceManager`, `OfflineQueueService`, `TaskService`
4. `runApp()` → ProviderScope > AuraApp > EasyLocalization > AuraAppMaterial

### Prayer Time Calculation Flow
1. `LocationService.getBestLocation()` — GPS or manual location, **cached 15 min** (`_locationCacheTTL`)
2. `PrayerTimesService.getPrayerTimes()` — 6 prayer times via Adhan library + selected method + Asr madhab
3. `PrayerTimesNotifier.loadPrayerTimes()` — **side effects run once per day** (guarded by `_lastSideEffectsDate`, set synchronously before async block)
4. Side effects: `schedulePostPrayerCheck()`, `scheduleDailyTaskDigest()`, `scheduleDailyPrayerAlarms()`, `savePrayerTimes()`, `updatePrayerTimes()`

**Critical next-prayer logic**: `getNextPrayer()` checks `prayer.time.isAfter(now)` for each prayer in order — only returns tomorrow's Fajr if ALL today's prayers have passed.

### Notification Architecture (Three-Layer System)
1. **Flutter NotificationService** — 10-min pre-prayer reminders via `flutter_local_notifications` + "Remind Me Again" (5 min before) + daily 8 AM task digest + achievement unlock notifications (channel `achievement_unlocked`, IDs 7100–8099, hash-based per achievement ID)
2. **Native PrayerAlarmReceiver** — exact AlarmManager at prayer time → adhan audio + **minimal** notification (no action buttons, `setTimeoutAfter(3000)` auto-dismisses from shade) + `setFullScreenIntent` launches `AdhanFullScreenActivity`. The notification is kept only because Android requires a posted notification to trigger `setFullScreenIntent` on locked/doze screens.
3. **Post-prayer + daily summary** — 30 min after adhan: Done/Late/Missed/Later actions write `prayer_status_{name}_{date}` to `aura_prayer_times` prefs. `DailySummaryReceiver` fires at configurable time (default 21:00). On app resume: `_syncNativePrayerStatuses()` syncs to Firestore and clears native keys. Navigation channel receives `openPostPrayerPicker`/`openReminderPicker`/`updatePrayerStatus` callbacks.

**Achievement notifications**: `AchievementService._award()` emits to `newAchievements` stream → `MainWrapperScreen` listener calls both `_showAchievementToast()` (in-app overlay) and `NotificationService.instance.showAchievementNotification()` (system notification).

**Notification channel `prayer_tracking`** (IMPORTANCE_DEFAULT) — created by `DailySummaryReceiver` if absent.

### Jumu'ah Reminder
- Channel `jumuah_reminder`, ID 8001, reads `dhuhr_time` from `aura_prayer_times` prefs
- Flutter control: `scheduleJumuahReminder`/`cancelJumuahReminder` on `com.aura.hala/prayer_alarms`
- Boot reschedule via `PrayerBootReceiver.rescheduleJumuahReminder()`

### Foreground Service Notification (PrayerForegroundService)
- Channel `prayer_foreground_channel`, IMPORTANCE_HIGH, VISIBILITY_PUBLIC, PRIORITY_MAX, CATEGORY_ALARM
- 4 layout variants: `notification_large` (LTR), `notification_large_rtl`, `notification_large_dark`, `notification_large_dark_rtl`
- Timer: `HH:MM` digital clock (no seconds). Arabic uses Eastern numerals.
- Icon by phone clock hour (NOT prayer times): 0–4→Isha, 5–6→Fajr, 7–15→Dhuhr, 16–17→Asr, 18–19→Maghrib, 20–23→Isha
- RTL layout: `notification_until` before `notification_time` in XML; time uses `textDirection="ltr"`
- Day transition: detects stale times, launches `MainActivity` with `refresh_prayer_times` extra

### Critical: Native SharedPreferences File Names
Flutter `shared_preferences` ≠ native Kotlin file. **NEVER use `${packageName}_preferences` in Kotlin.**

| File | Used By | Contains |
|------|---------|----------|
| `aura_prayer_times` | PrayerForegroundService, PrayerAlarmReceiver, AdhanFullScreenActivity, StopAdhanReceiver, DailySummaryReceiver | Prayer times, next prayer, language, `prayer_status_{name}_{YYYY-MM-DD}` keys |
| `aura_silent_mode` | SilentModeAutomation, PrayerAlarmReceiver, AdhanFullScreenActivity | silent_mode_enabled, is_silent_active, saved_ringer_mode |
| `aura_prefs` | AdhanPlayer | adhan_enabled |
| `aura_focus_mode` | FocusModeReceiver | completed_task_id, completed_at |
| `${packageName}_preferences` | Flutter only + FocusModeService (writes focus_completed_task_id) | Default Flutter prefs |

This was the root cause of Arabic text not showing in full-screen azan and silent mode not working.

### State Sync Pattern
- Firestore ↔ SharedPreferences bidirectional sync for logged-in users
- Login: Firestore → SharedPreferences; Change: SharedPreferences → Firestore
- Guest mode: SharedPreferences-only, migrated to Firestore on signup
- Collections: `users`, `tasks`, `prayer_records`

### Localization
- All UI strings: `.tr()` from `easy_localization`; keys in both `en.json` and `ar.json` (keep in sync, ~265 keys each)
- Arabic numerals: `NumberFormatter.withArabicNumeralsByLanguage()`; RTL: `context.locale.languageCode == 'ar'`
- AM/PM → ص/م; Arabic font: Cairo; English: Roboto
- Platform channels: always `try-catch`; log with emoji prefixes (`🕌`, `📱`, `🔔`, `✅`, `🔄`)

### Task System
- **Categories**: work, personal, shopping, health, study, prayer, other. **Priorities**: low, medium, high
- **Recurrence**: none/daily/weekly/monthly — completion auto-generates next via `completeRecurringTask()`
- **Subtasks**: `SubTask` model; `subtaskProgress` (0.0–1.0) and `completedSubtasks` are computed properties
- **Pin to top**: `isPinned` field; `_applySort()` always floats pinned tasks above sort order
- **Due time**: `hasDueTime` boolean + `TimeOfDay` in `dueDate`; badge shows 12h with ص/م
- **TasksScreen sections**: Overdue/Today/Upcoming/All Tasks/Completed (collapsible). Midnight timer at 00:00 refreshes sections.
- **Sort**: dateDesc/dateAsc/priority/title — persisted via SharedPreferences (`task_sort_order`). **Filter chips**: category (`task_category_filter`) + auto-generated tag chips
- **Context menu**: ⋮ → Edit/Duplicate/Change Priority/Pin/Toggle Complete/Delete (`onMenuTap` callback, separate from `onLongPress` for drag-to-reorder)
- **Task notifications**: `scheduleTaskReminder()` — with-time tasks get 30-min-before reminder; without-time get 9 AM. Controlled by `task_notifications_enabled` pref via `_TaskSettingsSheet` (gear in TasksScreen AppBar)
- **Focus Mode**: alarm fires → `FocusModeReceiver` → `FocusModeService` (overlay) → `FocusModeActivity` (`startLockTask()`). `AuraAccessibilityService` auto-clicks "Screen pinned" OK. After timer: DND restored, shows "Did you complete?" Yes → marks done via `getFocusCompletedTaskId` MethodChannel. `focus_a11y_ever_enabled` flag prevents re-asking on Huawei EMUI. Fields: `focusMode` (bool), `focusDurationMinutes` (int, default 25)
- **App resume** (`MainWrapperScreen.didChangeAppLifecycleState`): `_checkUntrackedPrayers()`, `ref.invalidate(prayerTimesProvider)`, `ref.invalidate(tasksProvider)`, `_handleWidgetIntent()`, `_syncNativePrayerStatuses()`
- **Celebration overlay**: `AnimationController` (NOT flutter_animate). **Task streak**: `task_streak_count`/`task_streak_date` in SharedPreferences
- **Daily summary notification**: ID 3999, `matchDateTimeComponents: DateTimeComponents.time`

### Dhikr/Tasbeeh System
- 6 presets: SubhanAllah, Alhamdulillah, Allahu Akbar, La ilaha illallah, Astaghfirullah, Custom
- Haptic feedback per tap (enable/simplified modes); session tracking + statistics persistence

### Wird (Daily Quran Reading) System
- **Tab**: 4th tab in QuranScreen (Surahs, Juz, Bookmarks, **Wird**)
- **Tracking modes**: `WirdUnit.page` (default) or `WirdUnit.juz`. Each has its own daily goal field (`dailyPageGoal` / `dailyJuzGoal`).
- **Model** (`lib/core/models/wird.dart`):
  - `WirdSettings`: `dailyPageGoal`, `dailyJuzGoal`, `wirdUnit` (WirdUnit enum), `reminderTimes`, `remindersEnabled`, `linkedBookmarkColor` (null/'red'/'orange'/'green'), `countedBookmarkPages` (pages already auto-synced)
  - `WirdProgress`: `date`, `pagesRead`, `startPage`, `currentPage`, `isCompleted`, `juzCompletedToday` (List\<int\> of juz numbers 1-30)
  - `WirdState`: above + `streakCount`, `streakDate`, `totalPagesRead`, `totalDaysCompleted`, `allCompletedJuz` (List\<int\> of all 30 juz ever completed — drives khatm progress circle)
- **Service** (`lib/core/services/wird_service.dart`): singleton, SharedPreferences persistence, Firestore sync for logged-in users
- **Provider** (`lib/core/providers/wird_provider.dart`): `wirdStateProvider` — `WirdNotifier` StateNotifier. Key methods: `setWirdUnit()`, `setDailyJuzGoal()`, `toggleJuzCompleted()`, `markJuzFromBookmarks(Set<int> newJuzNos, Set<int> allBookmarkPages)`, `setLinkedBookmarkColor()`, `syncBookmarkPages()`
- **SharedPreferences keys**: `wird_settings` (JSON), `wird_streak_count`, `wird_streak_date` ("YYYY-MM-DD"), `wird_total_pages_read`, `wird_total_days_completed`, `wird_progress_history` (JSON list, pruned to 90 days)
- **Streak logic**: mirrors task streak pattern — increments on first daily completion, resets if >1 day gap. `_refreshStreak()` called on load to detect broken streaks.
- **Reminders**: channel `wird_reminder`, notification IDs 5100-5119, scheduled via `NotificationService.scheduleWirdReminders()` using `zonedSchedule` with `matchDateTimeComponents: DateTimeComponents.time` for daily repeat. Max 10 reminders.
- **Page range**: `startPage` to `startPage + dailyPageGoal - 1` (clamped to 604). Tapping opens QuranReaderScreen at that page.
- **Bookmark auto-sync** (`_WirdContentViewState`): when `linkedBookmarkColor != null`, the `build()` method watches `quranBookmarksProvider` and diffs `countedBookmarkPages` vs current bookmark pages. New pages trigger `syncBookmarkPages()` (page mode) or `markJuzFromBookmarks()` (juz mode) via `addPostFrameCallback`. `_syncInProgress` bool prevents re-entrant calls during the async gap. **Juz sequential assumption**: a bookmark in juz 4 implies juz 1-4 all done — `maxJuz` is found and `List.generate(maxJuz, (i) => i+1)` is marked.
- **"Add from Bookmarks" dialog flow**: `_BookmarkPagesSheet` lists colors with existing bookmarks. Tapping a color shows an `AlertDialog` ("Add New" / "Choose One"). "Add New" calls `onUseAll` (marks all pages of that color). "Choose One" opens `_BookmarkListSheet` (DraggableScrollableSheet with individual bookmark items). Dismissing both sheets: `Navigator.of(context)..pop()..pop()`.
- **Achievements**: `wird_first` (1 day), `wird_streak_7`, `wird_streak_30`, `wird_khatma` (604 total pages) in `AchievementCategory.quran`

---

## Native Code Gotchas

- **RemoteViews**: Cannot use `<View>` elements (crashes Android 10). Use `<FrameLayout>` for dividers.
- **Notification channel importance**: Android won't downgrade. Call `deleteNotificationChannel()` before recreating. **Cannot delete while foreground service is active** — wrap in try-catch `SecurityException`.
- **Quran data**: `hafsData_v2-0.json` (12,472 ayahs) loaded **LAZILY** on first Quran tab open — NOT at startup (causes crash). Cached in `QuranService._cachedAyahs`. JSON fields: `sura_no`, `aya_no`, `jozz`, `page`, `line_start`, `line_end`, `aya_text` (PUA), `aya_text_emlaey` (standard Arabic — search only).
- **UthmanicHafs font**: `assets/fonts/uthmanic_hafs_v20.ttf`, family `UthmanicHafs`. Used in surah list and search for inline ayah text display. Mushaf pages are rendered as SVG (not font text).
- **SVG Quran reader**: Pages downloaded on-demand from `https://cdn.jsdelivr.net/gh/AlaaEldinTarek/aura-adhans/mushafs/hafs/svg` (files `001.svg`–`604.svg`), cached at `getApplicationDocumentsDirectory()/quran_pages/`. `QuranSvgService` deduplicates concurrent requests and preloads ±1 page. Dark mode inverts via `ColorFiltered` matrix. Tap detection maps widget coords → SVG coords → line number (from `line_start`/`line_end`) → `Ayah`. Pages 1–2 use square viewBox (235×235); pages 3–604 use portrait (345×550). There is **no ayah highlight** — `_AyahHighlightPainter` and `_selectedAyah` were removed; tapping an ayah goes straight to the `_AyahSheet` bottom sheet.
- **Quran reader bookmark color dialog**: `_AyahSheet.onBookmark` signature is `void Function(BuildContext context, BookmarkColor color)` — `BuildContext` is passed through so nested dialogs can be shown from within the sheet. When a color already has existing bookmarks, `_handleAyahTap` shows an `AlertDialog` ("Add New" / "Choose One"). "Choose One" opens `_BookmarkReplaceSheet` (DraggableScrollableSheet). On selection, `Navigator.of(context)..pop()..pop()` closes both sheets.
- **TextDirection conflict**: `easy_localization` exports `intl`'s `TextDirection`, shadowing Flutter's. Use `import 'dart:ui' as ui show TextDirection;` and `ui.TextDirection.rtl` in Quran reader.
- **Dhuhr/Zuhr naming**: SharedPreferences key always `dhuhr_time`; UI shows "Zuhr". All switch/map lookups must handle both: Flutter `case 'dhuhr': case 'zuhr':`, Kotlin `"Dhuhr", "Zuhr" ->`. `kPrayerNames` uses `'Zuhr'` as canonical.
- **Language switching**: `MainWrapperScreen.build()` must call `ref.watch(languageProvider)` — without it, bottom nav labels won't rebuild on locale change.
- **Mode naming**: `AppMode.prayerOnly` is labelled "Prayer & Quran" (EN) / "الصلاة والقرآن" (AR) everywhere — onboarding mode selection and Profile app mode tiles. Keep these in sync if labels change.
- **Bottom nav Quran tab visibility**: `showQuran = appMode == AppMode.both || appMode == AppMode.prayerOnly` — Quran shows in both `both` and `prayerOnly` modes; hidden only in `tasksOnly`. The PageView always has all 5 screens at fixed indices regardless of mode.
- **Iqama time in prefs**: `PrayerAlarmReceiver` writes `adhan_iqama_time` (absolute ms timestamp) to `aura_prayer_times` when a prayer alarm fires. `AdhanFullScreenActivity` reads this to drive the post-adhan countdown. Value is 0 if iqama is not configured for that prayer.
- **Makkah/Umm al-Qura Dhuhr offset**: `adhan` library's `umm_al_qura` method has zero Dhuhr adjustment by default. `PrayerTimesService.getPrayerTimes()` applies `params.adjustments.dhuhr = 3` when `calculationMethod == CalculationMethod.makkah` to match the official Umm al-Qura calendar (+3 min). Do not remove this offset.
- **Achievements screen collapsible sections**: Each `AchievementCategory` section has a tappable header row (name + earned/total count + rotating chevron). Collapsed state stored in `Set<AchievementCategory> _collapsedCategories` on `_AchievementsScreenState`. Grid animates with `AnimatedSize`.
- **Profile achievements grid**: `_AchievementsBadgeGrid` shows 2 rows collapsed by default. Uses `LayoutBuilder` to calculate `perRow` dynamically, then `all.take(perRow * 2)`. "Show all / Show less" toggle with `AnimatedSize`. Footer bar always navigates to `/achievements`.

---

## Theme System

Defined in `lib/core/theme/app_theme.dart`. Material 3, two fonts: Roboto (EN) + Cairo (AR).
- **Visual identity**: `#F5B301` (bright gold) = `AppConstants.primaryColor`
- **Light**: primary `#B5821B`, surfaces `#FFF8EB`/`#FFF3D6`, text `#2A2418`/`#7A6E5A`, border `#E8D5A8`
- **Dark**: primary `#F5B301`, surfaces `#111317`/`#1A1B1E`
- **AMOLED**: true black + `#F5B301`; **Dynamic color**: optional Material You via `dynamic_color`

---

## Key Dependencies

`flutter_riverpod` 2.4.9, Firebase suite (core/auth/firestore/storage/analytics + google_sign_in), `adhan` 2.0.0+1, `geolocator` 10.1.0, `flutter_local_notifications` 17.0.0, `audioplayers` 6.0.0, `easy_localization` 3.0.3, `flutter_svg` 2.0.0, `dio` 5.0.0, `table_calendar`, `flutter_animate`, `lottie`, `shared_preferences`, `timezone`, `permission_handler`

---

## Important File Notes

### Critical Services (Edit Carefully)
- `lib/core/services/prayer_times_service.dart` — day transitions, next/current prayer logic
- `lib/core/providers/prayer_times_provider.dart` — auto-refresh timer, alarm/notification/widget scheduling
- `android/.../PrayerAlarmReceiver.kt` — DO NOT modify notification IDs (1001-1006 prayers, 2001-2006 reminders, 6001-6006 post-prayer checks). Prayer alarm notification is intentionally minimal — no buttons, auto-dismisses in 3 s; all controls live in `AdhanFullScreenActivity`.
- `android/.../DailySummaryReceiver.kt` — ID 7001, reads `prayer_status_*` from `aura_prayer_times`; do not change key format

### Assets
- `assets/translations/en.json` + `ar.json` — ~265 strings each; always add to BOTH
- `assets/fonts/uthmanic_hafs_v20.ttf` — Uthmanic Hafs font (family `UthmanicHafs`) for inline ayah text in surah list and search
- `assets/data/hafsData_v2-0.json` — 12,472 ayahs; `aya_text` is PUA-encoded (display), `aya_text_emlaey` is standard Arabic (search)
- SVG mushaf pages are NOT bundled — downloaded from CDN and cached at `getApplicationDocumentsDirectory()/quran_pages/`

---

## Git Commit Guidelines

- One commit per logical change; imperative mood ("Fix Zuhr" not "Fixed Zuhr")
- **Always include**: `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`

```
Short summary (under 72 chars)

Explanation of what changed, why, which files/functions affected.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```
