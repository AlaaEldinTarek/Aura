# Consolidated Review Report — Dart → native settings bridge

**Target:** `docs/designs/fix-settings-bridge.md` (605 lines; FeatureRange 1–429, DetailedRange 430–605)
**Mode:** Consolidated (uninterrupted; no edits between stages) · **Date:** 2026-11-09
**GoldfishContext:** `reviews/settings-bridge/precheck.md`, `contracts/prefs-keys.md`, `contracts/method-channels.md`,
`CLAUDE.md`

## Stage status

| Stage | Reviewers | Status | Report |
| --- | --- | --- | --- |
| 5 Initial Zoom Out | zoom-out, inventive-catalyst | completed | `zoom_out_report.md` |
| 6 Comprehension | comprehension | completed | `comprehension_report.md` |
| 7 Critic | design, structural, style | completed | `critic_report.md` |
| 8 Intermediate Zoom Out | zoom-out | completed | `intermediate_zoom_out_report.md` |
| 9 Implementation Readiness | implementation-readiness, codebase-details, style | completed | `implementation_readiness_report.md` |

**Result:** 0 Blockers. Every reviewer judged the core architecture sound (Android reads each setting at use time
through `FlutterPrefs`, no native copy). The Majors are about unrecorded decisions, proofs that cannot run as written,
and a few mechanics left for the implementer to decide.

## Elephant notes (context the Goldfish did not have)

* **E1 — The preview-refusal rule *was* set by the author.** ZO-M1 and ZOM-3 call "preview does nothing while an adhan
  is playing" an unapproved behavior change and recommend dropping it. The author defined it during drafting
  (2026-11-09: "Define preview while an adhan is playing: preview does nothing"). The spec and precheck "User
  decisions" never recorded it, so no reviewer could see it. **Author decision needed:** keep it (record it as
  approved change #2, then resolve IR-1/2/3) or drop it (adopt ZOM-3: preview stops and replaces, no
  `AdhanPlaybackState`).
* **E2 — The reciter folder was read from the engine source.** `PathUtils.java:25–29` in the local Flutter SDK
  (`C:\Users\alaae\flutter\engine\src\flutter\shell\platform\android\io\flutter\util\PathUtils.java`, SDK commit
  3b62efc2a3d). Lines 69–70 are stale; fix the wording, no status change.
* **E3 — Reviewer conflicts to settle:** F15 shape (ZO-M3/ZOM-4 inline key functions vs the spec's builder, and CR-6
  listing "inline" as rejected); service restart scope (IC-M1 full gate vs ZOM-1 `shouldAutoRestart()` only vs ZO-N1
  gate inside `startService`); permanent scan tests (IC-M2) vs one-time greps (ZOM-2).
* **E4 — Spot-checked (VERIFIED static):** `playbackLock` unused, `play` `@Synchronized` (`AdhanPlayer.kt:32, :173`);
  `currentPrayer` (`:26`); `DailyRecalcReceiver` not exported; release build not debuggable; self-restart via
  `START_STICKY` (`PrayerForegroundService.kt:136`) and `shouldAutoRestart` (`:773`); `buildNativeCache` Zuhr mapping
  (`prayer_refresh.dart:52`).

## Consolidated actions

### 🔴 Blocker
None.

### 🟡 Major — author decisions

| ID | Decision | Options |
| --- | --- | --- |
| A1 | Preview while an adhan plays (E1) | Keep "does nothing" (record as approved change; fix IR-1/2/3) · Drop it (ZOM-3) |
| A2 | F15 shape (E3) | Key functions only at the two provider sites (ZO-M3/ZOM-4) · Builder as drafted (fix IR-7) · Also route `buildNativeCache`, or list it out of scope |
| A3 | Service restart scope (Goal 4) | Gate `shouldAutoRestart()` too, pure `isAutoStartAllowed(setting, userStopped)` (ZOM-1) · Also gate `onCreate` (IC-M1) · Gate inside `startService` (ZO-N1) · Keep as drafted and state the limit |
| A4 | Permanent scan tests | One-time greps in the PR (ZOM-2) · Permanent JUnit/Dart scan tests (IC-M2) · Separate Level B lint item |
| A5 | Rollback cost of the adhan commit (CR-4) | Document only (ZON-2) · Add a Flutter → native resync |

### 🟡 Major — fixes with one defensible answer

| ID | Action | Sources |
| --- | --- | --- |
| F1 | Dart test: every `availableAdhans` entry has `fileName == 'adhan_${id}.mp3'` and id `^[a-z0-9_]+$`; comment at `availableAdhans` → contract; add to Goal 2/8 proof | ZO-M2, IC-N1, CO-2, CR-2, IR-8 |
| F2 | Goal 9: today the toggle already shows the native copy; justify "Flutter wins" by write order; state the visible toggle may change; list both behavior changes in the Overview | CR-1, style M1 |
| F3 | Overview scope: only this group's four settings; `language` stays duplicated (F67) | CR-8 |
| F4 | Record Q2, Q3/Q4, Robolectric, one-PR (and A1) in precheck "User decisions"; link it; lead each rejection with the deciding trade-off; add "F49a via native write into `aura_silent_mode`" | CR-6, ZOM-4 |
| F5 | Risks: promote the `[a-z0-9_]+` path-traversal guard to a Security risk row; point to existing text for the rest | CR-5, ZON-2 |
| F6 | Goal 6: language is pushed at once on change (`preferences_provider.dart:124–152`); gap = no prayer times loaded (`:137`); define "push gap"; add the arrow to the diagram | CO-1, ZON-1 |
| F7 | S26 step (e) "select A, preview B, adhan fires → A plays" as the Goal 3 proof; fix the test 27 fallback reference | CO-3, IR-14 |
| F8 | Device proofs runnable on release: nightly recalc by setting the clock before 00:05 (+ `dumpsys alarm`); Zuhr check via logcat or a named debug build | CR-3, IR-9 |
| F9 | Fail-first rule: test 9 is a regression guard; item 10 wording conditional | IR-4 |
| F10 | `AdhanPlayerService` tests: drop the vacuous `initialize` assertion; decide no `_isAndroid` guard on `previewAdhan` (Windows → `false`) | IR-5 |
| F11 | Test 10: seeding via test subclass / overrides with fakes, times relative to now, dispose, check every captured call | IR-6 |
| F12 | Commit 4 summary < 72 chars | IR-10 |
| F13 | "caught, logged" is false for `setCustomAdhan` (no try-catch) | CR-10 |
| F14 | Cite the read-timing evidence (no `android:process`) | CR-11 |
| F15 | Language read count: cite the search; reconcile `prefs-keys.md:44` ("R ×20"); note `TasksWidget` reads `aura_tasks_widget` | CR-9 |

### 🟢 Nit

| ID | Action | Sources |
| --- | --- | --- |
| N1 | One folder-status wording; `io.flutter.util.PathUtils` | ZO-N2, IC-N2, CO-4, CR-7, IR-16 |
| N2 | Static checks that catch the bug (`toLowerCase()}_time`; exact silent-mode pattern) | IR-11 |
| N3 | Delete unused locals `:332–333`, `:671`; decide `getDownloadedPath` | IR-12 |
| N4 | Boot log from `startServiceIfAllowed` result | IR-13 |
| N5 | Add `prefs-keys.md:45` to item 11; give new text of `:42` and the `:56` note | IR-15, IR-16 |
| N6 | Contract row: reciter rule is Android only (Windows uses `adhans/<prayerName>.mp3`) | ZON-3 |
| N7 | One clause: `foreground_service_enabled` is Dart-only running state | ZON-4 |
| N8 | Known limitations: corrupt reciter → built-in plays without volume-key stop; stale preview UI after prayer takeover | CR-15, CR-16 |
| N9 | Label compile-fail JUnit as structural tests | CR-13, ZO-N1 |
| N10 | Structure: move playback-flag proof under §3; Goal/§ numbering cross-ref; dividers; column header | CR-17 |
| N11 | Glosses (Level B/C, "edit carefully", F10, S25/S26 at first use, `fg_user_stopped`, legacy plugin) | CO-5–CO-7, CO-10 |
| N12 | Line-range agreement; Problem row 5 names the sites | CO-8, CO-9, IR-16 |
| N13 | Wording calibrations (Stage 7 CR-18, Stage 9 IR-16 list); Technical Plan line citations → rules | CR-18, IR-16, ZO-N3 |

## Traceability matrix

| Raw finding | Action |
| --- | --- |
| ZO-M1, ZOM-3, IR-1, IR-2, IR-3 | A1 (+ IR-1/2/3 if kept) |
| ZO-M3, ZOM-4, IR-7 | A2 |
| IC-M1, CR-12, ZOM-1, ZO-N1 | A3 |
| IC-M2, ZOM-2 | A4 |
| CR-4, style N12 | A5 |
| ZO-M2, IC-N1, CO-2, CR-2, IR-8 | F1 |
| CR-1, style M1 | F2 |
| CR-8 | F3 |
| CR-6, ZOM-4 (part) | F4 |
| CR-5, ZON-2 | F5 |
| CO-1, ZON-1 | F6 |
| CO-3, IR-14 | F7 |
| CR-3, IR-9 | F8 |
| IR-4 | F9 |
| IR-5 | F10 |
| IR-6 | F11 |
| IR-10 | F12 |
| CR-10 | F13 |
| CR-11 | F14 |
| CR-9 | F15 |
| ZO-N2, IC-N2, CO-4, CR-7 | N1 |
| IR-11 | N2 |
| IR-12 | N3 |
| IR-13 | N4 |
| IR-15 | N5 |
| ZON-3 | N6 |
| ZON-4 | N7 |
| CR-15, CR-16 | N8 |
| CR-13 | N9 |
| CR-17 | N10 |
| CO-5, CO-6, CO-7, CO-10 | N11 |
| CO-8, CO-9 | N12 |
| CR-18, ZO-N3, IR-16 (rest) | N13 |
