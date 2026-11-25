# Stage 5 — Zoom-Out Review Report
**Target**: `docs/designs/fix-f34c.md`
**Date**: 2026-11-25
**Reviewers**: egm-zoom-out, egm-inventive-catalyst

---

## Findings

### 🔴 F1 — Blocker: Second call site not covered (both reviewers, VERIFIED in code)

**Scope**: Technical Plan § Call-site change; Detailed Implementation Plan § Target Files

`_checkUntrackedPrayers()` has two call sites, not one. The design only addresses the
`didChangeAppLifecycleState` resume path. The second call site is in `initState` at
line 217:

```dart
Future.delayed(const Duration(seconds: 3), _checkUntrackedPrayers);
```

Adding a required positional parameter (`List<PrayerTime> prayerTimes`) makes this
no-argument tearoff fail to compile. The design as written is not implementable without
resolving this call site.

**Resolution options raised:**
- **Option A** — Make `prayerTimes` optional with a fallback `ref.read(prayerTimesProvider)?.prayerTimes ?? []` that is reached synchronously (before any `await`) only on the cold-start path. The resume call site passes the explicit snapshot; the cold-start tearoff compiles unchanged. Risk: a future editor could omit the argument on the resume path and silently re-enable the race without any compile-time signal. Clear documentation at both call sites is required to prevent this.
- **Option B** — Replace the tearoff with a lambda that reads and passes the snapshot: `Future.delayed(const Duration(seconds: 3), () => _checkUntrackedPrayers(ref.read(prayerTimesProvider)?.prayerTimes ?? []))`. On cold start there is no prior invalidate, so this read returns the freshly loaded times. The parameter stays required, keeping the race-free invariant visible in the signature. No fallback inside the function.

The author must choose which option to adopt before the spec can be approved.

---

### 🟡 F2 — Major: CUJ 3 references a guard that does not exist in the function (inventive-catalyst, VERIFIED in code)

**Scope**: CUJ 3 § Resume before any prayer has passed; implicitly Technical Plan pseudocode

CUJ 3 states the no-sheet outcome at "Fajr + < 1 min" is due to "the 20-min
`isPrayerTimeReached` threshold." The actual filter in `_checkUntrackedPrayers` (lines
619–621 of `main_wrapper_screen.dart`) is:

```dart
prayerState.prayerTimes.where((p) => p.name != 'Sunrise' && p.time.isBefore(now))
```

There is no `isPrayerTimeReached` call. The 20-minute rule does not apply here. A prayer
1 minute after its adhan time would trigger the sheet, not suppress it. The spec
misdescribes the trigger condition and would lead to a test written against the wrong
boundary.

The spec must either: (a) note that the check intentionally uses raw adhan time, or
(b) add `isPrayerTimeReached` to the filter (a product decision — the sheet would then
never fire within the first 20 minutes after adhan, which may hide an in-progress prayer).

---

### 🟡 F3 — Major: Unstated assumption in Goal 2 and Technical Plan — after-midnight background refresh (inventive-catalyst)

**Scope**: Goals § Goal 2; Technical Plan § Why a snapshot parameter

Goal 2 states: "Prayer times used for the check are consistent with what the user saw
on screen before they left the app." This holds only if the provider has not been
refreshed to the next calendar day before resume fires.

`prayer.md` § Next-prayer logic documents that `_startNextPrayerUpdateTimer` calls
`loadPrayerTimes(now)` after Isha passes into the new day, and repeats every minute
(finding F52d). On desktop and some Android configurations where background timers
execute, the provider can advance to the next day's prayer list before
`didChangeAppLifecycleState(resumed)` fires. In that case `resumePrayerTimes` holds
tomorrow's future prayers, `pastPrayers` is empty, and the sheet silently does not
appear — which contradicts Goal 2 without any diagnostic signal.

The spec must acknowledge this scenario, either as a known gap in the Non-Goals or as
an explicit CUJ edge case.

---

### 🟡 F4 — Major: Altitude drop in Detailed Implementation Plan (zoom-out)

**Scope**: Detailed Implementation Plan § Proposed changes (lines 207–273)

The section reproduces literal before/after code blocks with exact variable names,
line-by-line function body pseudocode, and function signature diffs. The Technical Plan
section (lines 95–153) already describes the fix approach at the correct altitude.
The Detailed Implementation Plan duplicates and deepens it into code-writing territory
that belongs in the implementation, not the design document.

---

### 🟢 F5 — Nit: Non-Goals wording is inaccurate (inventive-catalyst)

**Scope**: Non-Goals § bullet 1

Non-Goals state: "no change to the order of other resume side effects (Fajr snapshot,
task reload, widget intent)." The fix moves `_checkUntrackedPrayers()` from line 108
(before the Fajr snapshot at lines 110–112) to after those reads. The claim is accurate
only for the effects that follow `ref.invalidate`, not for the entire resumed branch.

Suggested rewrite: "No change to the relative order of effects after
`ref.invalidate(prayerTimesProvider)` (task reload, widget intent, prayer status sync)."

---

### 🟢 F6 — Nit: CI baseline numbers in Verification Plan (zoom-out)

**Scope**: Verification Plan

The plan records current pipeline state values ("warnings must not increase vs. the
current baseline of 407 issues", "Current baseline: 890 Dart pass"). These are
transient numbers, not architectural constraints. They belong in a run-book or CI
config, not a design document.

---

## Summary

| # | Severity | Finding |
|---|---|---|
| F1 | 🔴 Blocker | Second call site (`initState` tearoff, line 217) not covered by the design |
| F2 | 🟡 Major | CUJ 3 / pseudocode reference `isPrayerTimeReached` threshold that the function does not apply |
| F3 | 🟡 Major | Goal 2 unstated assumption: provider may already reflect the next day on resume |
| F4 | 🟡 Major | Detailed Implementation Plan altitude drop — code-level diffs in a design doc |
| F5 | 🟢 Nit | Non-Goals wording falsely implies the call-site reorder does not touch line 108–112 |
| F6 | 🟢 Nit | CI baseline numbers (407 warnings, 890 tests) are pipeline state, not design constraints |
