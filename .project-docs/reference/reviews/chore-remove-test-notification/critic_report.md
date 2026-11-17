# Critic Report (Stage 7, round 2: redesigned spec)

**Target:** `docs/designs/chore-remove-test-notification.md`, FeatureRange lines 1-214 (the spec is 350 lines; the Detailed Implementation Plan from line 215 is Stage 9). This report replaces the round-1 report, which reviewed the earlier "remove the item" design.
**Dispatch:** direct (the synthesizer handed back without results last time). Reviewers were fresh, read no earlier report, and the Elephant wrote this file. No fix is applied; the spec was not changed by this round.
**Line numbers** below are the reviewers' own, taken from the spec as it stood at dispatch.

## Reviewer Status

| Reviewer | Standard | Status | Findings |
| --- | --- | --- | --- |
| `egm-design` | feature-spec-standard | completed | 5 Major, 4 Nit |
| `egm-structural` | feature-spec-standard | completed | 5 Major, 6 Nit |
| `egm-style` | none | completed | 3 Major, 10 Nit |

No Blockers. After merging overlap the list is **0 Blocker, 8 Major, about 12 Nit**. The reviewers who read code (`design`, `structural`) found the cited `desktop_tray_service.dart` line numbers and the description of the change correct. `egm-style` did not open the code. `egm-design` did not open the scheduler file or the A1 spec, so claims about those two files were not checked by it.

## Consolidated findings

### Major

**C1. "Alternative A" means two opposite things** (style-2-1, structural-2-1, design-2-1). In Decisions (Question 1 `:69-70`, Question 5 `:88`) "Alternative A" is the chosen design (hide in release). In Alternatives Considered (`:178`) "Alternative A" is "Remove the item entirely", the rejected one. VERIFIED by the Elephant with grep. This was introduced by the redesign. Design adds that the chosen design is not listed as an option, and that `!kReleaseMode`, a `--dart-define` or runtime flag, and similar variants were not weighed (structural-2-11 also asks for "Alternative D: `!kReleaseMode`"). *Recommendation:* use unique labels (for example "Option 1 Remove", "Option 2 Remove and also `fireTestAdhan()`", "Option 3 Keep and fix", "Option 4 Hide via `kDebugMode` (chosen)"), fix the two references in Decisions, and add `!kReleaseMode` (and a dart-define variant) with concrete reasons.

**C2. "Open Question N" vs "Decisions"** (style-2-4, structural-2-2). The spec says "Open Question 3/5" in the Status line, Overview, Decisions and elsewhere (VERIFIED: `:4, :20, :70, :174, :278-279`), but the section is now "Decisions" with "Question N" items. This is fallout from the M3 retitle. *Recommendation:* one term throughout, for example "Decision D1 to D5".

**C3. The tests cannot cover the production release default** (design-2-3). Tests run in debug mode, so D1 only pins the debug default, and R4 tests `includeTestItem: false`, not what a release build does. The Risks bullet at `:148` ("R4 asserts that no such item exists in release mode") reads as if R4 proves the release menu. *Recommendation:* say plainly that the release default is covered by the release-build device check, or make the default testable (for example a small getter); reword `:148`.

**C4. Contradiction about the late-final claim** (style-2-2, design-2-4). `:121-122` states as fact that a release build "never reads" the two `late final` fields; `:152-153` says the same claim is "not yet proven". *Recommendation:* reword the Technical Plan to "is expected not to read them (see the late-final check)". Design also says the temporary log line is not described in the reviewed range. The Verification Plan (outside this range) does specify the temporary edit and the capture method (steps a to d), so that part is a pointer problem, not a missing step.

**C5. Unresolved references inside the reviewed range** (style-2-3, structural-2-5). "Test R4" is never labelled in the Tests section (`:161-174`) and "the late-final check in the Verification Plan" sits in the out-of-scope part. VERIFIED: R1 to R4 and D1 are defined only in the Detailed Implementation Plan. *Recommendation:* label the tests R1 to R4 and D1 in the Tests section and name the Verification Plan heading in the pointer.

**C6. Verification gap for `fix/adhan-stop` in release builds** (design-2-5). Debug builds reproduce the fault, but the shipped (release) configuration has no manual trigger, so a fix cannot be confirmed there without a real prayer time. Decision 2 states this in one sentence. *Recommendation:* add it as a risk with the mitigation "a real prayer time check, owned by `fix/adhan-stop`".

**C7. Rejection reasons rest on "Rejected by author" with no link** (design-2-2, structural-2-4). This repeats critic finding M2 from round 1, which the Elephant partly contested: the draft workflow prescribes the form "Rejected by author: [technical rationale]" and asks for a link only when a maintainer is quoted. The Cons lines already hold the trade-offs. *Recommendation (reviewers'):* lead each reason with the trade-off.

**C8. "Risks & Mitigations" and other sub-blocks are bold run-in labels, not headings** (structural-2-3). The standard lists Risks & Mitigations as a required area. The owner approved "No new section" for the rename, and promoting it to a heading would change that. The reviewer also asks for one line on security and scalability (for example "none: compile-time menu entry only"). *Recommendation:* promote Risks & Mitigations (and Tests, Behavior after the change) to H3 headings, or record that it stays a run-in by owner decision.

### Nits

* **N1** Decision history (first decision, reopening, rename) is told in Overview, Decision 5 and Alternative A's rejection reason (style-2-5). Keep it once.
* **N2** "Only the two `buildMenu` entries become conditional" appears three times, and Goals items 2 and 3 duplicate Non-Goals and "Kept unchanged" (style-2-6, structural-2-7).
* **N3** The Stop Adhan fault ("fails as built") is described three times (style-2-7).
* **N4** The profile-build justification is stated three times, and "no profile build is shipped" has no cited source (style-2-8, design-2-7).
* **N5** Wording: "One wrong click starts the adhan" / "Today one build behaves the same in both modes" (style-2-9); "The device check is on Windows" is ambiguous and "The change is small and" is a subjective claim (style-2-10, structural-2-10).
* **N6** "owner", "author" and the pronoun "he" are used for the same person (style-2-11).
* **N7** The "Note:" bullet inside the Risks list states a fact, not a risk (style-2-12).
* **N8** "Follow-ups for `fix/adhan-stop`" is an H3 under Alternatives Considered and the line "No doc changes are needed beyond the usual STATE and log entries" reads as a contradiction with it (style-2-13, design-2-8, structural-2-6).
* **N9** Heading names differ from the standard ("Technical Plan (Architecture)" vs "Proposed Architecture"); Overview and The Problem overlap (structural-2-8).
* **N10** The menu diagram has three columns and no caption; the fourth case (debug build with the adhan playing) is only in prose (structural-2-9).
* **N11** The file name and git history say "remove"; the branch and title say "hide" (design-2-6). Add a one-line history note or rename.
* **N12** The Problem states the wrong-click risk without evidence of an incident (design-2-9).

## Elephant's notes

* VERIFIED by grep: C1 (`:69-70, :88` vs `:178`), C2 (`:4, :20, :70, :174, :278-279`), C4 (`:121-122` vs `:152-153`), C5 (R4 labelled only in the Detailed Implementation Plan).
* C7 and C8 repeat or override earlier owner decisions (M2 contested, "No new section"). They stay open for the owner's call, not as settled fixes.
* C3 is a real limit of unit tests. The release-build device check (owner) and the late-final check already cover the release default; the spec text overstates what R4 proves.
* The reviewers did not see the Detailed Implementation Plan, so C4's "temporary log line is not described" is partly a pointer problem, as noted.
* `desktop_tray_service.dart` line numbers cited in the spec matched the file for both reviewers that opened it (`:3, :10, :132-139, :148, :157, :166-167, :172-183, :209-211, :252-260`).
