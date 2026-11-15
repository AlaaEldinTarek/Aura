# Wird Mode Separation: Page Mode and Juz Mode as Independent Modes

*   **Author:** Alaa Eldin Tarek (drafted with Claude)
*   **Status:** Draft, not approved. On 2026-11-15 the owner answered every open question (his answers, A to M, are recorded under "Decisions"); nothing else in this file is decided, and phases M1 to M3 were done on `feat/mode-separation-m1` (see the Phases table).
*   **Date:** 2026-11-15
*   **Branch:** `docs/mode-separation` (from `feat/wird-marker` at `c81b429`, docs only)
*   **Reference convention:** file:line refs are on `feat/wird-marker` at `c81b429` unless marked `[M]` (main `31f1bcd`). Marks: VERIFIED (read in code or git, 2026-11-15), UNKNOWN (not checked), GUESS (inference).
*   **Related drafts (on branch `docs/juz-followups`, commit `3963128`, not on this branch):** `docs/designs/juz-auto-check.md` (juz auto-check from reading, out of scope here) and `docs/designs/wird-achievements-juz.md` (the earlier options for juz achievements; this spec takes option B from it). Feature spec the code builds on: `docs/designs/wird-marker.md`.

--------------------------------------------------------------------------------

## Overview

Wird has two units, pages and juz. Today they share one screen, one streak, one history and one khatma list, and switching between them only flips a setting. The owner wants two independent modes: each with its own job, progress and display, with separate achievements, a warning on switching, and a way to carry juz progress into page mode as a marker suggestion.

## The Problem

*   **Mode choice and switch today (VERIFIED).** The Page/Juz `SegmentedButton<WirdUnit>` is in the Wird settings section (`wird_tab.dart:1121-1128`). A tap calls `setWirdUnit` (`wird_provider.dart:235-239`), which only writes `settings.wirdUnit` through `updateSettings` (`wird_service.dart:57-66`) and updates the state. There is no dialog and no deletion.
*   **What a switch does to data today (VERIFIED).** Nothing is deleted. The marker record and undo record are kept (spec `wird-marker.md:190`; test "switching to juz mode keeps the marker in the state", `test/core/providers/wird_provider_test.dart`). The checked juz list `wird_completed_juz` is untouched (`wird_service.dart:311-330`).
*   **Shared data (VERIFIED).** Streak (`wird_streak_count`, `wird_streak_date`), day count (`wird_total_days_completed`) and history (`wird_progress_history`) are used by both modes (`wird_service.dart:353-364` for juz, the page paths for pages). The Khatm History list merges juz khatmas (`wird_khatm_count`, `wird_khatm_dates`) with the marker's (`wird_marker_logic.dart:181-185`, `khatma_dua_screen.dart:36`).
*   **Achievements (VERIFIED).** `wird_khatma`, `wird_pages_100` and `wird_pages_300` already read only the marker (`achievement_service.dart:15-21`), so they are already page-mode only; a juz user can never unlock them. There are no juz achievements (`achievement.dart:349-415`, the Wird entries are: first, weekly 7-day streak, 30-day streak, khatma, 100-day streak, pages 100, pages 300).
*   **Juz cards are manual (VERIFIED, `wird_tab.dart:721`).** Auto-check from reading does not exist (see `juz-auto-check.md`).
*   **Carrying juz progress into page mode (VERIFIED: not possible today).** `applySetup` accepts any page when there is no marker (`wird_marker_logic.dart:63-75`) and fails with `markerExists` when a marker exists. No code suggests a page from juz progress. The start sheet takes a `page` parameter (`wird_marker_widgets.dart:497-509`) and the Wird tab opens it from `_setMarkerFromTab` with `startSheetPage` (`wird_tab.dart:337-345`).

## Goals (the owner's requirements, 2026-11-15, simplified)

1.  Page mode and juz mode are fully independent: each has its own job, progress and display. Page shows only page mode. Juz shows only the 30 juz cards. One has no effect on the other.
2.  Achievements are separate: `wird_khatma`, `wird_pages_100` and `wird_pages_300` stay page-mode only. Juz mode gets its own achievements.
3.  Switching modes shows a warning, so the user can decide first, that going back to the other mode will empty the checked juz cards.
4.  In page mode the user can place the Wird marker at the last page read in juz mode, using the existing "Set Wird marker" start sheet, and start reading from there.

## Non-Goals

*   Juz auto-check from reading: separate draft `juz-auto-check.md`.
*   Changes to the marker's own rules (placement, move, undo, khatma, restart) in page mode.
*   Prayer, notification, alarm or native code.
*   Deleting the old unused code (the P5 phase of `wird-marker.md`).

## Current Behavior Summary

| Item | Page mode | Juz mode | Shared today |
|---|---|---|---|
| Progress | marker record `wird_marker` (VERIFIED) | `wird_completed_juz`, `juzCompletedToday` (VERIFIED) | none |
| Khatma | marker `khatmaCount`, `khatmaDates` | `wird_khatm_count`, `wird_khatm_dates` | merged list in Khatm History (VERIFIED) |
| Streak, day count | yes | yes | one value for both (VERIFIED) |
| Daily goal | `dailyPageGoal` | `dailyJuzGoal` | settings (VERIFIED) |
| Stats average | derived pages / days | juz / days (VERIFIED, `wird_marker_logic.dart:189-201`) | |
| Wird achievements | marker only | none reachable | |

## Design

### What each mode shows

*   **Page mode (GUESS that this is what the owner means; it matches today's page UI):** the marker progress, start entry points, undo, restart. No juz cards.
*   **Juz mode (VERIFIED as today):** the 30-card scroll row, the daily juz goal, no marker control (`wird-marker.md:190, 474`). Nothing about the marker.
*   **Display independence, remaining gaps (GUESS, to verify before code):** the shared streak and day count, the shared Khatm History and the stats screen still mix both modes. Decisions C, D and E settle this: Khatm History stays one merged list, the streak and day count stay shared, and the stats screen shows only the active mode's numbers (see Decisions).

### What a mode switch deletes and what it keeps

| Switch | Warning | Deletes | Keeps |
|---|---|---|---|
| Page → Juz | none (Decision A) | nothing | marker record and undo record, khatm history, earned achievements, streak |
| Juz → Page | yes (Goal 3, Decision A) | the checked juz cards: `wird_completed_juz` and today's `juzCompletedToday` | marker record and undo record, khatm history and juz khatma count, earned achievements, streak and day count (Decisions A, B, D) |

Order of the Juz → Page step (all in one step, after the user confirms; see "Check before emptying"): 1. read the khatma count and the checked cards, 2. run the juz achievement check on those values, 3. empty the cards, 4. set the unit to page, 5. offer the marker suggestion.

### Marker suggestion on the way to page mode (Goal 4)

*   **Rule (b), the owner's suggestion, GUESS on details:** the suggested page is the first page of the juz after the last consecutively checked juz. Let N be the largest number such that juz 1 to N are all checked. If N is 0, there is no suggestion. If N is 30, there is no suggestion (the khatma path resets the cards at 30, `wird_tab.dart:176-188`, VERIFIED). Otherwise the page is `startPages[N]` (zero-based list: juz N+1 starts there). Example: cards 1, 2, 3 and 5 checked gives N = 3 and page 62 (VERIFIED against the table `quran_reader_screen.dart:85-89`: juz 4 starts at page 62).
*   **Juz table (UNKNOWN whether the two tables agree):** the reader's static list (`quran_reader_screen.dart:85-89`) and `juzListProvider` (`quran_provider.dart:14`). The pure function takes the list as a parameter. Phase M1 compares them before use.
*   **Where it appears (GUESS):** after the user confirms leaving juz mode and the cards are emptied, if there is no marker (`applySetup` needs none, VERIFIED) and N is above 0, the existing start sheet opens with the suggested page (`WirdStartSheet` with `readingMode: false`, as `_setMarkerFromTab` does, `wird_tab.dart:337-345`). "Start here" places the marker (`placeMarker`, `wird_provider.dart:199-203`) and "Cancel" skips it. The texts are in "Marker suggestion text" below.
*   **Changing the suggested page (Decision F):** only through the reader's "Choose another page". No new button in the tab sheet. The tab version of the sheet offers only Start here and Cancel (VERIFIED, spec `wird-marker.md` items 9 to 11). How the user gets from the suggestion to the reader's sheet is not written in the decision (GUESS: cancel the suggestion, then start reading from the Wird tab or the reader, which opens the reader's start sheet).
*   **A marker already exists (Decision G, VERIFIED: placement fails with `markerExists`):** no suggestion is shown.

### New juz achievements (Goal 2)

Same collection and shape as today (`users/{uid}/achievements/{id}`, `achievement_service.dart:401-405`, contract row `firestore-paths.md:10`), so no schema change. Ids and thresholds are the owner's decision J. The Arabic names were reviewed by the owner on 2026-11-15 (REVIEWED BY OWNER).

| Id (decision J) | English name | Arabic name (REVIEWED BY OWNER, 2026-11-15) | Condition | Reads |
|---|---|---|---|---|
| `wird_juz_5` | Five Juz | خمسة أجزاء | at least 5 juz read in total | `wird_khatm_count × 30 + checked juz count` |
| `wird_juz_15` | Half the Quran | نصف القرآن | at least 15 juz in total | same value |
| `wird_juz_khatma` | Juz Khatma | ختمة بالأجزاء | `wird_khatm_count >= 1` | `WirdService.getKhatmCount` (`wird_service.dart:379-382`) |

Descriptions, in the style of the existing ones (VERIFIED examples: "Read 100 total pages through Wird" / "اقرأ 100 صفحة إجمالاً عبر الورد", "7-day Wird streak" / "تتابع ورد 7 أيام", `achievement.dart:349-415`). Inline strings (Decision I). The Arabic below was reviewed by the owner on 2026-11-15 (REVIEWED BY OWNER).

| Id | English description | Arabic description (REVIEWED BY OWNER, 2026-11-15) |
|---|---|---|
| `wird_juz_5` | Read 5 juz through Wird | اقرأ 5 أجزاء عبر الورد |
| `wird_juz_15` | Read 15 juz through Wird | اقرأ 15 جزءاً عبر الورد |
| `wird_juz_khatma` | Complete a khatma through Juz | أكمل ختمة عبر الأجزاء |

*   The existing Arabic descriptions use plain digits inside inline strings (VERIFIED, "100 صفحة"), which breaks the CLAUDE.md Arabic-numerals rule. The new ones follow the same pattern (Decision I) and are not a cleanup of it.

*   **Pure function (GUESS on the name):** `wirdJuzAchievementIds({required int juzKhatmCount, required int checkedJuz})` beside `wirdAchievementIds` (`achievement_service.dart:15-21`).
*   **Inputs (VERIFIED mechanism, Decision H):** worked out each time as `khatmas × 30 + checked cards`, with no new prefs key, no new `wird/data` field and no contract change. `wird_completed_juz` is emptied by `resetAllJuz` at each khatma (`wird_service.dart:404-408`) and, under Decision A, on leaving juz mode, so the value drops at those moments. Earned achievements stay (Decision B). The rule "Check before emptying" below stops the user losing one he was about to earn.
*   **Names are inline, not translation keys (VERIFIED):** the existing definitions hold `nameEn` and `nameAr` directly (`achievement.dart:379-415`). This draft follows that pattern. CLAUDE.md says every UI string goes through `.tr()`; the existing achievements do not (VERIFIED), so this is a known deviation. Decision I: use inline `nameEn` and `nameAr` to match the existing achievements. CLAUDE.md says to use translation keys, and the existing Wird achievements already break that rule (VERIFIED, `achievement.dart:349-415`); the new ones follow the existing pattern and are not a cleanup of it.
*   **Counts shown (VERIFIED the screen groups by category, `achievements_screen.dart:152`):** the Quran group goes from 1/7 style counts to a total of 10 (the three new ids). Per-user states are unaffected.
*   **When the check runs (UNKNOWN as of now):** achievements are checked only on a prayer record, a task completion and Profile badge grid mount (VERIFIED, see `wird-achievements-juz.md`). This spec does not change that; the timing question stays in that draft.
*   **Gaming (VERIFIED the cause):** cards are checked by tapping today, so these achievements can be earned by tapping. This is the same as the page-mode caveat for juz estimates and goes away only if `juz-auto-check.md` is built.

### Marker suggestion text (shown after the switch)

No new text is needed. The suggestion reuses the existing start sheet, so the page the marker will start from is already in its title (VERIFIED, `wird_start_sheet_title`, filled with the page by `startSheetTitle`, `wird_marker_widgets.dart`).

| Part | English | Arabic |
|---|---|---|
| Title (existing key `wird_start_sheet_title`) | Start your Wird from page %d? | هل تبدأ وردك من الصفحة %d؟ |
| Start button (existing key `wird_start_here`) | Start here | ابدأ من هنا |
| Cancel button (existing key `cancel`) | Cancel | إلغاء |

*   These texts already exist in the app (VERIFIED in `en.json` and `ar.json`), so they are not DRAFT. `%d` is the suggested page. It is filled after `.tr()` with the Arabic-numeral formatter, as the existing sheet does (VERIFIED by `startSheetTitle`).
*   Example (VERIFIED against the juz start table): cards 1 to 4 checked suggest page 82, so the title reads "Start your Wird from page 82?".
*   A one-line explanation such as "Continue from where your juz cards end" was considered and not added: the owner's decision F adds no new button or screen, and the title already states the page (GUESS that no extra line is wanted).

### Check before emptying (Decision H, new rule)

*   **Rule:** in the same step as the switch, after the user confirms the dialog and before any card is emptied, the app runs the juz achievement check, so a user who was about to earn `wird_juz_5`, `wird_juz_15` or `wird_juz_khatma` does not lose it by switching.
*   **Why `checkAndAward` as it is does not fit (VERIFIED):** `checkAndAward({required String userId})` (`achievement_service.dart:62`) first reads the earned list and 365 days of prayer statistics, the prayer streak, month data and task statistics, and only reaches the Wird block near the end (`:263-306`), where it reads the cards from prefs. Called as the first step of the switch it would still read the cards late. If the switch emptied the cards before it reached that block, or ran concurrently with it, the cards would already be gone (GUESS on the race; the order of awaits is VERIFIED).
*   **Proposed shape (GUESS on names):** capture the two inputs from prefs first (`getKhatmCount` and `getCompletedJuz`, VERIFIED to exist, `wird_service.dart:311, 379`). Then call a narrow method, for example `AchievementService.checkJuzAchievements(userId, juzKhatmCount, checkedJuz)`, that reads only the earned list, runs `wirdJuzAchievementIds` on the captured values and calls `_award` for the missing ids. Then empty the cards. The normal `checkAndAward` also gets the juz ids in its Wird block, so the achievements are also checked at the usual moments (prayer record, task completion, Profile badge grid; VERIFIED, see `wird-achievements-juz.md`). Both paths share the one pure function.
*   **Guest user (VERIFIED):** `checkAndAward` returns `[]` at once for `guest_user` (`achievement_service.dart:62-63`), and achievements are Firestore-backed. The narrow method must do the same. A guest has no achievements, so nothing is checked and the cards are emptied as usual.
*   **Offline (UNKNOWN, risk):** the earned-list read is a Firestore `get()`, and `_award` is a Firestore `set()`. The code does not configure persistence explicitly (VERIFIED: no `persistenceEnabled` or cache settings found in `lib/`), so the SDK default applies (GUESS: on for Android, UNKNOWN for Windows). Offline, the `get()` may return cached data or throw, and an awaited `set()` may not complete until the server acknowledges it (GUESS). Decision K says the switch must work offline, so the switch must not wait indefinitely on this check.
*   **Offline behavior (Decision L):** when the switch happens offline (or the check fails), the app waits only a short bounded time for the achievement check, catches every error the same way `checkAndAward` does (`achievement_service.dart:312`, the outer `catch` that logs and returns), and then empties the cards anyway (cards emptied locally at once, Decision K). The length of the wait is 5 seconds (`kJuzSwitchCheckTimeout = Duration(seconds: 5)`), OWNER CONFIRMED by Aladdin on 2026-11-15; it was not measured against real Firestore offline (UNKNOWN). If the check could not finish, the user can miss an achievement he was about to earn; the owner accepted that loss (Decision L). There is no pending-award note and no new key.
*   **Dialog text (GUESS):** the body already says earned achievements stay. It does not mention the check, and no user-facing text is needed for it.

### Stats screen shows only the active mode's numbers (Decision E)

*   **Today (VERIFIED):** `quran_stats_screen.dart` already branches on juz mode for the weekly chart (`:100`), the average unit (`:143-144`) and the juz grid (`:173`), but shows the combined `stats.khatmCount` (`:79`) and the page-derived `stats.totalPages` (`:71`) in both modes. `QuranStatsData.khatmCount` is the combined count (`wird-marker.md:959`, "Stats input mapping").
*   **Proposed (GUESS on the exact set):** page mode shows the marker's pages and the marker's khatma count; juz mode shows the checked cards, the juz khatma count (`WirdState.juzKhatmCount`, VERIFIED to exist, `wird.dart:191`) and the juz average. Streak, best streak and days stay shared (Decision D). This changes the P4b "Stats input mapping" rule (`khatmCount` combined) and the stats cases in `test/core/providers/wird_provider_test.dart` (the page-mode case expects a combined count of 3, VERIFIED in the P4b tests). Khatm History is not affected (Decision C).
*   **Files (GUESS):** `lib/core/providers/wird_provider.dart` (`quranStatsProvider`), `lib/features/quran/quran_stats_screen.dart`, possibly `lib/core/models/wird.dart` (a field), and the stats tests. Any new label is a string key in both languages.

### Warning dialog texts

The words match the app. VERIFIED from `assets/translations/en.json` and `ar.json` (2026-11-15): the Page/Juz segmented button uses `wird_unit_page` = "Pages" / "صفحات" and `wird_unit_juz` = "Juz" / "أجزاء"; `cancel` = "Cancel" / "إلغاء"; the Khatm History title (`khatma_history_title`) = "Khatm History" / "سجل الختمات"; the Arabic word the app uses for achievements is "الإنجازات" (`empty_achievements_title`). The dialog therefore says "Pages" and "Juz", not "Page mode".

Three keys are new and must go into both `assets/translations/en.json` and `ar.json` (VERIFIED rule, CLAUDE.md). The Cancel button reuses the existing key `cancel`, so it adds no new key. All Arabic below was reviewed by the owner on 2026-11-15 (REVIEWED BY OWNER): the title, the message and the Confirm button (new keys) and the Cancel button (existing key `cancel`). The message stays exactly as written, with "إلى أجزاء".

| Key | English | Arabic (REVIEWED BY OWNER, 2026-11-15) |
|---|---|---|
| `wird_mode_switch_title` (new) | Switch from Juz to Pages? | التبديل من أجزاء إلى صفحات؟ |
| `wird_mode_switch_body` (new) | Your checked juz cards will be emptied. Your khatm history and earned achievements stay. If you come back to Juz, you start with empty cards. | سيتم تفريغ بطاقات الأجزاء التي حددتها. يبقى سجل الختمات والإنجازات التي حصلت عليها. إذا عدت إلى أجزاء فستبدأ ببطاقات فارغة. |
| `wird_mode_switch_confirm` (new, Confirm button) | Switch | تبديل |
| `cancel` (existing, Cancel button) | Cancel | إلغاء |

*   **Message check (VERIFIED against the text above):** the message has three sentences: (1) the checked cards will be emptied; (2) the khatm history and earned achievements stay; (3) coming back to Juz starts with empty cards. The Arabic has the same three sentences, written as one line.
*   The body text states Decision B (history and earned achievements stay). If the owner changes A or B the text changes.
*   No number is interpolated into these strings, so no Arabic-numeral formatting is needed (VERIFIED by the texts above).
*   The Page → Juz direction has no dialog (Decision A).

## Decisions (owner, 2026-11-15)

The owner answered "yes" to the recommended list (questions A to K) and, separately, chose option 1 for L. Each item keeps the question text of the earlier draft, with his answer. The marks describe the state of the code the answer touches, not the owner's choice.

*   **A. Which switch empties the juz cards?** Answer: only Juz → Page empties the checked juz cards (`wird_completed_juz` and today's `juzCompletedToday`), after a warning dialog. Page → Juz changes nothing and shows no dialog. (Mechanism VERIFIED to be new: today `setWirdUnit` only writes the setting, `wird_provider.dart:235-239`.)
*   **B. Do Khatm History and earned achievements stay when cards are emptied?** Answer: yes, both stay. (VERIFIED that the khatma list lives in `wird_khatm_count` and `wird_khatm_dates`, which the emptying does not touch, `wird_service.dart:392-408`; earned achievements live in Firestore, `achievement_service.dart:401-405`.)
*   **C. Khatm History: one merged list or split per mode?** Answer: one merged list, as today. (VERIFIED, `khatma_dua_screen.dart:36`, `wird_marker_logic.dart:181-185`.)
*   **D. Streak and day count: shared or per mode?** Answer: shared between the modes, as today. Per-mode streaks are out of scope and need their own design. (VERIFIED as today, `wird_service.dart:353-364`.)
*   **E. Stats screen: only the active mode's numbers?** Answer: yes, show only the active mode's numbers. (See "Stats screen shows only the active mode's numbers" for the effect.)
*   **F. How does the user change the suggested page?** Answer: only through the reader's "Choose another page". No new button in the tab sheet. (VERIFIED that the reader sheet offers it and the tab sheet does not, `wird-marker.md` items 9 to 11.)
*   **G. A marker already exists when going to page mode.** Answer: show no suggestion. (VERIFIED: placement fails with `markerExists`, `wird_marker_logic.dart:63-75`.)
*   **H. Persisted cumulative juz counter, or derived?** Answer: derived each time (`khatmas × 30 + checked cards`). No new prefs key, no new `wird/data` field, no contract change. New rule: run the achievement check just before the cards are emptied, in the same step as the switch (see "Check before emptying").
*   **I. Inline achievement names or `.tr()` keys?** Answer: inline `nameEn` and `nameAr`, to match the existing achievements. CLAUDE.md says to use translation keys, and the existing achievements already break that rule (VERIFIED, `achievement.dart:349-415`).
*   **J. Thresholds and names.** Answer: `wird_juz_5` (5 juz), `wird_juz_15` (15 juz) and `wird_juz_khatma` (one juz khatma), with the draft names. The Arabic names were reviewed by the owner on 2026-11-15 (REVIEWED BY OWNER).
*   **K. Offline and sign-out.** Answer: empty locally at once, sync later. It must work offline. (VERIFIED mechanism: `updateSettings` and the cloud push run in the background, `wird_service.dart:57-66`.)
*   **L. Missed achievement when the check cannot finish.** The question: if the user is offline (or the check fails) at the moment of the switch, the cards are still emptied (Decision K), so a user who was about to earn a juz achievement can miss it. The options were: (1) accept the loss and wait only a short bounded time for the check; (2) keep a small "pending award" marker locally and retry later, which needs a new prefs key and so conflicts with Decision H; (3) block the switch until online, which conflicts with Decision K. Answer (owner, 2026-11-15): option 1. When switching Juz → Pages while offline, wait a short bounded time for the achievement check, catch errors the same way `checkAndAward` does, then empty the cards anyway. No pending-award note, no new key. (The mechanism is VERIFIED to need no new key: the check reads the earned list and writes with `_award`, `achievement_service.dart:67, 393-405`; the Firestore offline behavior stays UNKNOWN, see "Check before emptying".)

*   **M. "Completed today" in Pages mode (owner, 2026-11-15, answered "b"; clarifies D).** The streak and days-completed credit stay shared between the modes (D unchanged), and nothing here lowers either. The display is per mode: in Pages mode the green "Wird completed today" state comes only from page progress (the page goal reached, or "Mark Complete"), never from juz work. Page -> Juz is not part of this decision. The mechanism today (VERIFIED by reading code): the day entry has one shared `isCompleted` flag; the Pages screen reads `progress.isCompleted` (`wird_tab.dart:176`, shown at `:898`); a juz completion writes it (`wird_service.dart` `toggleJuzCompleted`: `juzToday.length >= dailyJuzGoal`), and a page completion writes it too (`creditPages`: `pagesRead >= dailyPageGoal || manualCredit`). What happens in each case:
    *   **(a) Completed today by juz, then Juz -> Pages.** The credit given by the juz work stays (streak and days unchanged, decisions B and D). The cards are emptied (decision A). The Pages screen is NOT in the completed state: it shows the normal progress card and the action buttons, with 0 pages read today.
    *   **(b) Then pages are read and the goal is reached the same day.** The Pages screen shows completed. The streak and days completed go up by at most the one credit for that day: if the juz work already gave today's credit, the page completion gives none (no double count).
    *   **(c) Completed today by pages, then Pages -> Juz (owner, 2026-11-15, answered "yes mirror").** Pages -> Juz changes nothing (decision A). In Juz mode "completed today" is true only from juz work: today's checked juz cards reach the daily juz goal (`juzCompletedToday.length >= dailyJuzGoal`), or the manual credit ("Mark Complete"); never from page progress alone. So after a day completed by pages, Juz mode with 0 cards checked is NOT completed and shows the juz actions. Before this answer Juz mode read the shared flag and showed completed (VERIFIED by reading `wird_tab.dart:176` and `:205-209`). The streak and days credit stay shared and never double count: the credit is given once per day, guarded by `wird_streak_date`.
    *   **Raised goal (owner accepted, 2026-11-15):** a Pages day that was complete by pages and whose goal is raised later shows not completed, because the display is worked out from the pages and the current goal; the stored streak credit stays. The same holds for Juz mode and a raised daily juz goal.

### Still open

No question is open. Decision M (c) was answered by the owner on 2026-11-15 ("yes mirror"): the rule above. The length of the bounded wait (Decision L) is settled: 5 seconds, OWNER CONFIRMED by Aladdin on 2026-11-15 (`kJuzSwitchCheckTimeout = Duration(seconds: 5)`). It was not measured against real Firestore offline (UNKNOWN).

## Files Touched (GUESS, from the decisions)

| File | Change |
|---|---|
| `lib/core/providers/wird_provider.dart` | a new "switch to page mode" action (capture, check, empty, set unit); `setWirdUnit` stays for page → juz; `quranStatsProvider` shows the active mode's numbers (Decision E) |
| `lib/core/services/wird_service.dart` | a method that empties `wird_completed_juz` and today's `juzCompletedToday` without touching khatma fields or streak |
| `lib/core/services/wird_marker_logic.dart` | pure `suggestMarkerPageAfterJuz(checked, juzStartPages)` |
| `lib/core/services/achievement_service.dart` | `wirdJuzAchievementIds`, its checks in the Wird block, and the narrow check-before-emptying method (guest guard, error handling like `checkAndAward`) |
| `lib/core/models/achievement.dart` | three new definitions with inline names (Decision I) |
| `lib/features/quran/wird_tab.dart` | the segmented button handler: dialog (Juz → Page only), then the switch action, then the marker suggestion when allowed |
| `lib/features/quran/quran_stats_screen.dart` | the active mode's numbers (Decision E) |
| `lib/core/models/wird.dart` | possibly a field for the stats split (GUESS) |
| `assets/translations/en.json`, `ar.json` | the three dialog keys, plus any stats label that changes |
| `.project-docs/contracts/` | no change under Decision H (no new key, no new field). Re-check at phase M4 |
| Tests | `wird_marker_logic_test.dart` (suggestion), new `achievement_wird_juz_test.dart`, provider tests for the switch and the stats split, a widget test for the dialog, an update of the P4b stats cases |

No Kotlin file is touched (GUESS: nothing native reads these keys; no Kotlin reader of `wird_*` is listed, VERIFIED `prefs-keys.md:74`).

## Risks

*   Emptying `wird_completed_juz` is data loss; the dialog is the only safeguard.
*   A second signed-in device can push a stale `completedJuz` back through the blind `wird/data` merge (VERIFIED risk in `wird-marker.md`, risk 12). The emptying is not durable across devices until that push order is fixed. Not in scope here.
*   Missed achievement when offline at the switch: accepted by the owner (Decision L).
*   An awaited Firestore call during the switch could hang offline (GUESS). The bounded wait is there for this (Decision L).
*   Achievements derived from checked cards can be earned by tapping until `juz-auto-check.md` is built (VERIFIED cause).
*   The two juz tables may disagree (UNKNOWN), which would put the marker suggestion on the wrong page. Phase M1 compares them.
*   The stats change alters the P4b stats mapping and its tests (VERIFIED they exist); the screen is also used in page mode.
*   One flow combines a dialog, a data change, an achievement check and a bottom sheet; the order and cancel paths need careful tests (GUESS on complexity).

## Phases (no phase has been started; each needs the owner's explicit go-ahead first)

| Phase | Content | Gate |
|---|---|---|
| M0 | The owner's answers are recorded (this file, 2026-11-15), including L. The Arabic texts were reviewed by him on 2026-11-15. | owner (done for A to L; the Arabic texts reviewed by the owner on 2026-11-15) |
| M1 | Design detail: the length of the bounded wait (Decision L) is chosen: 5 s. Tests first (red run): `suggestMarkerPageAfterJuz` (N = 0, 3 with a gap, 30, unsorted input, both juz tables compared); `wirdJuzAchievementIds` (khatma 0 and 1, checked 0, 4, 5, 14, 15, 30, boundaries of `khatmas × 30 + checked`); the method that empties only the juz data (keeps khatma fields, streak, marker, undo record); the **check-before-emptying order**: the inputs are captured before emptying and the check sees the full cards even when emptying follows at once; guest returns early and the cards are still emptied; a check that throws or times out still lets the cards be emptied. | owner's go-ahead for M1 (given 2026-11-15). Status: done on `feat/mode-separation-m1`, owner's go-ahead 2026-11-15, not yet merged. Done: the pure logic and its tests (suggestion, juz ids and definitions, `awardJuzAchievementsBeforeEmptying`). The wait length is `kJuzSwitchCheckTimeout` = 5 s, OWNER CONFIRMED by Aladdin on 2026-11-15 (not measured against real Firestore offline: UNKNOWN). Not done (left for M2/M3): the method that empties the juz data, the Wird block of `checkAndAward`, any UI. |
| M2 | The service, provider, logic and achievement code behind those tests: the narrow check method, the bounded wait (5 s, `kJuzSwitchCheckTimeout`, OWNER CONFIRMED 2026-11-15), the derived juz ids in the Wird block of `checkAndAward`, and the three definitions with inline names. owner's go-ahead for M2 (given 2026-11-15). Status: done on `feat/mode-separation-m1`, owner's go-ahead 2026-11-15, not yet merged. Done: `WirdService.emptyJuzData` (cards and today's `juzCompletedToday`; khatma fields, streak, days, marker kept), `WirdNotifier.switchToPageMode` (check, then empty, then set the unit; 5 s bounded wait; no-op when already Pages; `setWirdUnit` stays for Pages → Juz), and the three juz ids in the Wird block of `checkAndAward` (`localWirdJuzAchievementIds`). Not done (M3): dialog, keys, marker suggestion hand-off, stats screen. The Wird block itself is not run by a test (it needs Firestore); its input helper is. |
| M3 | The switch dialog and its keys (Arabic REVIEWED BY OWNER, 2026-11-15), the marker suggestion hand-off (no suggestion when a marker exists, change only through the reader), and the stats screen change (Decision E) with the `quranStatsProvider` update and its tests. | owner's go-ahead for M3 (given 2026-11-15). Status: done on `feat/mode-separation-m1`, owner's go-ahead 2026-11-15, not yet merged, phone test pending. Done: the dialog and its three keys (texts exactly as above, appended last in `en.json` and `ar.json`; Cancel reuses `cancel`), the Page/Juz segment calling `changeWirdUnit` (`wird_mode_switch.dart`: Juz → Pages asks first and calls `switchToPageMode` only on Switch; Pages → Juz switches at once), the marker suggestion hand-off (the existing start sheet, none when a marker exists, when no card is checked or when all 30 are), the reader's juz table exposed as `kJuzStartPages` (a test checks it equals the page table of `QuranService.getJuzList`), and the stats screen (Decision E: `khatmCount` is the active mode's; the first badge shows checked cards in Juz; the juz progress circle shows only in Juz). Follow-up, owner's decision M (2026-11-15), done on `feat/mode-separation-m1`, not yet merged, phone test pending: the Wird tab reads `WirdProgress.isCompletedIn(settings)` (Pages: page goal or Mark Complete; Juz: today's checked cards reach the juz goal or Mark Complete, the mirror rule of M (c), owner 2026-11-15), and `creditPages` and `toggleJuzCompleted` give no second credit when today's streak date is already today. Known, not changed here (UNDECIDED): on a day completed by pages, checking and then unchecking a juz card takes today's credit back (a scratch probe gave days 0 and streak 0); this was already so before decision M. The segment wiring in `wird_tab.dart` itself has no widget test (the tab is large); `changeWirdUnit` is tested. |
| M4 | Docs (re-check the contracts: none expected), the P4b stats mapping note in `wird-marker.md`, and the phone checks. | owner's go-ahead for M4 |

## Test Plan

*   **Pure-function tests:**
    *   Marker suggestion: no cards, cards 1 to 3 (page 62), cards 1, 2, 4 (N = 2, page 42), all 30 (no suggestion), a list in any order, a juz table with 30 entries.
    *   Juz achievements: every boundary of 5 and 15, khatma count 0 and 1, the derived total with and without leftover cards.
    *   Existing `wirdAchievementIds` tests stay unchanged (the page-mode ids do not read juz data).
*   **Check before emptying (new):** with a fake achievement store and a fake clock or timeout: (1) cards 1 to 5 checked, no earned ids: switching awards `wird_juz_5` and then empties the cards; (2) 4 cards checked: nothing is awarded and the cards are emptied; (3) guest: no award call, cards emptied; (4) the store throws: cards still emptied, no exception reaches the caller; (5) the store never answers: the bounded wait ends and the cards are emptied; (6) the award is made from values captured before emptying, not from prefs read afterwards.
*   **Provider tests:** the switch empties only juz data and leaves the marker, undo record, khatma fields, streak and settings alone; Page → Juz changes nothing; a cancelled dialog changes nothing; the stats provider shows the page numbers in page mode and the juz numbers in juz mode, with the streak shared.
*   **Widget tests:** the dialog shows in both languages with the two buttons and only on Juz → Page; "Cancel" keeps the mode and the cards; the stats screen shows only the active mode's tiles.
*   **Phone checks (not testable otherwise):** check 5 cards, switch to page, read the warning in English and Arabic (RTL), cancel once, then confirm; see `wird_juz_5` in the Quran group after the switch; see the cards empty when returning to juz; see the suggested page 82 (juz 5 starts there, after cards 1 to 4) and place the marker, then use "Choose another page" in the reader; with a marker already placed, confirm there is no suggestion; repeat the switch in airplane mode and check it still empties the cards; check Khatm History and the stats screen in both modes; sign in on a second device and compare `completedJuz`.
*   **Not covered by tests:** Firestore behavior offline and the push order on two devices, the exact Arabic wording, real-device layout of the dialog at the largest font.
*   **Baseline:** `flutter test` and `flutter analyze` numbers recorded before M1 and after every phase.

## Out of Scope

*   Checking a juz card automatically from reading: see `docs/designs/juz-auto-check.md` (draft, branch `docs/juz-followups`).
*   The achievement check timing in general: see `docs/designs/wird-achievements-juz.md` item 2 (this spec only adds the check at the switch).
*   Per-mode streaks and day counts (Decision D): they need their own design.
*   A persisted cumulative juz counter and a pending-award retry (they conflict with Decision H).
