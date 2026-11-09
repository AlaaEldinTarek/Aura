# Stage 5 — Initial Zoom Out Report

**Target:** `docs/designs/fix-settings-bridge.md` (full file, lines 1–605)
**Standard:** `zoom-out-standard.md` · **GoldfishContext:** `reviews/settings-bridge/precheck.md`,
`contracts/prefs-keys.md`, `contracts/method-channels.md`, `CLAUDE.md` · **Date:** 2026-11-09

## Reviewer Status

| Reviewer | Status | Verdict |
| --- | --- | --- |
| `egm-zoom-out` | completed | Pass with changes — 0 Blocker, 3 Major, 3 Nit |
| `egm-inventive-catalyst` | completed | Context sufficient — 0 Blocker, 2 Major, 2 Nit |

Both reviewers found the core architecture sound: Android reads each setting at the moment of use through the
existing `FlutterPrefs.kt`, with no native copy (root-cause fix, matches CLAUDE.md, reuses the
`silent_mode_duration` pattern). Both confirmed: defaults match on both sides; reciter ids match `[a-z0-9_]+`;
`flutter.language` is written by Dart; no `android:process` in the manifest (the "read timing" claim holds).

## Prioritized Findings

### ZO-M1 — Preview refusal while a prayer adhan plays is unapproved behavior; `AdhanPlaybackState` duplicates existing state — Major
* **Reviewer:** `egm-zoom-out`
* **Scope:** lines 225–238 (§3), 276–287 (playback-flag proof), 509–510 (file 19), 530 (file 25), 567–568 (S26 a–d), 318.
* **Discrepancy:** The only approved behavior change is "preview does not change the live adhan". "Preview does
  nothing while a prayer adhan plays" is a second new behavior: today a preview calls `playAdhan`, whose `play` calls
  `stop()` first (`AdhanPlayer.kt:190`), so a preview replaces whatever is playing. `AdhanPlayer` already has
  `currentPrayer` (`:26`), set only after a successful `start()` (`:267`, `:319`) and cleared only in
  `releasePlayer()` (`:355`) — the same lifecycle the new flag specifies.
* **Recommendation:** Either keep today's behavior (preview stops and plays) and drop `AdhanPlaybackState`, file 25
  and S26 a–d; or get explicit approval for the refusal rule and build it on `currentPrayer` instead of a new class.

### ZO-M2 / IC-N1 — Reciter file-name rule is a convention only Kotlin enforces — Major (zoom-out) / Nit (catalyst)
* **Reviewers:** `egm-zoom-out`, `egm-inventive-catalyst`
* **Scope:** lines 59–70, 112–115, 210–216, 389–395, 506–508, 541–543.
* **Discrepancy:** Dart's `AdhanReciter` has separate `id` and `fileName` fields (`adhan_downloads_screen.dart:47–97`);
  downloads use `fileName` (`:162`, `:282`). `fileName == 'adhan_<id>.mp3'` holds today only by hand. Dart never
  checks the id pattern. A future reciter that breaks the convention downloads fine but silently plays built-in on
  Android.
* **Recommendation:** Keep the resolver. Lock the rule on the Dart side: a pure Dart test that every `availableAdhans`
  entry has `fileName == 'adhan_${id}.mp3'` and an id matching `^[a-z0-9_]+$` (or derive `fileName` from `id`), plus a
  comment at `availableAdhans` pointing to `contracts/prefs-keys.md`.

### ZO-M3 — F15 fix is larger than the defect and still leaves a fourth Zuhr rule — Major
* **Reviewer:** `egm-zoom-out`
* **Scope:** lines 86–97, 291–296, 460–483.
* **Discrepancy:** The defect is two lines (`prayer_times_provider.dart:350, :543`); the right rule exists in
  `prayer_widget_service.dart:94–124`. The design adds a `buildNativePrayerTimesMap(includeIqama)` builder that fits
  only the provider sites (the widget service sends iqama in a separate `iqamaTimes` map and does not skip Sunrise,
  `:48–53`), three test files, and a `loadPrayerTimes` test it says may not be drivable. `buildNativeCache`
  (`lib/core/utils/prayer_refresh.dart:52`) has its own Zuhr→`dhuhr` mapping, not mentioned.
* **Recommendation:** Make `nativePrayerTimeKey` / `nativeIqamaTimeKey` public (move the widget-service functions);
  call them at the two provider sites without reshaping the loops; unit-test the key functions; rely on the static
  check plus the S43 `aura_prayer_times.xml` read end to end. Drop the builder, `includeIqama` and the provider test
  file. Optionally route `buildNativeCache` through `nativePrayerTimeKey`, or list it as out of scope.

### IC-M1 — "Background notification off" still has two owners; self-restart paths are not gated — Major
* **Reviewer:** `egm-inventive-catalyst`
* **Scope:** lines 79–85 (Goal 4), 257–274 (§5), 335–342 (Alt B), 593.
* **Discrepancy:** Besides boot, update and nightly recalc, the service restarts itself: `onDestroy` / `onTaskRemoved`
  → `scheduleRestartIfNeeded`, gated only by `shouldAutoRestart()` reading `fg_user_stopped`
  (`PrayerForegroundService.kt:759–811`); and `START_STICKY` (`:136`) lets the system recreate it, with no gate in
  `onCreate` (`:124–133`). If Dart's `stopForegroundService` channel call fails after the setting is written (caught,
  logged), the two values diverge and every swipe-away or memory kill restarts the service until reboot. Users
  already hit by F51i are in that state today (setting off, flag cleared, service running). The gate sits beside
  `startService`, so `BackgroundServiceHandler.kt:20` and future callers bypass it; the static check covers only two
  files.
* **Recommendation:** Use one decision in all native auto-start paths: `startServiceIfAllowed`, `shouldAutoRestart()`
  (setting on AND not `fg_user_stopped`), and a check in `onCreate`/`onStartCommand` that calls `stopSelf()` when off.
  Add an S42 step: off → swipe away / `am kill` → no service. Cost: the `onCreate` path must still call
  `startForeground` within 5 s before `stopSelf()` (brief notification flash on sticky restart); touches service
  lifecycle. Smaller option: gate only `shouldAutoRestart()` (closes swipe-away, not sticky restart).

### IC-M2 — Static checks run once; the bug class can return — Major
* **Reviewer:** `egm-inventive-catalyst`
* **Scope:** lines 49–52, 56–58, 101–102, 117–118, 397–403, 587–593.
* **Discrepancy:** `contracts/prefs-keys.md:12–13` records this file/prefix mismatch as the cause of at least five
  earlier bugs; this fix is the sixth round. Greps pasted into one PR do not stop the next commit from re-adding
  `getSharedPreferences("aura_prefs", …)` or a raw `"silent_mode_enabled"` read.
* **Recommendation:** Make the static checks permanent tests with no new dependency: a plain-JUnit test that scans
  `src/main/kotlin` and fails on any `"aura_prefs"` literal, any of the four keys outside a `FlutterPrefs.*` call, and
  any `PrayerForegroundService.startService(` outside the companion; a Dart test that fails on a `zuhr_time` literal
  in `lib/`. Optional: one `FlutterSettingKeys` object for the four Kotlin key names and defaults. Cost: text scans
  are brittle (comments, logs) and need an allow-list; they check routing, not runtime.

### ZO-N1 — `isAutoStartAllowed` is the identity function; its test proves nothing — Nit
* **Reviewer:** `egm-zoom-out`
* **Scope:** lines 83–85, 259–264, 550–553, 559–560 (file 34).
* **Recommendation:** Drop the pure function and file 34; S42 is the proof. Consider putting the
  `background_notification_enabled` check inside `PrayerForegroundService.startService` itself: Dart writes the pref
  before starting (`prayer_screen.dart:1288–1295`), so turning on still works; every caller, including
  `BackgroundServiceHandler.kt:20`, then follows the setting, and call sites need no change.

### ZO-N2 / IC-N2 — Spec contradicts itself on whether the folder was confirmed — Nit
* **Reviewers:** `egm-zoom-out`, `egm-inventive-catalyst`
* **Scope:** lines 69–70 vs 113, 216, 542.
* **Discrepancy:** Lines 69–70 say the folder name "is not read from the engine source"; line 216 cites
  `PathUtils.java:25–29`; lines 113 and 542 state `app_flutter/adhans` as fact.
* **Recommendation:** Pick one status (verified statically from the engine source, device checks confirm it).

### ZO-N3 — Technical Plan carries implementation-level line citations — Nit
* **Reviewer:** `egm-zoom-out`
* **Scope:** lines 231–238, 266–273.
* **Recommendation:** In §3 and §5 state the rule ("cleared only on release"); keep line citations in the
  implementation plan or precheck.

## Checked, no finding
* Reuse of `FlutterPrefs.kt` and `PathUtils.getDataDirectory`; removal of `aura_prefs` reads/writes and the 4 channel
  methods (net code removal); contract-doc updates in the same commit as each key change.
* Non-Goals keep F9, F66, F67, DataStore migration and Robolectric out; no premature optimization.
* F49h staying on `aura_prayer_times.language` (deferral to F67 with a reason); one PR with commits per repair
  (Alternative J); `adhan_enabled` conflict rule (follows from one reader).
* Catalyst found `AdhanPlaybackState` proportionate; zoom-out did not (ZO-M1). Elephant to weigh in the consolidated
  report.
