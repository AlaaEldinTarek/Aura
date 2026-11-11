# Stage 6: Comprehension Test — fix-quran-khatma-wird.md

Reviewer: egm-comprehension (read the document alone, lines 1-225).

## What this proposes
Two small fixes in the Quran feature, with no change to stored data and no new UI. (1) The reader's top-bar X button should call `Navigator.of(context).maybePop()` instead of `Navigator.pop`. That makes it go through the reader's `PopScope` handler, as system back and Esc already do. The handler shows the khatma ("Did You Finish?") prompt on page 604 in Wird page mode, and otherwise shows a "Close Reader?" dialog. The button's own desktop-sidebar line is removed, because the handler's closing branches already set it. (2) In Wird page mode, "Choose One" should link the bookmark color with a counted-pages set built by a new pure function, `countedPagesAfterChooseOne`. That set is the full set of pages of that color, unioned with the existing counted pages if the same color was already linked. Today the set is only `{bm.page}`, so the auto-sync counts every other bookmark of that color as new progress. The fix is at the call site only. `WirdService.setLinkedBookmarkColor` is left alone.

## How the existing system works, per this document
The reader wraps its Scaffold in `PopScope(canPop: false)`, with a handler that decides between the khatma prompt and the "Close Reader?" confirmation. Only back and Esc reach that handler, because the X button pops directly and bypasses it. In the Wird tab, "Choose One" does two things. It calls `recordPagesRead(1, page)`, and it calls `setLinkedBookmarkColor(color, {page})`, which replaces `countedBookmarkPages`. A sync in `build()` then compares the color's current bookmark pages against `countedBookmarkPages`. It adds the difference to today's progress through `syncBookmarkPages`. That is why the other bookmarks get counted. "Use all" passes the full color set, so it is unaffected. Juz mode uses a different path (`markJuzFromBookmarks`, which merges) and is unaffected.

## Findings
| # | Sev | Scope | Finding |
| --- | --- | --- | --- |
| M1 | Major | Overview, Problem, throughout | Project terms undefined: Wird, khatma, page vs juz mode, `pagesRead`, `countedBookmarkPages`, "linking a color", "Use all". Add a short background paragraph or glossary before The Problem. |
| M2 | Major | F38c text (lines 18–26), CUJ 3/4, diagram | The auto-sync is the core of the bug but described in one sentence. State its contract: inputs, what it adds, whether it updates the counted set, what `syncBookmarkPages` returns; explain `_syncInProgress`. |
| M3 | Major | Lines 24–26 vs fix and CUJ 4 | The double-count when the color is already linked is too thin. Add a worked example like CUJ 3 gives for the first bug. |
| M4 | Major | Technical Plan F38c; CUJ 3 | Meaning of `countedBookmarkPages` is unclear: "pages that added progress" or "pages the sync should ignore". Goals/CUJs use both. Define it; say what happens when a bookmark is removed and re-added. |
| M5 | Major | Technical Plan F38c vs Detailed Plan item 2 | Helper inputs described differently (nullable color name / `Set<int>` / stored sorted `List<int>`). State where the list↔set conversion happens. |
| M6 | Major | F38a sidebar text, Goals, CUJ 2 | Never says what `desktopSidebarVisibleProvider` controls or why the sidebar is hidden in the reader. The claim that three lines cover "every branch" is not checkable for the khatma Yes/Not Yet paths. |
| M7 | Major | All line-number cites | The case rests on line numbers in files that are not quoted; short excerpts would make the doc checkable alone, and line numbers will go stale. |
| M8 | Nit | Header, Detailed Plan | Process terms undefined: Level A/C, approve phase, EGM, "edit carefully" list (content not given, claim not checkable), project-log skill, S45/S46, nova 5T, STATE.md, baselines (260 tests, 418 issues). |
| M9 | Nit | Open Questions vs Goals | Decision status unclear (decided or pending) for "same as back" and for "Choose One on already-counted page". |
| M10 | Nit | Detailed Plan item 3 | Test setup relies on unexplained cloud push / `catchError`; assumes `syncBookmarkPages` returns the count of newly added pages, never stated. |
| M11 | Nit | Detailed Plan items 6, 7 | Reason for keeping findings out of the README not given; order of doc updates vs device checks not stated. |
