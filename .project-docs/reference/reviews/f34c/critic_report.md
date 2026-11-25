# Stage 7 — Critic Review Report (Round 1)
**Target**: `docs/designs/fix-f34c.md` lines 1–202 (FeatureRange)
**Date**: 2026-11-25
**Reviewers**: egm-design, egm-structural, egm-style

---

## Consolidated Findings

Findings carry stable ids `<reviewer>-<round>-<n>`. Duplicates across reviewers are
merged; the reviewer column lists every source.

---

### 🔴 Blockers

**B1** `design-1-2` / `zoom-1-1` — **Second call site not covered** (3 reviewers)
Lines: 109–126 (Technical Plan § Call-site change); `initState` line 217
`initState` calls `Future.delayed(const Duration(seconds: 3), _checkUntrackedPrayers)`
as a zero-argument tearoff. Adding a required `List<PrayerTime>` parameter makes this a
compile-time type error. The spec covers only the `didChangeAppLifecycleState` call
site. The cold-start path is entirely missing from the Technical Plan and the
Detailed Implementation Plan's file inventory.

**B2** `design-1-4` / `zoom-1-2` / `style-1-1` — **CUJ 3 internally contradicts the Technical Plan** (4 reviewers)
Lines: 79–84 (CUJ 3); 141–143 (Technical Plan pseudocode)
CUJ 3 states that at "Fajr + < 1 min, before the 20-min `isPrayerTimeReached`
threshold" `pastPrayers` is empty. The pseudocode filter is `time < now` with no
20-minute buffer; at Fajr + 1 min, Fajr passes that filter and IS in `pastPrayers`,
so the sheet fires, not suppresses. The spec contains an unresolved internal
contradiction between the CUJ's described outcome and the pseudocode's logic. Must be
resolved: either add `isPrayerTimeReached` to the filter (a product decision) or rewrite
CUJ 3 to describe what the code actually does.

**B3** `structural-1-1` — **Non-Functional Requirements: mandatory Risks & Mitigations section absent**
Lines: 185–189
The standard requires identification of failure modes and mitigations. The section
asserts "None" with no analysis. Two real scenarios exist (see Major M2 below); "None"
is not accurate.

**B4** `design-1-1` — **"Rejected by author:" attribution — CONTESTED**
Lines: 165, 177 (Alternatives Considered)
The design reviewer flagged "Rejected by author:" as a standards violation requiring a
linked issue/PR. **Contested**: the EGM design document template (`references/design_doc.md`)
explicitly prescribes `"Rejected by author: [technical rationale]"` for author
decisions, and states `"Do NOT state 'Rejected by maintainer' unless quoting an upstream
maintainer issue"`. The spec uses "author" not "maintainer"; it follows the template
exactly. This finding is a false positive against the template itself.
**Resolution**: CONTEST — no change to the spec required.

---

### 🟡 Majors

**M1** `zoom-1-3` — **Goal 2 / Technical Plan: unstated after-midnight assumption**
Lines: 36–38 (Goal 2); 111–114 (Technical Plan § snapshot rationale)
Goal 2 states the snapshot is "consistent with what the user saw on screen before they
left the app." This is false when `_startNextPrayerUpdateTimer` has already called
`loadPrayerTimes(now)` after Isha and advanced the provider to the next calendar day
before resume fires. `resumePrayerTimes` then holds tomorrow's prayers, all in the
future, `pastPrayers` is empty, and the sheet silently does not appear. The spec must
either acknowledge this as a known gap in Non-Goals or add an explicit CUJ edge case.

**M2** `design-1-3` — **NFR "None": two real failure scenarios silently elided**
Lines: 185–188
(a) Cold-start: `didChangeAppLifecycleState(resumed)` can fire before
`prayerTimesProvider` has populated, so `resumePrayerTimes` is `[]` and the
`prayerTimes.isEmpty` guard suppresses the check with no user-visible signal.
(b) Rapid double-resume (OEM activity transitions): a second lifecycle event fires
before the first check's Firestore call completes; the second `resumePrayerTimes`
captures an already-invalidated provider state. Neither scenario is acknowledged. These
belong in the Non-Goals or in a Risks subsection of NFR.

**M3** `style-1-2` — **"developer understood the constraint / intent was correct" — mental state inference**
Lines: 29–32 (The Problem, final paragraph)
Observable fact: the comment states the read must precede the invalidate. Inference: the
developer "understood" and "intended" this. Replace with the observable: "The comment on
line 107 states the read must precede the invalidate; the implementation does not enforce
this ordering across an `async` boundary."

**M4** `style-1-3` — **"On a slow connection this delay is visible" — uncalibrated claim**
Lines: 165–168 (Alternative A, Cons bullet)
No latency bound is given. Replace with the structural consequence: "provider
invalidation, Fajr snapshot, task reload, and widget intent handling are all blocked
until Firestore responds."

**M5** `structural-1-2` — **`### Additional Resources` heading skips a level**
Lines: 191–196
H3 `### Additional Resources` appears directly after a `---` horizontal rule with no
parent H2 — an orphaned heading that violates sequential heading hierarchy. Should be
promoted to H2 or placed under an appropriate H2 parent.

---

### 🟢 Nits

**N1** `zoom-1-5` / `design-1-4` — **Non-Goals wording: ordering claim is partly false**
The fix moves `_checkUntrackedPrayers()` from before the Fajr snapshot reads
(lines 110–112) to after them. The Non-Goals claim covers more than what is actually
unchanged.

**N2** `structural-1-3` — **Problem Statement fragmented across two H2 sections**
"Overview" (symptom) and "The Problem" (root cause) cover a single concept. Standard
expects one "Problem Statement" section.

**N3** `structural-1-4` — **"Open Questions: None" section adds no value**
With content of "None — the cause is confirmed and the fix approach is clear," the
section interrupts the scope-to-CUJ flow without contributing anything.

**N4** `style-1-4` — **"the fix approach is clear" is a quality judgment**
Line 55. Drop or replace with the observable: "the fix approach is defined in the
Technical Plan."

**N5** `style-1-5` — **"a future editor would not see the constraint" is speculative**
Lines 105–107. Replace with the observable: "nothing in the function signature records
the constraint that the read must precede any `await`."

**N6** `style-1-6` — **"fragile" undefined in Alternative B**
Line 179. Replace with the specific failure mode already described in the next sentence,
removing the label.

---

## Round 1 Summary

| ID | Sev | Description |
|---|---|---|
| B1 | 🔴 | Second call site (`initState` tearoff) missing from spec |
| B2 | 🔴 | CUJ 3 contradicts Technical Plan — `isPrayerTimeReached` vs. `time.isBefore(now)` |
| B3 | 🔴 | NFR section says "None" but real failure scenarios exist |
| B4 | 🔴 | "Rejected by author:" — **CONTESTED** (follows the template; false positive) |
| M1 | 🟡 | Goal 2 unstated assumption: provider may already reflect next day on resume |
| M2 | 🟡 | NFR "None": cold-start null provider + double-resume race unacknowledged |
| M3 | 🟡 | "developer understood / intent was correct" — mental state inference |
| M4 | 🟡 | "On a slow connection this delay is visible" — uncalibrated claim |
| M5 | 🟡 | `### Additional Resources` H3 orphaned (no parent H2) |
| N1 | 🟢 | Non-Goals ordering claim is partly inaccurate |
| N2 | 🟢 | Problem Statement split across two H2 sections |
| N3 | 🟢 | "Open Questions: None" section adds no value |
| N4 | 🟢 | "the fix approach is clear" — quality judgment |
| N5 | 🟢 | "future editor would not see the constraint" — speculative |
| N6 | 🟢 | "fragile" undefined label in Alternative B |

**Clean round**: No — 3 genuine Blockers (B4 contested) + 5 Majors open.
