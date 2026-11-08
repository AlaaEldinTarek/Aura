# FX-0 — Prayer settings: correct method / madhab, per-date times, full refresh

Spec: `docs/designs/fx-0-prayer-settings.md` (Approved 2026-11-07, amended A-1 2026-11-08). Findings fixed: F36a,
F36c, F52a, F53a, F51p (native divergences), F49c, F49j. Merge as a whole.

## Commits (spec § Commit order)
| # | Commit |
| --- | --- |
| 1 | d15ad6d Add JUnit test dependency for Kotlin unit tests (B) |
| 2 | dfba2b0 Add prayer parity fixture generator and fixture (B) |
| 3 | 59f986b Calculate prayer times for the requested date |
| 4 | 1183aca Add five calculation methods and case-insensitive madhab (contract) |
| 5 | d00aedb Drop "approximate" from the Dubai method label |
| 5a | 12a7c3e Make calculation dialog scrollable and show selection (A-1) |
| 6 | 1a3cb76 Add pure prayer refresh helpers |
| 7 | e6d6646 Replace once-per-day guard with input fingerprint |
| 8 | 7d848ad Cache seven days of prayer times for native |
| 9 | ce5b33b Schedule adhan alarms at next occurrence |
| 10 | b216a0d Reload prayer times after prayer settings save |
| 11 | ba2f224 Reload prayer times after iqama save |
| 12 | f9f23ad Port adhan calculation to Kotlin |
| 13 | 6f57e28 Document FX-0 prayer settings changes |

Every commit touching Dart or Kotlin: `flutter build apk --release --obfuscate --split-debug-info=build/debug-info`
succeeded and `flutter test` passed (from commit 1 on, `./gradlew :app:testDebugUnitTest` too).

## Pre-fix failing output (each new test run once against the pre-fix code / stubs)
**Item 4 — per-date + Umm al-Qura (commit 3):** 23 of 23 fail.
```
00:00 +0 -23: Some tests failed.
Which: at location [0] is <1776739920000> instead of <1776736680000>
```
**Item 4 — mapping (commit 4, with the spec's stubs = today's mapping):** 25 fail, 30 pass.
```
mapping functions every UI method string maps to its own internal value [E]
UI method x madhab equals the fixture <every method> / Hanafi [E]
UI method x madhab equals the fixture Qatar|Dubai|Turkey|Singapore|MoonsightingCommittee / Shafi [E]
Umm al-Qura adjustment qatar|dubai|turkey|singapore|moonsightingCommittee [E]
Which: at location [3] is <1774013400000> instead of <1774016640000>   (Hanafi Asr = Shafi Asr)
```
Passing before the fix (reason): the 7 unchanged methods with Shafi (`MuslimWorldLeague`, `Egyptian`, `Karachi`,
`UmmAlQura`, `NorthAmerica`, `Kuwait`, `Tehran`) — their mapping is already correct; the per-date / makkah tests from
commit 3 (already fixed).

**Item 21 — dialog widget test (commit 5a):** 4 of 4 fail.
```
A RenderFlex overflowed by 937 pixels on the bottom.
Bad state: No element        (no Scrollable in the dialog)
```
**Item 5 — refresh helpers (commit 6, with stubs = today's behaviour):** 12 fail, 5 pass.
```
sideEffectsFingerprint method|madhab|iqama|location|adjustment -> differ [E]
overlap: ... only run 2 writes [E]
cacheDays ... -> 7 distinct consecutive calendar dates [E] (x2)
buildNativeCache over 7 days -> exactly 42 keys [E]
nextOccurrences between Dhuhr and Asr / after Isha [E]
postChecksToSchedule Asr + 30 min still ahead [E]
Which: at location [0] is 'Maghrib' instead of 'Asr'
```
Passing before the fix (reason: today's behaviour is already the same there): app open (empty fingerprint), same
inputs twice, nextOccurrences before Fajr, postChecksToSchedule with Asr + 30 past, Sunrise never included.

**Item 6 — Kotlin parity (commit 12, with a stub `calculate` wrapping the old math):**
```
NativePrayerCalculatorParityTest > everyFixtureRowWithinOneMinute FAILED
11753 of 21840 times off by more than 1 min (worst 86460 s). First: Cairo 2026-03-20 muslimWorldLeague shafi fajr: off by 1320 s; ...
```
`dstDatesAreTransitionDays` passes before and after (it guards the hard-coded fixture dates, not app code).

## After
- `flutter test`: 140 pass (64 existing + 76 new).
- Kotlin: 2 pass; all 21,840 fixture times equal the package **to the millisecond** (max ±1 min allowed).
- Port size: 734 code lines in `adhan/` (estimate 824, stop rule 1,650).
- `flutter analyze`: 423 issues (baseline 425; −2 from dropped `.toList()` in spreads). No new issues.
- `dart format`: new files formatted; existing touched files were already unformatted before and were not reformatted
  (to keep the diff to the change).

## Deviations from the spec text (also in the spec's Implementation notes)
- Item 11: `if (mounted)` instead of `if (context.mounted)` (analyzer `use_build_context_synchronously` in a State).
- Item 21: `show()` moved next to `createState` (signature unchanged); the widget test loads the bundled fonts (test
  font made the unchanged section header overflow by 50 px horizontally).
- Item 2: fixture generated on a UTC+3 host (Asia/Riyadh) instead of Africa/Cairo (both offset ≥ 0).

## Device verification (nova 5T, API 29)
Baseline (base build 1.0.0+59, 2026-11-08): S01, S06, S18, S34 PASS; S29, S30 BLOCKED (Hanafi unreachable, F49c);
S33 FAIL/BLOCKED (method save never recalculated, F36c).

FX-0 build (code f9f23ad, same release certificate as the installed base, installed in place with `adb install -r`
2026-11-08 14:35, data kept). Details: `.project-docs/reference/device-checklist.md`; logs (local, gitignored) under
`.project-docs/reference/logcat/`.

| Scenario | Date (phone time) | Result | Log files |
| --- | --- | --- | --- |
| S29 Hanafi Asr | 2026-11-08 14:38–15:33 | **PASS** — Hanafi reached and tapped at normal Display/Font size, radio moved; immediate recalc; app and widget Asr 15:33 (= package); alarm 14:46 → 15:33, post-check 15:16 → 16:03; no adhan at 14:46; adhan fired 15:33:00, iqama 15:48, no MainActivity launch | `fx0-after-install-alarm.txt`, `S29-fx0-alarm.txt`, `S29-fx0-2026-11-08.txt`, `S29-fx0-fire-2026-11-08.txt`, `S29-fx0-asr-2026-11-08.txt` |
| S33 Corrected methods | 2026-11-08 15:39–15:43 | **PASS** — Qatar, Dubai, (Kuwait), Turkey, Singapore, Moonsighting Committee, MWL restore: each save recalculated immediately and equals the adhan package for the device location; alarms followed; Isha back at 18:22 after restore | `S33-fx0-2026-11-08.txt`, `S33-fx0-alarm.txt` |
| S30 No stale alarm | 2026-11-08 15:36 | **Observation (reverse setup)** — Shafi set after the Hanafi Asr fired: Asr re-armed only for tomorrow (14:45), no second Asr adhan today; Asr post-check kept at 16:03 (CUJ 2 exception a). Scripted S30 not run | `S33-fx0-2026-11-08.txt`, `S33-fx0-alarm.txt` |

Pending:
- **S34** (tomorrow's Fajr armed after Isha) — tonight after Isha 18:22: `dumpsys alarm` shows ID 1001 for 2026-11-09 Fajr.
- **S18** (stale recalculation across midnight) — tomorrow morning: 00:05 recalc uses `cached_2026-11-09` (7-day cache), no MainActivity launch.
- Also pending: S01, S06, S11, S13, S17, scripted S30, S31, S32, S35.

Nothing else is reported as device-passed.

## Release notes (Goal 7, Play Console)
- EN: "More accurate adhan timing when the app isn't open, including daylight-saving changes." + Hanafi Asr and the
  Qatar / Dubai / Turkey / Singapore / Moonsighting Committee corrections.
- AR: "تحسين دقة توقيت الأذان عندما لا يكون التطبيق مفتوحًا، بما في ذلك أيام تغيير التوقيت الصيفي."

🤖 Generated with [Claude Code](https://claude.com/claude-code)
