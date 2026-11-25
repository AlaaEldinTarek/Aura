# Fix F34c — Resume untracked-prayer check silently skips

*   **Author:** Alaa Eldin Tarek
*   **Status:** Review
*   **Date:** 2026-11-25

---

## Overview

When the Aura app returns to the foreground, `MainWrapperScreen` runs
`_checkUntrackedPrayers()` to find prayers the user has not yet tracked and
prompt them to record those prayers. The check never fires because prayer-time
data is cleared by `ref.invalidate(prayerTimesProvider)` before the async
function reads it.

## The Problem

`didChangeAppLifecycleState` in `main_wrapper_screen.dart` calls
`_checkUntrackedPrayers()` without `await` (line 108), then immediately calls
`ref.invalidate(prayerTimesProvider)` (line 114). Inside
`_checkUntrackedPrayers()`, the first `await` suspends execution so the prefs
read can resolve (line 607: `await prefs.isPrayerTrackingEnabled()`). By the
time the function resumes and reaches `ref.read(prayerTimesProvider)` (line
615), the provider has already been invalidated — its state is empty.
`prayerState.prayerTimes.isEmpty` is then `true`, the function returns early,
and the user never sees the untracked-prayer bottom sheet.

The comment on line 107 reads "Check untracked prayers BEFORE invalidating
provider (would clear prayer times)". The comment records the ordering
constraint; the implementation does not enforce it across a Dart `async`
suspension boundary.

## Goals

*   The untracked-prayer bottom sheet appears on every resume where at least one
    past prayer is untracked, regardless of timing between the check and the
    provider invalidation.
*   Prayer times used for the check are consistent with what the user saw on
    screen before they left the app (the pre-invalidation snapshot).
*   No change to the prompt UI, Firestore calls, or tracking flow.

## Non-Goals

*   Changing when `ref.invalidate(prayerTimesProvider)` runs or the relative
    order of resume effects that follow it (task reload, widget intent, prayer
    status sync). Note: the fix moves `_checkUntrackedPrayers()` from before
    the Fajr snapshot reads to after them.
*   Fixing any other condition under which `_checkUntrackedPrayers()` might
    exit early (e.g., no signed-in user, tracking disabled).
*   Modifying the bottom sheet or the prayer tracking dialog.
*   Applying the codebase-wide 20-minute `isPrayerTimeReached` threshold to
    the untracked-prayer filter — the function uses raw adhan time
    (`time.isBefore(now)`); whether the threshold should also apply is a
    separate product decision.
*   Handling the after-midnight background case: if
    `_startNextPrayerUpdateTimer` has already advanced `prayerTimesProvider`
    to the next calendar day before `didChangeAppLifecycleState(resumed)`
    fires, `resumePrayerTimes` holds tomorrow's prayers (all in the future),
    `pastPrayers` is empty, and no sheet appears. This is accepted: no prayers
    from the new day have passed yet.

---

## Critical User Journeys (CUJs)

### CUJ 1: Resume with untracked past prayers

*   **Given**: The user is signed in, prayer tracking is enabled, and at least
    one prayer whose adhan time has passed today has no tracking record.
*   **When**: The user switches away from Aura and then returns (any background
    duration).
*   **Then**: The untracked-prayer bottom sheet appears listing those prayers.
    The sheet is not affected by the provider invalidation that immediately
    follows.

### CUJ 2: Resume with all past prayers tracked

*   **Given**: The user is signed in, prayer tracking is enabled, and every
    past prayer today has a tracking record.
*   **When**: The user resumes the app.
*   **Then**: No bottom sheet appears. The function exits early at the
    `untracked.isEmpty` guard, same as before.

### CUJ 3: Resume before Fajr adhan time

*   **Given**: The user resumes the app before today's Fajr adhan time.
*   **When**: The user resumes the app.
*   **Then**: `pastPrayers` is empty (no prayer's `time.isBefore(now)` is true
    yet); no bottom sheet appears.

### CUJ 4: Resume when prayer tracking is disabled

*   **Given**: Prayer tracking is turned off in settings.
*   **When**: The user resumes the app.
*   **Then**: The function exits at the `!enabled` guard. No sheet appears, no
    Firestore call is made.

---

## Technical Plan

The async suspension gap is the only failure point. The fix closes it by
capturing the prayer-times list synchronously — before any `await` and before
the invalidate — and passing it into `_checkUntrackedPrayers()`.

### Why a snapshot parameter, not an early synchronous read inside the function

Moving `ref.read(prayerTimesProvider)` to the first line of
`_checkUntrackedPrayers()` (before the first `await`) would work for the same
reason but is fragile: nothing in the function signature records the constraint that
the read must precede any `await`. A parameter makes the dependency explicit
and verifiable at the call site.

### Call-site change

In `didChangeAppLifecycleState`, the existing `resumePrayerTimes` variable
(lines 110–111) already reads `prayerTimesProvider` before the invalidate and
is used to extract `resumeFajrTime`. We pass that same list directly to
`_checkUntrackedPrayers()`. No second provider read is needed.

```
didChangeAppLifecycleState (resumed branch):
  1. Snapshot prayer times → resumePrayerTimes  (already line 110)
  2. Extract resumeFajrTime from snapshot       (already line 112)
  3. _checkUntrackedPrayers(resumePrayerTimes)  ← pass snapshot (move call to here)
  4. ref.invalidate(prayerTimesProvider)        (unchanged line 114)
  ... rest unchanged
```

The `_checkUntrackedPrayers()` call moves from line 108 (before the snapshot)
to after the snapshot capture but still before the invalidate.

The `initState` cold-start path (line 217) calls this function as a
no-argument tearoff. Because the parameter is required, that tearoff is
replaced with a lambda so the function signature stays required at all call
sites:

    Future.delayed(const Duration(seconds: 3),
        () => _checkUntrackedPrayers(
            ref.read(prayerTimesProvider)?.prayerTimes ?? []));

On cold start there is no prior `ref.invalidate`, so this read returns the
freshly loaded times. The required parameter keeps the race-free invariant
visible at both call sites — a future editor who adds a third call site gets
a compile error until they explicitly pass prayer times.

### Function signature change

`_checkUntrackedPrayers` gains a `List<PrayerTime> prayerTimes` parameter.
The existing `ref.read(prayerTimesProvider)` read and the
`prayerState.prayerTimes.isEmpty` guard inside the function are removed; the
passed list replaces them.

```
_checkUntrackedPrayers(List<PrayerTime> prayerTimes):
  guard: _untrackedCheckInProgress
  guard: prayerTimes.isEmpty           ← replaces the provider read
  guard: await prefs.isPrayerTrackingEnabled()
  guard: userId null/empty
  now = DateTime.now()
  today = date-only
  pastPrayers = prayerTimes where name != Sunrise && time < now
  guard: pastPrayers.isEmpty
  tracked = await Firestore getPrayersForDate(userId, today)
  untracked = pastPrayers where name not in tracked
  guard: untracked.isEmpty
  _showUntrackedPrayersSheet(untracked)
```

`_untrackedCheckInProgress` is a boolean field on `_MainWrapperScreenState`
set `true` for the duration of a check; it blocks concurrent re-entrant calls
(e.g. rapid double-resume). `_showUntrackedPrayersSheet` is a private method
on `_MainWrapperScreenState`, unchanged by this fix.

The `prayerTimes.isEmpty` guard is placed before the first `await` so we skip
the prefs and Firestore calls when there is nothing to check.

---

## Alternatives Considered

### Alternative A: Await `_checkUntrackedPrayers()` before invalidating

Call `await _checkUntrackedPrayers()` before `ref.invalidate(prayerTimesProvider)`.

*   **Pros**: No signature change; function stays self-contained.
*   **Cons**: The function makes a Firestore call (`getPrayersForDate`). Awaiting
    it blocks the entire resume side-effect sequence — provider invalidation,
    Fajr snapshot for after-midnight detection, task reload, widget intent
    handling — until Firestore responds. Rejected by author: introduces a
    latency dependency on network I/O into a synchronous lifecycle callback.

### Alternative B: Read provider inside function before first await

Move `ref.read(prayerTimesProvider)` to the first executable line of
`_checkUntrackedPrayers()`, before `await prefs.isPrayerTrackingEnabled()`.
This captures the state before the Dart event loop yields.

*   **Pros**: Call site stays unchanged; one-line move inside the function.
*   **Cons**: The constraint "read before yielding" is invisible at the call
    site. A future edit that adds an earlier `await` (e.g., for a permission
    check) would silently reintroduce the bug. Rejected by author: the
    snapshot-parameter approach makes the dependency explicit in the function
    signature and prevents this regression at compile time.

---

## Non-Functional Requirements

No schema changes, no new I/O paths, no new persistent state.

Two edge cases are accepted as out-of-scope:

*   **Cold-start (provider not yet populated)**: If `prayerTimesProvider` has
    not populated before `didChangeAppLifecycleState(resumed)` fires (e.g., the
    app was killed and relaunched), `resumePrayerTimes` is `[]`, the
    `prayerTimes.isEmpty` guard exits early, and the check is silently skipped.
    This is correct behaviour — no past prayers are known yet.
*   **Rapid double-resume (OEM activity transitions)**: A second lifecycle
    `resumed` event that fires while the first check's Firestore call is still
    in flight is blocked by the `_untrackedCheckInProgress` re-entrancy guard
    already in the function.

---

## Additional Resources

*   `.project-docs/modules/prayer-tracking.md` — `_syncThenLoadPrayerStatus`
    and after-midnight rule; note on "read Fajr BEFORE invalidate"
*   `.project-docs/modules/prayer.md` — `PrayerTimesNotifier` invalidation
    behaviour on resume
*   `lib/features/main/main_wrapper_screen.dart` lines 104–127 (call site) and
    600–644 (function body)

---

## Detailed Implementation Plan

### Target Files to Create / Modify

#### 1. `lib/features/main/main_wrapper_screen.dart` (Modify)

*   **Type / Scope**: Flutter widget — app lifecycle handler and resume
    side-effects.

*   **Proposed changes**:

    **Call site — `didChangeAppLifecycleState`, resumed branch (lines 106–121)**

    Move the `_checkUntrackedPrayers()` call (line 108) to immediately after
    `resumePrayerTimes` is assigned (line 110) and pass it as an argument. See
    Technical Plan § Call-site change for the full ordering pseudocode. The call
    must stay before `ref.invalidate(prayerTimesProvider)` (line 114).

    **Cold-start call site — `initState` (line 217)**

    Replace the bare tearoff with a lambda:

        () => _checkUntrackedPrayers(ref.read(prayerTimesProvider)?.prayerTimes ?? [])

    On cold start there is no prior `ref.invalidate`, so the read returns freshly
    loaded times.

    **Function signature — `_checkUntrackedPrayers` (line 602)**

    Change to `_checkUntrackedPrayers(List<PrayerTime> prayerTimes)`.

    **Function body — remove provider read (lines 615–616)**

    Remove lines 615–616:
    - `final prayerState = ref.read(prayerTimesProvider);`
    - `if (prayerState.prayerTimes.isEmpty) return;`

    Replace the `pastPrayers` computation at line 619: change
    `prayerState.prayerTimes` to `prayerTimes`.

    Add `if (prayerTimes.isEmpty) return;` as the **first statement inside the
    `try` block** (before `final prefs = ...`). Placing it inside `try` ensures
    the `finally` block always resets `_untrackedCheckInProgress`; placing it
    before `try` would leave the flag permanently set on an early return.

    No other changes to the function body.

#### 2. `test/features/main/f34c_source_test.dart` (Create)

*   **Type / Scope**: Flutter unit/widget test — verifies the fix in isolation.

*   **Proposed changes** (test cases):

    **T1 — snapshot used, bottom sheet fires when untracked prayers exist**

    Construct a `MainWrapperScreen` under test following the pattern in
    `test/features/main/f34a_source_test.dart`. Mock `prayerTimesProvider` to
    return empty after invalidation. Trigger the check via
    `tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed)`
    with one past untracked prayer in the pre-invalidation snapshot. Verify that
    the untracked-prayers bottom sheet widget appears in the widget tree.

    **T2 — empty snapshot exits before Firestore call**

    Trigger resume with an empty prayer-times snapshot. Confirm that
    `PrayerTrackingService.getPrayersForDate` is never called.

*   **Verification**:
    *   `flutter test test/features/main/f34c_source_test.dart` must pass.

### Verification Plan

*   **Static analysis**: `flutter analyze` — must report 0 errors; warning
    count must not increase from the pre-fix baseline.
*   **Format**: `dart format --output=none --set-exit-if-changed lib/features/main/main_wrapper_screen.dart`
    — must exit 0.
*   **Unit tests**: `flutter test` — all existing tests plus T1 and T2 must
    pass.
*   **Device check (manual)**:
    *   S-F34c-1: Signed in, tracking enabled, at least one past prayer today
        untracked. Background and resume. Confirm the untracked-prayer sheet
        appears.
    *   S-F34c-2: All past prayers tracked. Background and resume. Confirm no
        sheet.

---

*Drafted with EGM*
