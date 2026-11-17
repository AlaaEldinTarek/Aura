# Intermediate Zoom Out Report (Stage 8, re-run)

**Target:** `docs/designs/chore-remove-test-notification.md`, full file (301 lines), against `zoom-out-standard.md`. This report replaces the first Stage 8 report, which reviewed the spec before the owner's trimming (late-final check removed, tests cut to R4 and D1, Decisions and Risks shortened).
**Reviewer:** `egm-zoom-out`, completed (direct dispatch), fresh context, read no earlier report. No spec change was made by this round.
**Verdict:** PASS (Nits only). No Blocker, no Major.

The reviewer confirmed against the code: the production change is one file with one defaulted parameter (`includeTestItem = kDebugMode`) and two collection-if entries; no new abstraction, no scheduler edit, no speculative feature. All cited `desktop_tray_service.dart` line numbers match (`buildMenu` `:154-170`, `_testNotifItem` `:132-139`, `_sepAfterTestNotif` `:148`, entries `:166-167`, `_rebuildMenu` `:172-183`, `case 'test_notif'` `:209-211`, `_fireTestAdhanFromMenu` `:252-260`). `fireTestAdhan()` has exactly one caller in `lib/`; the `profile_version_tile.dart` symbol is a separate constructor parameter. The "A2 step 6 result" heading exists in the A1 spec. The trimming left no broken reference and no real contradiction.

## Findings (all Nit)

* **zoomout8b-1** (lines 134-138, 242-248). Test ids R4 and D1 are leftovers from the earlier numbering: the spec has no R1 to R3 or D2, and the Risks section cites "Test R4" before the Detailed Implementation Plan defines it. *Recommendation:* call them "the release-mode menu test" and "the default test", or define the ids where first used.
* **zoomout8b-2** (lines 247-248). D1 is nearly tautological: it compares the default with `kDebugMode`, which is always true under `flutter test`, so it pins the default and cannot catch a release regression. The real release default is covered only by the owner's device check, as the spec admits. *Recommendation:* keep D1 as a one-line guard, or drop it and rely on R4 plus the device check (which also removes the "813 expected" arithmetic).
* **zoomout8b-3** (lines 87-110 vs 206-225). The same change is described in both the Technical Plan and the Detailed Implementation Plan (line numbers, signature, two conditions, "do not touch `_rebuildMenu`"); lines 108-110 add `late final` lazy-init and log-tag detail that does not change the decision. *Recommendation:* keep file-level steps in the Detailed Plan only.
* **zoomout8b-4** (lines 33-47, 54-55, 69-83, 148-182). More history than the change needs: Alternatives A and B describe a removed plan, Decisions 1 to 4 are mostly "unchanged" notes, the "reopened on 2026-11-16" story appears in the Overview, Decision 5 and Alternative A, and "no profile build is shipped" appears three times. *Recommendation:* merge A and B into one short "Removal (rejected)" entry and state the profile-build rationale once.
* **zoomout8b-5** (lines 184-193). "Follow-ups for `fix/adhan-stop`" sits under the Alternatives heading but is not an alternative; its five items are guidance for another branch and duplicate Decision 2 and Non-Goals text. *Recommendation:* reduce to one line or move to the STATE.md follow-up entry.
* **zoomout8b-6** (lines 271-273). The Verification intro says "six checks", but the list has seven bullets, because "Test Coverage Requirement: none" is the extra one. VERIFIED by the Elephant from the pasted section. *Recommendation:* drop that bullet or fix the count.
* **zoomout8b-7** (line 8). The branch is `chore/hide-test-notification-release` but the file is `chore-remove-test-notification.md`; line 265 acknowledges it for STATE.md only. *Recommendation:* add a one-line note near the title that the filename is kept from the earlier plan.

## Elephant's notes

* zoomout8b-6 and zoomout8b-1 are cheap, mechanical fixes. zoomout8b-2 to zoomout8b-5 are scope choices for the owner (several were deliberately kept or asked for earlier in the session: Alternative D, the Follow-ups items, the five-item Decisions list, the D1 default test).
* Stage 8 re-audit is now used (one re-run). Stage 9 (Implementation Readiness) has not run on this version of the spec.
