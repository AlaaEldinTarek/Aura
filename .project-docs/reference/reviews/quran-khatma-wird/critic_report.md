# Stage 7: Critic Review — fix-quran-khatma-wird.md (lines 1-164)

Reviewers: egm-design, egm-structural, egm-style (one pass each; no review loop). Standard: feature-spec-standard.md. No Blockers from any reviewer.
Limits: structural and style did not read the code (cites unchecked by them); design read code and confirmed the cites.

## Design (D)
| # | Sev | Finding | Elephant note |
| --- | --- | --- | --- |
| D1 | Major | Same-color-already-linked case sets `counted = existing ∪ S` (all pages of the color). That also swallows other unsynced bookmarks of that color, which auto-sync would have counted. "Intentional" is argued only for the not-yet-linked case. Smaller option: `existing ∪ {P}`. CUJ 4's "any other red page" blesses the swallowing; no CUJ for another unsynced red page. | Real design question. Needs author decision. |
| D2 | Major | Stale read: `existingCounted`/`linked` read from provider at tap time, writes unawaited; an in-flight `syncBookmarkPages` can write between read and `setLinkedBookmarkColor`, re-introducing the double-count. Non-goal defers this. | Same risk as Z4/C2. |
| D3 | Major | No Risks & Mitigations section. Missing: the race; the new dialog on X; re-entrancy if X is tapped repeatedly while the dialog is open; the `'no'` path uses `nav.pop()` after an await with no `mounted` check (`:364-367`); inflated data left in place with no communication. | Same as S1. |
| D4 | Major | "Juz mode not affected in the normal path" is undefined. If a color was linked in page mode and the user switches to juz mode, `linkedBookmarkColor` stays set; juz "Choose One" merges only the chosen page, so other pages of that color are "new" and auto-sync marks juz from them. Same bug family: out of scope (Non-Goals, UNVERIFIED) or needs a CUJ. Juz "Use all" (`:572-583`) never links a color; undiscussed. | Contradicts the doc's "VERIFIED by reading" juz claim for the mode-switch case. |
| D5 | Major | Alternatives: "Rejected by author" is not a rationale. A's reason ("only one caller is wrong") argues for A being safe. Missing alternatives: a merge-only service method; skipping `recordPagesRead` and letting sync count the page; for F38a, calling the handler directly. C's cost claims unquantified. | Same as S2. |
| D6 | Major | `maybePop` → `PopScope` is argued via Esc, which has no device evidence; PopScope semantics are Flutter-version dependent. Record the SDK version; a widget test would prove it. | Flutter 3.38.7 is in STATE.md. |
| D7 | Major | No testing/verification section in lines 1-164; test cases for the helper not listed. | Range artifact: the test plan and device checks S45/S46 are in the Detailed Implementation Plan (line 165+). Likely not a real gap; Stage 9 covers it. |
| D8 | Nit | Open Questions have no owner/deadline; "choose already-counted page adds twice" is a data-inflation vector of the same family. | Same as Z5/C3. |
| D9 | Nit | Rollback: a rolled-back build re-inflates counts; settings already written with the larger counted set persist (benign). | |
| D10 | Nit | Questions whether `.project-docs/modules/quran-wird.md` exists. | Exists (read earlier this session). Not a defect. |
| D11 | Nit | Add reproduction steps for the bugs. | |

## Structural (S)
| # | Sev | Finding |
| --- | --- | --- |
| S1 | Major | Missing "Risks & Mitigations" H2 (see D3). |
| S2 | Major | Alternatives rationales circular/appeal to unlinked rules (B cites "refactor rules"; C restates the decision). Rewrite as concrete trade-offs. |
| S3 | Major | "Additional Resources" is an H3 under Non-Functional Requirements; promote to H2 or fold into Overview. |
| S4 | Nit | Section names diverge from the standard ("The Problem" → Problem Statement; "Technical Plan (Architecture)" → Proposed Architecture). |
| S5 | Nit | "F38a/F38c/Juz mode" are bold pseudo-headings in The Problem; use H3. |
| S6 | Nit | Open Questions sits before CUJs and the plan; conventionally later. |
| S7 | Nit | File references are bare backtick paths, not links. |
| S8 | Nit | Trailing horizontal rule at line 163; confirm nothing was meant to follow. (Detailed plan follows; not a defect.) |

## Style (T)
| # | Sev | Finding |
| --- | --- | --- |
| T1 | Major | Calibration: "existing data and cloud sync work unchanged" (line 153) not shown checked; "stays a sorted `List<int>`" but plan builds a set and never says where it is sorted (the service sorts on write: `wird_service.dart:362`, `wird_provider.dart:161`). "No contracts touched" (156): "contracts" undefined. |
| T2 | Major | Terminology drift: khatma prompt / dialog / "Did You Finish?"; close button / X / `_TopBar.onClose`; counted set / counted pages / `countedBookmarkPages`. Pick one term each. |
| T3 | Major | "Normal path" (line 37) undefined (see D4). |
| T4 | Nit | "small" (line 11) is a judgment; delete. |
| T5 | Nit | Non-Goals "Use all" bullet overloaded; state the UNVERIFIED claim as such. |
| T6 | Nit | "The new strings are not needed" → "No new strings are added." |
| T7 | Nit | Open Questions wording: fragments, informal "Say if…"; rewrite as "Decision needed: …". |
| T8 | Nit | "(and any other red page)" (line 84) vague; state the exact set. |
| T9 | Nit | "Decided/Rejected by author" repeated; Rejection reasons restate Cons. |
| T10 | Nit | Line 143 cites unnamed "refactor rules"; this is a bug fix. Cite `CLAUDE.md`. |
| T11 | Nit | Alt C: "Explicit" vague; "600+ line file" imprecise (handler is ~75 lines). |
| T12 | Nit | "This is intentional" (line 116) → "This design intentionally…". |
| T13 | Nit | `pages` (line 120) used without introduction. |
| T14 | Nit | "Additional Resources" heading level (see S3). |
| T15 | Nit | Line 96 gloss "asks the route whether it can pop" can be cut. |

## Cross-stage overlaps
Race / unawaited writes: Z4, C2, D2. Duplicate-page guard: Z5, C3, D8. Risks section: D3, S1. Alternatives rationale: Z3, D5, S2, T9, T10. Juz "normal path": D4, T3. Heading level of Additional Resources: S3, T14.
