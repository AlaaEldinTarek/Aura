# Device characterization checklist
Written in Step 2 (2026-11-06), BEFORE any refactor. Re-run the affected scenarios after every phase and diff the captures.
Status: DRAFT — scenarios written, results NOT yet recorded (user runs them).

## Device (VERIFIED 2026-11-06 via adb)
| Item | Value |
| --- | --- |
| Model | Huawei nova 5T, `YAL-L21` (build `YAL-L61 10.1.0.251(C185E3R3P1)`), serial `SDEDU20310000545` |
| Android / API | 10 / **API 29** |
| EMUI | `EmotionUI_12.0.0` |
| GMS | **Present**: `com.google.android.gms` 26.34.65 (enabled), `com.android.vending` installed; also HMS (`com.huawei.hwid`, AppGallery) |
| Installed Aura | `com.aura.hala` 1.0.0 (59), minSdk 24, targetSdk 36, installed 2026-06-12 |

## Compatibility target (user decision 2026-11-06)
Supported = **current minSdk and every newer version**, not "Android 12+". Android 10 users must keep working.
SDK levels (VERIFIED): `android/app/build.gradle.kts:21,45,46` use `flutter.compileSdkVersion` / `flutter.minSdkVersion` /
`flutter.targetSdkVersion`, which Flutter 3.38.7 resolves to **compileSdk 36, minSdk 24, targetSdk 36**
(`flutter/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt:23,26,34`; `local.properties` has no
override; installed APK reports minSdk 24 / targetSdk 36).
- nova 5T (API 29) covers the low end. Nothing below API 29 is tested (API 24–28: UNVERIFIED).
- An Android 14/15 emulator is **REQUIRED** for exact-alarm permission (31+), notification permission (33+) and
  full-screen-intent / foreground-service-type rules (34+). Scenarios E01–E04 — BLOCKED until the emulator is set up.

## How to capture
adb is not on PATH: `ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"` (Git Bash).
For every scenario capture the **full** log, then filter — the raw file is the before/after artifact:
```bash
"$ADB" logcat -c
"$ADB" logcat -v threadtime > .project-docs/reference/logcat/S<NN>-<build>.txt   # Ctrl+C when scenario ends
grep -E "<filter>" .project-docs/reference/logcat/S<NN>-<build>.txt > .project-docs/reference/logcat/S<NN>-<build>.filtered.txt
```
`<build>` = `base` (current 1.0.0+59) or the phase name. Folder is git-ignored (`.gitignore:66`).
Git Bash `grep` cannot take 4-byte emoji as an argument on this machine — filters below use tags and `[BRACKET]` sub-tags
only. To filter on `🕌`, use PowerShell: `Select-String -Path <capture>.txt -Pattern '🕌' -Encoding utf8`.

Filter shorthands (used in the table):
- **F-PRAYER** = `PrayerAlarm|PrayerForegroundService|AdhanPlayer|AdhanFullScreen|StopAdhanReceiver|NativePrayerCalc|PrayerTimes|NotificationService|flutter`
- **F-SILENT** = `SilentMode|ToggleSilentMode|SilentOffReceiver|PrayerAlarm`
- **F-TRACK** = `PrayerAlarm|NativeNotifReceiver|DailySummaryReceiver|POST_CHECK|POST_PRAYER_PICKER|REMINDER_PICKER|MainActivity|flutter`
- **F-WIDGET** = `CombinedPrayerWidget|AllPrayersWidget|DailyContentWidget|NextTaskWidget|TasksWidget|WidgetUpdateService|MainActivity`
- **F-FOCUS** = `FocusMode|FocusModeReceiver|FocusModeService|FocusModeChannel`
- **F-BOOT** = `PrayerBootReceiver|PrayerRescheduleService|DailyRecalcReceiver|PrayerRecalcWorker|JumuahReminder|DailySummaryReceiver|PrayerAlarm`
- **F-APP** (Dart only) = `flutter` (narrow with a second `grep` on the feature's log prefix)
- Always also run the CLAUDE.md filter `PrayerAlarm|NotificationService|PrayerTimes|AdhanPlayer|SilentMode` once per prayer scenario (contract check).

## Scenarios
Result column: `PASS` / `FAIL` / `DIFF` (works but differs from expected) + one-line observation. Expected = what the code
is believed to do; record what you actually see, not the expectation.

| # | Scenario | Steps | Expected (from code) | Filter | Result (base) |
| --- | --- | --- | --- | --- | --- |
| S01 | Adhan — screen unlocked | Set a prayer 2–3 min ahead (or `testAdhanNow` from settings test button); keep app in background | Notification 1001–1006 on `prayer_times`, adhan audio, full-screen `AdhanFullScreenActivity`; MainActivity NOT launched | F-PRAYER | **PASS** (2026-11-08 Dhuhr, nova 5T, base): real Zuhr alarm fired 11:38:00 exactly; adhan audio (`adhan_default.mp3`), vibrate mode, notification 1003 on `prayer_times`, `AdhanFullScreenActivity` launched; no MainActivity launch. ADHAN_MODE iqama = 11:53 (same day, correct). `logcat/dhuhr-2026-11-08.txt` |
| S02 | Adhan — screen locked | As S01, screen off/locked | Full-screen activity shows over lock screen, audio plays, Stop works | F-PRAYER | |
| S03 | Adhan — doze | `"$ADB" shell dumpsys deviceidle force-idle`, wait for prayer; afterwards `dumpsys deviceidle unforce` | Alarm fires on time (exact alarm), same as S02 | F-PRAYER | |
| S04 | Adhan — stop controls | During adhan: (a) look at the notification; (b) press a volume key; (c) on a second adhan tap ✕, on a third press Back | (a) Minimal notification, no action buttons, auto-dismisses after ~3 s (`setTimeoutAfter(3000)`); (b) audio stops, adhan screen stays (iqama countdown); (c) audio stops and screen closes. `StopAdhanReceiver` not involved (nothing sends `STOP_ADHAN`, F51q). Corrected 2026-11-07 (drift report) | F-PRAYER | |
| S05 | Pre-prayer reminder | Enable reminder; wait for reminder time | Notification 2001–2006; foreground notification shows reminder; action buttons work | F-PRAYER + F-TRACK | |
| S06 | Post-prayer check → Done | ~30 min after adhan, tap Done/on-time | Notification 6001–6006 dismissed; `prayer_status_{name}_{date}` written; app shows status after open | F-TRACK | **PASS** (2026-11-08 Dhuhr, base): post-prayer check fired 12:08:00 (adhan + 30 min, req 3003); Done at 12:08:28 → `POST_DONE`, notification 6003 cancelled, Zuhr saved as `on_time` to prefs ("syncs on next app open"). In-app display after open not yet checked. `logcat/dhuhr-2026-11-08.txt` |
| S07 | Post-prayer check → Late | As S06, tap Late | Status `late` recorded and shown in app | F-TRACK | |
| S08 | Post-prayer check → Missed / Remind again | As S06, tap Missed; repeat with "remind again" | Status recorded; remind-again reschedules (ID +5000) | F-TRACK | |
| S09 | Post-prayer check tap (body) | Tap notification body | App opens; picker behavior recorded (note: picker extras have no writer — F13) | F-TRACK | |
| S10 | Daily prayer summary | Set summary time 2 min ahead in settings | Notification 7001 on `prayer_tracking` at set time, correct language; tap opens route | F-TRACK | |
| S11 | Jumu'ah reminder | On Friday (or set device date to Friday before Zuhr−30 min) with toggle on | Notification 8001 on `jumuah_reminder`; toggle off → none | F-BOOT | **Deferred to after-fix (regression only)** (2026-11-08, user: baseline stopped, enough evidence) |
| S12 | Silent mode on/off | Ringer normal; enable silent mode, duration N; wait for adhan; repeat once tapping "Stop Vibrate" on the adhan screen | Ringer → **vibrate** (`RINGER_MODE_VIBRATE`, not silent) at adhan, restored after N min; "Stop Vibrate" / "Keep Vibrate" shown on the adhan screen; "Stop Vibrate" restores the ringer and the screen stays open. Off case: S25 (F49a). Corrected 2026-11-07 (drift report) | F-SILENT | |
| S13 | Prayer widgets — light/dark, EN/AR | Add each prayer widget variant; switch theme + language in app | Widget colors/text follow theme & language; RTL layout in Arabic; next prayer correct | F-WIDGET | **Deferred to after-fix (regression only)** (2026-11-08, user: baseline stopped, enough evidence). Earlier informal note (user): "widgets work fine" — which variants and theme/language combinations were checked was not itemised; from 12:34 to 12:41 the widget data came from the Umm al-Qura calculation left by F36c, see S33) |
| S14 | Prayer widget tap targets | Tap each area (header, prayer rows, tabs) | Opens app on Prayer tab (`widget_target_tab=1`); internal tab switch via `ACTION_SWITCH_TAB` | F-WIDGET | |
| S15 | Tasks / Next-task / Daily-content widgets | Add each; light/dark, EN/AR; tap add / complete / row | Add → task form; complete → task completed after app open; row → Tasks tab (3) | F-WIDGET | |
| S16 | Focus mode start/end | Note ringer/DND state; start focus on a task with a short duration; try volume up ×3 once; let the timer end; answer "Yes" | Lock task + overlay + DND (if granted); volume keys do not exit (F52f); at end lock released, sound restored as normal ringer + DND off (F51m); "Did you complete?" → Yes → task done after app opens (`getFocusCompletedTaskId`). No notification 5999 (dead path, F51q). Corrected 2026-11-07 (drift report) | F-FOCUS | |
| S17 | Boot reschedule | `"$ADB" reboot`, unlock, don't open app; wait for next prayer | Alarms, daily summary, Jumu'ah rescheduled by boot receiver; adhan fires | F-BOOT + F-PRAYER | **Deferred to after-fix (regression only)** (2026-11-08, user: baseline stopped, enough evidence) |
| S18 | Stale prayer-time recalculation | Don't open app across midnight (or advance date 1 day) | Foreground notification/widgets show new day's times via `NativePrayerCalculator`; MainActivity NOT launched | F-BOOT + F-PRAYER | PASS (2026-11-08, nova 5T, base): `DailyRecalcReceiver` at 00:05 and WorkManager job at 02:53 both logged `Using cached adhan-accurate times for cached_2026-11-08` (cache, not Kotlin calculation) and re-armed 1001, 1003–1006; no MainActivity launch; widget/notification showed the new day (Sunrise next). Log: [logcat/S18-base.txt](logcat/S18-base.txt) |
| S19 | Offline task create → sync | Logged-in; airplane mode; create/edit/delete task; reconnect | Local changes visible immediately; appear in Firestore after reconnect (Firestore SDK cache; custom offline queue is never filled — findings F16) | F-APP | |
| S20 | Guest → account migration | Guest mode: create tasks; sign up / log in | Guest tasks uploaded to `users/{uid}/tasks`; no duplicates | F-APP | |
| S21 | Arabic / RTL screens | Switch to Arabic; visit Home, Prayer, Tasks, Quran/Wird, Settings, Profile | Full RTL, Arabic numerals everywhere, Zuhr shown as الظهر / Jumu'ah on Friday | F-APP | |
| S22 | Guest flag survives onboarding | Fresh state (signed out, no guest): Login → Continue as guest → finish onboarding → Home; kill app; relaunch | Today (findings F41a): Login appears = bug confirmed (`is_guest` reset to false). After fix: Home appears. Run before S20 (S20 depends on it) | F-APP | FAIL (2026-11-07, nova 5T, base): Login appeared on relaunch — F41a confirmed |
| S23 | Settings survive re-login onboarding | Signed in: set Arabic, dark theme, prayer-only mode; sign out; sign in again; on onboarding step 0 tap Skip | Today (findings F46a): language → English, theme → system, mode → both = bug confirmed. After fix: Arabic / dark / prayer-only kept | F-APP | |
| S24 | Qibla vs trusted reference | Outdoors, away from metal; calibrate compass (figure-8). Same spot, same phone position: open Aura Qibla and a trusted Qibla app (e.g. Google Qibla Finder); compare arrow bearings; also note Aura's instruction text | Findings F48f: a ~4–5° difference (≈ local magnetic declination) confirms magnetic heading is used; ≤ 1–2° = no offset. Record both bearings and the location | F-APP | |
| S25 | Silent mode OFF is honored at adhan | Ringer on normal; in Settings turn silent mode OFF; wait for an adhan (or set a prayer 2–3 min ahead); capture logcat `🔧 [SETTINGS]` | Findings F49a: ringer still switches to vibrate/silent and logcat shows `Silent mode enabled: true` = bug confirmed. After fix: ringer unchanged, log shows `false` | F-SILENT | |
| S26 | Chosen reciter survives app kill | In adhan downloads pick a non-default reciter; swipe the app away from recents (do not reopen); wait for the next adhan | Findings F49b: built-in adhan plays = bug confirmed. After fix: chosen reciter plays. Also: Reset / delete selected reciter → built-in plays without restarting the app | F-PRAYER | |
| S27 | Daily summary on an Arabic-locale phone | Phone system language Arabic (e.g. العربية (مصر)); answer at least one post-prayer check "Done"; set summary time 2–3 min ahead; wait; capture logcat `DailySummaryReceiver` | Findings F51a: summary says 5 untracked and log shows `🧹 Pruned N prayer status keys` including today's = bug confirmed. After fix: answered prayer not counted, today's key kept. Restore phone language afterwards | F-PRAYER | |
| S28 | Adhan during Focus Mode | Start a Focus Mode task timed to cover the next adhan (or a prayer 2–3 min ahead); wait for the adhan | Findings F51f: focus screen returns over the adhan screen and its ✕ cannot be tapped = bug confirmed. Record whether adhan audio plays and how the user can stop it | F-PRAYER | |
| Prep | FX-0 baseline prep snapshot | Record method, madhab, iqama, city, screenshot of today's times, `dumpsys alarm`; compare with [fx-0-baseline-reference.md](fx-0-baseline-reference.md) | Shown times = package times for the selected method (±1 min: city-level vs home coordinates) | F-PRAYER | 2026-11-08, nova 5T, base: method **MWL** (screenshot), madhab **Shafi** (log `Calculation method: muslimWorldLeague, Madhab: shafi`; madhab screenshot was a duplicate of the method one), iqama Fajr/Zuhr/Asr/Isha 15, Maghrib 5 (log `[IQAMA] Using defaults`), city Riyadh (widget). Times vs package MWL Day 2 (04:46 / 06:04 / 11:38 / 14:46 / 17:09 / 18:22): **before open** (widget 05:05, cache from F53a) 04:45 / 06:03 / 11:37 / 14:46 / 17:09 / 18:23 = −1 / −1 / −1 / 0 / 0 / +1 min (= Day 1 package except Fajr); **after open** (Dart 05:14:53) 04:46 / 06:04 / 11:38 / 14:46 / 17:09 / 18:22 = exact match. Dart logged identical times for 11-09 and 11-10 (shifted-day cache, F53a). `dumpsys alarm`: [logcat/S34-alarm-morning.txt](logcat/S34-alarm-morning.txt) (05:10, before open); log: [logcat/prep-2026-11-08.txt](logcat/prep-2026-11-08.txt) |
| S29 | FX-0: Hanafi Asr | Before Shafi Asr, set Asr madhab Hanafi on the prayer settings page (Prayer tab); record shown Asr, widget Asr, actual Asr adhan time; compare with the package Hanafi Asr (scratchpad times) | Base (F36a): shown, widget and adhan all use the **Shafi** Asr = bug confirmed. After FX-0: all three equal the package Hanafi Asr. Setup (F49c, A-1): on base the nova 5T dialog is cut off before Asr Madhab — first set Display size and Font size to the smallest; if Hanafi becomes reachable, run S29 and note "workaround used", otherwise record BLOCKED; restore Display/Font size right after S29. After FX-0: set up at **normal** Display/Font size by scrolling the dialog; Hanafi radio shows selected on tap (F49j) | F-PRAYER + F-WIDGET | **BLOCKED** (2026-11-08, nova 5T, base; user report): Hanafi cannot be reached in the calculation dialog (F49c). Smallest Display/Font size workaround tried: no effect. Re-run after FX-0 at normal size. **FX-0: PASS** (2026-11-08, nova 5T, FX-0 build installed 14:35 via `adb install -r`, data kept): Hanafi reached and tapped at normal Display/Font size from the Asr Madhab tile, radio moved on tap; saved 14:38:54 → immediate recalc `Madhab: hanafi`; app Asr 15:33, widget Asr 15:33 (= package MWL Hanafi 15:33; Shafi 14:46). Asr alarm moved 14:46 → 15:33, post-check 15:16 → 16:03 (`dumpsys alarm` 14:40); WorkManager recalc 14:54 kept 15:33 from `cached_2026-11-08`. No alarm at 14:46; adhan fired 15:33:00 (audio, vibrate, `AdhanFullScreenActivity` only, no MainActivity), iqama 15:48. Note: today's Zuhr shows 11:37 in both builds from 12:32 on vs 11:38 at 05:14 — GPS fix moved (lng 46.8029 → 46.8184, ~1.5 km), shifting solar noon ~4 s across the rounding boundary; not an FX-0 change. `logcat/S29-fx0-*.txt` |
| S30 | FX-0: no stale alarm | Right after S29's Asr adhan, before the Hanafi Asr time: switch to Shafi; `"$ADB" shell dumpsys alarm` before and after; wait past the Hanafi Asr time | Base: Hanafi was never applied, so no alarm exists at the Hanafi time — precondition not reproducible, record DIFF/N/A with the alarm dumps. After FX-0 (Hanafi applied): no Asr adhan fires today after the switch | F-PRAYER | **BLOCKED** (2026-11-08, base; user report): depends on S29 (Hanafi must be set first); Hanafi unreachable (F49c). Re-run after FX-0 |
| S31 | FX-0: iqama change | Before Maghrib: in `/iqama_settings` change Maghrib iqama X → X+5; do not reopen the prayer screen; at Maghrib note the countdown target on the adhan screen and the foreground notification | Base (F36c/F52a: iqama save never reloads): countdown to adhan + X = bug confirmed. After FX-0: adhan + X+5 | F-PRAYER | **Deferred to after-fix (regression only)** (2026-11-08, user: baseline stopped, enough evidence) |
| S32 | FX-0: app closed for days | Run in **guest mode** (or a test account / emulator) and mark **no prayers** while the date is shifted. Open the app once, close it; turn off automatic date/time; set the date +3 days, then +6 days, without opening the app; at each, let a prayer fire. Afterwards turn automatic date/time back on, then open the app | Base: Dart caches today … +2 only, so on +3 and +6 Kotlin uses its own calculation (no `Using cached adhan-accurate times` log); fire times may differ from the package by ~1–2 min. After FX-0: +3 uses the cache (`cached_*` holds today … +6, no fallback log); +6 cached until after Isha, then the `⚠️ No cached times … native fallback` log | F-PRAYER + F-BOOT | **Deferred to after-fix (regression only)** (2026-11-08, user: baseline stopped, enough evidence) |
| S33 | FX-0: corrected methods | After Maghrib, select in turn Qatar, Dubai, Turkey, Singapore, Moonsighting Committee; screenshot the 6 shown times each; compare with package times (scratchpad); restore the original method | Base (F36a): Qatar = Umm al-Qura times (Dhuhr +3, Isha Maghrib + 90), Dubai = Kuwait, Turkey / Singapore / Moonsighting Committee = MWL = bug confirmed. After FX-0: each equals its package method | F-APP | **FAIL / BLOCKED** (2026-11-08 12:32–12:34, nova 5T, base): from both prayer settings page tiles the selection saves (Qatar, Singapore, Egyptian, UmmAlQura, then MuslimWorldLeague to restore) but no save recalculates — shown times stay fixed (F36c, device-verified). FAIL = method change has no visible effect; BLOCKED = per-method comparison with the package not possible on base. Only an app resume recalculated (12:34:00, UmmAlQura → `makkah`, Isha 18:22 → 18:39). Last stored: MuslimWorldLeague (save log 12:34:25; prefs file not readable on release build). **Key after-fix check.** Switching away and back (12:36) did not recalculate (Isha alarm still 18:39 at 12:39); after the user's force-stop + reopen the app recalculated at 12:41:27 with MWL and `dumpsys alarm` (12:45) shows Isha 18:22 / post-check 18:52 restored. `logcat/S33-method-2026-11-08.txt`, `S33-restore-*.txt` |
| S34 | FX-0: tomorrow's Fajr after Isha | After Isha, open the app; `"$ADB" shell dumpsys alarm > S34-alarm.txt`; next morning note whether and when Fajr fired | Base: Dart skips past prayers; whether native has armed tomorrow's Fajr (post-Isha recalculation) is UNVERIFIED — record it. After FX-0: an Aura alarm armed for tomorrow's Fajr (ID 1001) | F-PRAYER | PASS (2026-11-08, nova 5T, base): tomorrow's Fajr (1001, 04:45) already armed in the 19:06 prep dump, re-armed 20:52 / 00:05 / 02:53; fired 04:45:00 (adhan, vibrate, notification 1001, `AdhanFullScreenActivity`). Cached time, 1 min before package 04:46 (F53a). First arming code path UNKNOWN; no `S34-alarm.txt` taken — morning dump: [logcat/S34-alarm-morning.txt](logcat/S34-alarm-morning.txt) |
| S35 | FX-0: later Asr after the old one fired | Shafi set; let Asr fire; switch to Hanafi; `dumpsys alarm` before and after; wait until Maghrib | Base: Hanafi ignored (F36a), nothing re-armed, no second Asr adhan. After FX-0: Asr re-armed at the Hanafi time; the 6-hour duplicate guard prevents a second adhan; the post-check may ask twice | F-PRAYER | **Deferred to after-fix (regression only)** (2026-11-08, user: baseline stopped, enough evidence) |

**FX-0 baseline plan (author, 2026-11-07).** Base build 1.0.0+59 stays installed until every baseline run is done.
Day 1: prep snapshot (method, madhab, iqama, city, screenshot, `dumpsys alarm`), S13, S01, S06, S29, S30, S31, S33,
S34 · night 1: S18 · day 2: S35, S17 · Friday: S11 · last: S32. Package reference times for S29/S30/S33/S11 (city-level
coordinates, not the exact home location): [fx-0-baseline-reference.md](fx-0-baseline-reference.md); S32 dates
computed when the run day is known.

### Emulator scenarios (Android 14/15) — device: **emulator**, status: **BLOCKED** (host is ARM64 Windows)
After E01–E04 pass, also re-run S01–S03, S05, S10, S17 on the emulator.

**Why BLOCKED (2026-11-08, setup attempt via SDK command-line tools).** Host CPU: Snapdragon X Elite (ARM64
Windows). The SDK repository ships the emulator for Windows **x64 only** (stable 37.2.13 and 37.3.8; ARM64 builds
exist only for macOS). Installed `emulator.exe` is x64 (PE machine 0x8664) and runs under Windows x64 emulation:
- x86_64 image (`android-34;google_apis;x86_64`): `emulator -accel-check` → "Virtualization extension is not
  supported" — no hardware acceleration, so x86_64 guests cannot run.
- arm64 image (`android-34;google_apis;arm64-v8a`): `FATAL | Avd's CPU Architecture 'arm64' is not supported by the
  QEMU2 emulator on x86_64 host. System image must match the host architecture.`
E01–E04 can run only on an **Intel/AMD PC** (emulator) or a **physical Android 13+ phone** — there is no Windows
ARM64 emulator in the SDK as of 2026-11-08. The test AVD `aura34` and both API 34 images were removed after the
attempt. Baseline continues on the nova 5T only.
Tooling note (not an app finding; F51a class): the older AVD `Pixel6_x64` `config.ini` holds Arabic-Indic digits
(`hw.ramSize = ٢G`, `sdcard.size = ٥١٢ MB`, `vm.heapSize = ٢٢٨M`), written under the Windows locale `ar-EG` (native
digits `٠١٢٣٤٥٦٧٨٩`) — the same locale-formatted-number class as F51a.
| # | Scenario | Steps | Expected (from code) | Filter | Result (base) |
| --- | --- | --- | --- | --- | --- |
| E01 | Exact-alarm permission (API 31+) | Revoke "Alarms & reminders" for Aura; open app; then grant | `canScheduleExactAlarms` false → app prompts / `openExactAlarmSettings`; after grant alarms schedule and adhan fires | F-PRAYER | BLOCKED |
| E02 | Notification permission (API 33+) | Fresh install; deny POST_NOTIFICATIONS, then allow | Deny: no crash, behavior recorded; allow: S01/S05/S10 notifications appear | F-PRAYER + F-TRACK | BLOCKED |
| E03 | Full-screen intent (API 34+) | Check "full screen notifications" access for Aura (revoked vs granted); trigger adhan locked | Granted: `AdhanFullScreenActivity` over lock screen; revoked: heads-up notification only (record) | F-PRAYER | BLOCKED |
| E04 | Foreground-service types (API 34+) | Start app, enable prayer service, focus mode | `PrayerForegroundService` (9999) and `FocusModeService` (5998) start without `ForegroundServiceTypeException` | F-PRAYER + F-FOCUS | BLOCKED |

## Recorded runs
| Date | Build | Scenarios run | Notes |
| --- | --- | --- | --- |
| 2026-11-07 | 1.0.0+59 (base) | S22 | FAIL — Login on relaunch after guest onboarding (F41a confirmed). Other scenarios not run yet. |
| 2026-11-08 | 1.0.0+59 (base) | Prep, S18, S34, S01, S06, S29, S30, S33 | Prep recorded (MWL/Shafi, times match package after open). S18, S34 PASS. Cache used across midnight (F53a evidence); stale iqama at Fajr adhan (F54a evidence). S01, S06 PASS at Dhuhr; same-day iqama correct (F54a context); azkar launched twice at 12:03 (F51j evidence). S29, S30 BLOCKED (Hanafi unreachable, F49c; workaround no effect). S33 FAIL / BLOCKED (no recalc after method save, F36c). Baseline stopped (user): S11, S13, S17, S31, S32, S35 deferred to after-fix (regression only). |
| 2026-11-08 | FX-0 build (branch `fix/fx-0-prayer-settings`, f9f23ad code, 1.0.0+59; same release key as base, installed in place 14:35) | S29 | S29 PASS (Hanafi at normal size, alarm 14:46 → 15:33, adhan 15:33). Pending: S01, S06, S11, S13, S17, S18, S30–S35 (S33 key check). |
