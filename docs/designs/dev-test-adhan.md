# Dev tool: fire a test adhan on demand (hidden)

Status: APPROVED by user ("approve the dev-test-adhan spec and phase"); Arabic strings reviewed by Aladdin on 2026-11-14 ("Arabic every where is very good") · Level A (this doc only) · implementation would be Level C and needs
"approve phase" · branch `fix/dev-test-adhan` (from main) · not a fix for a finding; a developer test aid.

Labels: VERIFIED = read in code at the cited line · UNKNOWN = not checked or not checkable by reading · GUESS = inference.

## Goal
Fire the REAL adhan flow on demand in the release build, to test on the phone: the adhan screen after a vibrate
window, the Stop Vibrate / Keep Vibrate buttons, and the silent-state auto-restore.

## What already exists (reused, not changed)
- `PrayerAlarmService.testAdhanNow(name)` (`prayer_alarm_service.dart:174-185`) calls the `testAdhanNow` channel method.
  No caller exists in `lib/` (grep: only the definition). VERIFIED.
- Kotlin handler `MainActivity.kt:422-468` sets an exact alarm 10 s ahead, request code 9999, on `PrayerAlarmReceiver`,
  with extras `prayer_name`, `prayer_name_ar`, `prayer_time`, `is_test=true`. VERIFIED.
- `PrayerAlarmReceiver.onReceive` (`PrayerAlarmReceiver.kt:394-594`) then runs the real path: adhan audio (:503), vibrate
  window if `silent_mode_enabled` (:514-516), notification (:526), `AdhanFullScreenActivity` (:531-533). VERIFIED.
- `is_test` skips only the 6-hour duplicate guard and does not write `last_adhan_fired_*` (:486-495). VERIFIED.
- Window length = `silent_mode_duration` pref, default 20 (:721). The test does not change it. VERIFIED.
- Stop/Keep Vibrate buttons show only if `silent_mode_enabled && is_silent_active` (`AdhanFullScreenActivity.kt:291-297`). VERIFIED.
- Not reachable from adb: receiver and activity are `exported="false"` (`AndroidManifest.xml:74-85,121-124`). VERIFIED.
  That is why an in-app trigger is needed.

## Design (Dart only)
1. `lib/features/profile/profile_screen.dart`, About card, non-Windows branch (Version tile, `:298-310`). The screen is a
   stateless `ConsumerWidget` (`:30`), so the tile moves into a small private `StatefulWidget`
   (`_VersionTile`) that owns `int _taps` (not persisted, resets on every visit to the screen). VERIFIED (class at :30).
2. Each tap on the Version tile increments `_taps`. At 7 taps, `_unlocked = true` and a "Fire test adhan" `SettingTile`
   appears below it (setState). No toast or hint before 7. Leaving the screen resets both.
3. Tapping "Fire test adhan" opens a confirm `AlertDialog`:
   - body: what will happen (below). Buttons: Cancel (existing `cancel` key, `en.json:174`) and "Fire".
4. On "Fire": check `PrayerAlarmService.instance.canScheduleExactAlarms()` (`prayer_alarm_service.dart:188`; Kotlin
   `MainActivity.kt:556-563`, VERIFIED). If false, show a snackbar and stop. Otherwise call
   `testAdhanNow('Zuhr')`, then show a snackbar "fires in about 10 seconds".
   Reason for the pre-check: `testAdhanNow` Dart wrapper returns `void` and swallows every error with `debugPrint`
   (`:179-184`, VERIFIED), and the Kotlin handler has no try/catch and no permission check (`MainActivity.kt:422-468`,
   VERIFIED). On Android 12+ an exact alarm without permission can throw (GUESS: standard Android behavior, not run here),
   which would make the tile look like it worked in release while nothing fires.
5. Windows: the tile is never built (the Windows Version branch at `:291-297` is separate). Web: not a target.
   `testAdhanNow` is an Android channel call, so no desktop path is touched. VERIFIED (branch structure).
6. The tile and dialog are visible only after 7 taps. No `kDebugMode` gate: it must work in the release build.

## Explicitly not done
- No Kotlin, manifest, intent-extra, prefs-key, channel, notification-ID or contract change. `testAdhanNow` is already in
  `contracts/method-channels.md:27`. VERIFIED.
- No change to `silent_mode_duration` or the window length. The window stays at the user's setting.
- Must NOT call `cancelAllPrayerAlarms`, `schedulePrayerAlarm`, `scheduleReminderAlarm`, or recalculate or re-arm
  anything; must NOT touch the real prayer schedule or settings; must NOT show the tile to normal users.
- Hard-coded `'Zuhr'` only. No prayer picker.

## Why Zuhr
- Fajr and Isha additionally call `requestFlutterUpdateStatic` (a Flutter recalculation) after firing (:590-593). VERIFIED.
- Zuhr is a canonical name handled everywhere (`kPrayerNames` `'Zuhr'`; `getNotificationId` handles `"Dhuhr", "Zuhr"`,
  :77). VERIFIED. Prefs key stays `dhuhr_time`.

## Side effects of a test run
Real state written (all VERIFIED in `PrayerAlarmReceiver.kt` unless noted):
| Effect | Where | Note |
| --- | --- | --- |
| Ringer set to vibrate; `saved_ringer_mode` overwritten with the CURRENT mode; `is_silent_active=true`; `silent_end_time` | :705-723 | Overwrite is unconditional. |
| Restore alarm, request code 3999, at window end | :733-748 | Same code as a real adhan. |
| Adhan notification, Zuhr ID (`NOTIFICATION_DHUHR`) | :791, `showPrayerNotification` | Same ID as the real Zuhr. |
| `adhan_active`, `adhan_end_time` (+20 min), `adhan_iqama_time` (from stored `dhuhr_iqama_time`) | :555-561 | Foreground service shows the iqama countdown (`PrayerForegroundService.kt:451-452`; clears at :482,:495). |
| Azkar alarm at iqama+10 min, or now+15 min if no iqama time | :569-571 | Request code per prayer (`AzkarAlarmReceiver.kt:78`): same as the real Zuhr azkar alarm. If iqama is already past, the alarm is skipped (`AzkarAlarmReceiver.kt:59-62`). If the exact-alarm permission is missing it is skipped (:67-70). |
| Post-prayer check alarm at test time + 30 min | :581 → :323-351 | Request code `notificationId+2000`: same as the real Zuhr post-check. Only if `prayer_tracking_notifications_enabled`. |
| `next_prayer_name/_ar/_time` rewritten, widgets refreshed | :575, :599-650 | See below. |

Pending alarms about 15 min (azkar) and 30 min (post-check) after the test:
- Azkar: opens the azkar full-screen. VERIFIED that it is scheduled; what it shows is not re-read here.
- Post-check: if `prayer_status_Zuhr_<today>` is not set, it posts the "did you pray" notification (:416-427). Its buttons
  (Prayed / Late / Missed / Later) write the REAL tracking record for Zuhr today (`handlePostPrayerCheckAction`, :409-413).
  Tapping one would change real tracking and streak. GUESS on exact streak impact, VERIFIED that the handler is invoked.

`updateNextPrayer` effect on the next real alarm:
- VERIFIED: it writes only the `next_prayer_*` cache prefs and refreshes widgets. It does not schedule, cancel or move
  any alarm (:599-650).
- VERIFIED: the loop starts at the prayer AFTER Zuhr (`currentIndex + 1`, :616). If you fire the test BEFORE the real Zuhr
  time, the cache says Asr while the real next prayer is Zuhr, until something recomputes it. If fired after the real
  Zuhr time and before Asr, the result equals what a real adhan would write.
- UNKNOWN: which of `PrayerForegroundService.kt:138-139`, `MainActivity.kt:302-304`, `NativePrayerCalculator.kt:82-84`
  rewrites the cache first, and how soon. The Dart UI does not read these keys (grep of `lib/`: none). Per
  ADR/memory, the app derives next prayer; the widget and notification read the cache. Not verified on device.
- The real Zuhr alarm is unaffected: the test alarm uses code 9999, and `last_adhan_fired_Zuhr` is not set, so the real
  adhan still passes the duplicate guard. VERIFIED (:486-495).

## Cleanup note for the user (include in the dialog body too)
- Before testing, set the phone ringer to Normal. The restore returns the phone to the mode saved at fire time; if the
  phone was already on vibrate (or a vibrate window is still active), it restores to vibrate (:705-706, restore at
  `ToggleSilentModeReceiver.kt:388-389`). VERIFIED.
- Do not fire within about 20 min before a real prayer or while a vibrate window is active: the second adhan would save
  "vibrate" as the original mode (:705-706, VERIFIED) and the restore would leave the phone on vibrate.
- Best time: after the real Zuhr time and before Asr (see `updateNextPrayer` above), with the phone locked or the app in
  the background, as a real adhan arrives.
- After the test: use Stop Vibrate (or let the window run out) and dismiss the 15 and 30 min notifications without tapping
  Prayed / Late / Missed. If the post-check is turned off in settings, no post-check is scheduled.
- Reset: if the phone is stuck on vibrate, set it to Normal in system sound settings.

## Android notes
- Android 12+ (API 31): exact alarms need `SCHEDULE_EXACT_ALARM` or `USE_EXACT_ALARM`; both are declared
  (`AndroidManifest.xml:13-14`). VERIFIED that they are declared; UNKNOWN whether granted on the user's phone, hence the
  pre-check in step 4.
- Android 13+: needs `POST_NOTIFICATIONS` (declared :15). Android 14+: full-screen intent permission (`USE_FULL_SCREEN_INTENT`
  declared :16; the receiver also starts the activity directly, :531). The test phone is the nova 5T, API 29, so
  neither applies there (STATE.md: test device API 29).
- Android 10+ background activity start limits: the direct `startActivity` at :531 is the same code a real adhan uses.
  If the app is in the foreground at fire time it is not a faithful test of the lock-screen case. Lock the phone after
  tapping Fire. UNKNOWN whether the activity start succeeds on every OEM; the notification full-screen intent is the fallback.
- DND: `enableSilentModeForPrayer` checks DND permission but sets ringer vibrate either way (:692-711). VERIFIED.

## Strings (new keys in BOTH `assets/translations/en.json` and `ar.json`; the Arabic was reviewed by Aladdin on 2026-11-14 ("Arabic every where is very good"))
Arabic numerals rule: the English text has the number "10"; the Arabic writes it as a word, so no raw digit
appears in Arabic UI. If you prefer a digit, it must go through `NumberFormatter.withArabicNumerals`.
Reuses `cancel` (`en.json:174`, `ar.json:174`).

| Key | English | Arabic (reviewed 2026-11-14) |
| --- | --- | --- |
| `dev_test_adhan_title` | Fire test adhan | تشغيل أذان تجريبي |
| `dev_test_adhan_subtitle` | Developer: runs the real adhan flow | للمطور: يشغّل مسار الأذان الحقيقي |
| `dev_test_adhan_dialog_title` | Fire a real test adhan? | تشغيل أذان تجريبي حقيقي؟ |
| `dev_test_adhan_dialog_body` | In about 10 seconds the real Zuhr adhan will play with sound, the phone will switch to vibrate for your Silent Mode duration from Settings, and the adhan screen will open. Azkar and prayer-check reminders may follow later. Set the ringer to Normal first. | بعد نحو عشر ثوانٍ سيُشغَّل أذان الظهر الحقيقي بالصوت، وسيتحول الهاتف إلى الاهتزاز طوال مدة الوضع الصامت المحددة في الإعدادات، وستظهر شاشة الأذان. وقد تصلك لاحقاً تذكيرات الأذكار ومتابعة الصلاة. اضبط الرنين على الوضع العادي أولاً. |
| `dev_test_adhan_fire` | Fire | تشغيل |
| `dev_test_adhan_scheduled` | Test adhan in about 10 seconds. Lock your phone now. | الأذان التجريبي بعد نحو عشر ثوانٍ. اقفل هاتفك الآن. |
| `dev_test_adhan_no_exact_alarm` | Exact alarm permission is off. Enable it in the app's alarm settings, then try again. | إذن المنبه الدقيق غير مفعّل. فعّله من إعدادات المنبهات ثم أعد المحاولة. |

All keys through `.tr()`. Note: the tile sits next to existing tiles that hard-code `isArabic ? ... : ...` (e.g.
`profile_screen.dart:306,314`); the new tile uses `.tr()` as CLAUDE.md requires. VERIFIED.

## Tests
Write first (tests-first, per group process):
- Widget test `test/features/profile/dev_test_adhan_tile_test.dart` for the extracted `_VersionTile` (made public, e.g.
  `ProfileVersionTile`, with injectable `fireTestAdhan` and `canScheduleExactAlarms` callbacks and a `version` string):
  1. 6 taps: no "Fire test adhan" tile. 7 taps: tile appears.
  2. Tapping the tile shows the dialog; Cancel calls nothing.
  3. Fire with permission: callback called once with `'Zuhr'`.
  4. Fire without permission: callback not called; the no-exact-alarm snackbar shows.
  5. Re-built widget (new instance): tile hidden again (not persisted).
  6. Arabic locale, 360 dp: no overflow.
- Existing `test/core/services/` has no `prayer_alarm_service` channel test; add one for `testAdhanNow` (sends
  `{'prayerName': 'Zuhr'}`; swallows PlatformException), modeled on `adhan_player_service_test.dart:34-53`. VERIFIED that
  file exists; UNKNOWN whether `PrayerAlarmService.initialize()` can run under test without more mocking.
Device-only (cannot be unit tested), on the nova 5T release build:
- D1: 7 taps reveal the tile; a fresh visit hides it.
- D2: Fire; the adhan sound, vibrate mode, notification and adhan screen appear in about 10 s.
- D3: adhan screen shows Stop Vibrate / Keep Vibrate; Stop Vibrate restores the ringer.
- D4: leave it; at window end the ringer restores to the saved mode (needs the real window length; shorten
  `silent_mode_duration` in Settings first if the Settings UI allows it, minimum UNKNOWN).
- D5: the real Zuhr adhan still fires normally afterwards (do on a day when it is possible).

## File boundary
- `lib/features/profile/profile_screen.dart`, new `lib/features/profile/profile_version_tile.dart` (if extracted),
  `assets/translations/en.json`, `assets/translations/ar.json`, new tests.
- Docs on completion: `lib/features/profile/README.md` (folder EGM contract), `STATE.md`, log.
- No Kotlin, manifest, pubspec, contracts.

## Phase and gate
- Phase `dev-test-adhan`, one branch, one PR; Level C for `lib/`, `assets/`, `test/` cases. Needs your review of this spec,
  then your explicit "approve phase dev-test-adhan". Nothing here is approved.
- Review size: small, no "edit carefully" files, no native contracts: one lightweight review.
- Verification after approval: `flutter analyze` (no new issues vs the baseline), `flutter test`, a release build,
  then the device checks D1-D5.
- Decisions (user): (a) Zuhr only: yes. (b) Keep the `canScheduleExactAlarms()` pre-check: yes. (c) The tile stays hidden
  behind the seven taps in ALL builds, no special case for debug builds. (d) Arabic strings: reviewed by Aladdin on 2026-11-14 ("Arabic every where is very good").
