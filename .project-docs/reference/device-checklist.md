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
| S01 | Adhan — screen unlocked | Set a prayer 2–3 min ahead (or `testAdhanNow` from settings test button); keep app in background | Notification 1001–1006 on `prayer_times`, adhan audio, full-screen `AdhanFullScreenActivity`; MainActivity NOT launched | F-PRAYER | |
| S02 | Adhan — screen locked | As S01, screen off/locked | Full-screen activity shows over lock screen, audio plays, Stop works | F-PRAYER | |
| S03 | Adhan — doze | `"$ADB" shell dumpsys deviceidle force-idle`, wait for prayer; afterwards `dumpsys deviceidle unforce` | Alarm fires on time (exact alarm), same as S02 | F-PRAYER | |
| S04 | Adhan — stop from notification | During adhan tap Stop action | `StopAdhanReceiver` stops audio, notification dismissed | F-PRAYER | |
| S05 | Pre-prayer reminder | Enable reminder; wait for reminder time | Notification 2001–2006; foreground notification shows reminder; action buttons work | F-PRAYER + F-TRACK | |
| S06 | Post-prayer check → Done | ~30 min after adhan, tap Done/on-time | Notification 6001–6006 dismissed; `prayer_status_{name}_{date}` written; app shows status after open | F-TRACK | |
| S07 | Post-prayer check → Late | As S06, tap Late | Status `late` recorded and shown in app | F-TRACK | |
| S08 | Post-prayer check → Missed / Remind again | As S06, tap Missed; repeat with "remind again" | Status recorded; remind-again reschedules (ID +5000) | F-TRACK | |
| S09 | Post-prayer check tap (body) | Tap notification body | App opens; picker behavior recorded (note: picker extras have no writer — F13) | F-TRACK | |
| S10 | Daily prayer summary | Set summary time 2 min ahead in settings | Notification 7001 on `prayer_tracking` at set time, correct language; tap opens route | F-TRACK | |
| S11 | Jumu'ah reminder | On Friday (or set device date to Friday before Zuhr−30 min) with toggle on | Notification 8001 on `jumuah_reminder`; toggle off → none | F-BOOT | |
| S12 | Silent mode on/off | Enable silent mode, duration N; wait for adhan | Ringer → silent at adhan, restored after N min; toggle action works | F-SILENT | |
| S13 | Prayer widgets — light/dark, EN/AR | Add each prayer widget variant; switch theme + language in app | Widget colors/text follow theme & language; RTL layout in Arabic; next prayer correct | F-WIDGET | |
| S14 | Prayer widget tap targets | Tap each area (header, prayer rows, tabs) | Opens app on Prayer tab (`widget_target_tab=1`); internal tab switch via `ACTION_SWITCH_TAB` | F-WIDGET | |
| S15 | Tasks / Next-task / Daily-content widgets | Add each; light/dark, EN/AR; tap add / complete / row | Add → task form; complete → task completed after app open; row → Tasks tab (3) | F-WIDGET | |
| S16 | Focus mode start/end | Start focus on a task with short duration | Overlay/lock + DND (if granted); end notification 5999; completed task handed back to app | F-FOCUS | |
| S17 | Boot reschedule | `"$ADB" reboot`, unlock, don't open app; wait for next prayer | Alarms, daily summary, Jumu'ah rescheduled by boot receiver; adhan fires | F-BOOT + F-PRAYER | |
| S18 | Stale prayer-time recalculation | Don't open app across midnight (or advance date 1 day) | Foreground notification/widgets show new day's times via `NativePrayerCalculator`; MainActivity NOT launched | F-BOOT + F-PRAYER | |
| S19 | Offline task create → sync | Logged-in; airplane mode; create/edit/delete task; reconnect | Local changes visible immediately; appear in Firestore after reconnect (Firestore SDK cache; custom offline queue is never filled — findings F16) | F-APP | |
| S20 | Guest → account migration | Guest mode: create tasks; sign up / log in | Guest tasks uploaded to `users/{uid}/tasks`; no duplicates | F-APP | |
| S21 | Arabic / RTL screens | Switch to Arabic; visit Home, Prayer, Tasks, Quran/Wird, Settings, Profile | Full RTL, Arabic numerals everywhere, Zuhr shown as الظهر / Jumu'ah on Friday | F-APP | |
| S22 | Guest flag survives onboarding | Fresh state (signed out, no guest): Login → Continue as guest → finish onboarding → Home; kill app; relaunch | Today (findings F41a): Login appears = bug confirmed (`is_guest` reset to false). After fix: Home appears. Run before S20 (S20 depends on it) | F-APP | FAIL (2026-11-07, nova 5T, base): Login appeared on relaunch — F41a confirmed |
| S23 | Settings survive re-login onboarding | Signed in: set Arabic, dark theme, prayer-only mode; sign out; sign in again; on onboarding step 0 tap Skip | Today (findings F46a): language → English, theme → system, mode → both = bug confirmed. After fix: Arabic / dark / prayer-only kept | F-APP | |

### Emulator scenarios (Android 14/15) — device: **emulator**, status: **BLOCKED** (emulator not set up)
After E01–E04 pass, also re-run S01–S03, S05, S10, S17 on the emulator.
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
