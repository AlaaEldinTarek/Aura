Status: resolved (2026-11-07)

Author decisions: A3 = (a) full parity, Moonsighting Committee ported line by line, no release dependency; stop and
ask if the port exceeds about 2× its estimate (Alt-6 JVM library = fallback). A2 approved (exact port; approximation,
2-min ceiling, stop rule and A27 removed; every method ±1 min). A9 approved (F54a, MEDIUM, out of FX-0). A12
approved (boundary → `PrayerSettingsPage._saveCalculationSettings`). N11 declined. All other PROPOSE FIX items
auto-accepted and applied to the spec (full rewrite of `docs/designs/fx-0-prayer-settings.md`).
Counts: accepted 39 (incl. 4 author-decided) · contested 0 · escalated 0 · declined 1 · unaddressed 0.

# Goldfish Annotated Review Report

**Target:** `docs/designs/fx-0-prayer-settings.md` (`full file`, 1–507)
**Findings source:** `consolidated_review_report.md` (A1–A28, N1–N12; raw IDs traced there)
**Author decisions needed:** A3, A2 (linked), A9, A12 — marked **[AUTHOR]**.

Facts checked by the Elephant for this report (read-only, 2026-11-07):
- `updateNextPrayer()` has no caller in `lib/` → the "tomorrow-dated load" in Z2/IR7/CD3 is dead code.
- `scheduleReminderAlarm` channel: only call site `main_wrapper_screen.dart:859` (user snooze); `PrayerAlarmService.scheduleReminderAlarm` (`prayer_alarm_service.dart:99`) has no caller.
- Package Moonsighting Committee logic = `prayer_times.dart:163–167, 172–180, 199–219` (≥ 55° rule, seasonal safe bounds) + `_seasonAdjustedMorningTwilight` / `_seasonAdjustedEveningTwilight` / `daysSinceSolstice` (`:335–405`): about 60 lines of piecewise-linear math, no new astronomy.
- Package high-latitude handling applies the night-portion "safe" bound on **every** day (`:169–184, 206–219`), confirming D10.

## Prioritized Findings & AI Suggestions

### [A1] [`egm-implementation-readiness`, `egm-codebase-details`] - Severity: Blocker
*   **Affected Scope:** Lines 380-389 (Step 2, item 4); 407-418 (items 7, 10)
*   **Discrepancy Description:** The core P1/P2 test cannot fail as promised: `getPrayerTimes` takes enums; the UI-string mapping is private in the notifier.
*   **Rationale:** F36a regression stays untested; implementer must invent the seam.
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Justification:*** Valid. `prayer_settings.dart` has no imports (pure Dart) and already holds both enums, so it is the natural home.
*   ***Proposed Edit:***
    *   Location: item 7; item 10 first bullet; item 4 first bullet.
    *   Change: item 7 adds top-level `CalculationMethod calculationMethodFromPref(String? value)` (UI values `'MuslimWorldLeague'`, `'UmmAlQura'` → `makkah`, …, the five new ones; enum names accepted as today; unknown/null → `muslimWorldLeague`) and `AsrMadhab asrMadhabFromPref(String? value)` (case-insensitive; unknown/null → `shafi`). Item 10: `_getCalculationMethod` / `_getAsrMadhab` delegate to them. Item 4: tests call these two functions for every UI value × madhab string, then `getPrayerTimes` with the result vs the package.

### [A2] [`egm-implementation-readiness`, `egm-comprehension`, `egm-style`] - Severity: Blocker — **[AUTHOR]**
*   **Affected Scope:** Lines 15-16, 48-49, 203, 221-225, 460
*   **Discrepancy Description:** The Kotlin Moonsighting Committee "documented approximation" is never defined.
*   **Rationale:** Zero-decision rule broken for the one allowed exception.
*   ***AI Suggestion:*** PROPOSE FIX (needs the author's OK: it replaces the approximation decided 2026-11-07)
*   ***Justification:*** An approximation without the seasonal terms would miss the 2-min ceiling at London/Toronto (the seasonal Isha bound moves by tens of minutes over the year), so the stop rule would trigger. The exact package logic is about 60 lines (facts above). Porting it is less work than defining, documenting and validating an approximation.
*   ***Proposed Edit:***
    *   Location: Overview, Goal 2, divergence table MC row, shared change 6 MC bullet, item 6, item 13, Alternative C.
    *   Change: Moonsighting Committee is ported exactly (package `prayer_times.dart:163–219, 335–405`), held to ±1 min like every method; remove "approximation", the 2-min ceiling and the stop rule; Alternative C becomes the chosen approach with the reason above. (If A3 = option a, this row becomes "exact port" too — it is cheap either way.)

### [A3] [`egm-zoom-out`, `egm-inventive-catalyst`, `egm-design`] - Severity: Major — **[AUTHOR]**
*   **Affected Scope:** Lines 14-16, 44-49, 192-206, 231-257, 295-300, 451-464
*   **Discrepancy Description:** Full Kotlin parity is the largest cost but under B protects only a fallback; N = 7 is unexplained.
*   **Rationale:** False compromise; scope decision should come first.
*   ***AI Suggestion:*** PROPOSE FIX — part 1 (record the reason) is mechanical; part 2 (scope) is the author's choice.
*   ***Justification:*** The parity requirement comes from the author's rule "native times must never differ from Dart times", recorded only in `fx-0-decisions.md`, which the reviewers were not given. A human reader of the spec also needs it, so it belongs in Goals. Whether to keep full parity is an architecture choice → author.
*   ***Proposed Edit:***
    *   Part 1 (Goal 2): add "Reason: the adhan users hear must equal the time the app shows, also on the fallback path (author rule, 2026-11-07)." and "N = 7: the week covers normal gaps between opens; larger N is possible but grows the prefs rewrite on every open."
    *   Part 2 (choose one): (a) keep full parity as written (with A2 exact MC); (b) raise N (e.g. 30) and limit Kotlin to 5 names + per-instant offset + rounding + fallback log; (c) JVM Adhan library (adds a release dependency — conflicts with the "test-only dependency" boundary).

### [A4] [`egm-zoom-out`, `egm-inventive-catalyst`, `egm-implementation-readiness`, `egm-codebase-details`] - Severity: Major
*   **Affected Scope:** Lines 150-161 (shared change 4); items 9-10
*   **Discrepancy Description:** Which date anchors the 7-day window, fingerprint and `nextOccurrences`.
*   ***AI Suggestion:*** PROPOSE FIX (contest the dead-code premise only)
*   ***Justification:*** The cited tomorrow-dated call (`prayer_times_provider.dart:453`) is in `updateNextPrayer()`, which has no caller (fact above); all live callers pass `DateTime.now()`. The anchor still needs one sentence.
*   ***Proposed Edit:*** shared change 4, after the fingerprint definition: "The window (today … +6), the fingerprint and `nextOccurrences` always use the wall-clock local date, independent of the `date` argument of `loadPrayerTimes`." Add `updateNextPrayer` to the dead-code list (N4). No extra tomorrow-dated test.

### [A5] [`egm-design`, `egm-inventive-catalyst`, `egm-codebase-details`] - Severity: Major
*   **Affected Scope:** Lines 150-161; 254; item 10
*   **Discrepancy Description:** Overlapping loads and failed effects under the fingerprint.
*   ***AI Suggestion:*** PROPOSE FIX (Stage 8's smaller version)
*   ***Proposed Edit:*** shared change 4: "The fingerprint is compared and stored synchronously before the async side effects start (as `_lastSideEffectsDate` is today). Each run takes a generation number; before each platform write it checks it is still the latest run and stops otherwise. A failed write is not retried in the same notifier; the next app open or resume (new notifier, empty fingerprint) rewrites everything — accepted risk." Add test: two overlapping runs → only the later run's values are written.

### [A6] [`egm-inventive-catalyst`] - Severity: Major
*   **Affected Scope:** Lines 120-131; item 10
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** item 10 new bullet: "Order inside the side effects: `updatePrayerTimes`, then `cacheAccuratePrayerTimes`, then adhan alarms and post-checks (each in its own try/catch), so a native recalculation that runs in between reads the new data." Future Improvements: "single alarm writer (Dart publishes data, native schedules)".

### [A7] [`egm-zoom-out` (Stage 8), `egm-design`] - Severity: Major
*   **Affected Scope:** Lines 150-161; item 10
*   **Discrepancy Description:** The fingerprint would also re-run the task digest (Firestore reads) and `cleanupFuturePrayerRecords` (Firestore deletes) on every input change; later Asr can delete a legitimate record.
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** shared change 4: "Only prayer-derived effects run on a fingerprint change: post-checks, adhan alarms, widgets, desktop timers, `updatePrayerTimes`, `cached_*`. The daily task digest and `cleanupFuturePrayerRecords` keep the once-per-day date guard unchanged." Item 10 matches.

### [A8] [`egm-comprehension`, `egm-inventive-catalyst`, `egm-style`, `egm-design`] - Severity: Major
*   **Affected Scope:** Lines 84-88 (CUJ 2); 166-182; S30
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** CUJ 2 Then: "…No adhan alarm fires at a method-X time. Exception: a post-prayer check whose new time + 30 min is already past keeps its old alarm and fires once." Stale alarms: add "If the old time already fired and the new time is later (Shafi → Hanafi after Asr), today's Asr is armed again; a second adhan is prevented only by the existing 6 h duplicate guard (`PrayerAlarmReceiver.kt:486–495`), which FX-0 relies on and does not change. The post-check may ask twice." Add S35: mirror of S30 (Shafi → Hanafi after the Shafi Asr fired → no second adhan).

### [A9] [`egm-design`, `egm-zoom-out`, `egm-comprehension`] - Severity: Major — **[AUTHOR]**
*   **Affected Scope:** Lines 90-93 (CUJ 3); S31; item 14
*   **Discrepancy Description:** Alarms armed for tomorrow read today's (past) `*_iqama_time`; native never writes iqama.
*   ***AI Suggestion:*** PROPOSE FIX (scope narrowing = author OK)
*   ***Justification:*** The gap exists today (native `reschedule` arms tomorrow without iqama). Fixing it needs new keys and out-of-bounds files.
*   ***Proposed Edit:*** CUJ 3 / S31: "the next Maghrib adhan **today**". Add to Problem/Risks: "Iqama countdown for an alarm armed for tomorrow uses today's iqama instant (existing gap; next-occurrence scheduling now also reaches it). Logged as new finding F54a, out of FX-0." New finding goes to `findings.md` (item 20).

### [A10] [`egm-style`, `egm-zoom-out` (Stage 8)] - Severity: Major
*   **Affected Scope:** Lines 183-185
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** replace the bullet with: "Pre-prayer reminders: no reminder alarm is scheduled automatically. The `scheduleReminderAlarm` channel is called only by the user's 'remind me later' snooze (`main_wrapper_screen.dart:859`); `PrayerAlarmService.scheduleReminderAlarm` and `NotificationService.scheduleDailyPrayers` have no caller. The snooze is user-started and short-lived; out of scope."

### [A11] [`egm-design`] - Severity: Major
*   **Affected Scope:** Lines 163-164; item 9-10
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** item 9 `buildNativeCache` / item 10: "Day i = `DateTime(now.year, now.month, now.day + i)` (calendar days, not `add(Duration(days: i))`), used for both the key and the calculation." Item 5 test: clock fixed at 23:30 on a DST eve → 7 distinct consecutive date keys.

### [A12] [`egm-codebase-details`, `egm-design`] - Severity: Major — **[AUTHOR]**
*   **Affected Scope:** Lines 156, 446-450 (item 12); Target Scope
*   **Discrepancy Description:** `PrayerSettingsPage._saveCalculationSettings` pops the dialog, not the page; item 12 reloads only when the page is left.
*   ***AI Suggestion:*** PROPOSE FIX (boundary change = author OK)
*   ***Justification:*** CUJ 2 says "without restarting … use method Y"; waiting until the page is closed breaks it. Reloading in the save itself needs no widget-type change: `ProviderScope.containerOf(context, listen: false).read(prayerTimesProvider.notifier).loadPrayerTimes(DateTime.now())`.
*   ***Proposed Edit:*** item 12: "`PrayerSettingsPage._saveCalculationSettings` (`:1544–1557`): after saving, reload via `ProviderScope.containerOf(context, listen: false)` (in try/catch, debugPrint on failure), before `Navigator.pop`. `_showPrayerSettings` unchanged." Target Scope: `prayer_screen.dart` (only `PrayerSettingsPage._saveCalculationSettings`).

### [A13] [`egm-structural`, `egm-style`, `egm-design`] - Severity: Major
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** rename "Shared changes (both options)" → "Changes (chosen design, Option B)"; Option A text keeps "today + 2"; shared change 3 "each cached day".

### [A14] [`egm-structural`, `egm-design`] - Severity: Major
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** new H2 "Risks & Mitigations" after Non-Functional Requirements, one row each: Dart calc bug (fixture + per-date tests); Kotlin fallback bug (parity test, fallback log); failed write (next open/resume rewrites; A5); overlapping runs (generation check; A5); stale post-check fires once (A8); second adhan relies on 6 h guard (A8); iqama for tomorrow-armed alarms (A9, F54a); DST-eve key gap (A11).

### [A15] [`egm-structural`, `egm-design`] - Severity: Major
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** rename alternatives Alt-1 … Alt-5 (+ Alt-6 JVM Adhan library: exact results, cost = release dependency, licence review; rejected because FX-0 allows only a test-only dependency — unless A3 = c). Each "Rejected by author" gets "(recorded in `docs/designs/fx-0-decisions.md`, decision N)" as a Markdown link; Alt-2 (entry point) reads "Rejected by the author when approving the Technical Plan (2026-11-07)".

### [A16] [`egm-design`, `egm-implementation-readiness`, `egm-codebase-details`, `egm-style`] - Severity: Major
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** item 13: "`internal fun calculate(lat: Double, lng: Double, year: Int, month: Int, day: Int, zone: java.util.TimeZone, method: String, madhab: String): PrayerResult` — `PrayerResult` becomes `internal`. `calculate` and the method table make no `android.*` calls (no `Log`); warnings and the fallback log stay in `calculateAndSave` / `cachedOrComputed`. Hence `junit` alone suffices (no `testOptions`)." Item 6 and shared change 6: "passes the row's IANA zone as `zone`".

### [A17] [`egm-implementation-readiness`, `egm-codebase-details`, `egm-style`] - Severity: Major
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** Step 2: "Step 2 first adds compiling stubs: the five enum values with their switch cases (items 7, 8), the two `…FromPref` functions with today's mapping, `prayer_refresh.dart` signatures returning today's behaviour, and the Kotlin `internal calculate` wrapping today's math. Tests then compile and fail on assertions." Contract commit: "items 7 (enum + mappers), 8 (adhan mapping cases), 13 (method names in the table only) and 16". The Kotlin math port is a separate commit.

### [A18] [`egm-zoom-out`, `egm-implementation-readiness`, `egm-codebase-details`] - Severity: Major
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** shared change 6 gets one table: city, lat, lng, IANA zone — Cairo, Makkah, Doha, Dubai, Istanbul, Singapore, Karachi, Tehran, Toronto, New York, London, Birmingham (UK, Europe/London), Oslo. Test year 2026; dates: solstices, equinoxes, DST start/end of Africa/Cairo, Europe/London, America/Toronto, America/New_York. Every method × madhab for every city (MC included everywhere, incl. Oslo, if A2 = exact port). Item 2: the generator has its own copy of the name → package method mapping and the +3 (it cannot import Flutter code). Item 4: one check — the app's `getPrayerTimes` output equals each fixture row (merges the two Dart checks).

### [A19] [`egm-implementation-readiness`, `egm-design`, `egm-codebase-details`] - Severity: Major
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** item 13: "Method table copied verbatim from `adhan-2.0.0+1/lib/src/calculation_method.dart` `getParameters()` (angles, interval, Maghrib angle, adjustments) for the 12 package-backed names; `fixedAngle` uses Egyptian parameters and `proportional` uses MWL parameters (same as Dart, `prayer_times_service.dart:269–274`) — both added to the fixture; `makkah` adds Dhuhr +3. Rounding: `CalendarUtil.roundedMinute` for every method (package rounds the same way for all). The existing clamp and 1/7 fallback (`:118–145`) are replaced by the package's safe-bound logic (night portions every day; MC: seasonal bounds and the ≥ 55° rule)."

### [A20] [`egm-implementation-readiness`, `egm-codebase-details`, `egm-comprehension`, `egm-style`] - Severity: Major
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** item 5 lists each test as inputs → expected result against `sideEffectsFingerprint` / `buildNativeCache`: method change (different `days`) → fingerprint differs; madhab → differs; iqama map → differs; location (days computed for other coordinates) → differs; adjustment (days computed with different params) → differs; fresh notifier = empty previous fingerprint → run; same inputs → equal fingerprint → no run; plus A5 overlap and A11 DST-eve tests. Shared change 4 drops "no old `cached_*` key survives" from the Dart tests: "relies on `MainActivity.kt:698–704` (VERIFIED static); checked on device in S32".

### [A21] [`egm-zoom-out`, `egm-implementation-readiness`, `egm-codebase-details`] - Severity: Major
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** delete item 11; remove `prayer_alarm_service.dart` from the Target Scope (move to out-of-bounds with "no change: already schedules every entry and skips past ones"). Renumber.

### [A22] [`egm-comprehension`, `egm-implementation-readiness`, `egm-codebase-details`] - Severity: Major
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** item 21: "`docs/designs/fx-0-prayer-settings.md` (Modify: status → Approved) and `docs/designs/README.md` (list it)"; Target Scope: drop "(new)".

### [A23] [`egm-implementation-readiness`, `egm-codebase-details`] - Severity: Major
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** item 7: `displayName` / `displayNameAr` reuse the `AdhanCalculationMethod` `nameEn` / `nameAr` strings for Qatar, Dubai (`'Dubai'`), Turkey, Singapore, Moonsighting Committee (`'لجنة الرؤية'`, …) — copied, not new strings; line refs `:42–63` and `:65–86`.

### [A24] [`egm-style`, `egm-design`] - Severity: Major
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** Overview: "must match … verified by new tests". Goal 7 parenthetical: "about 1–2 min per cached day, and 1 h across DST only when Kotlin calculates". Rollout: "Kotlin math changes at install; only the method/madhab inputs stay old until the first open. Rollback = ship the previous code with a higher versionCode (Android blocks downgrades); the old build's Kotlin maps the five new strings to MWL until its first open." Drop "common for users …" (no data). Items 4, 6: "expected to fail on current code".

### [A25] [`egm-comprehension`, `egm-structural`, `egm-style`] - Severity: Major
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** header gains a two-line glossary: Level A = docs, B = tooling/test infra ("approve B" = tooling approval, unrelated to Option B), C = production code ("approve phase FX-0"); ADR 0001 = `.project-docs/decisions/0001-fix-track-before-refactor.md` (verified). Plan intro: "Level B for step 1, C for steps 2–3, A for step 4 (item 16 lands in the C contract commit)". "→ P6" → "→ refactor phase P6 (cleanup)". Replace "Q1 decision" / "decision N" with the decision text.

### [A26] [`egm-comprehension`, `egm-design`, `egm-style`] - Severity: Major
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** "request codes 1001, 1003–1006 (1002 = Sunrise, no adhan alarm; untouched)".

### [A27] [`egm-design`, `egm-zoom-out`] - Severity: Major
*   ***AI Suggestion:*** PROPOSE FIX — moot if A2 = exact port (MC then held to ±1 min at all fixture cities incl. Oslo). Otherwise scope Goal 2's ceiling to the tested cities.

### [A28] [`egm-structural`] - Severity: Major
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** split shared change 4 into H4s (Fingerprint and triggers · Overwrite · Stale alarms · Tests), which also removes the lazy-continuation rendering fault.

### [N1–N10, N12] (various) - Severity: Nit
*   ***AI Suggestion:*** PROPOSE FIX (all cheap): N1 move evidence to the implementation plan + one tag set (`VERIFIED-static`, `VERIFIED-run`, `UNVERIFIED`); N2 remove duplicates; N3 F51p in header + Problem 5 lists all 8 divergences (F51p = Kotlin offset; Jumu'ah item cites F51p as the same finding's second symptom — say so); N4 dead-code list (`updateNextPrayer`, `setCalculationMethod`, `setAsrMadhab`, `PrayerAlarmService.scheduleReminderAlarm`, `NotificationService.scheduleDailyPrayers`, `_PrayerScreenState._saveCalculationSettings`); N5 fingerprint note + NFR per-minute post-Isha loads; N6 wording fixes; N7 definitions; N8 cite provider `:326–334` for desktop; N9 links + rewrap; N10 implementation-plan precision items; N12 "location: picked up by the next `loadPrayerTimes` (screen open, settings save, resume); the minute tick does not fetch GPS".

### [N11] [`egm-inventive-catalyst`] - Severity: Nit
*   ***AI Suggestion:*** DECLINE (record only) — "Dart publishes resolved parameters" changes the channel contract; listed in Future Improvements with A6's single-writer note, no other change.

## Tally
PROPOSE FIX 38 (incl. 4 needing author OK: A2, A3 part 2, A9, A12) · CONTEST 0 (A4's dead-code premise noted, fix still proposed) · ESCALATE 0 · DECLINE 1 (N11).
