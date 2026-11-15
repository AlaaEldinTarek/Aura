# Wird Mode Separation: Page Mode and Juz Mode as Independent Modes

*   **Author:** Alaa Eldin Tarek (drafted with Claude)
*   **Status:** Draft, not approved. Every "decided" in this file is the owner's requirement text of 2026-11-15; everything marked GUESS or OPEN QUESTION is not decided.
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
*   **Display independence, remaining gaps (GUESS, to verify before code):** the shared streak and day count, the shared Khatm History and the stats screen still mix both modes. See open questions C, D and E.

### What a mode switch deletes and what it keeps

| Switch | Warning | Deletes | Keeps |
|---|---|---|---|
| Page → Juz | none proposed (GUESS) | nothing | marker record and undo record |
| Juz → Page | yes (Goal 3) | the checked juz cards: `wird_completed_juz` and today's `juzCompletedToday` (GUESS, see open question A) | marker, khatm history, earned achievements, streak (GUESS, open questions B to E) |

The owner's wording is "going back to the other mode will empty the checked juz cards". It is not certain which direction empties the cards. This draft assumes it is leaving juz mode. OPEN QUESTION A asks.

### Marker suggestion on the way to page mode (Goal 4)

*   **Rule (b), the owner's suggestion, GUESS on details:** the suggested page is the first page of the juz after the last consecutively checked juz. Let N be the largest number such that juz 1 to N are all checked. If N is 0, there is no suggestion. If N is 30, there is no suggestion (the khatma path resets the cards at 30, `wird_tab.dart:176-188`, VERIFIED). Otherwise the page is `startPages[N]` (zero-based list: juz N+1 starts there). Example: cards 1, 2, 3 and 5 checked gives N = 3 and page 62 (VERIFIED against the table `quran_reader_screen.dart:85-89`: juz 4 starts at page 62).
*   **Juz table (UNKNOWN whether the two tables agree):** the reader's static list (`quran_reader_screen.dart:85-89`) and `juzListProvider` (`quran_provider.dart:14`). The pure function takes the list as a parameter. Phase 1 compares them before use.
*   **Where it appears (GUESS):** after the user confirms leaving juz mode, if there is no marker (`applySetup` needs none, VERIFIED) and N is above 0, the existing start sheet opens with the suggested page (`WirdStartSheet` with `readingMode: false`, as `_setMarkerFromTab` does, `wird_tab.dart:337-345`). "Start here" places the marker (`placeMarker`, `wird_provider.dart:199-203`) and "Cancel" skips it. The sheet title "Start your Wird from page N?" is already translated.
*   **"The user can change it" (UNKNOWN how):** the tab version of the sheet offers only Start here and Cancel (spec `wird-marker.md` items 9 to 11). The reader version offers "Choose another page" and "Just read". This draft assumes the user can use "Choose another page" in the reader (GUESS). OPEN QUESTION F asks.
*   **A marker already exists (VERIFIED: placement fails with `markerExists`):** no suggestion is shown. OPEN QUESTION G asks whether to offer a move instead.

### New juz achievements (Goal 2)

Same collection and shape as today (`users/{uid}/achievements/{id}`, `achievement_service.dart:401-405`, contract row `firestore-paths.md:10`), so no schema change. Names are DRAFT.

| Id (proposed) | English name | Arabic name (DRAFT) | Condition (GUESS on thresholds) | Reads |
|---|---|---|---|---|
| `wird_juz_5` | Five Juz | خمسة أجزاء | at least 5 juz read in total | `wird_khatm_count × 30 + checked juz count` |
| `wird_juz_15` | Half the Quran | نصف القرآن | at least 15 juz in total | same value |
| `wird_juz_khatma` | Juz Khatma | ختمة بالأجزاء | `wird_khatm_count >= 1` | `WirdService.getKhatmCount` (`wird_service.dart:379-382`) |

*   **Pure function (GUESS on the name):** `wirdJuzAchievementIds({required int juzKhatmCount, required int checkedJuz})` beside `wirdAchievementIds` (`achievement_service.dart:15-21`).
*   **Inputs and the emptying problem (VERIFIED mechanism):** `wird_completed_juz` is emptied by `resetAllJuz` at each khatma (`wird_service.dart:404-408`) and, under this spec, on leaving juz mode. The derived total `khatmas × 30 + checked` therefore drops when cards are emptied by a switch. An achievement that was already earned stays earned. One that was not yet awarded can be missed if the cards are emptied before the next check. OPEN QUESTION H asks whether to add a persisted cumulative juz counter instead.
*   **Names are inline, not translation keys (VERIFIED):** the existing definitions hold `nameEn` and `nameAr` directly (`achievement.dart:379-415`). This draft follows that pattern. CLAUDE.md says every UI string goes through `.tr()`; the existing achievements do not (VERIFIED), so this is flagged OPEN QUESTION I.
*   **Counts shown (VERIFIED the screen groups by category, `achievements_screen.dart:152`):** the Quran group goes from 1/7 style counts to a total of 10 (the three new ids). Per-user states are unaffected.
*   **When the check runs (UNKNOWN as of now):** achievements are checked only on a prayer record, a task completion and Profile badge grid mount (VERIFIED, see `wird-achievements-juz.md`). This spec does not change that; the timing question stays in that draft.
*   **Gaming (VERIFIED the cause):** cards are checked by tapping today, so these achievements can be earned by tapping. This is the same as the page-mode caveat for juz estimates and goes away only if `juz-auto-check.md` is built.

### Warning dialog texts

Keys are new and must go into both `assets/translations/en.json` and `ar.json` (VERIFIED rule, CLAUDE.md). The two buttons reuse the existing `cancel` key (VERIFIED used by the wird-marker sheets, `wird-marker.md` "Reused as they are"). The Arabic is a DRAFT for the owner's review.

| Key (proposed) | English | Arabic (DRAFT) |
|---|---|---|
| `wird_mode_switch_title` | Switch to Page mode? | التبديل إلى وضع الصفحات؟ |
| `wird_mode_switch_body` | Your checked juz cards will be emptied. Your khatm history and earned achievements stay. If you come back to Juz mode you start with empty cards. | سيتم تفريغ بطاقات الأجزاء التي حددتها. يبقى سجل الختمات والإنجازات التي حصلت عليها. إذا عدت إلى وضع الأجزاء فستبدأ ببطاقات فارغة. |
| `wird_mode_switch_confirm` | Switch | تبديل |

*   The body text states what GUESS (a) assumes (history and achievements stay). If the owner answers question A or B differently the text changes.
*   No number is interpolated into these strings, so no Arabic-numeral formatting is needed (VERIFIED by the texts above).
*   The page-to-juz direction has no dialog in this draft. If the owner wants one in that direction too, a second pair of keys is added.

## Open Questions for Aladdin

*   **A. Which switch empties the juz cards?** (1) Leaving juz mode (juz → page); proposed. (2) Leaving page mode (page → juz) too, so juz always starts empty. (3) Never on a switch, only on a khatma (today's behavior), and the warning only explains that cards stay. Cost: (1) one deletion in `setWirdUnit` plus the dialog; (2) the same in both directions; (3) no deletion, dialog text only. Risk: (1) and (2) delete user data, and the blind `wird/data` push can restore or lose `completedJuz` on a second device (`wird-marker.md` risk 12, VERIFIED to exist in the spec).
*   **B. (GUESS a) Khatm history and earned achievements stay when cards are emptied.** Alternative: also empty juz khatma entries, which would change the Khatm History and `wird_juz_khatma` logic. Proposed: keep.
*   **C. (GUESS c) Khatm History: one merged list (today) or split per mode.** One list needs no change. Split needs two lists on the Khatm Du'a screen (`khatma_dua_screen.dart:36`) and a source tag on each entry (the data already knows its source: legacy fields versus marker fields, VERIFIED), plus new strings.
*   **D. Streak and day count.** One shared streak (today, VERIFIED) or one per mode. A per-mode streak needs new prefs keys, new `wird/data` fields and contract rows. Proposed: leave shared, because "fully independent" in the owner's text most likely concerns progress and display (GUESS).
*   **E. Stats screen.** Show only the active mode's numbers (the average already differs by mode, VERIFIED) or keep the shared totals.
*   **F. Changing the suggested page.** Offer "Choose another page" in the tab sheet or only through the reader.
*   **G. Marker already exists on the way to page mode.** No suggestion (proposed) or offer to move it.
*   **H. A persisted cumulative juz counter for the achievements** (new prefs key, `wird/data` field, contract rows) or the derived value above (proposed).
*   **I. Inline achievement names (follows the existing pattern, proposed) or `.tr()` keys (CLAUDE.md rule).**
*   **J. Thresholds** (5 and 15 juz) and the achievement names above.
*   **K. Offline and sign-out.** Emptying `wird_completed_juz` locally is pushed in the background (`updateSettings` and `_pushToCloud`, `wird_service.dart:57-66`, VERIFIED mechanism). Whether the owner wants the emptying to wait for a connection is UNKNOWN.

## Files Touched (GUESS, for the proposed answers)

| File | Change |
|---|---|
| `lib/core/providers/wird_provider.dart` | `setWirdUnit` stays; new `switchToPageMode` (or a flag) that empties juz data, only after the dialog (OPEN A) |
| `lib/core/services/wird_service.dart` | a method that empties `wird_completed_juz` and today's `juzCompletedToday` without touching khatma fields or streak |
| `lib/core/services/wird_marker_logic.dart` | pure `suggestMarkerPageAfterJuz(checked, juzStartPages)` |
| `lib/core/services/achievement_service.dart` | `wirdJuzAchievementIds` and its checks in the Wird block |
| `lib/core/models/achievement.dart` | three new definitions |
| `lib/features/quran/wird_tab.dart` | the segmented button handler (dialog, then switch, then the optional start sheet) |
| `assets/translations/en.json`, `ar.json` | the three dialog keys (and any answer to C or F) |
| `.project-docs/contracts/prefs-keys.md`, `firestore-paths.md` | only if OPEN D or H adds keys (the proposed answers add none) |
| Tests | `wird_marker_logic_test.dart` (suggestion), a new `achievement_wird_juz_test.dart`, a provider test for the switch, a widget test for the dialog |

No Kotlin file is touched (GUESS: nothing native reads these keys; the contracts list no Kotlin reader for `wird_*`, VERIFIED `prefs-keys.md:74`).

## Risks

*   Deleting `wird_completed_juz` on a switch is data loss; the dialog is the only safeguard (OPEN A).
*   A second signed-in device can push a stale `completedJuz` back through the blind `wird/data` merge (VERIFIED risk in `wird-marker.md`, risk 12). The emptying would not be durable across devices until the push order is fixed.
*   Achievements derived from checked cards can be missed or earned by tapping (see above).
*   "Fully independent" and the shared streak, history and Khatm History do not fully agree (OPEN C, D, E).
*   The two juz tables may disagree (UNKNOWN), which would put the marker suggestion on the wrong page.
*   The marker suggestion in one flow combines a dialog, a mode change and a bottom sheet; the order and cancel paths need careful tests (GUESS on complexity).

## Phases (all need the owner's go-ahead first; no phase is open)

| Phase | Content | Gate |
|---|---|---|
| M0 | The owner answers questions A to K; this file is updated. | the owner |
| M1 | Tests first (red run): `suggestMarkerPageAfterJuz` (N = 0, 3 with a gap, 30, unsorted input, both juz tables compared), `wirdJuzAchievementIds` (khatma 0 and 1, checked 0, 4, 5, 14, 15, 30), the new method that empties only the juz data. | "approve phase M1" |
| M2 | The service, provider and logic code behind those tests, plus the three achievement definitions. | "approve phase M2" |
| M3 | The switch dialog, the new keys (Arabic DRAFT reviewed by the owner), the start-sheet hand-off. | "approve phase M3" |
| M4 | Docs, contract rows if any, and the phone checks. | "approve phase M4" |

## Test Plan

*   **Pure-function tests:**
    *   Marker suggestion: no cards, cards 1 to 3 (page 62), cards 1, 2, 4 (N = 2, page 42), all 30 (no suggestion), a list in any order, a juz table with 30 entries.
    *   Juz achievements: every boundary of 5 and 15, khatma count 0 and 1, derived total with and without leftover cards.
    *   Existing `wirdAchievementIds` tests must still pass unchanged (the page-mode ids do not read juz data).
*   **Provider tests:** the switch empties only juz data and leaves the marker, undo record, khatma fields, streak and settings alone; page → juz changes nothing; a cancelled dialog changes nothing.
*   **Widget test:** the dialog shows both languages and the two buttons; "Cancel" keeps the mode.
*   **Phone checks (not testable otherwise):** check 5 cards, switch to page, read the warning in English and Arabic (RTL), cancel once, then confirm; see the cards emptied when returning to juz; see the suggested page 82 (juz 5 starts there, after cards 1 to 4); place the marker and open the reader at that page; check Khatm History and the Quran achievements group; sign in on a second device and compare `completedJuz`.
*   **Not covered by tests:** Firestore push order on two devices, the exact Arabic wording, real-device layout of the dialog at the largest font.
*   **Baseline:** `flutter test` and `flutter analyze` numbers recorded before M1 and after every phase.

## Out of Scope

*   Checking a juz card automatically from reading: see `docs/designs/juz-auto-check.md` (draft, branch `docs/juz-followups`).
*   The achievement check timing: see `docs/designs/wird-achievements-juz.md` item 2.
*   A per-mode streak (OPEN D) unless the owner decides it, which would need its own design.
