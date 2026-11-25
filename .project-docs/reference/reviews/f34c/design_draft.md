# Fix F34c — Resume untracked-prayer check silently skips

*   **Author:** Alaa Eldin Tarek
*   **Status:** Draft
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
provider (would clear prayer times)", which shows the developer understood the
constraint. The intent was correct; the implementation did not account for the
Dart `async` suspension boundary.

## Goals

*   The untracked-prayer bottom sheet appears on every resume where at least one
    past prayer is untracked, regardless of timing between the check and the
    provider invalidation.
*   Prayer times used for the check are consistent with what the user saw on
    screen before they left the app (the pre-invalidation snapshot).
*   No change to the prompt UI, Firestore calls, or tracking flow.

## Non-Goals

*   Changing when `ref.invalidate(prayerTimesProvider)` runs or the order of
    other resume side effects (Fajr snapshot, task reload, widget intent).
*   Fixing any other condition under which `_checkUntrackedPrayers()` might
    exit early (e.g., no signed-in user, tracking disabled).
*   Modifying the bottom sheet or the prayer tracking dialog.

---

## Open Questions

*   None — the cause is confirmed and the fix approach is clear.

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

### CUJ 3: Resume before any prayer has passed

*   **Given**: The user resumes the app before Fajr time (or at Fajr + < 1 min,
    before the 20-min `isPrayerTimeReached` threshold).
*   **When**: The user resumes the app.
*   **Then**: `pastPrayers` is empty; no bottom sheet appears.

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
reason but is fragile: nothing in the function signature signals that the read
must precede any `await`, and a future editor would not see the constraint. A
parameter makes the dependency explicit and verifiable at the call site.

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
    handling — until Firestore responds. On a slow connection this delay is
    visible. Rejected by author: introduces a latency dependency on network I/O
    into a synchronous lifecycle callback.

### Alternative B: Read provider inside function before first await

Move `ref.read(prayerTimesProvider)` to the first executable line of
`_checkUntrackedPrayers()`, before `await prefs.isPrayerTrackingEnabled()`.
This captures the state before the Dart event loop yields.

*   **Pros**: Call site stays unchanged; one-line move inside the function.
*   **Cons**: The constraint "read before yielding" is invisible at the call
    site. A future edit that adds an earlier `await` (e.g., for a permission
    check) would silently reintroduce the bug. Rejected by author: fragile; the
    snapshot-parameter approach makes the dependency explicit and
    reviewable.

---

## Non-Functional Requirements

None. This is a one-file, two-method change with no new I/O, no schema changes,
and no new state.

---

### Additional Resources

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

    Move the `_checkUntrackedPrayers()` call from its current position (before
    the snapshot) to immediately after `resumePrayerTimes` is assigned, and
    pass `resumePrayerTimes` as an argument:

    ```
    // Current order (broken):
    _checkUntrackedPrayers();                        // line 108, fires async
    final resumePrayerTimes = ref.read(...)?.prayerTimes ?? [];  // line 110
    final resumeFajrTime = ...;                      // line 112
    ref.invalidate(prayerTimesProvider);             // line 114  ← clears state

    // Fixed order:
    final resumePrayerTimes = ref.read(...)?.prayerTimes ?? [];  // unchanged
    final resumeFajrTime = ...;                      // unchanged
    _checkUntrackedPrayers(resumePrayerTimes);       // pass snapshot
    ref.invalidate(prayerTimesProvider);             // unchanged
    ```

    **Function signature — `_checkUntrackedPrayers` (line 602)**

    Change:
    ```
    Future<void> _checkUntrackedPrayers() async {
    ```
    To:
    ```
    Future<void> _checkUntrackedPrayers(List<PrayerTime> prayerTimes) async {
    ```

    **Function body — remove provider read (lines 613–616)**

    Remove:
    ```
    final prayerState = ref.read(prayerTimesProvider);
    if (prayerState.prayerTimes.isEmpty) return;
    ```

    Replace the `pastPrayers` computation (line 619) to use the parameter
    instead of `prayerState.prayerTimes`:
    ```
    // Before (broken):
    final pastPrayers = prayerState.prayerTimes
        .where((p) => p.name != 'Sunrise' && p.time.isBefore(now))
        .toList();

    // After:
    final pastPrayers = prayerTimes
        .where((p) => p.name != 'Sunrise' && p.time.isBefore(now))
        .toList();
    ```

    Add an early guard before the first `await` (after the
    `_untrackedCheckInProgress` guard):
    ```
    if (prayerTimes.isEmpty) return;
    ```

    No other changes to the function body.

#### 2. `test/features/main/f34c_source_test.dart` (Create)

*   **Type / Scope**: Flutter unit/widget test — verifies the fix in isolation.

*   **Proposed changes** (test cases):

    **T1 — snapshot used, bottom sheet fires when untracked prayers exist**

    Set up a mock/fake `prayerTimesProvider` that returns empty after
    invalidation (simulating the broken state). Pass a non-empty
    `List<PrayerTime>` with one past prayer directly to
    `_checkUntrackedPrayers()`. Confirm that
    `PrayerTrackingService.getPrayersForDate` is called and
    `_showUntrackedPrayersSheet` is reached (or the sheet widget appears).

    *Implementation note*: The existing tests in
    `test/features/main/f34a_source_test.dart` show how `MainWrapperScreen` is
    constructed under test; follow the same pattern. Because
    `_checkUntrackedPrayers` is `private`, test it via the lifecycle event
    (`didChangeAppLifecycleState(resumed)`) or by exposing a test-only hook if
    the widget test infrastructure does not support direct private calls.

    **T2 — empty snapshot exits before Firestore call**

    Call `_checkUntrackedPrayers([])` (or trigger resume with empty prayer
    times). Confirm that `getPrayersForDate` is never called.

*   **Verification**:
    *   `flutter test test/features/main/f34c_source_test.dart` must pass.
    *   Test count in the suite increases by exactly the number of T1/T2 cases
        added.

### Verification Plan

*   **Static analysis**: `flutter analyze` — must report 0 errors; warnings must
    not increase vs. the current baseline of 407 issues.
*   **Format**: `dart format --output=none --set-exit-if-changed lib/features/main/main_wrapper_screen.dart`
    — must exit 0.
*   **Unit tests**: `flutter test` — all existing tests plus T1 and T2 must
    pass. Current baseline: 890 Dart pass.
*   **Device check (manual)**:
    *   S-F34c-1: Signed in, tracking enabled, at least one past prayer today
        untracked. Background and resume. Confirm the untracked-prayer sheet
        appears.
    *   S-F34c-2: All past prayers tracked. Background and resume. Confirm no
        sheet.

---

*Drafted with EGM*
