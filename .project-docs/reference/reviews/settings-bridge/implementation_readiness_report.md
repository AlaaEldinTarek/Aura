# Stage 9 — Implementation Readiness Report

**Target:** `docs/designs/fix-settings-bridge.md` (DetailedRange, lines 430–605)
**Standards:** `implementation-readiness-standard.md` (readiness, codebase details); persona rules (style)
**GoldfishContext:** `reviews/settings-bridge/precheck.md`, `contracts/prefs-keys.md`, `contracts/method-channels.md`,
`CLAUDE.md` · **Date:** 2026-11-09

## Reviewer Status

| Reviewer | Status | Findings |
| --- | --- | --- |
| `egm-implementation-readiness` | completed | 0 Blocker, 5 Major, 9 Nit |
| `egm-codebase-details` | completed | 0 Blocker, 6 Major, 9 Nit |
| `egm-style` | completed | 0 Blocker, 4 Major, 9 Nit |

Codebase-details verified as accurate: `AdhanPlayer.kt` :47, :53–60, :65, :179–186, :190, :200–211, all `releasePlayer()`
exits, :346, :352, :403–407; `MainActivity.kt` :353–391, :642; `PrayerAlarmReceiver.kt` :497–499;
`AdhanFullScreenActivity.kt` :293/:294; `ToggleSilentModeReceiver.kt` :142/:222/:238, :253–256, :373–375;
`PrayerBootReceiver.kt` :36, :44, :58–65, :89; `DailyRecalcReceiver.kt:73`; manifest :151; provider :348–360,
:541–545; widget service :79, :94–124; adhan service :37–45, :96–100, :133–150; downloads screen cited lines;
`prefs-keys.md` :19/:42/:59–61. Every Modify target exists; S42/S43 are free; all 5 `availableAdhans` entries satisfy
`fileName == 'adhan_<id>.mp3'` and `[a-z0-9_]+`.

Elephant spot-check (VERIFIED static, main @ c5a848e): `playbackLock` declared, unused (`AdhanPlayer.kt:32`); `play`
is `@Synchronized` (`:173`); `DailyRecalcReceiver` `exported="false"` (`AndroidManifest.xml:232–234`); release
build has no `debuggable` (`build.gradle.kts:51–63`).

## Prioritized Findings (deduplicated)

### IR-1 — `previewAdhan` is placed under `playbackLock`, which nothing uses; `play` is `@Synchronized` — Major
* **Reviewers:** readiness (M1), codebase (M1)
* **Scope:** 515; Technical Plan 231–238, 318.
* **Recommendation:** `previewAdhan` is `@Synchronized` (same monitor as `play`); state what happens to `playbackLock`
  (delete or leave) and whether `stop()` stays unlocked.

### IR-2 — `begin(PRAYER)` call sites unclear; built-in path would leave the flag unset — Major
* **Reviewers:** readiness (M2), codebase (N2)
* **Scope:** 513–515; Technical Plan 233.
* **Recommendation:** name every site: after `playCustomAdhan` returns true; after the built-in loop sets
  `playedSuccessfully`; never on `playDefaultSound`; `begin(PREVIEW)` in `previewAdhan` after start. Say whether
  `begin` lives in the callers or inside the shared `playCustomAdhan`.

### IR-3 — Dart pre-stop before preview can kill a prayer adhan; native preview stop order unspecified — Major
* **Reviewer:** codebase (M2); related readiness (N1), style (M3 second half)
* **Scope:** 523–526, 535–537; Technical Plan 226–230; S26 (d) 285.
* **Discrepancy:** `adhan_downloads_screen.dart:666–668` sends `stopAdhan` when `playingAdhanProvider != null`; native
  never tells Dart a preview ended, so after a prayer adhan pre-empts a preview the next play tap sends `stopAdhan`
  and kills the prayer adhan; then `previewAdhan` starts. "Prayer playing → preview refused" fails end to end.
* **Recommendation:** pin native order (enabled check → refuse if prayer playing → resolve → `stop()` → volume
  receiver + media session → vibrate → play → `begin(PREVIEW)`); decide the Dart pre-stop (drop it, or accept the gap);
  say whether Dart keeps its `adhan_vibration_enabled` vibration (`adhan_player_service.dart:68–71`); align test 27's
  expected channel log.

### IR-4 — Test 9 cannot fail before the fix; contradicts the fail-first rule — Major
* **Reviewers:** codebase (M3), style (M1), readiness (N4)
* **Scope:** 436, 476–478, 583–584. Also style M2: "Both fail before the fix" (481–483) is conditional.
* **Recommendation:** mark test 9 as a regression guard exempt from fail-first; word item 10 conditionally.

### IR-5 — Dart `AdhanPlayerService` tests run on a non-Android host; `initialize` assertion is vacuous; `_isAndroid` guard for `previewAdhan` undecided — Major
* **Reviewers:** readiness (M3), codebase (M4)
* **Scope:** 520–523, 532–534.
* **Recommendation:** drop the `initialize` assertion (static grep covers it) or list a production seam; decide
  "`previewAdhan` has no `_isAndroid` guard; on Windows it returns `false`" (or the opposite) so tests 26/27 can see
  the call.

### IR-6 — Test 10 (`updateNextPrayer`) does not say how to drive the notifier — Major
* **Reviewer:** readiness (M4)
* **Scope:** 479–483.
* **Gaps:** `state` setter is protected (analyzer issue); constructor starts `_init()` and a timer
  (`prayer_times_provider.dart:99–104`); `getNextPrayer` reads the wall clock (`prayer_times_service.dart:169–171`),
  so fixed times may take the "tomorrow → `loadPrayerTimes`" branch (`:505–508`); `updateNextPrayer` also calls
  `savePrayerTimes`, so two `updatePrayerTimes` calls are captured. Fallback covers only `loadPrayerTimes`.
* **Recommendation:** specify the seeding method (test subclass or `ProviderContainer` overrides with fakes), times
  relative to `DateTime.now()`, dispose to cancel the timer, and "no captured map contains `zuhr_time`".

### IR-7 — Widget-service F15 change leaves two options; map shapes differ — Major
* **Reviewers:** codebase (M5), readiness (N3), style (N2)
* **Scope:** 471–472; Technical Plan 291–295.
* **Discrepancy:** the widget service sends prayer and iqama keys in two maps (`prayer_widget_service.dart:38–54,
  :79–86`) and emits Sunrise iqama if present; the provider merges and skips Sunrise.
* **Recommendation:** pick one (codebase suggests `buildNativePrayerTimesMap(…, includeIqama: false)` +
  `nativeIqamaTimeKey` for the separate map, Sunrise unchanged, delete both private methods) — or adopt Stage 8
  ZOM-4 (key functions only, no builder).

### IR-8 — No test guards the id ↔ `fileName` rule — Major
* **Reviewer:** codebase (M6) — same as ZO-M2, CO-2, CR-2
* **Scope:** 506–508, 527–529, 541–543.
* **Recommendation:** Dart unit case on every `availableAdhans` entry; list the file.

### IR-9 — Two device proofs cannot run on a release APK — Major
* **Reviewer:** readiness (M5) — S42 half same as CR-3
* **Scope:** 567–570; Goal 5 fallback 96; 597.
* **Discrepancy:** `run-as` needs a debuggable build (release is not); `DailyRecalcReceiver` is not exported, so
  `am broadcast` is refused.
* **Recommendation:** recalc step: set the clock to just before 00:05 and wait (check `dumpsys alarm`), or run on a
  debug build and say so. Zuhr read: logcat (a listed log change) or a debug build.

### IR-10 — Commit 4 summary is 75 characters (CLAUDE.md: < 72) — Major (style)
* **Reviewer:** style (M4) · **Scope:** 444.
* **Recommendation:** "Respect background notification setting on restarts (F51i, F49i)".

### IR-11 — Static checks that cannot catch the bug — Nit
* **Reviewers:** style (N1), readiness (N5)
* **Scope:** 591–592. The bug interpolates `'${p.name.toLowerCase()}_time'`; the literal `zuhr_time` never appears.
  Search `toLowerCase()}_time`; give an exact pattern for the silent-mode check (e.g. no `getBoolean("silent_mode_enabled"`
  outside `FlutterPrefs` calls).

### IR-12 — Unused locals after removing `setCustomAdhan` — Nit
* **Reviewers:** codebase (N1), readiness (N2)
* **Scope:** 524–526. `adhan_downloads_screen.dart:332–333` and `:671` become unused (`unused_local_variable` breaks
  "0 new issues"); say whether `getDownloadedPath` (`:278–283`) is kept.

### IR-13 — Boot log claims a restart that was skipped — Nit
* **Reviewers:** codebase (N4), readiness (N6) · **Scope:** 554–556. Log from the `Boolean` of
  `startServiceIfAllowed` (`PrayerBootReceiver.kt:90`).

### IR-14 — Test 27 fallback cites S26 (d) instead of the Goal 3 step — Nit
* **Reviewers:** codebase (N5), readiness (N7), style (M3) — same as CO-3 · **Scope:** 535–538.

### IR-15 — Contract row `prefs-keys.md:45` goes stale — Nit
* **Reviewer:** codebase (N6) · Row `:45` cites `_getIqamaKey` at `prayer_widget_service.dart:51`; add it to item 11.

### IR-16 — Placeholders and paths — Nit
* **Reviewers:** codebase (N7, N8), readiness (N8, N9), style (N3–N9)
* `.project-docs/log/<date>.md` → exact path or rule (456, 575).
* Test asserts `prefs.getBool('adhan_enabled')`, not `flutter.adhan_enabled` (534).
* Import `io.flutter.util.PathUtils` (508).
* Windows Gradle command `gradlew.bat :app:testDebugUnitTest` (582).
* Give the new text of `prefs-keys.md:42` and the `:56` ⚠ note being removed (484–486).
* Line ranges disagree (`:253–255` vs `:253–256`; `:59–65` vs `:58–65`).
* One exact "obsolete" string (311 vs 562); "new findings found" (455); single "Why:" line (467); "F9 note" (571).
* "`MY_PACKAGE_REPLACED` via reinstall" → update in place `adb install -r` (569); source of baseline 418 (585);
  name the provider and a console baseline (595); "widgets correct" → measurable (598).
* Precedent for JUnit on a Service companion: `DailySummaryDateKeyTest.kt` (559).
