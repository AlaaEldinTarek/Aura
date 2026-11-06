# Wird (daily Quran reading)
Relocated from CLAUDE.md on 2026-11-06; not yet re-verified (Step 2). Parent: quran-wird.md.

## Overview
- 4th tab in `QuranScreen` (Surahs, Juz, Bookmarks, **Wird**); UI in `lib/features/quran/wird_tab.dart`.
- Tracking modes: `WirdUnit.page` (default) or `WirdUnit.juz`, each with its own goal (`dailyPageGoal` / `dailyJuzGoal`).
- Custom goal, streak tracking, bookmark color auto-sync, multiple configurable daily reminders, 4 achievements.

## Model (`lib/core/models/wird.dart`)
- `WirdSettings`: `dailyPageGoal`, `dailyJuzGoal`, `wirdUnit`, `reminderTimes`, `remindersEnabled`,
  `linkedBookmarkColor` (null/'red'/'orange'/'green'), `countedBookmarkPages` (pages already auto-synced)
- `WirdProgress`: `date`, `pagesRead`, `startPage`, `currentPage`, `isCompleted`, `juzCompletedToday` (List<int>, 1–30)
- `WirdState`: above + `streakCount`, `streakDate`, `totalPagesRead`, `totalDaysCompleted`, `allCompletedJuz`
  (List<int> of all juz ever completed — drives the khatm progress circle)

## Service & provider
- `lib/core/services/wird_service.dart`: singleton, SharedPreferences persistence, Firestore sync for logged-in users.
- `lib/core/providers/wird_provider.dart`: `wirdStateProvider` (`WirdNotifier` StateNotifier). Key methods:
  `setWirdUnit()`, `setDailyJuzGoal()`, `toggleJuzCompleted()`,
  `markJuzFromBookmarks(Set<int> newJuzNos, Set<int> allBookmarkPages)`, `setLinkedBookmarkColor()`, `syncBookmarkPages()`.
- Prefs keys: contracts/prefs-keys.md (`wird_*`; progress history pruned to 90 days).

## Rules
- Streak: mirrors the task streak — increments on first daily completion, resets if >1 day gap; `_refreshStreak()` on
  load detects broken streaks.
- Page range: `startPage` to `startPage + dailyPageGoal - 1` (clamped to 604); tapping opens `QuranReaderScreen` there.
- Reminders: channel `wird_reminder` (IDs: contracts/notification-ids.md), via `NotificationService.scheduleWirdReminders()`
  using `zonedSchedule` + `matchDateTimeComponents: DateTimeComponents.time` (daily repeat). Max 10 reminders.

## Bookmark auto-sync (`_WirdContentViewState`)
- When `linkedBookmarkColor != null`, `build()` watches `quranBookmarksProvider` and diffs `countedBookmarkPages` vs
  current bookmark pages. New pages trigger `syncBookmarkPages()` (page mode) or `markJuzFromBookmarks()` (juz mode)
  via `addPostFrameCallback`. `_syncInProgress` prevents re-entrant calls during the async gap.
- Juz sequential assumption: a bookmark in juz 4 implies juz 1–4 done — find `maxJuz`, mark
  `List.generate(maxJuz, (i) => i+1)`.

## "Add from Bookmarks" dialog
- `_BookmarkPagesSheet` lists colors with bookmarks. Tapping a color → `AlertDialog` ("Add New" / "Choose One").
  "Add New" → `onUseAll` (marks all pages of that color). "Choose One" → `_BookmarkListSheet` (DraggableScrollableSheet
  of individual bookmarks). Dismiss both: `Navigator.of(context)..pop()..pop()`.

## Achievements & tutorial
- `wird_first` (1 day), `wird_streak_7`, `wird_streak_30`, `wird_khatma` (604 total pages) in `AchievementCategory.quran`.
- Wird tutorial launches from `_WirdContentViewState.initState` — do NOT add a tab-level Wird tutorial in `_onTabChanged`.
