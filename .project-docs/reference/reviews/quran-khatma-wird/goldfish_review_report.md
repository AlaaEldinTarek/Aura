# Goldfish Annotated Review Report

**Status:** resolved 2026-11-11; former section 6 items 1–6 applied afterwards (section 6A); round 2 recorded in section 7 (spec commits 953ec7a, 2eed355); second reviewer pass and spec approval remain open
**Target:** `docs/designs/fix-quran-khatma-wird.md` (full file, as revised 2026-11-11)
**Source findings:** `consolidated_review_report.md` and the five stage reports in this folder.
Layout note: findings are grouped by disposition, not one block per raw finding, because 70+ raw findings collapse into about 30 consolidated items (see the traceability table in `consolidated_review_report.md`).
Closing audit: every "applied" claim in section 2 was re-checked against the design file at close. Corrections are marked **[corrected at close]**.

## 1. ESCALATE — resolved by the user

| # | Item | Outcome |
| --- | --- | --- |
| E1 | Decision 1 applied to the already-linked branch only; whole-color marking kept on first link. | **Resolved: user chose to keep it.** CUJ 3 requires it (without it the auto-sync counts the other bookmarks, which is the F38c bug). No edit. |
| E2 | "In order" applied as link first, then `recordPagesRead`. | **Resolved: accepted.** Counted set stored as `List<int>`, but every writer dedupes through a Set, so a duplicate add is harmless (VERIFIED by reading). Link-first does not double-count the chosen page. Risks section updated (design lines 189–190): overlap with the auto-sync can lose one progress increment (undercount, never double-count); tap before Wird state loads is treated as a first link (known edge). "Accepted, not yet device-checked." |
| E3 | New UI string for the guard. | **Resolved: wording approved.** Key `wird_bookmark_already_counted`; English "This page was already added"; Arabic "تمت إضافة هذه الصفحة بالفعل". Added to `assets/translations/en.json` and `ar.json` after `wird_bookmark_added` (uncommitted); both parse with `json.tool`; the Arabic value is codepoint-identical to the approved string. Design item 2 and phase 2 updated. **Arabic remains UNVERIFIED pending native-speaker review.** |
| E4 | Checklist filter tag for S45/S46. | **Resolved: keep `F-APP`.** No edit. |

## 2. PROPOSE FIX — applied in the revision (re-checked at close)

| Finding(s) | Applied as | Close check |
| --- | --- | --- |
| D1, Stage 8 #2 (same-color branch) | Same-color: `existing ∪ {P}`; CUJ 4 has an unsynced page 200; rationale for first link vs later added. | Confirmed (lines 58, 96–98, 133–140). |
| Z4, C2, D2, I1 (race) | Both calls awaited, link first; Non-Goal rewritten; residual overlap in Risks and S46 step 3. | Confirmed (lines 60, 69, 136–138, 189). |
| Z1, Z2, Stage 8 #1/#5 | Helper kept per decision; signature given once, in the plan. | Confirmed (line 241). |
| D4, T3, Stage 8 #7 (juz) | "Never-linked state" wording; Non-Goal marked UNVERIFIED. | Confirmed (lines 51, 68). |
| Z5, Z6, C3, D8, M9, T7 | Open Questions "None", decisions listed; CUJ 6 and guard. | Confirmed (lines 198–204, 106–110). |
| D3, S1, Stage 8 #8, D9 | Risks & Mitigations section (race, edge case, close dialog, repeated taps, `'no'` path `mounted` gap, inflated data, rollback, color switch). | Confirmed (lines 187–196). |
| Z3, D5, S2, T9, T10, T11 | Rationales as trade-offs; D and E added; `CLAUDE.md` cited; "by author" dropped. | Confirmed (lines 155–185). |
| M1–M6, M8, T2, C1 | Background section; `countedBookmarkPages` definition; worked examples; sidebar meaning (`quran_reader_screen.dart:95`); approval levels glossed. | Confirmed, except terminology drift (section 6, item 3). |
| C1 known limit | Color switch re-count in Non-Goals and Risks. | Confirmed (lines 70, 196). |
| D6 | Flutter 3.38.7 recorded; S45 as proof. | Confirmed (line 120). |
| T1, T5, T6, T8, T12, T13 | Calibrated cloud-sync and "contracts" wording; one new string; exact set in CUJ 4; `pages` local named. | Confirmed (lines 67, 72, 96–98, 208–210, 243). |
| S3, S4 | "Additional Resources" is H2; headings renamed to Problem Statement / Proposed Architecture. | Confirmed. |
| S5, S6, S7 | H3 for F38a/F38c; Open Questions moved after Risks; links in Background and Additional Resources. | **Partial** (section 6, items 1–2). |
| I3 (phases) | Five phases with checks; note that call-site wiring is covered only by S45/S46. | Confirmed (lines 224–232). |
| I2, K2, W2, K5 (tests) | Helper cases with inputs and outputs; invariant and negative-control tests; best-effort service tests with probe and fallback; negative control uses the real service call. | Confirmed (lines 255–271). |
| W3 (tests contradict) | The "tests must fail on old behavior" sentence is gone; note at line 232 says call-site wiring is untested. **[corrected at close]** The earlier report said the design states which tests fail on old code; it does not. No automated test fails on the old call site, because the call site is untested. The helper tests cannot "fail on old code" (the helper is new) and the service-level tests do not depend on the call site. | Resolved by removal, not by the earlier claim. |
| I4, K1, W1 | Import stated explicitly; nullable handling; helper placement; local `pages` kept. | Import part corrected 2026-11-12: the explicit import was wrong and was dropped in `59f6c63` (no new import needed; see section 3, I4). The rest (nullable handling, helper placement, local `pages`) was confirmed at the time. |
| I5, K3, K4, W5, W6, R6–R8 | Items split per file; replacement text; README edits limited to two sentences; `_isDesktop` kept; S45/S46 rows with the six checklist columns; log file named. | Confirmed (lines 245–304). |
| W4, K8, K9, R9 | Baseline re-run; format check on named files; coverage claim stated with its gate. | Confirmed (lines 222, 308–312). |
| C4, C5 | Negative control labelled; both sheets share the color-filtered source. | Confirmed (lines 242, 267). |

## 3. CONTEST — not overruled

The user did not walk these in the interactive breakdown; per the resolve rules, contests are bypassed unless overruled. They stand as contested, except I4 (part), which was wrong and is withdrawn in its row.

| Finding | Evidence |
| --- | --- |
| **D7** "no testing section" | False for the file: `### Verification Plan` (line 306) and item 4, the test file (line 255). The reviewer was given lines 1–164 only. The user asked about this and was told it is false. |
| **D10** `quran-wird.md` may not exist | The file exists (`.project-docs/modules/quran-wird.md`). |
| **I4 (part)** "`material.dart` already re-exports `visibleForTesting`" | **Withdrawn: the reviewer's import claim was correct.** `material.dart` already provides `visibleForTesting` through `framework.dart` → `widgets.dart` → `material.dart` (`material.dart:200`, `widgets.dart:63`, `framework.dart:26–34`). The earlier contest was wrong, because it checked only `widgets.dart` line 18. The design was corrected in `59f6c63` (no new import). |

## 4. DECLINE (Nit, recorded, not applied)

*   M7: code excerpts instead of line cites (Stage 8 advised against bloating a small-fix document; most line cites were removed instead).
*   D11: reproduction steps (worked examples cover it).
*   W13: arrows as connectives in the test case list and diagrams.
*   S8: trailing rule at the end of the feature range.

## 5. Counts

*   Escalated: 4, all resolved by the user (2 with edits, 2 no change).
*   Proposed fixes: 20 rows; 19 applied (the two rows that were partial at close are complete after section 6A), 1 resolved by removal (W3).
*   Contested: 3; 2 stand (D7, D10); 1 withdrawn as wrong (I4, part: the import claim).
*   Declined: 4 recorded.
*   Remaining unaddressed: section 6.

## 6. NOT applied or not resolved at close

Items 1–6 were applied afterwards; see section 6A. Items 7–10 stay open (numbering kept).

7.  **No second reviewer pass.** The revision added content no reviewer has read: the guard and CUJ 6, the new string, the phases, the test cases, the Risks section, Alternatives D and E.
8.  **UNVERIFIED items:** service-level tests under `flutter test` (`cancelAllReminders` path); that `maybePop` stops stacked dialogs; the juz mode-switch bug; the "Use all" re-run double add; the Arabic wording (needs native-speaker review).
9.  **Spec not approved.** Design Status is still "Draft". No "approve phase" has been given. The two translation files were edited on the user's explicit request before that approval, on `fix/quran-khatma-wird`, uncommitted.
10. **Nothing committed.** The design, this review folder and the two JSON edits are uncommitted; nothing was pushed. No code under `lib/` or `test/` has been touched.

## 6A. Applied after close (former section 6, items 1–6)

Applied 2026-11-11 on the user's instruction; design line numbers as of the edit. Nothing committed.

| Former item | Change | Design line |
| --- | --- | --- |
| 1. S5 | "Juz mode, never-linked state" is now an H3 heading; the paragraph starts "Not affected." | 51 (paragraph 53) |
| 2. S7 | File references in the Target Files headings are links: items 1, 2 (both files), 3, 5, 6, 7, 8, 9, 10. Item 4 stays unlinked because the test file does not exist yet. The `.project-docs/log/2026-11-11.md` reference in phase 5 is a link too. | 238, 247, 252, 275, 280, 285, 290, 295, 300; 232; item 4 at 257 unlinked |
| 3. T2 | Diagram says "khatma prompt" instead of "khatma dialog". | 126 |
| 4. W10 | The `project-log` step moved out of item 10 into phase 5; item 10 keeps "Record results only after the checks run." | 232 (phase 5), 306 (item 10) |
| 5. W14 | Heading is "E2E/Integration (device)"; the device name moved into the text ("on the nova 5T"). | 314 |
| 6. M10, M11 | Cloud push explained in the service-level probe bullet (Firestore sync for signed-in users; reads `FirebaseAuth.instance`; failure expected without Firebase and caught by `.catchError`; UNVERIFIED until the probe runs). README edit scope explained: other F38 mentions (lines 29, 64, 103) are about F38b, F38e and a general pointer, so they stay. | 273 (cloud push), 288 (README scope) |

Related rows in section 2 (S5/S6/S7 and M1–M6) are now fully applied.

## Handoff
Escalated 4 (all resolved); proposed-fix rows 20 (17 confirmed, 1 resolved by removal, 2 partial); contested 3 (2 stand, 1 withdrawn as wrong: the I4 import claim); declined 4; remaining open: section 6 items 7–10 (no second reviewer pass, UNVERIFIED items, spec not approved, nothing committed). Former items 1–6 are applied (section 6A).

(Superseded in part by section 7: the design is now committed, so "nothing committed" in item 10 no longer holds for the design file.)

## 7. Round 2: short review of the revised sections, and spec commits 953ec7a and 2eed355

Date: 2026-11-11. Branch `fix/quran-khatma-wird`. Both commits contain design text only (`docs/designs/fix-quran-khatma-wird.md`); no code, no tests, no translation files.

*   `953ec7a`: adds the design (Level A, spec only), including S46 step 3 and CUJ 4 stating that the "linked color with unsynced bookmarks" state cannot be reproduced on a device.
*   `2eed355`: applies the decisions from this round (below).

**Review run:** one egm-design reviewer, one pass, on selected sections only (the guard, CUJ 6, the new string, Risks, Alternatives D and E, the cloud push explanation). Result: 4 Majors, no Blockers. Sections not reviewed in this round were not re-checked.

### 7.1 Resolved in spec (text applied in `2eed355`; not verified by any test or device run)
1.  **Guard wording:** option (c). The string "This page was already added" is kept; a "Guard message wording" bullet in Risks records that it also fires for pages that were only baselined and may be revisited after native review.
2.  **"Never a double-count":** replaced in Risks with "no double-count when a sync is idle", plus the two cases that can still re-count pages: (a) a sync already running at tap time writes back an older counted set, (b) a stale provider snapshot.
3.  **Unconditional Goals bullet:** qualified with "when the same color is already linked and the Wird state is loaded or, when it is not yet loaded, `initialState` is used", plus a note that the read can be stale.
4.  **Tap before the Wird state loads:** the design reads `ref.read(wirdStateProvider).valueOrNull ?? widget.initialState`; the F38c approach, Target Files item 1 and helper unit case 7 were updated, the Risks bullet was rewritten as a defensive fallback, and the unit count went from six to seven. Described as unreachable on a device; that description is UNVERIFIED (see 7.2).
5.  **S46 overlap case:** S46 step 3 now uses a red-to-green color switch; S46 and the Risks bullet say the already-linked case with unsynced bookmarks is not reproducible on a device and is covered by unit helper case 5 only. This also removes the Risks text that named Alternative D as a follow-up it cannot fulfil.

### 7.2 UNVERIFIED (not resolved, not verified)
*   The Arabic wording "تمت إضافة هذه الصفحة بالفعل": pending native-speaker review.
*   The service-level `flutter test` claims (`WirdService.instance` under test, the `cancelAllReminders` path, the `_pushToCloud` failure being caught): the probe has not been run.
*   `maybePop` double-tap behavior (dialogs not stacking): not run on a device.
*   The juz mode-switch bug: not reproduced.
*   The "Use all" re-run double add: not investigated.
*   That `WirdTab` builds the content view only inside `when(data:)`, so `initialState` always exists and "tap before load" cannot happen on a device: from reading `wird_tab.dart:27–31` only; not confirmed in the running widget tree.
*   Also still unverified: S45 and S46 on a device (not run), and every claim in the design marked "VERIFIED by reading".

### 7.3 STILL OPEN
*   **Second reviewer pass:** the design was revised several times after the last full review (guard, CUJ 6, new string, phases, tests, Risks, Alternatives D and E, `initialState`, S46); this round reviewed only selected sections once.
*   **Spec approval:** design Status is still "Draft"; no "approve phase" has been given for Level C (`lib/`, `assets/translations/`, `test/`).
*   **Uncommitted:** `assets/translations/en.json` and `ar.json` (new key `wird_bookmark_already_counted`) and the review reports in this folder. They are not in `953ec7a` or `2eed355`.
