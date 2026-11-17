# Comprehension Report (Stage 6)

**Target:** `docs/designs/chore-remove-test-notification.md` (1-266; FeatureRange 1-188, DetailedRange 189-266)
**Reviewer:** `egm-comprehension` (completed). Read the document alone, no other file.
**Result:** 0 Blocker, 0 Major, 9 Nit. Complete reviewer result below, unchanged except for the
Elephant's verification notes at the end.

## What this proposes

The document proposes deleting the "Test Notification" item from the Windows tray menu, which plays the Fajr adhan and shows the toast on demand. It also deletes the code that exists only for that item, all in `desktop_tray_service.dart`: the item, its separator, the click-handler case, the `_fireTestAdhanFromMenu` helper with its guard key, and one now-unused import. It also edits one test file so its expected menu no longer lists the item. `DesktopPrayerScheduler.fireTestAdhan()` is deliberately kept (now with no caller), and the Stop Adhan path, `_clickGuard`, translation keys and Android are untouched. The work is Level C (production code), so it needs approval and the phrase "approve phase". The doc also covers verification steps, rejected alternatives, and follow-ups for a later `fix/adhan-stop` branch.

## How the existing system works, per this document

The tray menu is built by `buildMenu` from fixed, reused menu items. Their ids are kept stable across rebuilds. In order, the items are next prayer, separator, optionally Stop Adhan and its separator while the adhan plays, Open Aura, separator, Test Notification, separator, Quit. Clicks go through `onTrayMenuItemClick`, which switches on the item key. A shared `SameTurnGuard` object (`_clickGuard`) suppresses duplicate clicks, because the tray plugin reports one click twice. The Test Notification handler calls `DesktopPrayerScheduler.instance.fireTestAdhan()`, which plays the adhan and emits a prayer event. A real prayer time plays it through the scheduler timer. Stop Adhan is described as currently faulty, and its fix is deferred.

## Findings

**Blocker:** none. Every section could be paraphrased.

**Major:** none.

**Nit**
1. Lines 4 and 6: "`/egm:egm-review` Stage 5" and "Level C / Level A" appear with no definition or link. The Level scheme is only said to come from `CLAUDE.md` Rules. A reader can infer the meaning, but the Status line depends on these process terms.
2. Lines 17-21 and 26: "A2 (device check)", "A1 spec", "PR #37 work" and "PR #24" are referenced as if known. The doc names `docs/designs/desktop-single-adhan-popup.md` once, but "A2" is never explained inline. The same applies to "A2 step 6 result" at line 123. One sentence saying what A2 was would fix this.
3. Line 8-9 versus Technical Plan: the branch is "from `main`" while line numbers are cited "on main 96ddbcc". The git state shows 132d241 as the latest commit. The Detailed Plan says to re-check line numbers, which covers this. State clearly that 96ddbcc is the reference commit, not necessarily the current tip.
4. Line 45: "the playing-flag lines (`:85-87` and `:110-112`)" are never explained. The doc does not say what the "playing flag" is or why those lines matter until the Question 1 text says it is the pattern behind the Stop Adhan bug. Define it at first mention.
5. Line 27 and 131: "VERIFIED" and "REPORTED" are used as evidence labels (line 262 implies REPORTED is weaker than VERIFIED). The convention is never defined.
6. Lines 62-85: the Open Questions section is mostly closed or decided, yet Question 2's resolution just repeats Question 1 and the Goals. Question 4 refers to "the usual STATE and log entries" without saying where they live (they appear only in Detailed Plan section 4). This is redundant, not blocking.
7. Line 112-119: the "Before (idle)" column has a different separator layout from the "After" columns, and the "After (adhan playing)" column shows Stop Adhan, then Open Aura, with no separator between the next-prayer separator and Stop Adhan. This conflicts slightly with the Goals' order (next prayer, separator, Stop Adhan and its separator, Open Aura). A reader may not be sure which is authoritative. The Detailed Plan's playing key order (line 223) matches the Goals text.
8. Line 210: `dart format` is said to be kept even if it changes unrelated lines. It does not say what to do if the formatter touches code outside the deleted regions.
9. Line 90-91: "ids stay stable, per `docs/designs/tray-quit-fix.md`, 'T3 result and T2b'" cites section labels the reader cannot interpret without opening that file. The ids test (line 140) partly explains this, but not why stability matters.

## Elephant's verification notes (not part of the reviewer's result)

* Nit 7 looks mistaken: in the diagram at lines 110-118, the "After (adhan playing)" column does have a separator between the next-prayer line and Stop Adhan (third row of dashes), and another after Stop Adhan. The three columns differ only because Test Notification is gone. UNVERIFIED by the reviewer's reading; VERIFIED by the Elephant reading the file.
* Nit 3: 96ddbcc is main at the time of drafting; the current branch tip is a later docs commit. `lib/` and `test/` had no diff between them (VERIFIED earlier with `git diff main -- lib test`).
