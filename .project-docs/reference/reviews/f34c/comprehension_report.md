# Stage 6 — Comprehension Test Report
**Target**: `docs/designs/fix-f34c.md`
**Date**: 2026-11-25
**Reviewer**: egm-comprehension

---

## Feature Spec Paraphrase

The Aura app has a feature that, whenever the app returns to the foreground, runs
`_checkUntrackedPrayers()` to find prayers the user has not yet logged and show them a
bottom-sheet prompt. This feature is completely non-functional because of an async
scheduling bug: the caller fires the function without `await`, then immediately runs
`ref.invalidate(prayerTimesProvider)` on the next synchronous line. That invalidation
executes before the function reaches its first `await` (a prefs read), so by the time
the function resumes and tries to read prayer-time data from the provider, the provider's
state is already empty. The function hits an `isEmpty` guard and exits, and the bottom
sheet never appears. The developer had commented in the source that the check must happen
before the invalidation, so the intent was correct; the implementation failed because an
unawaited async function yields control at its first `await` and the caller does not wait
for it.

The fix goal is to make the bottom sheet appear reliably on every resume where at least
one past prayer is untracked, by using a synchronous pre-invalidation snapshot of prayer
times rather than reading from the provider inside the async function. The UI, Firestore
calls, and tracking flow are explicitly left unchanged.

## Implementation Plan Paraphrase

One existing file is changed and one new test file is created. In
`main_wrapper_screen.dart`, the `_checkUntrackedPrayers()` call in the lifecycle handler
is repositioned: it currently fires before the snapshot variable `resumePrayerTimes` is
assigned, so it now moves to just after that assignment (still before the invalidation).
The call passes `resumePrayerTimes` as an argument; no second provider read is needed.

The function signature gains a `List<PrayerTime> prayerTimes` parameter. Inside the
function, the `ref.read(prayerTimesProvider)` call and its associated `isEmpty` guard are
removed and replaced by a guard on the passed parameter, placed before the first `await`.
The `pastPrayers` computation switches from `prayerState.prayerTimes` to the parameter.

The new test file covers two cases: T1 passes a non-empty list while the provider
returns empty after invalidation, verifying the Firestore call and bottom-sheet display
are reached; T2 passes an empty list and verifies no Firestore call is made.

---

## Findings

### 🟡 C1 — Major: `_untrackedCheckInProgress` undefined in the document

**Scope**: Technical Plan pseudocode — first guard in `_checkUntrackedPrayers` body

`_untrackedCheckInProgress` appears as the first guard in the pseudocode but is never
described. A fresh reader cannot determine whether it is a field, a lock, or a flag set
externally, and cannot judge whether the fix interacts with it safely. A one-line
description ("boolean field on `_MainWrapperScreenState`; set true while a check is
in progress to prevent concurrent re-entrant calls") would close the gap.

### 🟡 C2 — Major: T1 test strategy left ambiguous — lifecycle event vs. test-only hook

**Scope**: Detailed Implementation Plan — test file T1 implementation note

The note says tests should use "the lifecycle event (`didChangeAppLifecycleState(resumed)`)
or by exposing a test-only hook." These paths differ substantially: the lifecycle path
exercises the call-site reordering (a core part of the fix), while a hook tests only the
function in isolation without verifying the snapshot is passed correctly. The ambiguity
leaves the implementer free to choose the weaker path. The spec must commit to one
approach.

### 🟡 C3 — Major: T1 Firestore mock return value unspecified

**Scope**: Detailed Implementation Plan — T1 test case success criterion

T1 states the criterion is that `getPrayersForDate` is called and
`_showUntrackedPrayersSheet` is reached. For the sheet to be reached, the Firestore mock
must return a result that leaves at least one prayer in the untracked list (e.g., an
empty tracked set). Without specifying what the mock returns, a developer could write a
test that calls `getPrayersForDate` but whose mock returns all prayers as tracked,
satisfying only part of the criterion.

### 🟡 C4 — Major: CUJ 3 references `isPrayerTimeReached` without defining it
*(overlaps with zoom-out F2 — confirms the same gap)*

**Scope**: CUJ 3 — Resume before any prayer has passed

CUJ 3 cites "the 20-min `isPrayerTimeReached` threshold" without defining it inline or
linking its definition. Combined with zoom-out finding F2 (the function uses
`time.isBefore(now)`, not `isPrayerTimeReached`), this is both an undefined term and a
misdescribed behaviour.

### 🟢 C5 — Nit: `_showUntrackedPrayersSheet` never described

**Scope**: Technical Plan pseudocode; T1 test case

It is listed as the final step and referenced in T1 but never described. A one-line note
("private method on `_MainWrapperScreenState`; unchanged by this fix") would let a
reader confirm the fix boundary.

### 🟢 C6 — Nit: `PrayerTrackingService` introduced without context

**Scope**: Detailed Implementation Plan — T1 test case

`PrayerTrackingService.getPrayersForDate` appears for the first time in the test section
with no prior mention. A brief description or link would let the test author locate it
without external lookup.

### 🟢 C7 — Nit: `ref.read(...)` ellided in call-site pseudocode

**Scope**: Technical Plan § Call-site change; Detailed Implementation Plan code blocks

Both sections write `ref.read(...)?.prayerTimes` without naming the provider. A reader
verifying the plan against the source cannot confirm from the document alone that the
same `prayerTimesProvider` read is reused. The full form `ref.read(prayerTimesProvider)?.prayerTimes` resolves this.
