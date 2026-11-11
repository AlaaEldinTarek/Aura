# Goldfish Review Report

**Target:** `design_draft.md` (lines 1-248, full document)
**Standard:** `feature-spec-standard.md` (+ `implementation-readiness-standard.md`, `zoom-out-standard.md`)
**Date:** 2026-11-10

## Reviewer Status

| Reviewer | Status |
| --- | --- |
| `structural` | completed |
| `comprehension` | completed |
| `design` | completed |
| `codebase-details` | completed |
| `implementation-readiness` | completed |
| `style` | completed |
| `zoom-out` | completed |
| `inventive-catalyst` | completed |

**Severity breakdown:** 1 Blocker, 10 Major, 13 Nit

---

## Prioritized Findings (Blockers -> Major -> Nits)

### 1. Missing "Alternatives Considered" Section - Severity: Blocker

* **Reviewer Lens:** `structural`, `style`, `design`, `comprehension`, `codebase-details`, `inventive-catalyst` (6/8 reviewers)
* **Affected Scope:** Document-level -- no Alternatives section present between Design and Risks
* **Discrepancy Description:** The feature-spec standard contains a mandatory Alternatives Rule (standard lines 14-21): "It fails this standard if it proposes a single path without proving that other viable designs were considered and rejected for specific, documented reasons." The spec proposes a single design (intercept `KEYCODE_VOLUME_UP` in the activity's `onKeyDown`, count timestamps, trigger exit) with no section documenting rejected alternatives.
* **Rationale & Recommendation:** Credible alternatives exist and should be evaluated with concrete rejection rationale: (a) intercepting volume keys in the overlay's `dispatchKeyEvent` as the primary design (mentioned only as an untested fallback in R3); (b) using `AudioManager.getStreamVolume()` polling or a `ContentObserver` on volume settings; (c) using `MediaSession` / `MediaButtonReceiver` for hardware media-key events; (d) using a different escape gesture (shake detection, power button pattern); (e) implementing a Flutter MethodChannel approach. Add an "Alternatives Considered" H2 section with at least two rejected options and concrete trade-off rationale.

---

### 2. `repeatCount == 0` Filter Missing from Design Section A - Severity: Major

* **Reviewer Lens:** `zoom-out`, `implementation-readiness`, `design`, `comprehension`, `inventive-catalyst` (5/8 reviewers)
* **Affected Scope:** Section A, `onKeyDown` change (lines 97-105) vs. Risk R4 (line 203)
* **Discrepancy Description:** Risk R4 states the detector should filter `event.repeatCount == 0` to distinguish discrete presses from press-and-hold repeat events. Without this filter, holding VOLUME_UP generates rapid-fire `onKeyDown` events with incrementing `repeatCount`, easily accumulating three timestamps within 1500 ms and triggering an unintentional exit from a single long press. However, the four normative design steps in Section A do not mention `repeatCount` filtering at all. An implementer following Section A alone would produce a detector that exits on a single long-press.
* **Rationale & Recommendation:** Promote this from a risk mitigation into the design steps. Add as a precondition in step 1: "If `event?.repeatCount != 0`, return `true` (consume but do not record)."

---

### 3. Design vs. Risk R2 Contradiction: Duplicate Teardown vs. Shared Method Extraction - Severity: Major

* **Reviewer Lens:** `zoom-out`, `implementation-readiness`, `inventive-catalyst`, `comprehension` (4/8 reviewers)
* **Affected Scope:** Section A `triggerVolumeExit()` (lines 107-124) vs. Risk R2 (line 201)
* **Discrepancy Description:** Section A specifies `triggerVolumeExit()` as a new method that reproduces all 10+ teardown steps from `onCountdownComplete()`. Risk R2 then identifies the resulting duplication as a risk and proposes extracting a shared `performExit(isEarly: Boolean)` method as a mitigation. The spec accepts code duplication as the primary design while simultaneously acknowledging it creates a maintenance liability. An implementer must decide which structure to use -- this violates the Zero-Decision rule.
* **Rationale & Recommendation:** Make the extraction the design, not a risk mitigation. Replace the 11-step enumeration in Section A with a statement that a shared private method `performExit(isEarly: Boolean)` is called by both `onCountdownComplete()` and the volume-exit path, differing only in the timer-text label ("Exited" vs. "Done!") and the press-counter reset. Define the method signature. Remove R2 from the risk table (it becomes a solved design decision).

---

### 4. Inaccurate `onDestroy` Restart Guard Description - Severity: Major

* **Reviewer Lens:** `codebase-details`, `design`, `comprehension`, `inventive-catalyst` (4/8 reviewers)
* **Affected Scope:** Section B (lines 131-138), Risk R5 (line 204); `FocusModeService.kt` lines 214-229
* **Discrepancy Description:** The spec states: "the guards in `onDestroy` (:214-228) and `onTaskRemoved` (:203-211) only restart when `!isTimerFinished && isRunning`." This is wrong for `onDestroy`. Actual code: `onTaskRemoved` (line 204) checks `if (!isTimerFinished && isRunning)` -- correct. But `onDestroy` (line 221) checks only `if (!isTimerFinished)` -- single-flag guard, not compound. Furthermore, `onDestroy` sets `isRunning = false` at line 219 before the check, so `isRunning` is always false by the time the restart decision runs. The spec's conclusion (restart is suppressed) is correct, but the stated reasoning is wrong. A maintainer could incorrectly believe `isRunning` is part of the `onDestroy` guard.
* **Rationale & Recommendation:** Correct the spec to accurately describe the two different guards. `onTaskRemoved` checks both flags; `onDestroy` checks only `isTimerFinished`. The same false claim propagates to R5 and Section B's "both flags" language.

---

### 5. Translation String Mismatches: JSON vs. Proposed Kotlin Strings - Severity: Major

* **Reviewer Lens:** `codebase-details`
* **Affected Scope:** Section C table (lines 147-150); `en.json:215`, `ar.json:215`
* **Discrepancy Description:** Two discrepancies between the existing translation files and the proposed Kotlin hardcoded strings:
  - **EN wording:** `en.json:215` has "Press volume up 3 times to exit"; proposed Kotlin `exitHint` has "Press volume up 3 times **quickly** to exit" (adds "quickly").
  - **AR numerals:** `ar.json:215` uses Western digit `3` (U+0033); proposed Kotlin uses Eastern Arabic digit `٣` (U+0663) and adds `بسرعة` (quickly). No existing hardcoded Arabic string in `FocusModeActivity.kt` contains literal Eastern Arabic digits -- the codebase uses `toArabicNumerals()` for dynamic conversion.
  The spec claims (line 152) the JSON keys have "the correct text," but the proposed Kotlin strings differ in wording. This is contradictory.
* **Rationale & Recommendation:** Decide which text is canonical (the JSON or the proposed Kotlin strings). If "quickly" should be present, update the JSON too. For Arabic numerals, either use `toArabicNumerals("3")` inline (matching the existing pattern) or justify hardcoding Eastern digits.

---

### 6. Checklist Claims "9 Existing" Kotlin Tests; Actual Count Is 5 - Severity: Major

* **Reviewer Lens:** `codebase-details`
* **Affected Scope:** Checklist line 230 vs. Section D line 162
* **Discrepancy Description:** The checklist states "Kotlin tests pass (9 existing + new VolumeExitDetectorTest)." Section D of the same spec correctly states "alongside the existing 5 Kotlin unit tests." The actual file count in `android/app/src/test/kotlin/com/aura/hala/` is 5. The checklist contradicts the spec's own Section D and the actual codebase.
* **Rationale & Recommendation:** Change "9 existing" to "5 existing" in the checklist.

---

### 7. Test Structure Ambiguity: Standalone Class vs. Inline Wrapper - Severity: Major

* **Reviewer Lens:** `implementation-readiness`, `zoom-out`
* **Affected Scope:** Section D (lines 158-170)
* **Discrepancy Description:** The spec says "Extract the timestamp-list + threshold logic into a small testable helper class **or** keep it inline and test via a pure-logic wrapper." The two options have different implementation consequences (class name, constructor, public method signatures vs. wrapper access to internal state). The test file name `VolumeExitDetectorTest.kt` implies a standalone class, but no class interface is specified. The "or" leaves an architectural decision to the implementer.
* **Rationale & Recommendation:** Pick one option and specify the class/method signatures (e.g., `class VolumeExitDetector` with `fun recordPress(timestampMs: Long): Boolean`), or state that the logic stays inline with the test exercising a package-visible wrapper function.

---

### 8. `isActivityVisible = true` in Teardown Sequence Unexplained - Severity: Major

* **Reviewer Lens:** `comprehension`
* **Affected Scope:** Section A, `triggerVolumeExit()` step 1 (line 110)
* **Discrepancy Description:** The method's first step sets `isActivityVisible = true` alongside `isTimerFinished = true`. The spec never explains what `isActivityVisible` controls or why it must be set during early exit. Per the source, `FocusModeService.monitorRunnable` checks this flag and relaunches the activity if it is false. Setting it to true prevents the monitor from relaunching during the teardown window before the service is stopped. This rationale is absent.
* **Rationale & Recommendation:** Add a brief inline comment explaining the flag's purpose: it prevents the service's 100 ms monitor from relaunching the activity during the brief window between setting the flag and stopping the service.

---

### 9. R3 Overlay Fallback Path Is Undesigned - Severity: Major

* **Reviewer Lens:** `inventive-catalyst`
* **Affected Scope:** Section A (lines 84-105), Risk R3 (line 202)
* **Discrepancy Description:** R3 acknowledges that on some OEMs the `TYPE_APPLICATION_OVERLAY` may intercept `KEYCODE_VOLUME_UP` before it reaches the activity. The proposed fallback ("intercept in the overlay's `dispatchKeyEvent`") is undesigned -- the cross-component communication path (overlay in service -> press event -> activity exit) is unspecified. If R3 materializes during S44 testing, the implementer faces a design gap without a spec.
* **Rationale & Recommendation:** Design the fallback concretely now: specify whether the overlay forwards volume key events to a static method, broadcasts a `LocalBroadcastManager` message, or duplicates the press-counter in the service. Document which approach will be used if R3 materializes on the nova 5T, so a tester knows the remediation path without a new design cycle.

---

### 10. Undefined Project-Specific Identifiers - Severity: Major

* **Reviewer Lens:** `comprehension`
* **Affected Scope:** Title (line 1), Non-Goals (line 76), Goals (lines 48-66), metadata (line 6)
* **Discrepancy Description:** Four project-specific identifiers are used without definition or links: "F52f" (fix identifier in title), "F51f" (referenced in Non-Goals as "a separate finding"), "S44" (device-check identifier used throughout Goals and Checklist), and "Level: C" (approval level in metadata, parenthetically described but not contextualized within the A/B/C system). A fresh reader cannot decode these without searching project docs externally.
* **Rationale & Recommendation:** Either define the naming conventions briefly (e.g., "F## = finding number from findings.md; S## = device-check sequence number") or add links to the project docs where they are defined.

---

### 11. Uncalibrated Behavioral Claims in Risk Table - Severity: Major

* **Reviewer Lens:** `style`
* **Affected Scope:** Risk R1 mitigation (line 200), Risk R4 likelihood (line 203)
* **Discrepancy Description:** Two claims lack evidence: (a) R1's "Acceptable trade-off" is an editorial opinion without criteria -- acceptable to whom, under what threshold? (b) R4's "most volume adjustments are press-and-hold" asserts typical user behavior without data. The technical fact that follows (held keys produce `repeatCount > 0`) is solid, but the behavioral premise is unverified.
* **Rationale & Recommendation:** For R1, replace "Acceptable trade-off" with the factual justification directly: "The existing confirmation dialog already promises this behavior, and volume-down is unaffected." For R4, narrow the claim to what the code guarantees: held-key repeats produce `repeatCount > 0` and are filtered, so only distinct physical presses count. Drop the generalization about user behavior.

---

### 12. Code Snippet Declares Second `companion object` - Severity: Nit

* **Reviewer Lens:** `implementation-readiness`
* **Affected Scope:** Section A, code snippet (lines 88-94)
* **Discrepancy Description:** The snippet declares `private companion object { ... }`, but `FocusModeActivity` already has a `companion object` at source lines 41-52. Kotlin allows only one companion object per class; a second would be a compile error. The constants must be added to the existing companion object.
* **Rationale & Recommendation:** Change the snippet to show the constants being added to the existing companion object, or note "add to existing companion object."

---

### 13. `System.currentTimeMillis()` vs. `SystemClock.elapsedRealtime()` - Severity: Nit

* **Reviewer Lens:** `design`
* **Affected Scope:** Section A step 1 (line 100)
* **Discrepancy Description:** The spec uses `System.currentTimeMillis()` for press timestamps. This clock is subject to NTP adjustments and user-initiated time changes. `SystemClock.elapsedRealtime()` (monotonic) is the standard Android choice for measuring elapsed intervals. Within a 1.5-second window the practical risk is negligible, but the monotonic clock is trivially correct.
* **Rationale & Recommendation:** Use `SystemClock.elapsedRealtime()` instead of `System.currentTimeMillis()`.

---

### 14. Timestamp-Pruning Semantics Underspecified - Severity: Nit

* **Reviewer Lens:** `comprehension`
* **Affected Scope:** Section A, `onKeyDown` step 2 (line 101)
* **Discrepancy Description:** Step 2 says "Drop entries older than `VOLUME_EXIT_WINDOW_MS`." This could mean (a) drop entries where `now - entry > 1500`, or (b) drop entries where `newestEntry - entry > 1500`. The two definitions produce different behavior when presses are spread unevenly. Since this is the core detection logic that the unit test validates, the definition should be explicit.
* **Rationale & Recommendation:** Specify: "Drop entries where `System.currentTimeMillis() - entry > VOLUME_EXIT_WINDOW_MS`" (i.e., relative to current time, not relative to the newest entry).

---

### 15. Double Sound-Mode Restoration on Early Exit - Severity: Nit

* **Reviewer Lens:** `design`
* **Affected Scope:** Section A step 4 (line 113) and Section B (line 131)
* **Discrepancy Description:** `triggerVolumeExit()` calls `restoreSoundMode()` in the activity (step 4), then `FocusModeService.stop()` (step 5), which triggers `stopFocusMode()` in the service, which also calls `restoreSoundMode()`. The two implementations differ: the activity's version always sets `RINGER_MODE_NORMAL`, while the service's version restores `savedRingerMode`. If the user's original ringer mode was vibrate, the two calls conflict. This is a pre-existing pattern in `onCountdownComplete()`, not new to this fix.
* **Rationale & Recommendation:** If Finding 3 is addressed (shared `performExit` extraction), decide whether the activity or the service owns sound restoration. Acknowledge the pre-existing double-restore in the spec.

---

### 16. Line-Number References Off by 1-2 Lines - Severity: Nit

* **Reviewer Lens:** `codebase-details`
* **Affected Scope:** Multiple locations throughout the document
* **Discrepancy Description:** Several line-number ranges omit closing braces or include adjacent methods:
  - `onKeyDown` claimed as `:221-240`, actual is `:221-231` (range bleeds into `onKeyUp`)
  - `onKeyUp` claimed as `:233-242`, actual is `:233-243`
  - `onCountdownComplete` claimed as `:373-401`, actual is `:373-402`
  - `onDestroy` claimed as `:214-228`, actual is `:214-229`
  - `onTaskRemoved` claimed as `:203-211`, actual is `:203-212`
  - Touch blocker claimed as `:262-305`, actual `addTouchBlocker()` spans `:271-308`
* **Rationale & Recommendation:** Correct the line ranges. The `onKeyDown` range (221-240) is particularly misleading since it crosses into a different method.

---

### 17. Structural Heading Name Deviations - Severity: Nit

* **Reviewer Lens:** `structural`
* **Affected Scope:** H2 "The Problem" (line 22), H2 "Design" (line 80)
* **Discrepancy Description:** The standard lists "Problem Statement" and "Proposed Architecture" as the canonical heading names. The spec uses "The Problem" and "Design" instead. Content fulfills the same purpose; naming is a minor deviation.
* **Rationale & Recommendation:** Consider renaming for strict template alignment, or leave as-is since the content matches.

---

### 18. Voice and Tone Inconsistencies - Severity: Nit

* **Reviewer Lens:** `style`
* **Affected Scope:** Lines 155-156 ("We keep that pattern"), line 213 ("(broken)"), line 13 (filler clause)
* **Discrepancy Description:** (a) "We keep that pattern and hardcode the updated strings" uses first-person plural; the rest of the document uses impersonal or imperative voice. (b) "(broken)" in the Rollback section is an editorial characterization. (c) "to help the user concentrate on a task" in the Overview is a filler clause.
* **Rationale & Recommendation:** Use consistent impersonal voice throughout. Replace "(broken)" with a neutral descriptor. Trim the filler clause.

---

### 19. Inconsistent List Markers - Severity: Nit

* **Reviewer Lens:** `structural`
* **Affected Scope:** Lines 2-7 and 74-78 (use `*`) vs. lines 221-247 (use `-`)
* **Discrepancy Description:** The document mixes `*` and `-` as unordered-list markers. Both are valid Markdown, but consistency within a document is cleaner.
* **Rationale & Recommendation:** Pick one marker and use it throughout.

---

### 20. `stopLockTask()` Context Missing - Severity: Nit

* **Reviewer Lens:** `comprehension`
* **Affected Scope:** Section A, `triggerVolumeExit()` step 2 (line 111)
* **Discrepancy Description:** The teardown calls `stopLockTask()`, but the spec never mentions that `startLockTask()` is called during Focus Mode setup (`onCreate` line 110 and `onResume` line 119 in the source). A reader unfamiliar with the codebase does not know when lock-task mode was entered.
* **Rationale & Recommendation:** Add a brief note in the Overview or Problem section that lock-task mode is entered during setup.

---

### 21. "adhan" Interaction in Non-Goals Unexplained - Severity: Nit

* **Reviewer Lens:** `comprehension`
* **Affected Scope:** Non-Goals (line 76)
* **Discrepancy Description:** "Changing how Focus Mode interacts with adhan (that is F51f, a separate finding)" does not explain the nature of the interaction. A reader cannot assess whether this non-goal has any bearing on the volume-exit feature.
* **Rationale & Recommendation:** Add one clause describing the interaction (e.g., "whether adhan audio should break through Focus Mode silence").

---

### 22. Ordering Step 1 Ambiguity - Severity: Nit

* **Reviewer Lens:** `implementation-readiness`
* **Affected Scope:** Section F, Ordering (lines 186-193)
* **Discrepancy Description:** Step 1 says "Extract/write the press-counter logic + unit test" but step 1 (writing a test for a class that does not yet exist) cannot pass until step 2 (wire the detector) is done. The plan should clarify whether step 1 means creating both the helper class and its test together.
* **Rationale & Recommendation:** If a standalone class is chosen (Finding 7), state: "Create `VolumeExitDetector` class + `VolumeExitDetectorTest.kt`, run tests to green."

---

### 23. Line-Number References Unversioned - Severity: Nit

* **Reviewer Lens:** `comprehension`
* **Affected Scope:** Throughout the document
* **Discrepancy Description:** Line-number references are extensive but not anchored to a specific commit hash. They match the current `main` state but will drift with any edit.
* **Rationale & Recommendation:** Add a commit hash reference in the metadata (e.g., "Line references based on commit `e64bf95`").

---

### 24. Verbose Parenthetical in "Not Changed" List - Severity: Nit

* **Reviewer Lens:** `style`
* **Affected Scope:** Lines 180-182
* **Discrepancy Description:** The parenthetical "(keys exist but are Flutter-side; Kotlin hardcodes its own strings matching the existing pattern)" repeats what lines 152-156 already explained.
* **Rationale & Recommendation:** Shorten to "(Flutter-side only; see section C)."
