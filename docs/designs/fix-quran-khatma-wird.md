# Fix Quran Khatma Prompt and Wird "Choose One" Bookmark (F38a + F38c)

*   **Author:** Alaa Eldin Tarek
*   **Status:** Draft (revised 2026-11-11 after EGM review; decisions applied)
*   **Date:** 2026-11-11

--------------------------------------------------------------------------------

## Overview

Two bugs in the Quran feature record the wrong data. The reader's top-bar close button skips the page-604 khatma prompt, so a finished khatma can go unrecorded. The Wird tab's "Choose One" bookmark action counts every bookmark of that color as read, so Wird progress, streak and totals come out too high. Neither fix changes a stored data format. The only UI addition is one snackbar message for the new "already counted" guard.

## Background

*   **Wird**: the user's daily Quran reading goal, tracked in the Wird tab (`wird.md`: [wird module doc](../../.project-docs/modules/wird.md)). **Khatma**: one full read of the Quran.
*   **Page mode / juz mode**: a Wird setting. Page mode counts pages read against a daily page goal. Juz mode marks juz (1 of 30 parts) as completed.
*   **Bookmark color link**: the user can link one bookmark color (red, orange or green) to the Wird. Bookmarks of the linked color then add to progress through an **auto-sync** that runs inside `_WirdContentViewState.build()` (`wird_tab.dart`). The sync takes the pages of the linked color's bookmarks, subtracts `countedBookmarkPages`, and adds the difference as pages read (`syncBookmarkPages`, which returns how many pages it added).
*   **`countedBookmarkPages`** (stored in `WirdSettings`, a sorted `List<int>`): the pages the auto-sync must skip. A page is in it either because it already added progress, or because it was deliberately marked as counted when the color was linked.
*   **Desktop sidebar**: on desktop the reader hides the main navigation sidebar when it opens (`quran_reader_screen.dart:95`). Each closing path must set `desktopSidebarVisibleProvider` back to `true`.

## Problem Statement

### F38a: close button skips the khatma prompt (VERIFIED by reading the code, not run on a device)

The reader wraps its `Scaffold` in `PopScope(canPop: false, onPopInvokedWithResult: ...)`. That handler shows the khatma prompt (the "Did You Finish?" dialog) on page 604 in Wird page mode when today's wird is not done, and otherwise a "Close Reader?" confirmation. The top-bar close button calls `Navigator.pop(context)` directly. A direct `pop` does not go through `PopScope`, so the handler never runs. Only the system back gesture and the desktop Esc key reach it. The Esc handler already calls `Navigator.of(context).maybePop()`, which does run `PopScope`.

A user who reads to page 604 and taps the close button never sees the prompt, so `recordPageKhatma()` and `markComplete()` are never called.

### F38c: "Choose One" counts every bookmark of that color (VERIFIED by reading the code, not run on a device)

In Wird page mode, the user taps a color with bookmarks, then "Choose One", then selects one bookmark. The `onSelect` handler in `_showBookmarkListSheet` (`wird_tab.dart`, page-mode branch) then does two things:

1.  `recordPagesRead(1, bm.page)` adds one page of progress.
2.  `setLinkedBookmarkColor(color.name, {bm.page})` links the color and **replaces** `countedBookmarkPages` with that single page (`WirdService.setLinkedBookmarkColor`).

The auto-sync then sees every other bookmark of that color as new and counts all of them.

**Example, color not linked yet.** Red bookmarks on pages 10, 50, 100, 200, 300. The user chooses 100. Progress shows 1 page. `countedBookmarkPages` becomes `[100]`. On the next rebuild the sync adds 10, 50, 200 and 300: progress jumps to 5 pages, the daily goal of 5 completes, and the streak increments.

**Example, color already linked.** Red is linked and `countedBookmarkPages` is `[10, 50]` (both already counted). The user chooses page 100. The replace turns the set into `[100]`, so the next sync counts 10 and 50 a second time.

Callers of `setLinkedBookmarkColor` in `lib/` (`grep -rn setLinkedBookmarkColor lib/`, run 2026-11-11):

| Caller | Passes | Depends on replace? |
| --- | --- | --- |
| `_showBookmarkListSheet` `onSelect`, page mode ("Choose One") | `{bm.page}` | This is the bug. |
| `_showBookmarkPagesSheet` `onUseAll` ("Use all") | every page of the chosen color | No. The set is the full color set, so replace gives the same result. |

Nothing else calls it (the provider method `WirdNotifier.setLinkedBookmarkColor` is a pass-through). No caller needs replace behavior, so the fix goes in the call site.

### Juz mode, never-linked state (VERIFIED by reading)

Not affected. The juz-mode "Choose One" calls `markJuzFromBookmarks`, which merges the chosen page into `countedBookmarkPages` and does not set the linked color, so no other pages become "new". The mode-switch case is out of scope; see Non-Goals.

## Goals

*   The close button runs the same logic as system back and Esc: the khatma prompt on page 604 in page mode with today's wird not done, otherwise the "Close Reader?" confirmation.
*   When no sync is running and the counted set is current, in page mode this handler ("Choose One") adds one page of progress, whatever the number of bookmarks of that color. The auto-sync can add further pages for other unsynced bookmarks (Goal 4, CUJ 4).
*   When no sync is running and the counted set is current: on first link (or when switching to a different color), the existing bookmarks of that color are marked as counted without adding progress. After that, bookmarks added later still auto-count.
*   When no sync is running and the counted set is current, and the color is already linked, "Choose One" keeps every page already counted and adds only the chosen page to the set. Other bookmarks of that color that were not synced yet are counted by the auto-sync as new bookmarks (existing behavior).
*   "Choose One" on a page that is already counted does not add it again when no sync is running, the counted set is current, and the same color is already linked (the Wird state, or `initialState` if it is not yet loaded, is the source of the set). The counted set read can be stale (see Risks), so this is not a guarantee against every re-count. The user sees a snackbar saying so.
*   The two calls in the page-mode "Choose One" handler are awaited in a fixed order, so the state change from the first call cannot start an auto-sync that sees the chosen page as new. This holds when no sync is running and the counted set is current (see Risks (a) and (b)).
*   Desktop sidebar visibility behaves as today in every close path, including "Keep Reading".

## Non-Goals

*   Repairing Wird progress already inflated by F38c. The stored data cannot show which pages were counted by mistake.
*   Changing `WirdService.setLinkedBookmarkColor`, `WirdNotifier`, or the stored shape of `WirdSettings`.
*   Changing the "Use all" flow. Re-running "Use all" on an already-counted color may add the page count again (UNVERIFIED); not investigated.
*   **Juz mode, mode-switch case (UNVERIFIED):** Scenario: switching from page mode to juz mode after pages were counted in page mode, then adding pages in juz mode. Code reading suggests this is not a bug; not verified.
*   Other unawaited writes in the Wird code (F39), and the auto-sync's own read-modify-write, which can still overlap with the awaited calls (see Risks).
*   A baseline field or per-color counted map. Known limit: the counted set belongs to the one linked color, so switching to another color and back replaces it. Switching back via "Choose One" baselines that color's pages and adds only the chosen one; whole-color re-counting happens only through "Use all", which is a Non-Goal. Follow-up only.
*   Other F38/F39 items: `scrollToAyaNo` (F38b), stats weekday labels (F38d), stats average unit (F38e).
*   Changing the khatma prompt text or the "Close Reader?" dialog text. The only new string is `wird_bookmark_already_counted`.

## Critical User Journeys (CUJs)

### CUJ 1: Close button on page 604 records the khatma

*   **Given**: Wird unit is page mode, today's wird is not completed, the reader is on page 604, top bar visible.
*   **When**: The user taps the close button in the top bar.
*   **Then**: The "Did You Finish?" dialog appears. "Yes, I'm Done!" records the khatma, marks today complete and opens the celebration screen. "Not Yet" closes the reader without recording. "Keep Reading" stays in the reader.

### CUJ 2: Close button on another page confirms, then closes

*   **Given**: The reader is on any page other than 604 (or on 604 in juz mode, or with today's wird done).
*   **When**: The user taps the close button.
*   **Then**: The "Close Reader?" dialog appears. "Close" leaves the reader. "Keep Reading" stays and, on desktop, the sidebar stays hidden.

### CUJ 3: Choose One on first link counts one page

*   **Given**: Page mode, 5 red bookmarks (pages 10, 50, 100, 200, 300), red not linked, no pages read today.
*   **When**: The user opens Add from Bookmarks → red → Choose One → page 100.
*   **Then**: When no sync is running and the counted set is current: today's `pagesRead` is 1. Red is linked. `countedBookmarkPages` is `[10, 50, 100, 200, 300]`. After the next rebuild, `pagesRead` is still 1.

### CUJ 4: Choose One with the color already linked

*   **Given**: Red is linked, `countedBookmarkPages` is `[10, 50]`, red also has bookmarks on page 100 and page 200, neither synced yet (the auto-sync has not run since they were added).
*   **When**: The user chooses page 100.
*   **Then**: When no sync is running and the counted set is current: `countedBookmarkPages` becomes `[10, 50, 100]`. Page 100 adds one page. Page 200 is not in the set, so the auto-sync counts it once as a new bookmark. Pages 10 and 50 are not counted again. On a device this state is almost unreachable, because the auto-sync runs when the Wird tab opens. Only the set arithmetic is covered, by unit helper case 5; the progress outcome ("page 100 adds one page", "pages 10 and 50 are not counted again") has no automated test and no device step.

### CUJ 5: A bookmark added later still auto-counts

*   **Given**: CUJ 3 finished.
*   **When**: The user adds a new red bookmark on page 400.
*   **Then**: When no sync is running and the counted set is current, the auto-sync counts page 400 once, and only page 400.

### CUJ 6: Choose One on an already-counted page

*   **Given**: Red is linked and `countedBookmarkPages` contains page 100.
*   **When**: The user chooses page 100 via Choose One.
*   **Then**: When the guard fires, this handler writes nothing: progress and `countedBookmarkPages` do not change from it, and a snackbar shows "This page was already added". The guard decides from the counted set it reads, so it can fire while a sync is running (the sync can still change progress). Under overlap, a running sync or a stale set can make it miss an already-counted page, which is then added again (Risks (a)/(b)).

## Proposed Architecture

### F38a

Replace the body of `_TopBar.onClose` with `Navigator.of(context).maybePop()`. `maybePop` runs the route's `PopScope` handler. Esc already makes the same call.

The desktop sidebar line is removed from the button. Every closing branch of the handler already sets `desktopSidebarVisibleProvider` to `true`: the khatma "Yes" branch, the khatma "Not Yet" branch, and the "Close Reader?" close branch. Keeping the line in the button would show the sidebar behind the reader after "Keep Reading". The `_isDesktop` field stays, because the handler uses it.

The claim that `maybePop` reaches `PopScope(canPop: false)` rests on Flutter 3.38.7 (STATE.md) and on the Esc path using the same call. Device check S45 is the proof.

```text
Before:  close tap ──► Navigator.pop ───────────────► reader closed (PopScope skipped)
After:   close tap ──► maybePop ──► PopScope handler ─┬─ page 604 + page mode + not done ──► khatma prompt
         back / Esc ─────────────────────────────────┘   └─ otherwise ───────────────────► "Close Reader?" dialog
```

### F38c

Fix at the call site. In the page-mode branch of `onSelect`:

1.  A new pure function `countedPagesAfterChooseOne` computes the new counted set and whether the chosen page was already counted. Inputs: the linked color name (nullable), the existing counted pages, the chosen color name, the chosen page, and the pages of every bookmark of the chosen color. Outputs: `counted` and `alreadyCounted`.
    *   **Same color already linked**: `counted` = existing counted pages ∪ {chosen page}. `alreadyCounted` = the chosen page is in the existing set.
    *   **Not linked, or a different color**: `counted` = all pages of the chosen color ∪ {chosen page}. `alreadyCounted` is false. The color link is new, so its current bookmarks become the baseline. This is the F38c fix. A different color replaces the link, so the old color's counted pages no longer matter.
2.  If `alreadyCounted`, show the snackbar and stop. No writes.
3.  Otherwise: `await setLinkedBookmarkColor(color.name, counted)`, then `await recordPagesRead(1, chosen page)`, then the existing "added" snackbar.

**Why the link goes first.** Each provider method reloads state, and a state change re-runs `build()`, which runs the auto-sync. If `recordPagesRead` ran first and the color was already linked, the sync could see the chosen page as new (it is not in the old counted set yet) and add it a second time. Linking first puts the chosen page into `countedBookmarkPages` before the sync that the link's own state change triggers, when no sync is running and the counted set is current (Risks (a) and (b)).

**Why first link and later choices differ.** The first link baselines the bookmarks that exist now; the user picked one page to count. After that, bookmarks that are not in the counted set are bookmarks added since, and auto-counting them is the feature (CUJ 4, CUJ 5).

The existing counted pages and linked color come from the current Wird state, read as `ref.read(wirdStateProvider).valueOrNull ?? widget.initialState` at the top of the page-mode (`else`) branch of `onSelect` in `_showBookmarkListSheet` (`wird_tab.dart`, the branch that today calls `recordPagesRead(1, bm.page)` at line 649). This is the same fallback `build()` uses (`wird_tab.dart:144`) and `_launchWirdTutorial` (`:75`). `WirdTab` builds `_WirdContentView` only when the provider has data and passes a new `initialState` on every provider data change (`:25–31`), so `widget.initialState` is as current as the provider. The `??` fallback is therefore defensive and effectively unreachable; it is kept so the helper never receives an invented empty set. The read is a snapshot and can be stale in the cases in Risks (a) and (b).

The juz-mode branch and the "Use all" flow are unchanged.

```text
Choose One(page P, color C, pages of C = S)
  same color linked:  counted = existing ∪ {P};  alreadyCounted = P ∈ existing
  otherwise:          counted = S ∪ {P};          alreadyCounted = false
  alreadyCounted → snackbar, stop
  else → await setLinkedBookmarkColor(C, counted) → await recordPagesRead(1, P) → snackbar
auto-sync (build): currentPages \ counted → later bookmarks only
```

## Alternatives Considered

### Alternative A: Merge inside `WirdService.setLinkedBookmarkColor`

*   **Pros**: Every caller is protected from the replace behavior.
*   **Cons**: Changes shared service behavior that "Use all" also uses. "Use all" on a color whose bookmarks were removed since would keep stale pages in the counted set. The grep found one wrong caller out of two.
*   **Reason for Rejection**: The shared change adds risk for the "Use all" flow to protect callers that do not exist. The footgun stays in the service; this design accepts that and documents the replace contract in the plan.

### Alternative B: "Choose One" does not link the color

*   **Pros**: Smallest change. Nothing can be auto-synced.
*   **Cons**: Today choosing one bookmark also turns on auto-count for future bookmarks of that color. This would remove that.
*   **Reason for Rejection**: It removes a working behavior to fix a counting bug. `CLAUDE.md` allows no behavior change beyond what a spec approves, and nothing in this design needs it.

### Alternative C: Extract the PopScope handler into a method and call it from the close button

*   **Pros**: The close path would not depend on `PopScope` routing.
*   **Cons**: Moves the roughly 75-line handler and adds a second entry point to keep in sync with `PopScope`.
*   **Reason for Rejection**: `maybePop` is a one-line change and matches the Esc handler, which already uses it.

### Alternative D: A merge-only service method (for example `addCountedBookmarkPages`)

*   **Pros**: Does the read, union and write in one service call, so a stale provider snapshot cannot overwrite a newer set.
*   **Cons**: A new public service method and provider wrapper. It still needs the call site to compute the color's pages for the first link.
*   **Reason for Rejection**: Awaiting the two calls in order removes the ordering race the new method would address. The remaining overlap, the auto-sync's own write, is not removed by this alternative either.
*   **Note on Risk (b)**: This alternative would remove Risk (b) (stale provider read), because it reads and writes the counted set inside one service call; the rejection above does not rely on that. Risk (b) is accepted as a known limit for this fix.

### Alternative E: Skip `recordPagesRead` and let the auto-sync count the chosen page

*   **Pros**: No ordering problem between two calls. Set `counted` to exclude the chosen page and the sync adds it.
*   **Cons**: Progress depends on a side effect inside `build()`. The snackbar cannot know how many pages were added. In the already-linked case the same sync also counts other unsynced bookmarks in one step.
*   **Reason for Rejection**: Hidden coupling to `build()` for something the handler can do explicitly.

## Risks & Mitigations

*   **Auto-sync overlap (accepted, not yet device-checked).** In the already-linked case with other unsynced bookmarks (CUJ 4), the state change from `setLinkedBookmarkColor` can start an auto-sync while `recordPagesRead` runs. Both read and write the progress history without a lock, so one progress increment could be lost. The effect is an undercount. There is no double-count when a sync is idle (the chosen page is already in the counted set before any sync runs); two cases can still re-count pages: (a) a sync already running at tap time can write back an older counted set that the next sync counts again, and (b) a stale provider snapshot can do the same. In both cases the already-counted guard (CUJ 6) can miss, because it decides from the same counted set, and the page is added again. The window is short. The overlap case cannot be reproduced on a device (see S46); it is argued from the code, not tested.
*   **Sync reverts the color link.** A sync running at tap time can write back the settings it read earlier, which can undo the new color link and its baseline. The next sync then counts the old color's unsynced pages. Accepted for this fix; a service-level merge in `syncBookmarkPages` is a follow-up (see Follow-ups). Trigger: a sync overlapping a Choose One tap.
*   **Tap before the Wird state loads (defensive fallback, effectively unreachable).** If the provider has no data at tap time, "Choose One" reads `widget.initialState` instead (see F38c). `WirdTab` builds the content view only when the provider has data and passes a new `initialState` on every data change, so the state cannot be missing while the sheet is open and `initialState` is as current as the provider. Like the provider read, it can be stale (Risks (b)).
*   **Guard message wording.** The guard message says 'already added' but also fires for pages that were only baselined; the wording is kept for this fix and may be revisited after native review.
*   **Close dialog on every close.** The close button now shows "Close Reader?" on non-604 pages. This is decided (below) and follows system back.
*   **Repeated close taps.** While a dialog is open its modal barrier blocks taps on the close button, so the handler should not stack dialogs. UNVERIFIED; S45 includes a rapid double tap.
*   **Double-tap on a stacked dialog.** Double-tap on a stacked dialog runs `nav.pop()` twice. Accepted for this fix: rare, and the second pop is limited by the navigator stack. No re-entry flag. Add a device check if it reproduces. UNVERIFIED: not traced beyond reading the handler.
*   **Existing handler, not changed here.** The khatma "Not Yet" branch calls `nav.pop()` after an `await` without a `mounted` check (`quran_reader_screen.dart`, in the `PopScope` handler). The close button now reaches it more often. Left as is; it uses a navigator captured before the await.
*   **Inflated data stays.** Progress already inflated by F38c is not repaired. No user communication is planned.
*   **Rollback.** Revert the commits. Settings already written with a larger counted set stay as stored. That is benign: those pages are counted once. A rolled-back build brings the bug back.
*   **Color switch.** Switching to another color and back via "Choose One" baselines that color's pages and adds only the chosen one; a page counted under the old color can be added again if it is the chosen page. Whole-color re-counting happens only through "Use all", a Non-Goal (see Non-Goals).

## Open Questions

None. Decided 2026-11-11:

*   The close button shows the "Close Reader?" confirmation on non-604 pages, same as system back.
*   "Choose One" does not add an already-counted page twice when no sync is running and the counted set is current (CUJ 6). The guard applies only when the same color is already linked; after a color switch, a page counted under the old color can be added again if it is the chosen page (known limit). Switching back via "Choose One" baselines the color's pages and adds only the chosen one; whole-color re-counting happens only through "Use all", a Non-Goal.
*   In the already-linked case, "Choose One" adds only the chosen page to the counted set, not the whole color.

## Follow-ups (not part of this fix)

*   A service-level merge in `WirdService.syncBookmarkPages`, so an overlapping sync cannot undo a new color link (Risks, "Sync reverts the color link"). It needs its own finding and spec; `WirdService` is out of scope here (Non-Goals).

## Non-Functional Requirements

*   **Data compatibility**: No stored key or Firestore shape changes. `countedBookmarkPages` stays a sorted `List<int>` inside `wird_settings`; the service sorts it on write (`WirdService.setLinkedBookmarkColor`). Cloud sync of `wird_settings` was not checked and is not changed.
*   **Strings and numerals**: One new key, `wird_bookmark_already_counted`, in both `assets/translations/en.json` and `ar.json`, used through `.tr()`. The message shows no number, so no Arabic-numeral handling.
*   **Edit-carefully list**: None of the files here is on the "edit carefully" list in `CLAUDE.md`. No native code, prefs key names, notification IDs, MethodChannels or other native contracts are touched.

## Additional Resources

*   [findings.md](../../.project-docs/reference/findings.md) § F38 (a) and (c); F39 for related backlog items left alone.
*   [quran-wird module](../../.project-docs/modules/quran-wird.md), [wird module](../../.project-docs/modules/wird.md), [quran folder README](../../lib/features/quran/README.md).
*   EGM review reports: `.project-docs/reference/reviews/quran-khatma-wird/`.

--------------------------------------------------------------------------------

## Detailed Implementation Plan

Approval levels (`CLAUDE.md`): `lib/`, `assets/translations/` and `test/` cases are Level C and need an approved spec plus "approve phase" for this group. Docs are Level A. Branch: `fix/quran-khatma-wird`. One commit per phase. The `en.json` and `ar.json` edits are already in the working tree, uncommitted: stage files by name in every phase commit so the keys land only in the phase 2 commit. Before the first edit: `git status`, and run `flutter test` and `flutter analyze` once to record the baseline (STATE.md says 260 tests, 418 analyze issues; re-check on the current HEAD).

### Phases

1.  **Helper and tests.** Add the helper and `visibleForTesting` import in `wird_tab.dart` (call site unchanged), create the test file. Check: `flutter test test/features/quran/wird_choose_one_test.dart` passes, `flutter analyze` shows no new issues.
2.  **Call site and strings.** Change the page-mode `onSelect` branch. Translation keys `wird_bookmark_already_counted` (en and ar) already added 2026-11-11, uncommitted; they ship with this phase's commit (stage them by name; phase 1 must not include them). Check: analyze, full `flutter test`.
3.  **Close button.** Change `onClose` in `quran_reader_screen.dart`. Check: analyze, full `flutter test`.
4.  **Docs (Level A).** Module docs, README, and the S45/S46 rows in the device checklist (Result column left empty, so the checks are defined before they run).
5.  **After the device checks (S45, S46).** Mark F38a and F38c fixed in findings, add the STATE.md entry, record the S45/S46 results in the device checklist (rows added in phase 4), and log the work (Target Files item 11).

Note: the tests exercise the helper and the service. The wiring of the call site and of the close button is covered only by S46 and S45.

### Target Files to Create/Modify

#### 1. [`lib/features/quran/wird_tab.dart`](../../lib/features/quran/wird_tab.dart) (Modify) — phases 1 and 2

*   **Type / Scope**: Flutter widget file.
*   **Proposed Changes**:
    *   Add `import 'package:flutter/foundation.dart' show visibleForTesting;` (the file imports only `material.dart`, and `widgets.dart` re-exports `foundation.dart` with `show Brightness, UniqueKey` only; checked in the Flutter SDK source).
    *   Add a top-level function above the widget classes: `@visibleForTesting ({Set<int> counted, bool alreadyCounted}) countedPagesAfterChooseOne({required String? linkedColor, required Set<int> existingCounted, required String chosenColor, required int chosenPage, required Set<int> colorPages})`. Rule as in Proposed Architecture (same color linked → `existingCounted ∪ {chosenPage}`, `alreadyCounted = existingCounted.contains(chosenPage)`; otherwise `colorPages ∪ {chosenPage}`, `alreadyCounted = false`).
    *   In the `else` (page-mode) branch of `onSelect` in `_showBookmarkListSheet`: read `settings = (ref.read(wirdStateProvider).valueOrNull ?? widget.initialState).settings`; call the helper with `settings.linkedBookmarkColor`, `settings.countedBookmarkPages.toSet()`, `color.name`, `bm.page`, and `bookmarks.map((b) => b.page).toSet()` (`bookmarks` is the already color-filtered list the sheet received). If `alreadyCounted`: show a snackbar with `'wird_bookmark_already_counted'.tr()` using the same style as the neighbouring snackbars, and return. Otherwise `await` `setLinkedBookmarkColor(color.name, counted)`, then `await` `recordPagesRead(1, bm.page)`, then `if (!mounted) return;` before the existing "added" snackbar.
    *   Keep the local `pages = {bm.page}`: the juz-mode branch still uses it. Do not change the juz branch or `_showBookmarkPagesSheet`.

#### 2. [`assets/translations/en.json`](../../assets/translations/en.json) and [`assets/translations/ar.json`](../../assets/translations/ar.json) (Modify) — phase 2

*   **Type / Scope**: Translation files.
*   **Proposed Changes**: Added `wird_bookmark_already_counted` after `wird_bookmark_added` in both files (2026-11-11, uncommitted; belongs to the phase 2 commit, so stage the two files by name). English: "This page was already added". Arabic: "تمت إضافة هذه الصفحة بالفعل" (follows the wording of `wird_bookmark_added`). The stored Arabic value in `ar.json` matches the JSON parser check (both files parse; the Arabic value is codepoint-identical to the approved string). The Arabic wording is UNVERIFIED pending native-speaker review.

#### 3. [`lib/features/quran/quran_reader_screen.dart`](../../lib/features/quran/quran_reader_screen.dart) (Modify) — phase 3

*   **Type / Scope**: Flutter widget file, `_TopBar` usage in `build()`.
*   **Proposed Changes**: `onClose` becomes `Navigator.of(context).maybePop()`. Remove the `if (_isDesktop) ... desktopSidebarVisibleProvider ... = true` lines from `onClose` only; the `PopScope` handler already sets the provider in each closing branch and uses `_isDesktop`, so do not remove the field. Do not change the handler or the Esc handler.

#### 4. `test/features/quran/wird_choose_one_test.dart` (Create) — phase 1

*   **Type / Scope**: Dart unit test (Level C). Path matches the existing `test/features/quran/` convention.
*   **Proposed Changes**:
    *   **Helper cases** (color `red`, color pages `{10, 50, 100, 200, 300}` unless stated, chosen page 100):
        1.  Not linked (`null`), existing `{}` → `counted` `{10,50,100,200,300}`, `alreadyCounted` false.
        2.  Linked to `green`, existing `{7,8}` → `counted` `{10,50,100,200,300}`, false.
        3.  Linked to `red`, existing `{10,50}`, color pages `{10,50,100}` → `counted` `{10,50,100}`, false.
        4.  Linked to `red`, existing `{10,50,100}` → `counted` `{10,50,100}`, `alreadyCounted` true.
        5.  Linked to `red`, existing `{10,50}`, color pages `{10,50,100,200}` → `counted` `{10,50,100}`; `colorPages.difference(counted)` is `{200}`.
        6.  Not linked, empty color pages → `counted` `{100}`.
        7.  Stale counted set (known limit; pins Risks (a)/(b); update this expectation when the stale-set path is fixed): linked to `red`, existing `{10,50}` (stale: the stored set already holds 100 and 200), color pages `{10,50,100,200}`, chosen page 200 → `counted` `{10,50,200}`, `alreadyCounted` false. The helper only sees its inputs, so it cannot tell that 200 is already stored; the page would be added again and 100 dropped from the stored set. Known limit; pins Risks (a)/(b); update this expectation when the stale-set path is fixed. The `?? widget.initialState` fallback sits in the widget and has no unit test; it has no device step either, because the provider cannot be non-data while the sheet is open (see Risks, "Tap before the Wird state loads").
    *   **Invariant checks** (plain set difference, the same operation the auto-sync does): after case 1, `colorPages.difference(counted)` is empty; with a new bookmark on page 400 it is `{400}`.
    *   **Negative control (labelled as pinning the old behavior)**: with the old rule `counted = {100}`, `colorPages.difference(counted)` has 4 pages. This uses set difference, not the helper.
    *   **Service-level, best effort** (`TestWidgetsFlutterBinding.ensureInitialized()`, `SharedPreferences.setMockInitialValues({})`, `WirdService.instance`; read progress with `(await WirdService.instance.getFullState()).todayProgress?.pagesRead`; default daily goal is 5):
        1.  Record 1 page, `setLinkedBookmarkColor('red', {10,50,100,200,300})`, `syncBookmarkPages({10,50,100,200,300})` returns 0 and `pagesRead` stays 1; then `syncBookmarkPages` with `{10,50,100,200,300,400}` returns 1 and `pagesRead` is 2.
        2.  Old behavior control: record 1 page, link with `{100}`, sync the five pages → returns 4, `pagesRead` 5 (the day completes; harmless in the test).
    *   **Probe first (UNVERIFIED)**: `updateSettings` calls `cancelAllReminders()` when no reminder times are set, and its path into the notification layer was not checked under test. `_pushToCloud` is the service's Firestore sync for signed-in users; in a unit test it reads `FirebaseAuth.instance`, which is expected to fail without Firebase initialization, and the `.catchError` on that call catches the failure (UNVERIFIED until the probe runs). Run the service-level tests once in phase 1 and record the result in the project log. If they cannot run in a unit test (the repo's `task_streak_test.dart` avoids the singleton for the same reason), drop them and keep the helper, invariant and negative-control tests.

#### 5. [`.project-docs/modules/quran-wird.md`](../../.project-docs/modules/quran-wird.md) (Modify) — phase 4

*   **Type / Scope**: Docs, Level A.
*   **Proposed Changes**: Replace the sentence "The top-bar close button bypasses this (F38a)." with "The top-bar close button calls `Navigator.maybePop()`, so it runs the same handler as back and Esc."

#### 6. [`.project-docs/modules/wird.md`](../../.project-docs/modules/wird.md) (Modify) — phase 4

*   **Type / Scope**: Docs, Level A.
*   **Proposed Changes**: Replace "Page-mode "Choose One" bug: F38c." with: page-mode "Choose One" links the color. On first link or a color change the counted set is every page of that color; when the color is already linked it is the existing counted pages plus the chosen page. It awaits the link before `recordPagesRead`, and does not add an already-counted page twice when no sync is running and the counted set is current.

#### 7. [`lib/features/quran/README.md`](../../lib/features/quran/README.md) (Modify) — phase 4

*   **Type / Scope**: Folder README, Level A.
*   **Proposed Changes**: In the "Reader back" bullet, replace "The top-bar close button calls `Navigator.pop` directly and skips both (F38)." with a sentence that the close button calls `maybePop()` and runs both. In the "Bookmark auto-sync" bullet, replace the sentence about "Choose one" resetting the counted set (ending "(F38)") with the new rule from item 6. These two sentences are the only edits. The other F38 mentions in the README stay because they are about findings this change does not fix: line 29 (`scrollToAyaNo`, F38b), line 64 (stats average unit, F38e) and line 103 (a general pointer to F38 and F39).

#### 8. [`.project-docs/reference/findings.md`](../../.project-docs/reference/findings.md) (Modify) — phase 5

*   **Type / Scope**: Docs, Level A.
*   **Proposed Changes**: Mark F38 (a) and (c) as fixed with the date, only after S45 and S46 pass.

#### 9. [`.project-docs/STATE.md`](../../.project-docs/STATE.md) (Modify) — phase 5

*   **Type / Scope**: Docs, Level A.
*   **Proposed Changes**: Add a "Done" bullet for this group (PR, spec, review report, device result, test and analyze counts) before the "Next (ADR 0001)" bullet, and remove F38a, F38c from the "Fix track (needs spec)" list.

#### 10. [`.project-docs/reference/device-checklist.md`](../../.project-docs/reference/device-checklist.md) (Modify) — rows in phase 4, results in phase 5

*   **Type / Scope**: Docs, Level A. Table columns: `# | Scenario | Steps | Expected (from code) | Filter | Result (base)`.
*   **Proposed Changes**: Add two rows after S43 (S44 is only in the results log; S45 and S46 are unused):
    *   **S45**, "Reader close button runs the khatma prompt (F38a)", Filter `F-APP`. Steps: (1) page mode, today's wird not done: open the reader, jump to page 604, tap the top-bar close button; try "Keep Reading", "Not Yet" and "Yes, I'm Done!" (in separate runs); (2) page 100: tap close → "Close Reader?"; (3) tap close, then try to tap it again at once; (4) system back gives the same dialogs; (5) Windows: sidebar returns after Close and stays hidden after Keep Reading. Expected: base closes at once with no prompt; after fix the dialogs appear, "Yes" records one khatma and shows the celebration, "Not Yet" records none, dialogs do not stack.
    *   **S46**, "Choose One counts exactly one page (F38c)", Filter `F-APP`. Steps: (1) page mode, 4+ bookmarks of one unlinked color (red), Wird → Add from Bookmarks → red → Choose One → pick one; leave and reopen the tab; (2) add one new red bookmark; (3) with red linked and synced, Add from Bookmarks → green (3+ green bookmarks) → Choose One → pick one; (4) with red linked and synced, Add from Bookmarks → red → Choose One → pick a red page that is already counted. Expected: base counts all bookmarks of the color; after fix step 1 adds exactly 1 page and stays at 1, step 2 adds exactly 1, step 3 adds exactly 1 page, green becomes the linked color and its other bookmarks do not add pages, step 4 changes nothing and shows the snackbar "This page was already added" (Arabic UI: "تمت إضافة هذه الصفحة بالفعل"). Not reproducible on device: the already-linked case where other bookmarks of the color are still unsynced; only its set arithmetic is covered, by unit helper case 5 (the progress outcome is untested).
    *   Record results only after the checks run.

#### 11. Daily log in [`.project-docs/log/`](../../.project-docs/log/) (Modify or create) — phase 5

*   **Type / Scope**: Docs, Level A.
*   **Proposed Changes**: Log the work with the `project-log` skill, which appends to the log of the day it runs (`.project-docs/log/YYYY-MM-DD.md`). UNVERIFIED: this rests only on the skill's one-line description in the skill list; the skill file was not read. The work started on 2026-11-11, but the entry is dated by when it is written, so the file may be a later day's and may not exist yet (`2026-11-12.md` does not exist at the time of this edit). The `2026-11-11.md` log has no F38 entry.

### Verification Plan

*   **Baseline**: before the first edit, `flutter test` and `flutter analyze` on the current HEAD; record both counts.
*   **Unit Tests**: `flutter test test/features/quran/wird_choose_one_test.dart`, then `flutter test`. Expected: baseline plus the tests added (seven helper, two invariant checks, one negative control, up to two service-level).
*   **Static Analysis & Linting**: `flutter analyze`: no issues beyond the recorded baseline (compare counts). `dart format --output=none --set-exit-if-changed` on the three touched `.dart` files only (`wird_tab.dart`, `quran_reader_screen.dart`, the new test); if a file was unformatted before the edit, do not reformat it, and say so in the log.
*   **Coverage**: The helper and its branches are covered by unit tests. There is no automated coverage for the close button or for the `onSelect` wiring; F38a and F38c are not marked fixed until S45 and S46 pass. This stays UNVERIFIED until they run.
*   **E2E/Integration (device)**: S45 and S46 above, on the nova 5T. Not yet run.
*   **Review**: Small fix, no "edit carefully" files, no native contracts: one lightweight EGM review (done: `.project-docs/reference/reviews/quran-khatma-wird/`).

--------------------------------------------------------------------------------

*Drafted with EGM*
