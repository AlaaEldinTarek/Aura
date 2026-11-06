# Home Feature Blueprint

## System Overview
The Home tab (bottom-nav index 0): one screen, `home_screen.dart`, that summarizes the day. It shows the greeting,
daily verse/hadith, Jumu'ah banner, next Islamic event, next prayer countdown, prayer progress, task progress and
today's tasks. It owns no data. It reads prayer, task and event providers from `../../core/providers/` and writes
only through `dailyPrayerStatusProvider.markToday` and `TaskService.toggleTaskCompletion`. It also owns the
first-run app tutorial and the task streak writer. Cross-folder views: `.project-docs/modules/prayer-tracking.md`
and `.project-docs/modules/tasks.md`. Behavior-preserving rule: no UI or logic change without an approved spec.

## Local Interface & Invariants

### Interface
| File | Public symbols / entry points |
| --- | --- |
| `home_screen.dart` | `HomeScreen()` (no params). Private: `_HomeScreenState` (`WidgetsBindingObserver`), `_HomeCelebrationOverlay` |

- Navigation out: `/prayer` (greeting, next-prayer card), `/daily_content`, `/islamic_events`, `/task_form`
  (edit, with the `Task` passed as `arguments`). "View All" sets `tabNavigationProvider` to 3 (Tasks).
- Watches: `prayerTimesProvider` (`nextPrayer`, `prayerTimes`), `dailyPrayerStatusProvider`, `appModeProvider`,
  `currentUserProvider`, `guestModeProvider`, `islamicEventsProvider`, `allTasksProvider`, `taskStatisticsProvider`.
  Listens to `showTutorialProvider` (manual tutorial replay, set from `profile_screen.dart`).
- Tutorial: the keys `_greetingKey`, `_dailyContentKey`, `_nextPrayerKey`, `_prayerProgressKey`, `_taskProgressKey`,
  `_todayTasksKey` and `AuraBottomNavBar.navBarKey`; text keys `tutorial_welcome_*` … `tutorial_nav_*`.

### Invariants
- **App mode**: `showPrayer = appMode != tasksOnly`, `showTasks = appMode != prayerOnly` (in `build` and again in
  `_launchTutorial`). Card order: greeting → daily content → Jumu'ah banner (Fridays) → event card (first event
  with `daysUntil <= 30`) → next prayer → prayer progress → task progress → today's tasks → `'app_tagline'.tr()`.
- **Desktop vs mobile layout** (`_isDesktop` = Windows/macOS/Linux): desktop is a plain column with larger gaps and
  no animations; mobile is limited to `maxWidth: 800`, uses `flutter_animate` and adds an 80 px bottom spacer.
- **Next prayer** comes from `prayerTimesProvider.nextPrayer`; the screen does no selection of its own
  (`.project-docs/modules/prayer.md`). Its name goes through `getPrayerDisplayName` (Jumu'ah on Fridays).
- **Countdown**: `Timer.periodic(1 s)` updates `_countdownNotifier`, and only the `ValueListenableBuilder` rebuilds.
  The timer stops on paused/inactive and restarts on resumed. `_formatCountdown` shows `--:--` at zero and uses
  Arabic units and digits via `NumberFormatter`.
- **Prayer progress**: statuses are filtered by `isPrayerTimeReached`; `completedCount` counts only `onTime` and
  `late` over `kPrayerNames` (5). `missed` and `excused` both show a red cancel icon (findings F25). The labels are
  a hard-coded Arabic list or `kPrayerNames[i]`; there is no `getPrayerDisplayName`, so no Jumu'ah (findings F32).
- **Marking a prayer** (`_markPrayerFromHome`): `canMarkPrayer` (20-minute rule) → `showPrayerStatusDialog` →
  `dailyPrayerStatusProvider.notifier.markToday(name, status)`. The status is stored as the dialog returns it.
- **Today's tasks**: "today" = `isDueToday || dueDate == null` (progress card and preview). The preview shows up to
  3 incomplete tasks; when there are none, it falls back to `isUpcoming` tasks with an "Upcoming" label. The "Late"
  mini-stat uses `taskStatisticsProvider.overdue`.
- **Task streak** (the only writer of `task_streak_count` / `task_streak_date`, date `yyyy-MM-dd`):
  `_incrementStreak` runs only when the last incomplete "today" task is completed **from Home**. It does nothing
  if the date is already today, adds 1 after yesterday, and otherwise resets to 1. `_getStreak` writes 0 when the
  last date is older than yesterday. `TasksScreen` celebrates but never updates the streak (findings F32).
- **Tutorial**: starts after `PermissionDialogHandler.onDone` when `isTutorialCompleted()` is false. It retries
  until `ModalRoute.isCurrent`, then waits 800 ms. Steps whose key has no context or whose card the app mode hides
  are skipped. `onDone` calls `setTutorialCompleted(true)`. A manual replay skips the completed check.
- **Localization**: almost all strings are inline `isArabic ? '…' : '…'`. Only `app_tagline`, the tutorial keys and
  the `InfoTipIcon` keys use translation keys (findings F33).
- **Unused code**: `_buildDailyProgressRing`, `_buildRecentActivity` / `_getRecentRecords` and `_getPrayerEmoji`
  have no callers (P6 cleanup candidates).

### Side Effects
- `dailyPrayerStatusProvider.notifier`: `load(fajrTime:)` once in `initState`; `markToday` when marking a prayer.
- `TaskService.instance.toggleTaskCompletion`, then `ref.invalidate(allTasksProvider / taskStatisticsProvider)`
  (also after `/task_form` returns `true`).
- SharedPreferences: read/write `task_streak_count`, `task_streak_date`; tutorial flag via
  `SharedPreferencesService.isTutorialCompleted` / `setTutorialCompleted`.
- `RatingService.instance.maybeRequest()` 5 s after `initState`; `DailyContentService.instance.getToday()` on build.
- Timers / overlays: the 1 s countdown, the tutorial retry delays (300/400/800 ms), and the celebration
  `OverlayEntry` (shown 800 ms after completion, removed after 3 s).

## Subdirectories & System Boundaries
- None (flat directory).

## Global Invariants
- The streak keys are a shared contract ([prefs-keys](/.project-docs/contracts/prefs-keys.md)), read by
  `task_stats_screen`, `achievement_service` and `task_widget_service`.
- This screen writes prayer statuses only through `dailyPrayerStatusProvider` (which writes through
  `PrayerTrackingService`); it does not touch Firestore or MethodChannels directly.

## Global Side Effects
- Prayer records (via the provider) and task completion (via `TaskService`); everything else is read only.

## System Verification
- Run: `flutter test` (no tests for this folder yet). Manual checks: `.project-docs/reference/device-checklist.md`
  S06–S08 (statuses shown in app), S21 (Arabic / Jumu'ah on Home).
- Known issues: findings F32 (verified) and F33 (scout backlog).
