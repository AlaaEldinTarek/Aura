# Stage 9 Re-audit — Implementation Readiness Report
Target: `docs/designs/fx-0-prayer-settings.md` (DetailedRange 404–611, after resolution) · Date: 2026-11-07
Reviewers: `egm-implementation-readiness`, `egm-codebase-details` (implementation-readiness-standard), `egm-style`
Verdict: **NOT READY** — 0 Blockers; 7 distinct Majors (below). This was the one allowed re-audit (EGM cap).
All earlier Blockers (A1 mapping seam, A2 MC definition) are resolved; the baseline line references were re-verified.

## Major (deduplicated)
| ID | Finding | Raw |
| --- | --- | --- |
| R1 | Fixture row count wrong: 10 dates listed (4 seasonal + 6 DST), so 13 × 10 × 14 × 2 = 3,640, not 4,368. | IR-1, CD-1 |
| R2 | `PrayerSettingsPage._saveCalculationSettings`: (a) `BuildContext` used after an `await` without a `mounted` check → `use_build_context_synchronously` lint breaks the "no new analyzer issues" gate; (b) awaiting the reload (possible GPS fetch) before `Navigator.pop` keeps the dialog open for seconds — a manual Close or a second pick meanwhile makes the delayed pop close the page itself. Fix: read the notifier from `ProviderScope.containerOf` before the first `await`, pop the dialog right after the prefs writes, then reload (unawaited or awaited after the pop). | IR-2, CD-3 |
| R3 | No ordered commit list. Contract commit = items 7, 8 (mapping cases), 10 (delegation), 13 (names), 15 — order vs the per-date and port commits, and the Kotlin table values for the five new names before the port (Qatar 90-min interval, MC seasonal) are unspecified. | IR-3 |
| R4 | DST-transition assertion undefined; naive checks fail for Cairo (start 00:00 on 04-24; end instant 2026-10-29T21:00Z). Specify: a `ZoneRules.nextTransition` instant lies in [start of D, start of D+1) in UTC; hard-coded zone → dates map (Birmingham = London). | IR-4, CD-2 |
| R5 | Port file list incomplete: also `internal/calendrical_helper.dart`, `double_util.dart`, `math.dart`, `shadow_length.dart` / `madhab.dart`, `data/time_components.dart` (`fromDouble` truncation), `extensions/datetime.dart` (`dayOfYear`, `copyWith` hour overflow). The ~600-line estimate behind the 1,200-line stop rule omits them (and sums to ~652). | CD-4, SS-14 |
| R6 | Cross-reference / scope precision: item 5 says "helpers of item 8" (→ item 9); item 9 "the two model files" unnamed (`prayer_time.dart`, `prayer_settings.dart`); `cacheDays(count = 7)` vs "i = 0 … 6". | SS-1, SS-2, SS-3 |
| R7 | Level of `prefs-keys.md` (item 15): table says A only, text says it lands in the C contract commit — mark the exception in the table. | SS-4 |

## Nit (grouped)
- Kotlin details: `PrayerResult` must be `internal` already in the Step 2 stub; old `private calculate(cal, …)` removed or kept, `cachedOrComputed` switch; how `calculateAndSave` learns a method name is unknown (e.g. `methodParams(name): Params?`); Dart `round()` (half away from zero) vs Kotlin → use `Math.round` / `floor(x + 0.5)`; package `dayOfYear` depends on host offset (generate fixture on UTC ≥ 0 host; difference < 0.25 min). (IR-5, IR-8, CD-6, CD-9)
- Provider details: which list each effect uses (`updatedPrayerTimes` vs `days[0]`); remove `_lastSideEffectsDate` field, declare fingerprint + `_generation`; `_lastDailyEffectsDate` key from wall-clock date or `date`; daily effects in the same async block and order; generation counter is per notifier — a disposed notifier's in-flight run can still write after resume (static counter or accepted risk). (IR-6, CD-7, CD-12)
- Tests: `cacheDays` DST-eve test exercises DST only if the test process runs in that zone (set `TZ` or say it checks calendar arithmetic); the Dart Cairo per-date check cannot detect DST errors on a non-Cairo host — say what it proves. (IR-7, CD-10)
- Generator output: destination file, `date` format, lat/lng format; `adhan.` prefix on `PrayerTimes` / `DateComponents`; rationale names `prayer_times_service.dart` (Flutter imports). (CD-8, CD-5, SS-7)
- prefs-keys.md: refresh Kotlin reader (`:173–178`) and writer (`:61–66`) refs after the port. (IR-9, CD-11)
- Wording: "UTC epoch ms" → "epoch ms"; "within 0 min" → exact equality; "the five methods" → name them; verbless fragments; method owner is `_PrayerSettingsPageState`; "the save still counts" → concrete effect; "(epoch ms)" belongs to `PrayerResult` fields; item 13 `:118–145` names `NativePrayerCalculator.kt`; item 15 call chain; item 16 per-file topics; item 20 "after author approval"; widgets block `:336–349`; § Changes vs plan item numbering. (SS-5, SS-6, SS-8–SS-13, SS-15–SS-18)
