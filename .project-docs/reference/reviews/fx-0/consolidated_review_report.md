# FX-0 Consolidated Review Report
Target: `docs/designs/fx-0-prayer-settings.md` (507 lines; FeatureRange 1–339, DetailedRange 340–507) · Date: 2026-11-07
Mode: consolidated (Stages 5–9, no remediation between stages) · 11 Goldfish runs, fresh context, reading list of 10 files
(no `fx-0-decisions.md`). Stage reports in this folder: `zoom_out_report.md`, `comprehension_report.md`,
`critic_report.md`, `intermediate_zoom_out_report.md`, `implementation_readiness_report.md`.

**Overall verdict: NOT READY for "approve phase FX-0".** 2 Blockers, 26 Major action items, Nits grouped below.
Stage 8 advises settling the Kotlin scope (A3) first, because several other items shrink or disappear with it.

## 🔴 Blocker
| ID | Action | Raw findings |
| --- | --- | --- |
| A1 | Make the UI-string → enum mapping testable: public pure functions (e.g. `methodFromPref(String)`, `madhabFromPref(String)`) in a named file; notifier delegates; item 4 tests call them. Today's test plan cannot fail for Hanafi and does not compile for the new methods. | IR1, CD1 |
| A2 | Define the Kotlin Moonsighting Committee approximation (formula, adjustments, where documented) and add a placeholder table for the measured error — or remove the need via A3. | IR2, C3, SS6 |

## 🟡 Major
| ID | Action | Raw findings |
| --- | --- | --- |
| A3 | Settle Kotlin scope and window size N before other Kotlin items: (a) larger N + only cheap fixes (5 names, per-instant offset, rounding, fallback log), (b) JVM Adhan library, (c) current hand port. Write down why N. | Z1, I1, R1, D7, R7, T5 |
| A4 | State the anchor: 7-day window, fingerprint and `nextOccurrences` use wall-clock today, independent of `date` (`updateNextPrayer` caller of `:453` is dead code). | Z2, I2, R5, IR7, CD3 |
| A5 | Fingerprint concurrency/failure: synchronous compare-and-set before the async block; one latest-wins generation int checked before each platform write; "failed write lasts until next open/resume" as accepted risk. No backoff. | I5, D1, R2, IR7, CD14 |
| A6 | Side-effect order: write `updatePrayerTimes` and `cached_*` first, schedule alarms last (own try block); single alarm writer → Future Improvement. | I4 |
| A7 | Only prayer-derived effects behind the fingerprint; task digest (Firestore reads) and `cleanupFuturePrayerRecords` (Firestore deletes) keep the once-per-day date guard. Removes the record-deletion risk. | R6, D5 |
| A8 | Narrow CUJ 2 to adhan alarms; state the kept-post-check exception; document reliance on the 6 h duplicate guard for "old fired, new later" (Asr twice); add S30 mirror. | C1, I3, T1, D4, I8, R10 |
| A9 | Iqama for tomorrow-armed alarms: narrow CUJ 3 + S31 to the same day's next adhan; log a finding (gap exists today in native `reschedule`). | D3, R3, C6 |
| A10 | Correct the pre-prayer reminder sentence: no automatic reminder alarm; `scheduleReminderAlarm` is only the user's "remind me later" snooze (`main_wrapper_screen.dart:859`); out of scope. | T2, R4 |
| A11 | Cache loop: calendar-day arithmetic `DateTime(y, m, d + i)` for keys and dates; fixed-clock DST-eve test (7 distinct consecutive keys). | D2 |
| A12 | Prayer settings page: its save pops the dialog, not the page, so item 12 reloads only when the page is left. Accept + document, or change `_saveCalculationSettings` (needs `ref`; currently out of bounds). | CD2, D19 |
| A13 | Shared changes assume 7 days; mark window-dependent text as Option B (or window-neutral). | S4, T3, D15 |
| A14 | Add a Risks & Mitigations section from existing failure rows + A5, A7, A8, A11; one line each, no new mechanisms. | S1, D8, R9 |
| A15 | Alternatives: re-label (Alt-1…5) to avoid "Option B" collision; link each author decision to its record; add the JVM Adhan library alternative (if not chosen in A3). | S2, S3, D7, D17 |
| A16 | Kotlin test API: pure Android-free `internal fun calculate(...)` with typed params, `zone` argument (one mechanism everywhere), internal result type; logging stays in `calculateAndSave`. | D6, IR4, CD4, CD8, SS5 |
| A17 | Phasing: Step 2 must compile (stubs / signatures first, or tests co-land with their API); contract commit = items 7, 8, 10 (mapping), 13 (names only), 16; split the Kotlin port. | IR6, CD5, SS4 |
| A18 | Fixture spec: one table of city, lat, lng, IANA zone (Birmingham UK?), fixed test year, methods per city, MC rows; generator's own mapping; fixture check runs through the app's `getPrayerTimes` (merge with method × madhab check). | Z3, IR5, CD6, CD7, IR12, IR13, Z9 |
| A19 | Kotlin method table: values (or verbatim package source), `fixedAngle` = Egyptian, `proportional` = MWL (add to fixture), rounding mode per method, remove/replace the existing clamp and 1/7 fallback. (Shrinks under A3a.) | IR3, IR10, D10, D11, CD13 |
| A20 | Trigger tests: concrete inputs → expected result per test against the pure helpers; one place for "no old key survives" (device S32, "relies on … VERIFIED static"). | IR8, CD15, C2, SS3 |
| A21 | Item 11 is a no-op: drop it and `prayer_alarm_service.dart` from the boundary (or state the edit). | Z4, IR9, CD10 |
| A22 | Item 21 / scope table: the spec already exists; "Create … moved from `design_draft.md`" → commit/modify. | C15, IR15, CD9 |
| A23 | Give EN/AR display strings for the five new enum values (e.g. reuse `AdhanCalculationMethod` names); fix `:42–80`. | IR11, CD11 |
| A24 | Calibrate claims: Overview present tense; Goal 7 DST parenthetical (1 h only on Kotlin path); rollout (Kotlin math changes at install; Android downgrade impossible → rollback = old code, higher versionCode); "common for users…" (cite or drop); "fails today" → "expected to fail". | T4, T5, T6, T7, D18, SS2 |
| A25 | Define process terms: Level A/B/C and gates per step (B / C / A), ADR 0001 path, "approve B" vs "Option B", P6, Q1/decision refs (self-contained). | C4, C9, C11, S8, SS1 |
| A26 | Request codes: "five prayers" → 1001, 1003–1006 (1002 = Sunrise, never scheduled). | C5, D16, T13 |
| A27 | MC ceiling coverage: scope "every prayer" to the tested cities/latitudes (or add one city > 55° N). | D9, R1 |
| A28 | Fix the Markdown lazy continuation in shared change 4 (trigger-test spec renders inside the reminder bullet); make shared change 4 H4 sub-sections. | S5, S6 |

## 🟢 Nit (grouped)
| ID | Action | Raw findings |
| --- | --- | --- |
| N1 | Move evidence detail (DateTime.add, PendingIntent equality, file:line) out of Problem / Technical Plan; one evidence-tag set defined once. | Z8, T15, T19 |
| N2 | Remove duplication: Option A described twice; B rationale ×3; Goal 6 past tense; "No cancel call" duplicated; "written first, before any fix". | S7, T9, T10, T14, T20 |
| N3 | Header and Problem 5: add F51p; list solar position / Qatar / MC divergences in Problem 5; F51p cited for two things. | S9, S10, T21, C10 |
| N4 | Dead-code list in Future Improvements: `updateNextPrayer`, `setCalculationMethod`, `setAsrMadhab`, `PrayerAlarmService.scheduleReminderAlarm`, `NotificationService.scheduleDailyPrayers`; keep screens calling `loadPrayerTimes(now)` (do not reuse the setters). | R11, R8, Z6 |
| N5 | Fingerprint: note why method/madhab stay (native strings); if N rises, inputs + build number; NFR: per-minute post-Isha reloads. | Z7, I6, R7, D14 |
| N6 | Wording: location trigger sentence; Dubai rename rationale; Goal 2 "several cities"; Problem 4 drift claim; CUJ 4 tolerance (cache path is exact); off-by-one evening (D+7 Fajr). | T17, T18, T12, T11, T8, D13 |
| N7 | Definitions for a fresh reader: `makkah` = Umm al-Qura; post-prayer check; EGM folder contract; `cacheAccuratePrayerTimes` channel; "Prayer screen dialog" naming vs two `_saveCalculationSettings`. | C7, C8, C16, C17, C14 |
| N8 | Desktop refresh claim: cite provider `:329` or add a scenario; no desktop file in the boundary is intended. | C13, T16 |
| N9 | Paths and links: one root, Markdown links in Additional Resources; L266 overlong. | S11, S12, T21 |
| N10 | Implementation-plan precision: line refs (`:253`, `:403–426`); typed helper signatures; CSV header on one line; misplaced notes (items 15, 21); "edit carefully"; unknown-name warning is new; `calculateAndSave` "signature and cache-first order"; catch behaviour; item 14 await; new import; test/issue baseline source; "9 current enum names"; prefs-keys `cached_*` location column; `prayer_refresh.dart` vs `prayer_time_rules.dart` reason. | CD12, SS10, SS11, SS12, SS13, SS7, SS8, SS9, SS15, IR14, CD15, SS16, SS17, IR16, SS14, Z5 |
| N11 | Interface-level alternative as Future Improvement: Dart publishes resolved parameters to Kotlin. | I7 |
| N12 | Location trigger: what starts the next load on mobile. | C12 |

## Traceability Matrix
| Raw finding | → | Raw finding | → | Raw finding | → |
| --- | --- | --- | --- | --- | --- |
| Z1 A3 | Z2 A4 | Z3 A18 | Z4 A21 | Z5 N10 | Z6 N4 |
| Z7 N5 | Z8 N1 | Z9 A18 | I1 A3 | I2 A4 | I3 A8 |
| I4 A6 | I5 A5 | I6 N5 | I7 N11 | I8 A8 | C1 A8 |
| C2 A20 | C3 A2 | C4 A25 | C5 A26 | C6 A9 | C7 N7 |
| C8 N7 | C9 A25 | C10 N3 | C11 A25 | C12 N12 | C13 N8 |
| C14 N7 | C15 A22 | C16 N7 | C17 N7 | D1 A5 | D2 A11 |
| D3 A9 | D4 A8 | D5 A7 | D6 A16 | D7 A3/A15 | D8 A14 |
| D9 A27 | D10 A19 | D11 A19 | D12 A18 | D13 N6 | D14 N5 |
| D15 A13 | D16 A26 | D17 A15 | D18 A24 | D19 A12 | S1 A14 |
| S2 A15 | S3 A15 | S4 A13 | S5 A28 | S6 A28 | S7 N2 |
| S8 A25 | S9 N3 | S10 N3 | S11 N9 | S12 N9 | T1 A8 |
| T2 A10 | T3 A13 | T4 A24 | T5 A24/A3 | T6 A24 | T7 A24 |
| T8 N6 | T9 N2 | T10 N2 | T11 N6 | T12 N6 | T13 A26 |
| T14 N2 | T15 N1 | T16 N8 | T17 N6 | T18 N6 | T19 N1 |
| T20 N2 | T21 N3/N9 | R1 A3/A27 | R2 A5 | R3 A9 | R4 A10 |
| R5 A4 | R6 A7 | R7 A3/N5 | R8 N4 | R9 A14 | R10 A8 |
| R11 N4 | R12 A18 | IR1 A1 | IR2 A2 | IR3 A19 | IR4 A16 |
| IR5 A18 | IR6 A17 | IR7 A4/A5 | IR8 A20 | IR9 A21 | IR10 A19 |
| IR11 A23 | IR12 A18 | IR13 A18 | IR14 N10 | IR15 A22 | IR16 N10 |
| CD1 A1 | CD2 A12 | CD3 A4 | CD4 A16 | CD5 A17 | CD6 A18 |
| CD7 A18 | CD8 A16 | CD9 A22 | CD10 A21 | CD11 A23 | CD12 N10 |
| CD13 A19 | CD14 A5 | CD15 A20/N10 | SS1 A25 | SS2 A24 | SS3 A20 |
| SS4 A17 | SS5 A16 | SS6 A2 | SS7–SS17 N10 | | |
