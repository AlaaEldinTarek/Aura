# Wird (daily Quran reading)
Verified against code 2026-11-07 (reference/2026-11-07_DRIFT_REPORT.md); updated 2026-11-15 for the Wird marker (spec `docs/designs/wird-marker.md`, phases P2 to P5; P6 is this update). Parent: quran-wird.md.

## Overview
- 4th tab in `QuranScreen` (Surahs, Juz, Bookmarks, **Wird**); UI in `lib/features/quran/wird_tab.dart`.
- Tracking modes: `WirdUnit.page` (default) or `WirdUnit.juz`, each with its own goal (`dailyPageGoal` default 5 /
  `dailyJuzGoal` default 1).
- Custom goal, streak tracking, the Wird marker (page mode), multiple daily reminders (on by default), 7 achievements.

## Model (`lib/core/models/wird.dart`)
- `WirdSettings`: `dailyPageGoal`, `dailyJuzGoal`, `wirdUnit`, `reminderTimes`, `remindersEnabled`. (The old
  `linkedBookmarkColor` and `countedBookmarkPages` were removed in P5; `fromJson` ignores them, `toJson` omits them.)
- `WirdProgress`: `date`, `pagesRead`, `startPage`, `currentPage`, `isCompleted`, `juzCompletedToday` (List<int>, 1–30)
- `WirdState`: above + `streakCount`, `streakDate`, `totalPagesRead` (the derived progress total from the marker),
  `totalDaysCompleted`, `allCompletedJuz` (all juz ever completed — drives the khatm progress circle), `khatmCount`,
  `khatmDates` (legacy juz khatmas plus the marker's), `juzKhatmCount`, `marker`, `undo`.
- `WirdMarkerRecord` (`lib/core/models/wird_marker.dart`): `markerPage` (1 to 604, null before setup and after Restart),
  `startPage`, `runningTotal` (pages in finished cycles), `khatmaCount`, `khatmaDates`, `cycle` (raised by khatma, Restart
  and Reset All Progress), `version` (raised by every change), `ownerId` (null for a guest), `color` (ARGB). Progress total =
  `runningTotal + (markerPage − startPage)`. `WirdUndoRecord` is local only.

## Service & provider
- `lib/core/services/wird_service.dart`: singleton, SharedPreferences persistence, Firestore sync for logged-in users
  (`syncFromFirestore` replaces local settings/streak/totals; progress history is local only — F52g).
- `lib/core/services/wird_marker_service.dart` (`WirdMarkerService.instance`) and `wird_marker_logic.dart` (pure rules): the marker
  record, prefs `wird_marker` and `wird_marker_undo`, Firestore `users/{uid}/wird/marker`.
- `lib/core/providers/wird_provider.dart`: `wirdStateProvider` (`WirdNotifier`), `quranStatsProvider`. Methods include
  `setWirdUnit`, `setDailyPageGoal`, `setDailyJuzGoal`, `toggleJuzCompleted`, `markComplete`, `undoComplete`, reminder
  methods (`setReminderTimes`, `addReminder`, `removeReminder`, `setRemindersEnabled`), `refresh`, `resetAllProgress`,
  `resetJuzForKhatma`, and the marker actions `placeMarker`, `moveMarker`, `undoMove`, `completeKhatma`, `restartWird`.
- Prefs keys: contracts/prefs-keys.md (`wird_*`; progress history pruned to 90 days).

## Rules
- Streak: mirrors the task streak — increments on first daily completion, resets if >1 day gap; `_refreshStreak()` on
  load detects broken streaks.
- Page range: starts at the page today's reading began, else the marker page, else 1 (`wirdRangeStart`), to
  `start + dailyPageGoal - 1` (clamped to 604). The Start/Continue button opens `QuranReaderScreen` at the marker page when
  one exists (`wirdReadingPage`).
- Reminders: max 10 (enforced in `WirdNotifier`; the service has 20 ID slots, 5100+i). Android → native
  `scheduleNativeNotification` (repeat daily, tap tab 2); other mobile → `zonedSchedule` +
  `matchDateTimeComponents: DateTimeComponents.time`, channel `wird_reminder`; desktop →
  `DesktopNotificationService.scheduleWirdReminders`. IDs: contracts/notification-ids.md. Mobile text always says
  pages (F52i).

## Wird marker (page mode)
- One marker per user: the page the reading has reached and the color it is drawn in. Juz mode shows no marker controls.
- Set: the start sheet (`WirdStartSheet`) from Start Reading, the reader's top-bar Wird icon, the verse sheet or the
  setup card; the page can come from "Add from Bookmarks" (`WirdBookmarkPickSheet`, which only picks a page). Ordinary
  bookmarks are not counted any more.
- Move: forward only (`applyMove`). Pages moved are credited to today (`WirdService.creditPages`); a move above the daily
  goal asks for confirmation. Page 604 offers the khatma: `completeKhatma` adds the khatma, restarts the cycle at page 1.
- Undo rule: one step, today only. `applyUndo` needs the undo record to match today, the cycle and the version; otherwise it
  refuses (`staleDay` / `staleRecord`). The streak credit is taken back only when that move granted it and today is now below
  the goal.
- Restart Wird starts a new cycle and keeps the color; Reset All Progress wipes streak, totals, history, juz and legacy
  khatma data and restarts the marker record.
- Sync rule (`decideSync`, signed-in users): cloud absent and a guest marker → claim and push; cloud absent and another
  account's marker → discard local; both present → higher (`cycle`, `version`) wins. A failed or invalid cloud read skips
  the sync. A guest marker lives only in prefs.
- Stats: `quranStatsProvider` uses `averagePerCompletedDay` ("Average per completed day"). `wird_total_pages_read` is no
  longer written or read; no migration (owner's decision 2026-11-15).

## Achievements & tutorial
- `AchievementCategory.quran`: `wird_first` (1 day), `wird_streak_7`, `wird_streak_30`, `wird_streak_100`,
  `wird_pages_100`, `wird_pages_300`, `wird_khatma`. The last three read the marker (`wirdAchievementIds`: 100 pages, 300 pages,
  one khatma). Wird code never calls `checkAndAward` (F52h): the check runs from the Profile badge grid, after a prayer record
  and after a task completion. Juz-mode users cannot earn those three (see `docs/designs/mode-separation.md`, draft).
- Wird tutorial launches from `_WirdContentViewState.initState` — do NOT add a tab-level Wird tutorial in `_onTabChanged`.
