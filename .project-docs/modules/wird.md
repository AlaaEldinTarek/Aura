# Wird (daily Quran reading)
Verified against code 2026-11-07 (reference/2026-11-07_DRIFT_REPORT.md). Parent: quran-wird.md.

## Overview
- 4th tab in `QuranScreen` (Surahs, Juz, Bookmarks, **Wird**); UI in `lib/features/quran/wird_tab.dart`.
- Tracking modes: `WirdUnit.page` (default) or `WirdUnit.juz`, each with its own goal (`dailyPageGoal` default 5 /
  `dailyJuzGoal` default 1).
- Custom goal, streak tracking, bookmark color auto-sync, multiple daily reminders (on by default), 7 achievements.

## Model (`lib/core/models/wird.dart`)
- `WirdSettings`: `dailyPageGoal`, `dailyJuzGoal`, `wirdUnit`, `reminderTimes`, `remindersEnabled`,
  `linkedBookmarkColor` (null/'red'/'orange'/'green'), `countedBookmarkPages` (pages already auto-synced)
- `WirdProgress`: `date`, `pagesRead`, `startPage`, `currentPage`, `isCompleted`, `juzCompletedToday` (List<int>, 1–30)
- `WirdState`: above + `streakCount`, `streakDate`, `totalPagesRead`, `totalDaysCompleted`, `allCompletedJuz`
  (all juz ever completed — drives the khatm progress circle), `khatmCount`, `khatmDates`

## Service & provider
- `lib/core/services/wird_service.dart`: singleton, SharedPreferences persistence, Firestore sync for logged-in users
  (`syncFromFirestore` replaces local settings/streak/totals; progress history is local only — F52g).
- `lib/core/providers/wird_provider.dart`: `wirdStateProvider` (`WirdNotifier`), `quranStatsProvider`. Methods include
  `setWirdUnit`, `setDailyPageGoal`, `setDailyJuzGoal`, `toggleJuzCompleted`,
  `Future<int> markJuzFromBookmarks(Set<int> newJuzNos, Set<int> allBookmarkPages)`,
  `setLinkedBookmarkColor(String colorName, Set<int> initialPages)`, `Future<int> syncBookmarkPages(Set<int>)`,
  `recordPagesRead`, `markComplete`, `undoComplete`, reminder methods (`setReminderTimes`, `addReminder`,
  `removeReminder`, `setRemindersEnabled`), `refresh`, `resetAllProgress`, `resetJuzForKhatma`, `recordPageKhatma`.
- Prefs keys: contracts/prefs-keys.md (`wird_*`; progress history pruned to 90 days).

## Rules
- Streak: mirrors the task streak — increments on first daily completion, resets if >1 day gap; `_refreshStreak()` on
  load detects broken streaks.
- Page range: `startPage` to `startPage + dailyPageGoal - 1` (clamped to 604). The Start/Continue button opens
  `QuranReaderScreen` at `currentPage`.
- Reminders: max 10 (enforced in `WirdNotifier`; the service has 20 ID slots, 5100+i). Android → native
  `scheduleNativeNotification` (repeat daily, tap tab 2); other mobile → `zonedSchedule` +
  `matchDateTimeComponents: DateTimeComponents.time`, channel `wird_reminder`; desktop →
  `DesktopNotificationService.scheduleWirdReminders`. IDs: contracts/notification-ids.md. Mobile text always says
  pages (F52i).

## Bookmark auto-sync (`_WirdContentViewState`)
- When `linkedBookmarkColor != null`, `build()` watches `quranBookmarksProvider` and diffs `countedBookmarkPages` vs
  current bookmark pages. New pages trigger `syncBookmarkPages()` (page mode) or `markJuzFromBookmarks()` (juz mode)
  via `addPostFrameCallback`. `_syncInProgress` prevents re-entrant calls during the async gap.
- Juz sequential assumption: a bookmark in juz 4 implies juz 1–4 done — find `maxJuz`, mark
  `List.generate(maxJuz, (i) => i+1)`.

## "Add from Bookmarks" dialog
- `_BookmarkPagesSheet` lists colors with bookmarks. Tapping a color → `AlertDialog` ("Add New" / "Choose One").
  "Add New" → `onUseAll` (marks all pages of that color). "Choose One" pops the dialog; `onChooseOne` pops the sheet and
  opens `_BookmarkListSheet` (DraggableScrollableSheet); `onSelect` pops once. Page-mode "Choose One" bug: F38c.

## Achievements & tutorial
- `AchievementCategory.quran`: `wird_first` (1 day), `wird_streak_7`, `wird_streak_30`, `wird_streak_100`,
  `wird_pages_100`, `wird_pages_300`, `wird_khatma` (604 total pages). Wird code never calls `checkAndAward` (F52h).
- Wird tutorial launches from `_WirdContentViewState.initState` — do NOT add a tab-level Wird tutorial in `_onTabChanged`.
