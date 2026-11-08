# Fix: locale-dependent keys (F51a)

Status: APPROVED (user 2026-11-08, "approve phase locale-keys"; no EGM review) · Level C · branch `fix/locale-keys` ·
finding `reference/findings.md` F51 (a)

## Problem
`DailySummaryReceiver.todayDateKey` and `pruneOldPrayerStatuses` (`DailySummaryReceiver.kt:155–165`) build
`yyyy-MM-dd` dates with `String.format("%02d", …)`, which uses the default locale. Every writer of
`prayer_status_*` keys uses `SimpleDateFormat("yyyy-MM-dd", Locale.US)` (`PrayerAlarmReceiver.kt`,
`NativeNotificationReceiver.kt:119`). When the device locale uses Arabic-Indic digits:
1. `today` never matches a stored key, so the summary always reports 5 untracked.
2. The prune cutoff compares `"2026-1…" < "2026-١…"`, which is always true. Prune runs first in `onReceive` (`:76`),
   even when tracking is off, so it deletes **all** `prayer_status_*` keys, including today's unsynced native answers.

This depends on the device locale, not the app language. Audit 2026-11-07: no other key builders are affected.

## Fix
- Add one pure helper in `DailySummaryReceiver.kt` (companion, `internal` for tests), for example
  `dateKey(cal: Calendar): String`, built with `String.format(Locale.US, "%04d-%02d-%02d", …)`. This gives the same
  output as the writers' `SimpleDateFormat(…, Locale.US)`.
- `todayDateKey` and the prune cutoff both call it. No other logic changes (prune order, the 7-day window and the
  untracked counting stay as they are; F51b and F51c are separate items).
- Behavior on Latin-digit locales: output is byte-identical to today's. Arabic-digit locales get the same keys the
  writers already use.
- No contract changes: key names, the prefs file (`FlutterPrefs`), IDs, channels and log tags are unchanged. No
  migration is needed because the bug only affects reads and the cutoff, and stored keys are already ASCII.
  Keys that were already pruned cannot be recovered (out of scope).

## Tests (written first, must fail before the fix)
New file `android/app/src/test/kotlin/com/aura/hala/DailySummaryDateKeyTest.kt` (JVM, next to
`NativePrayerCalculatorParityTest.kt`), run with `./gradlew :app:testDebugUnitTest`:
- Set `Locale.setDefault(Locale("ar", "EG"))`, then restore it in `@After`.
- Precondition assert: `String.format("%02d", 5)` under that default is **not** `"05"`. This proves the JVM really
  produces Arabic-Indic digits, so the test is meaningful.
- `dateKey(2026-11-08)` == `"2026-11-08"`, and it equals `SimpleDateFormat("yyyy-MM-dd", Locale.US)` on the same date.
- Cutoff ordering: a key 3 days old is **not** below the 7-day cutoff, and a key 10 days old is.
- Same assertions with `Locale.US` as default (no regression).
If the cutoff comparison is not reachable without Android `SharedPreferences`, test the cutoff string only
(the comparison itself is plain `String < String`).

Commit order (every commit builds and passes tests):
1. Extract `dateKey` with the **current** formatting (no behavior change) and add the test file, with the ar-EG
   cases marked `@Ignore("F51a")`. Before committing, run them without `@Ignore` and record the failure in the log
   as bug evidence.
2. Switch `dateKey` to `Locale.US` and remove the `@Ignore`.

## File boundary
- Production: `android/app/src/main/kotlin/com/aura/hala/DailySummaryReceiver.kt` only.
- Test: the new test file above only.
- Docs: `.project-docs/` (STATE, findings F51a status, log, device-checklist S27 result).
- Not touched: Dart, other Kotlin files, `pubspec.*`, contracts.

## Verification
- `./gradlew :app:testDebugUnitTest`: new test fails before the fix and passes after; the existing parity test still passes.
- `flutter analyze` (no new issues), `flutter test` (140 pass).
- Bug evidence: the new ar-EG unit test failing on the old code (with the digit precondition holding), plus the
  2026-11-07 audit. No "before" device run, because it would delete unsynced answers.
- Primary fix evidence: the ar-EG unit test passing.
- Device, **S27 on nova 5T: optional, after-fix only.** The phone's system language is English (Western digits), so
  F51a does not affect it today. If run: switch the phone to Arabic before 21:00, confirm Arabic-Indic digits on the
  clock, check the summary count, then switch back to English (steps: `reference/device-checklist.md` S27).
- Record results in the log (and device-checklist if S27 runs). Do not mark PASS unless the check ran.

## Out of scope
F51b (prune ignores sync state), F51c (counts prayers not yet due), any change to the summary UI or text.
