# Fix F34f — Untracked-prayers sheet can open twice

*   **Author:** Alaa Eldin Tarek
*   **Status:** Draft (not approved; Level C code needs "approve phase P1")
*   **Date:** 2026-11-28

---

## Overview

`MainWrapperScreen` shows an "Untracked Prayers" bottom sheet listing past
prayers with no tracking record. Two triggers call `_checkUntrackedPrayers()`:
a 3 s delayed cold-start call and the `resumed` lifecycle branch. Nothing
prevents a second trigger from opening a second sheet while the first is still
open.

## The Problem

`_untrackedCheckInProgress` (`main_wrapper_screen.dart:610`) is set at the start
of `_checkUntrackedPrayers()` and reset in its `finally`. The function ends by
calling `_showUntrackedPrayersSheet(untracked)` (line 649), which calls
`showModalBottomSheet` without awaiting it. The function therefore returns, and
the flag resets, as soon as the sheet is *requested*, not when it is *closed*.
The guard covers the async check, not the sheet's lifetime.

Observed on 2026-11-28 (Windows release build, signed-in account, Zuhr
untracked): the window was restored about 3 s after launch, so the cold-start
check and a `resumed` event both ran and two sheets stacked (two drag handles,
the backdrop click closed one, one remained). VERIFIED by screenshots and by
reading the code; not yet reproduced a second time under a debugger.

Other ways to hit it (UNVERIFIED, same code path):

*   Desktop: `resumed` fires on every window focus gain, so alt-tabbing away and
    back while the sheet is open stacks another sheet.
*   Android: resuming while the sheet is still open (it survives backgrounding).

Second effect: each sheet holds its own copy of the list (`remaining`, line
663). Handling Zuhr in one sheet does not remove it from the other, so the same
prayer can be offered, and recorded, twice. UNVERIFIED (not exercised).

## Goals

*   At most one untracked-prayers sheet is open at any time.
*   A check that runs while the sheet is open does nothing (no Firestore call,
    no second sheet).
*   After the sheet closes (any way: Later, backdrop, all handled), the next
    trigger can open it again as today.

## Non-Goals

*   Changing the sheet's contents, buttons, wording, or the recording call
    (`_recordPrayerStatusFromNotification`).
*   Refreshing an open sheet's rows when the check runs again. A later check
    after close picks up the current state.
*   Moving the sheet's inline `isArabic ? … : …` strings to `.tr()` keys (an
    existing violation of the strings rule; separate cleanup).
*   Changing the cold-start delay or the F34c snapshot logic.

---

## Critical User Journeys (CUJs)

### CUJ 1: Cold start, window shown within 3 s

*   **Given**: Signed in, tracking enabled, one past prayer untracked.
*   **When**: The app starts and the window gains focus (a `resumed` check runs)
    before the 3 s cold-start check.
*   **Then**: Exactly one sheet is open after both checks.

### CUJ 2: Refocus while the sheet is open (desktop)

*   **Given**: The sheet is open.
*   **When**: The user alt-tabs away and back.
*   **Then**: Still one sheet; no extra Firestore read.

### CUJ 3: Dismiss and return

*   **Given**: The sheet was dismissed with Later or the backdrop; the prayer is
    still untracked.
*   **When**: The app is backgrounded and resumed.
*   **Then**: The sheet opens again (unchanged behavior).

---

## Technical Plan

Add a boolean field `_untrackedSheetOpen` to `_MainWrapperScreenState`.

*   In `_checkUntrackedPrayers`, add `if (_untrackedSheetOpen) return;` next to
    the existing `_untrackedCheckInProgress` guard. It goes **before** the flag
    `_untrackedCheckInProgress = true` is set, so the early return does not need
    the `finally` reset (same pattern as the existing guard).
*   In `_showUntrackedPrayersSheet`, set `_untrackedSheetOpen = true` before
    `showModalBottomSheet` and attach `.whenComplete(() { _untrackedSheetOpen =
    false; })` to the returned future. No `setState`: the flag is not read by
    `build`.
*   The entry guard alone is not enough: two checks can both pass it while the
    flag is still false (both are awaiting prefs or Firestore), then both reach
    the show call. So also re-check `_untrackedSheetOpen` right before calling
    `_showUntrackedPrayersSheet`, after the `mounted` check. There is no `await`
    between that re-check and the line that sets the flag, so only one check can
    get through.

```
_checkUntrackedPrayers(prayerTimes):
  guard: _untrackedCheckInProgress
  guard: _untrackedSheetOpen                 ← new (entry)
  ...existing guards and Firestore read...
  guard: !mounted
  guard: _untrackedSheetOpen                 ← new (after awaits, before show)
  _showUntrackedPrayersSheet(untracked)

_showUntrackedPrayersSheet(untracked):
  _untrackedSheetOpen = true
  showModalBottomSheet(...).whenComplete(() => _untrackedSheetOpen = false)
```

Reset on `dispose`: not needed; the field dies with the state, and
`whenComplete` runs when the route is removed.

## Alternatives Considered

### Alternative A: Make the check await the sheet

`await showModalBottomSheet(...)` keeps `_untrackedCheckInProgress` true while
the sheet is open, reusing the existing flag.

*   **Pros**: No new field.
*   **Cons**: Holds the "check in progress" flag for as long as the user leaves
    the sheet open (minutes), and the `finally` then runs after a long gap; it
    mixes "checking" and "showing" state. Rejected: a separate flag keeps each
    meaning clear.

### Alternative B: Dismiss the old sheet and open a fresh one

On a second trigger, pop the open sheet and show a new one.

*   **Pros**: The list is always fresh.
*   **Cons**: The sheet flickers on every refocus and can interrupt a user
    mid-tap. Rejected for a desktop app where focus changes often.

---

## Non-Functional Requirements

No schema, prefs, channel, notification-ID, or Firestore changes. No new I/O.
This is a Level C change in `lib/features/main/`; it does not touch any
"edit carefully" file. Behavior-preserving except that a duplicate sheet no
longer opens.

---

## Additional Resources

*   `docs/designs/fix-f34c.md` — resume snapshot and the existing
    `_untrackedCheckInProgress` guard.
*   `.project-docs/modules/prayer-tracking.md`
*   `lib/features/main/main_wrapper_screen.dart` lines 104–128 (resume), 207–242
    (cold start), 610–788 (check and sheet).

---

## Detailed Implementation Plan

### Target Files to Create / Modify

#### 1. `lib/features/main/main_wrapper_screen.dart` (Modify)

*   Add `bool _untrackedSheetOpen = false;` next to `_untrackedCheckInProgress`
    (line 610).
*   `_checkUntrackedPrayers`: add the entry guard and the pre-show guard as in
    the Technical Plan.
*   `_showUntrackedPrayersSheet`: set the flag before `showModalBottomSheet`; add
    `.whenComplete` to clear it. No other change to the sheet body.

#### 2. `test/features/main/f34f_source_test.dart` (Create)

Source-text tests in the style of `f34c_source_test.dart`:

*   **T1**: the file declares `_untrackedSheetOpen`.
*   **T2**: `_checkUntrackedPrayers` contains the entry guard and a second guard
    after the `mounted` check and before `_showUntrackedPrayersSheet(`.
*   **T3**: `_showUntrackedPrayersSheet` sets the flag to `true` before
    `showModalBottomSheet` and clears it in `.whenComplete`.

### Verification Plan

*   `flutter analyze`: 0 errors; issue count not above the current baseline.
*   `dart format --output=none --set-exit-if-changed` on the two files.
*   `flutter test`: all existing tests plus T1–T3.
*   Device / desktop checks (manual, owner-observed):
    *   S-F34f-1 (Windows): start the app with a past prayer untracked and show
        the window within 3 s. One sheet, not two.
    *   S-F34f-2 (Windows): with the sheet open, alt-tab away and back. Still one
        sheet.
    *   S-F34f-3: dismiss with Later, background and resume. The sheet opens
        again.

---

*Drafted by Claude Code; not yet reviewed with EGM*
