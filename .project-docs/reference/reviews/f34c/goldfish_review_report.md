# Goldfish Annotated Review Report

**Target:** `docs/designs/fix-f34c.md` (lines 1–202)
**Stage:** 7 — Critic Review, Round 1

---

## Prioritized Findings & AI Suggestions

---

### [B1] [design + zoom-out] — Severity: Blocker

*   **Affected Scope:** Lines 109–126 (Technical Plan § Call-site change); `initState` line 217
*   **Discrepancy Description:** `initState` calls `_checkUntrackedPrayers` as a no-argument tearoff via `Future.delayed`. Adding a required parameter causes a compile-time type error. The spec covers only the `didChangeAppLifecycleState` call site.
*   **Rationale:** Confirmed in code. The fix as written is not implementable without resolving this.
*   ***AI Suggestion:*** ESCALATE
*   ***Justification:*** Two distinct architectural options exist, each with trade-offs; the author must choose one before the spec can be updated. The choice is not derivable from the codebase alone.
*   ***Author Decision Required:***
    *   **Option A — Optional parameter with internal fallback**: Change signature to `_checkUntrackedPrayers([List<PrayerTime> prayerTimes = const []])` or `_checkUntrackedPrayers({List<PrayerTime>? prayerTimes})` with an internal fallback `ref.read(prayerTimesProvider)?.prayerTimes ?? []` read **synchronously before the first `await`**. `initState` tearoff compiles unchanged. Risk: a future editor can omit the argument on the resume path and silently re-enable the race; inline documentation at both call sites is required.
    *   **Option B — Lambda wrapper in `initState`**: Keep the parameter required. Replace the `initState` tearoff with `Future.delayed(const Duration(seconds: 3), () => _checkUntrackedPrayers(ref.read(prayerTimesProvider)?.prayerTimes ?? []))`. On cold start there is no prior `ref.invalidate`, so the read returns the freshly loaded times. The required parameter keeps the race-free invariant visible in the signature.

---

### [B2] [design + zoom-out + style + inventive-catalyst] — Severity: Blocker

*   **Affected Scope:** Lines 79–84 (CUJ 3); 141–143 (Technical Plan pseudocode)
*   **Discrepancy Description:** CUJ 3's "Given" and "Then" reference a 20-minute `isPrayerTimeReached` threshold that the function does not apply. The actual filter is `time.isBefore(now)`. At Fajr + 1 min, the sheet fires — not suppresses.
*   **Rationale:** Confirmed in code at line 620: `p.time.isBefore(now)`. The `isPrayerTimeReached` guard is documented in `prayer-tracking.md` as a *display-layer* guard, not applied inside `_checkUntrackedPrayers`.
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Justification:*** The fix is behavior-preserving (Non-Goal: no changes to the tracking flow). CUJ 3 must describe the actual `time.isBefore(now)` filter. The question of whether `isPrayerTimeReached` *should* be added is a future product decision, out of scope for this fix per Non-Goal bullet 2. Document it as a known gap in Non-Goals.
*   ***Proposed Edit:***
    *   Location: Lines 79–84 (CUJ 3)
    *   Replace entire CUJ 3 block with:

        ```markdown
        ### CUJ 3: Resume before Fajr adhan time

        *   **Given**: The user resumes the app before today's Fajr adhan time.
        *   **When**: The user resumes the app.
        *   **Then**: `pastPrayers` is empty (no prayer's `time.isBefore(now)` is
            true yet); no bottom sheet appears.
        ```

    *   Location: Non-Goals section (after line 49)
    *   Add bullet:
        ```
        *   Applying the codebase-wide 20-minute `isPrayerTimeReached` threshold to
            the untracked-prayer filter — the function uses raw adhan time
            (`time.isBefore(now)`); whether the threshold should also apply is a
            separate product decision.
        ```

---

### [B3 + M2] [structural + design] — Severity: Blocker / Major (merged)

*   **Affected Scope:** Lines 185–188 (Non-Functional Requirements)
*   **Discrepancy Description:** NFR section says "None" but two real failure scenarios exist: (a) cold-start where `prayerTimesProvider` has not populated yet, so `resumePrayerTimes = []` and the check is silently suppressed; (b) OEM rapid double-resume fires a second lifecycle event before the first check's Firestore call completes.
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Justification:*** Both scenarios are real but accepted as out-of-scope: (a) is correct behavior when no times are available yet; (b) is guarded by `_untrackedCheckInProgress`. The NFR section should acknowledge them rather than assert "None."
*   ***Proposed Edit:***
    *   Location: Lines 185–188
    *   Replace:
        ```markdown
        None. This is a one-file, two-method change with no new I/O, no schema changes,
        and no new state.
        ```
    *   With:
        ```markdown
        No schema changes, no new I/O paths, no new persistent state.

        Two edge cases are accepted as out-of-scope:

        *   **Cold-start (provider not yet populated)**: If `prayerTimesProvider` has not
            populated before `didChangeAppLifecycleState(resumed)` fires (e.g., the app
            was killed and relaunched), `resumePrayerTimes` is `[]`, the
            `prayerTimes.isEmpty` guard exits early, and the check is silently skipped.
            This is correct behaviour — no past prayers are known yet.
        *   **Rapid double-resume (OEM activity transitions)**: A second lifecycle
            `resumed` event that fires while the first check's Firestore call is still
            in flight is blocked by the `_untrackedCheckInProgress` re-entrancy guard
            already in the function.
        ```

---

### [B4] [design] — Severity: Blocker

*   **Affected Scope:** Lines 165, 177 (Alternatives Considered — rejection attributions)
*   **Discrepancy Description:** Reviewer flagged `"Rejected by author:"` as requiring a linked issue/PR.
*   ***AI Suggestion:*** CONTEST
*   ***Justification:*** The EGM design document template (`references/design_doc.md`) explicitly prescribes `"Rejected by author: [technical rationale]"` and states `"Do NOT state 'Rejected by maintainer' unless quoting an upstream maintainer issue, discussion, or PR URL."` The spec uses "author" (the person writing this spec), not "maintainer" (an upstream project). The reviewer misread the standard's restriction. No change to the spec is required.

---

### [M1] [zoom-out + inventive-catalyst] — Severity: Major

*   **Affected Scope:** Lines 36–38 (Goal 2); 109–114 (Technical Plan § snapshot rationale)
*   **Discrepancy Description:** Goal 2 claims the snapshot is "consistent with what the user saw on screen before they left the app," but `_startNextPrayerUpdateTimer` can advance the provider to the next calendar day while backgrounded, making `resumePrayerTimes` hold tomorrow's prayers.
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Justification:*** The scenario is real but accepted as out-of-scope: after midnight the user has no untracked prayers from the new day yet, so the empty `pastPrayers` result is correct. The spec must acknowledge the boundary rather than imply Goal 2 always holds.
*   ***Proposed Edit:***
    *   Location: Non-Goals bullets (lines 45–49)
    *   Add bullet:
        ```
        *   Handling the after-midnight background case: if `_startNextPrayerUpdateTimer`
            has already advanced `prayerTimesProvider` to the next calendar day before
            `didChangeAppLifecycleState(resumed)` fires, `resumePrayerTimes` holds
            tomorrow's prayers (all in the future), `pastPrayers` is empty, and no sheet
            appears. This is accepted: no prayers from the new day have passed yet.
        ```

---

### [M3] [style] — Severity: Major

*   **Affected Scope:** Lines 29–32 (The Problem, final paragraph)
*   **Discrepancy Description:** "shows the developer understood the constraint. The intent was correct" infers mental state from a code comment.
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:***
    *   Location: Lines 30–32
    *   Replace:
        `"which shows the developer understood the constraint. The intent was correct; the implementation did not account for the Dart `async` suspension boundary."`
    *   With:
        `"The comment records the ordering constraint; the implementation does not enforce it across a Dart `async` suspension boundary."`

---

### [M4] [style] — Severity: Major

*   **Affected Scope:** Lines 165–168 (Alternative A, Cons bullet)
*   **Discrepancy Description:** "On a slow connection this delay is visible" is an uncalibrated claim.
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:***
    *   Location: Line 167
    *   Replace:
        `"On a slow connection this delay is visible."`
    *   With:
        `""`  (remove the sentence; the structural consequence already stated before it is sufficient)

---

### [M5] [structural] — Severity: Major

*   **Affected Scope:** Lines 191–196 (`### Additional Resources`)
*   **Discrepancy Description:** H3 heading with no parent H2, violating heading hierarchy.
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:***
    *   Location: Line 193
    *   Change `### Additional Resources` → `## Additional Resources`

---

### [N1] [zoom-out + inventive-catalyst] — Severity: Nit

*   **Affected Scope:** Lines 45–48 (Non-Goals bullet 1)
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:***
    *   Replace:
        `"Changing when `ref.invalidate(prayerTimesProvider)` runs or the order of other resume side effects (Fajr snapshot, task reload, widget intent)."`
    *   With:
        `"Changing when `ref.invalidate(prayerTimesProvider)` runs or the relative order of resume effects that follow it (task reload, widget intent, prayer status sync). Note: the fix moves `_checkUntrackedPrayers()` from before the Fajr snapshot reads to after them."`

---

### [N2] [structural] — Severity: Nit

*   **Affected Scope:** Lines 9–27 (Overview + The Problem)
*   ***AI Suggestion:*** DECLINE
*   ***Justification:*** The two-section pattern (brief Overview → detailed The Problem) is intentional and standard for this codebase's design docs. The EGM template itself uses both headings. A single merged section would reduce readability for this fix's level of detail.

---

### [N3] [structural] — Severity: Nit

*   **Affected Scope:** Lines 53–56 (Open Questions)
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:***
    *   Delete the entire Open Questions section (lines 53–56 including the `---` dividers).

---

### [N4] [style] — Severity: Nit

*   **Affected Scope:** Line 55
*   ***AI Suggestion:*** PROPOSE FIX (merged into N3 deletion above)

---

### [N5] [style] — Severity: Nit

*   **Affected Scope:** Lines 105–107
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:***
    *   Replace:
        `"a future editor would not see the constraint"`
    *   With:
        `"nothing in the function signature records the constraint that the read must precede any `await`"`

---

### [N6] [style] — Severity: Nit

*   **Affected Scope:** Line 179 (Alternative B, Cons bullet)
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:***
    *   Replace:
        `"Rejected by author: fragile; the snapshot-parameter approach makes the dependency explicit and reviewable."`
    *   With:
        `"Rejected by author: a later edit that adds an earlier `await` would silently reintroduce the race; the snapshot-parameter approach makes the dependency explicit in the function signature."`

---

## Summary

| ID | Sev | Category | Action |
|---|---|---|---|
| B1 | 🔴 | ESCALATE | Author must choose Option A or B for `initState` cold-start path |
| B2 | 🔴 | PROPOSE FIX | Rewrite CUJ 3; add Non-Goal about raw-adhan-time threshold |
| B3+M2 | 🔴 | PROPOSE FIX | Replace NFR "None" with two accepted edge cases |
| B4 | 🔴 | CONTEST | "Rejected by author:" follows the template; no change needed |
| M1 | 🟡 | PROPOSE FIX | Add Non-Goal for after-midnight background refresh window |
| M3 | 🟡 | PROPOSE FIX | Remove mental-state inference from The Problem |
| M4 | 🟡 | PROPOSE FIX | Remove uncalibrated latency sentence from Alternative A |
| M5 | 🟡 | PROPOSE FIX | Promote Additional Resources to H2 |
| N1 | 🟢 | PROPOSE FIX | Narrow Non-Goals ordering claim |
| N2 | 🟢 | DECLINE | Two-section problem statement is intentional |
| N3+N4 | 🟢 | PROPOSE FIX | Delete Open Questions section |
| N5 | 🟢 | PROPOSE FIX | Replace speculative phrasing in Technical Plan |
| N6 | 🟢 | PROPOSE FIX | Replace undefined "fragile" label in Alternative B |
