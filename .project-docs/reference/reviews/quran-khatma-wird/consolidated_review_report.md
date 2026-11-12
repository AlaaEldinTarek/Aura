# Consolidated Review — docs/designs/fix-quran-khatma-wird.md (F38a + F38c)

Date: 2026-11-11. Mode: consolidated (uninterrupted), all five stages, one pass per stage (no review loop, no re-audit). Reviewers: egm-zoom-out, egm-inventive-catalyst, egm-comprehension, egm-design, egm-structural, egm-style (×2), egm-implementation-readiness, egm-codebase-details. Context given: `quran_reader_screen.dart`, `wird_tab.dart`, `wird_service.dart`, `wird.md`. Design file NOT edited by this review.
Stage reports (same folder): `zoom_out_report.md`, `comprehension_report.md`, `critic_report.md`, `intermediate_zoom_out_report.md`, `implementation_readiness_report.md`.

## Verdict
No Blockers. Reviewers re-confirmed against code: the F38a and F38c bug descriptions, the two-caller grep, the juz-mode merge path, all cited lines. The design is not ready to implement as written: 4 decisions and several Major gaps need author action first.

## Decisions needed from the author (change code or design)
| # | Decision | Sources | Detail |
| --- | --- | --- | --- |
| 1 | Same-color-linked branch: `existing ∪ S` or `existing ∪ {P}`? | D1, Z-8 (Stage 8 #2) | `existing ∪ S` also marks other unsynced bookmarks of that color as counted without reading them (they would otherwise auto-count). "Intentional" is argued only for first link. Decide first; it sets the helper's inputs. Add a CUJ for another unsynced bookmark of the color. |
| 2 | Race / write ordering | Z4, C2, D2, I1 | `recordPagesRead` and `setLinkedBookmarkColor` are unawaited; each assigns provider state, which triggers `build()` auto-sync. In CUJ 4 the auto-sync can run against the old counted set and double-add page 100. Options: await in order (`setLinkedBookmarkColor` first, then `recordPagesRead`), which amends the Non-Goal; or accept and write the expectation into S46. |
| 3 | Keep the `countedPagesAfterChooseOne` helper, or inline? | Z1, Stage 8 #1 | One conditional behind a four-parameter function plus a new `@visibleForTesting` pattern (used once elsewhere in `lib/`). Depends on decision 1. |
| 4 | Juz mode-switch case | D4, T3, Stage 8 #7 | If a color was linked in page mode and the user switches to juz mode, the stale link stays and juz "Choose One" merges only the chosen page, so other pages of that color look new. Same bug family. Reviewers advise: reword the "not affected" claim to the never-linked case and add a Non-Goal marked UNVERIFIED. |
| 5 | Confirm dialog on X, and the double-add on Choose One | Z5, Z6, C3, D8, M9 | Mark "same as back" Decided (Goals/CUJ 2 assume it); mark the duplicate-page guard as deferred, or add the one-line guard. |

## Document fixes (no scope growth)
1. Add a Risks & Mitigations H2, one line each: the race; confirm dialog on X; X-tap re-entrancy while the dialog is open; `'no'` path `nav.pop()` after an await with no `mounted` check (pre-existing, `quran_reader_screen.dart:364-367`); inflated data left in place; rollback leaves the larger counted set (benign). (D3, S1, Stage 8)
2. Rewrite Alternatives rationales as concrete trade-offs; drop "Rejected by author" as a reason; cite `CLAUDE.md` instead of "refactor rules". A's real cost: "Use all" semantics on stale pages would change if the service merged. Add two alternatives: a merge-only service method; skip `recordPagesRead` and let sync count the page. (Z3, D5, S2, T9–T11)
3. Add one background paragraph and a one-line definition of `countedBookmarkPages` ("pages the sync should ignore"; the plan makes it that). Link `.project-docs/modules/wird.md` instead of explaining auto-sync internals. Add a worked example for the already-linked double-count. Say what `desktopSidebarVisibleProvider` controls. Fix terminology drift (khatma prompt, close button, `countedBookmarkPages`). (M1–M6, T2, C1)
4. Record the known limit: switching color and back re-counts everything; keep a baseline field / per-color map as a one-line follow-up only. (C1)
5. State the Flutter SDK basis (3.38.7 per STATE.md) for the `maybePop`→`PopScope` claim; S45 stays as proof. (D6)
6. Calibrate: "cloud sync works unchanged" and "no contracts touched" (T1); "sorted `List<int>`" (service sorts on write, `wird_service.dart:362`, `wird_provider.dart:161`); "normal path" (T3); "Use all" Non-Goal wording (T5).
7. Structure: promote "Additional Resources" to H2; H3 for the F38a/F38c/juz pseudo-headings; consider the standard's section names; Open Questions later in the document. (S3–S6)

## Implementation-plan fixes
1. Define phases: (1) helper + pure tests + service regression tests, `flutter test`; (2) `wird_tab.dart` call site; (3) `quran_reader_screen.dart`; (4) docs. "Tests first" as written cannot compile for the helper. (I3)
2. Make the service-level test concrete: read API for `pagesRead`, setup, page sets and expected values, `TestWidgetsFlutterBinding` choice. Resolve whether `WirdService.instance` works under test (repo convention `task_streak_test.dart` avoids the singleton; `updateSettings` → `cancelAllReminders()` path unconfirmed, UNVERIFIED). Say which tests fail on old code and which (negative control) pass on both; the negative control uses the real service call. (I2, W3, K5)
3. `wird_tab.dart` details: exact import answer (`material.dart` re-export of `visibleForTesting` is claimed by one reviewer, not confirmed, UNVERIFIED), nullable expressions, placement of the helper, keep local `pages` for the juz branch, expected result for the empty-list case. (I4)
4. Split item 7 into separate files with exact edits: STATE.md section, log file path, S45/S46 rows in the checklist's six columns, and which phase marks the findings fixed (after device check). (I5)
5. Doc-edit rows: give replacement text for `quran-wird.md` (sentence on line 32 only), `wird.md:49`, README (only the F38 mentions at ~43 and ~55; leave :29, :64, :103); anchor on quoted text, not line numbers. In item 1, do not remove `_isDesktop`; cite `:390`. (W5, W6, R6–R8, K6–K7)
6. Verification: name the `dart format` files (touched only), give a method for the 418-issue comparison and the expected new test total, re-run the 260 baseline before the first edit, state the "no automated coverage for the close button; F38a not marked fixed until S45 passes" claim. (W4, R9, K8–K9)

## Likely non-issues (reviewer limits)
- D7 (no testing section in lines 1-164): the plan and device checks are in the Detailed Implementation Plan; range artifact.
- D10 (does `quran-wird.md` exist): it does; read earlier in this session.

## Traceability
| Consolidated item | Raw findings |
| --- | --- |
| Decision 1 | D1, Stage 8 #2 |
| Decision 2 | Z4, C2, D2, I1, Stage 8 #3 |
| Decision 3 | Z1, Z2, Stage 8 #1, #5 |
| Decision 4 | D4, T3, Stage 8 #7 |
| Decision 5 | Z5, Z6, C3, D8, M9, T7 |
| Doc fix 1 | D3, S1, Stage 8 #8, D9 |
| Doc fix 2 | Z3, D5, S2, T9, T10, T11 |
| Doc fix 3 | M1–M6, T2, C1, M8 |
| Doc fix 4 | C1 |
| Doc fix 5 | D6, Stage 8 #9 |
| Doc fix 6 | T1, T3, T5, T6, T8, T12, T13 |
| Doc fix 7 | S3–S8, T14 |
| Impl fixes 1–6 | I1–I5, W3–W5, K1–K9, R6–R9, W6–W14 |
| Not carried | M7 (excerpts instead of line cites; Stage 8 advises against bloating a small-fix doc), M10, M11, D11 (reproduction steps; Stage 8: do not add), C4/C5 (nits, fold into impl fix 2/doc fix 3) |

## Limits of this review
One pass per stage, no antagonistic re-audit loop, no re-audit after edits. Structural and style reviewers (Stage 7) did not read the code. The close-button claim rests on code reading; no device or test run has been done by anyone. UNVERIFIED items are marked above.
