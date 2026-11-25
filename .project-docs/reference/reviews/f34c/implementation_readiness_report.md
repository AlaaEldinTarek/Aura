# Stage 9 — Implementation Readiness Report

**Target:** `docs/designs/fix-f34c.md` (lines 238–end, DetailedRange)
**Date:** 2026-11-25
**Reviewers:** egm-implementation-readiness, egm-codebase-details, egm-style

---

## Consolidated Findings

Findings carry stable ids `IR/CD/ST-<n>`. Duplicates across reviewers are merged.

---

### 🔴 Blockers

**B1** `CD-1` / `IR-1` — **`initState` call site (line 217) absent from Detailed Implementation Plan** (2 reviewers, VERIFIED)
Lines: design doc lines 242–308 (proposed changes block); source line 217.

The DIP scopes the call-site edit exclusively to `didChangeAppLifecycleState` resumed branch (lines 106–121). It never instructs the implementer to touch line 217, where `_checkUntrackedPrayers` is passed as a bare no-argument tearoff to `Future.delayed`. Once the required `List<PrayerTime>` parameter is added, that tearoff is a compile error. The lambda replacement is described only in the FeatureRange Technical Plan (lines 134–141), which a developer executing the DIP alone may not read.

**Fix:** Add a third bullet to the `main_wrapper_screen.dart` proposed-changes block: "Replace the tearoff on line 217 with `() => _checkUntrackedPrayers(ref.read(prayerTimesProvider)?.prayerTimes ?? [])`."

---

### 🟡 Majors

**M1** `ST-1` / `ST-2` / `F4` — **Altitude drop: Dart code blocks duplicate Technical Plan and belong in a PR diff** (3 reviewers)
Lines: 255–307 (before/after Dart code blocks); 238–308 (overall DIP section).

The four before/after Dart code blocks reproduce exact production source lines at implementation level. The Technical Plan (lines 115–177) already captures the same logic as pseudocode at the correct altitude. The DIP adds no new constraints, edge-case handling, or rationale; it only restates the same changes at a lower code altitude, creating a dual-maintenance surface. The design doc standard prohibits actual code (pseudocode and schemas allowed).

**Fix:** Remove the Dart code blocks. Retain the pseudocode in the Technical Plan as the authoritative implementation description. Replace the DIP's current proposed-changes block with a prose + line-range description referencing the Technical Plan.

---

**M2** `IR-2` — **Ambiguous insertion point for `prayerTimes.isEmpty` guard — flag-leak risk** (1 reviewer)
Lines: design doc lines 302–306; source lines 603–605.

The plan says "Add an early guard before the first `await` (after the `_untrackedCheckInProgress` guard)." The function body has three syntactic positions that satisfy this: (a) before `_untrackedCheckInProgress = true;`, (b) between `_untrackedCheckInProgress = true;` and `try {`, or (c) inside `try {`. Position (b) would cause the function to return while the flag is `true` with the `finally` block never executing — permanently blocking future checks. The plan must specify the exact position.

**Fix:** Change the guard instruction to: "Insert `if (prayerTimes.isEmpty) return;` as the first statement inside the `try` block, before `final prefs = ...`, so the `finally` block always resets `_untrackedCheckInProgress`."

---

**M3** `IR-3` / `ST-4` — **T1 test strategy left as an unresolved open choice** (2 reviewers)
Lines: 327–331.

The T1 implementation note reads "test it via the lifecycle event (`didChangeAppLifecycleState(resumed)`) **or** by exposing a test-only hook if the widget test infrastructure does not support direct private calls." The "or" branch leaves the implementer to decide the approach, design the hook, and determine whether a `@visibleForTesting` annotation suffices. This is a design decision the plan must resolve.

**Fix:** Remove the conditional clause; specify the single approach: trigger via `tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed)` following the pattern in `f34a_source_test.dart`.

---

### 🟢 Nits

**N1** `CD-2` — **"lines 613–616" label is off by two** (VERIFIED)
Lines: design doc lines 280–286.
The two lines to remove (`final prayerState = ref.read(prayerTimesProvider);` and `if (prayerState.prayerTimes.isEmpty) return;`) are at lines 615–616, not 613–616. Lines 613–614 are `final now = ...` and `final today = ...`, which are unrelated.
**Fix:** Change range label to "lines 615–616".

**N2** `ST-3` — **"(broken)" labels are informal editorial characterisations**
Lines: 257, 291.
`// Current order (broken):` and `// Before (broken):` are subjective labels embedded in code blocks. The document already establishes these as the incorrect states.
**Fix:** Replace with `// Before:` / `// After:` throughout.

**N3** `IR-4` — **T1 assertion target is ambiguous**
Lines: 319–322.
"Confirm that ... `_showUntrackedPrayersSheet` is reached (or the sheet widget appears)" leaves two acceptable assertion targets. Collapse to one.
**Fix:** Use "verify that the untracked-prayers bottom sheet widget appears in the widget tree" as the single assertion target.

**N4** `ST-5` — **Tautological verification statement**
Lines: 339–340.
"Test count in the suite increases by exactly the number of T1/T2 cases added" is a truism that adds no actionable pass/fail criterion.
**Fix:** Remove the sentence; `flutter test` passing is the sufficient criterion.

---

## Round Summary

| ID | Sev | Description |
|---|---|---|
| B1 | 🔴 | `initState` line 217 not in DIP file inventory |
| M1 | 🟡 | Altitude drop: Dart code blocks duplicate Technical Plan |
| M2 | 🟡 | `prayerTimes.isEmpty` guard insertion point ambiguous (flag-leak risk) |
| M3 | 🟡 | T1 test strategy unresolved "or" branch |
| N1 | 🟢 | "lines 613–616" label off by two |
| N2 | 🟢 | "(broken)" labels informal |
| N3 | 🟢 | T1 assertion target ambiguous |
| N4 | 🟢 | Tautological test-count verification statement |

**Clean round:** No — 1 Blocker + 3 Majors open.
