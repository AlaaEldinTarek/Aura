# Fix: Dart → native settings bridge (F49a, F49b, F51i, F15, F49h, F49i, `adhan_enabled`)

*   **Author:** Alaa Eldin Tarek
*   **Status:** Proposed — EGM review done (`.project-docs/reference/reviews/settings-bridge/consolidated_review_report.md`),
    findings applied 2026-11-09; next: "approve phase settings-bridge"
*   **Date:** 2026-11-09
*   **Level:** C (production code: `lib/`, `android/`, `test/` cases; needs an approved spec and the phrase
    "approve phase settings-bridge", per `CLAUDE.md` § Rules) · branch `fix/settings-bridge`
*   **Input and decision record:** `.project-docs/reference/reviews/settings-bridge/precheck.md` (read-only check of
    main @ c5a848e; § "User decisions" lists every author decision, D1–D8 and A1–A5)

--------------------------------------------------------------------------------

## Overview

The Flutter (Dart) side of the app saves the user's settings in one prefs file, `FlutterSharedPreferences`, with
every key prefixed `flutter.`. The Android (Kotlin) side also needs some of these settings when the app is not
running: when an adhan alarm fires, after a reboot, or during the nightly prayer-time recalculation. For several
settings, the Android side looks in a different file, uses a different key, never saves the value, or ignores the
setting. The user changes a setting in the app and Android does not follow it.

This fix makes the four settings in this group (`silent_mode_enabled`, `adhan_enabled`, `selected_adhan_id`,
`background_notification_enabled`) come from one documented file and key each, records them in
`.project-docs/contracts/prefs-keys.md`, and fixes three related key mismatches (F15, F49h, F49i). The app
`language` stays duplicated in a native copy until F67.

It includes **two approved behavior changes**:

1.  Previewing an adhan reciter no longer changes the adhan that plays at prayer time (precheck § User decisions).
2.  For users whose two stored copies of "adhan on/off" disagree, the Flutter copy wins after the update; for them the
    toggle shown in the app and the adhan may both change (D8, Goal 9).

## The Problem

Static reading of the current code (main @ c5a848e) shows seven places where a Dart setting or value does not
reach, or is not kept by, the Android side. Device impact is not yet observed: device checks S25 (silent mode off at
adhan) and S26 (chosen reciter after the app is killed) in `.project-docs/reference/device-checklist.md` have not run.

| # | Setting or value | What the user does | What Android does today | Finding |
| --- | --- | --- | --- | --- |
| 1 | Silent mode at adhan | Turns it **off** | Reads `silent_mode_enabled` from `aura_silent_mode`, where no writer was found; the default `true` wins, so the phone is still switched to vibrate at adhan | F49a |
| 2 | Adhan reciter | Selects a downloaded reciter | Keeps the file path only in memory; after the app process ends (swipe away, reboot, low memory) the built-in adhan plays. Reset and deleting the selected reciter do not clear the path in a running process | F49b |
| 3 | Adhan reciter preview | Taps play to listen to a reciter | The previewed reciter becomes the live adhan for the rest of the process, even if the user never selects it | F49b (behavior) |
| 4 | Background prayer notification | Turns it **off** | Restarts the foreground service after reboot, after an app update, and every night after the 00:05 recalculation, and clears the service's "user stopped" flag (`fg_user_stopped`, set when Dart stops the service) each time | F51i |
| 5 | Prayer times sent to the service | (automatic, on every refresh) | `PrayerTimesNotifier.loadPrayerTimes` and `.updateNextPrayer` send the Zuhr time under `zuhr_time`; every Android reader uses `dhuhr_time`. `PrayerWidgetService.savePrayerTimes` sends the right key, so whether Android's Zuhr time goes stale depends on call order (not yet observed) | F15 |
| 6 | App language | Chooses Arabic | The silent-mode receiver reads `language` from `aura_prefs`, where no writer was found, so three of its messages are always English | F49h |
| 7 | (no setting; dead check) | — | The boot receiver skips re-arming adhan alarms if `aura_prefs.notifications_enabled` is false; no writer was found, so it is always `true` | F49i |

A further inconsistency breaks the one-key rule: **adhan on/off** (`adhan_enabled`) is saved twice, in Flutter prefs
and, through the `setAdhanEnabled` channel call, in `aura_prefs`. Android reads only `aura_prefs`, and the Dart
toggle also shows the `aura_prefs` copy, because `AdhanPlayerService.initialize` overwrites its value with the
native `isAdhanEnabled` result (`adhan_player_service.dart:38–42`, shown by `prayer_screen.dart:1128`). The copies
stay equal only while every channel call succeeds.

Why this keeps happening: there is no single rule for how Android reads a Dart setting. Some readers already use
`FlutterPrefs.kt` (the helper for `FlutterSharedPreferences` + `flutter.` prefix, e.g. `silent_mode_duration`,
`daily_summary_time`), while others use private native files that only some code paths fill. No test in `test/` or
`android/app/src/test/` references these keys (search, precheck § 5.9).

## Goals

Each goal names its proof and the Technical Plan section (§) that implements it. A **regression test** fails before
the fix and passes after it; a **structural test** exercises new code that does not exist before the fix (it fails
to compile before, which proves nothing about the bug); a **guard test** passes before and after and protects
behavior that is already right. Kotlin unit tests are plain JUnit with no Android runtime (see Non-Goals: no
Robolectric), so `SharedPreferences` reads are proven by named device checks.

1.  **Silent mode off is respected (F49a, §1):** with the toggle off, no adhan switches the ringer to vibrate or shows
    the vibration buttons, whether the app process is alive, killed, or the phone was rebooted.
    *   **Proof:** device check **S25** (toggle off → wait for an adhan with the app killed → ringer unchanged; logcat
        `🔧 [SETTINGS] Silent mode enabled: false`); the Kotlin scan test (§10) keeps `silent_mode_enabled` on
        `FlutterPrefs`.
2.  **Selected reciter survives the process (F49b, §3):** Android finds the selected reciter on its own, from
    `flutter.selected_adhan_id` plus the reciter download folder; there is no native copy of the path. This works
    after the app is swiped away, after reboot, after an app update, and for users who selected a reciter before this
    update. If no reciter is selected, the id does not match the rule, or the file is missing, the built-in adhan
    plays. Reset and deleting the selected reciter take effect at the next adhan, also in a running process.
    *   **Proof:** Kotlin structural test of the resolver (§3); Dart regression-guard test that every reciter in the
        catalog follows the file-name rule (§3); device check **S26** (select reciter → swipe app away → adhan plays
        the reciter; reset → built-in).
3.  **Preview does not change the live adhan (approved behavior change 1, §3–§4):**
    *   Old: previewing a reciter (`adhan_downloads_screen.dart:672–673`) calls `setCustomAdhan(path)`, so the
        previewed reciter becomes the live adhan for the rest of the process.
    *   New: previewing plays the reciter once; the adhan at prayer time stays the selected one (or built-in if none).
        Only selecting a reciter changes it. Everything else about preview stays as today, including that a preview
        stops whatever is playing (A1; listed as an open question under F66).
    *   **Proof:** Dart regression test on the downloads screen with a mocked adhan channel: a preview sends no
        `setCustomAdhan` and leaves `selected_adhan_id` unchanged (fails before: preview sends `setCustomAdhan`).
        Device check **S26 step (e)**: select A, preview B, let the adhan fire → A plays.
4.  **Background notification off stays off (F51i, §5):** Dart's `background_notification_enabled` is the single
    owner of this choice (D2). Every way the service starts without a user action follows it: reboot, app update and
    nightly recalculation (through `startServiceIfAllowed`), the service's own restart after swipe-away or destroy
    (`shouldAutoRestart`), and the system's `START_STICKY` recreation. The service stays off until the user turns the
    setting on (the Dart toggle writes the setting, then starts or stops the service over the
    `com.aura.hala/background_service` channel). `foreground_service_enabled` is a Dart-only record of whether the
    service is running, not the setting; nothing native reads it.
    *   **Proof:** Kotlin regression-relevant unit test of the decision `isAutoStartAllowed(settingEnabled,
        userStopped)` (four cases); Kotlin scan test (§10) that only allowed files call `startService` directly;
        device check **S42** (reboot, app update, nightly recalc by clock change, swipe-away); device check **S43**
        step for a user already caught by F51i (setting off, service running) who updates.
5.  **Zuhr key is always `dhuhr` (F15, §6):** one Dart function, `nativePrayerKey(name)`, gives the native key base for
    every prayer (`Zuhr`/`Dhuhr` → `dhuhr`), and every Dart sender builds keys with it: both provider sites, the
    widget service, and `buildNativeCache`. No Dart path writes `zuhr_time` or `zuhr_iqama_time`.
    *   **Proof:** Dart unit test of `nativePrayerKey`; Dart regression test of `PrayerTimesNotifier` capturing every
        `updatePrayerTimes` map (fails before the fix); existing `prayer_refresh_test.dart` and a new widget-service
        test as guard tests; Dart scan test (§10) that fails on any `toLowerCase()}_time` key building in `lib/`; device
        logcat step in **S43** (§6: every "🕌 [FG_SERVICE] Prayer time keys" line contains `dhuhr_time` and no
        `zuhr_time`).
6.  **Silent-mode receiver messages follow the app language (F49h, §7):** `ToggleSilentModeReceiver` reads
    `aura_prayer_times.language`, the same channel-pushed copy that 13 other native language reads use (D4). Dart
    pushes that copy at once when the language changes (`LanguageNotifier.setLanguage`,
    `preferences_provider.dart:124–152`, calls `PrayerWidgetService.savePrayerTimes`) and on every prayer refresh.
    The **push gap** is the one case where the copy lags: a language change while no prayer times are loaded yet
    (`:137`), or a failed push (logged only, `:150–151`); the copy then updates at the next refresh. Moving all native
    language reads to `flutter.language` is F67.
    *   **Proof:** device check **S25**, Arabic run: change the language to Arabic with prayer times loaded, then
        trigger the silent-mode messages → Arabic text.
7.  **No native code reads a key that nothing writes (F49i, §8):** the boot receiver's
    `aura_prefs.notifications_enabled` check (`PrayerBootReceiver.kt:58–65`) is removed. No writer of that key was
    found in current code (precheck § 3), so the check is always `true` today and removing it changes no behavior:
    adhan alarms are re-armed at every boot, as now. "Adhan off" stays enforced at alarm time by `AdhanPlayer.play`,
    which reads `flutter.adhan_enabled` after this fix.
    *   **Proof:** Kotlin scan test (§10: no `"aura_prefs"` literal); reboot step of **S42** (adhan alarms re-armed,
        `dumpsys alarm`).
8.  **One file and key for each setting in this group (§ Rule, §2, §3):** `silent_mode_enabled`, `adhan_enabled`,
    `selected_adhan_id` and `background_notification_enabled` are read by Android only from
    `FlutterSharedPreferences` through `FlutterPrefs`; `adhan_enabled` has one stored copy; native keeps no copy of the
    reciter path. Each is listed in `contracts/prefs-keys.md` with file, key, writer and readers, together with the
    Android reciter rule (§3). `aura_prayer_times.language` stays, listed as a known channel-pushed duplicate of
    `flutter.language` (F67). Settings outside this group are not moved.
    *   **Proof:** Kotlin and Dart scan tests (§10) run on every `flutter test` / Gradle unit-test run; contract table
        reviewed against the code in the PR.
9.  **Settings on update (approved behavior change 2, §2):** a user who updates keeps their silent-mode choice,
    selected reciter, and background-notification choice. For adhan on/off, if the two old copies disagree, **Flutter
    prefs wins** (D8). Reason: `AdhanPlayerService.setEnabled` writes Flutter prefs first (`:94`) and only then calls
    the channel (`:97`), and no code writes `aura_prefs.adhan_enabled` without that Flutter write, so Flutter prefs
    always holds the user's latest choice; a disagreement means a channel call failed. For those users both the
    toggle shown in the app (which today shows the native copy, see The Problem) and the adhan may change after the
    update.
    *   **Proof:** device check **S43** (install the current main build, set silent mode off, a reciter, adhan off,
        background notification off; update in place to the fix build; each setting holds at the next adhan or
        restart). The disagreement case is not reproducible without editing prefs on the device; it follows from Goal 8.

## Non-Goals

*   **F9** (`com.aura.hala/silent_mode` channel without a Kotlin handler; unused `SilentModeService`): moved to P6
    cleanup (precheck § User decisions).
*   No new settings, screens, or strings; no UI layout changes.
*   No change to notification IDs, notification channels, alarm request codes, or intent extras. MethodChannel
    **names** stay; the methods of `com.aura.hala/adhan` change (4 removed, `previewAdhan` added, §4), and
    `contracts/method-channels.md` is updated in the same commit.
*   No change to native state keys that are not user settings (`is_silent_active`, `saved_ringer_mode`,
    `silent_end_time`, `adhan_active`, `fg_user_stopped`, prayer-time keys other than the F15 Zuhr key).
*   No migration of Dart to `SharedPreferencesAsync` / DataStore (risk R5).
*   No change to Windows behavior: the desktop adhan (`desktop_adhan_service.dart`) reads `adhan_enabled` from Flutter
    prefs and plays `adhans/<prayerName>.mp3`; it does not use `selected_adhan_id`.
*   No Focus Mode prefs (`${packageName}_preferences`, `aura_focus_state`, `aura_focus_mode`).
*   No other findings in the same files (e.g. F51h stale next prayer, F51j azkar launch, F53a cache use).
*   **F66** ("adhan off" only stops the sound; and a preview can interrupt a prayer adhan): intended behavior is
    undecided. This fix keeps both behaviors and only moves the `adhan_enabled` read to Flutter prefs.
*   **F67** (native `language` reads use channel-pushed copies instead of `flutter.language`): later fix (D4).
*   No Robolectric or other new test dependency (D6).

## Open Questions

None. All decisions are recorded in precheck § User decisions (D1–D8 while drafting, A1–A5 after the review).

## Technical Plan (Architecture)

### Rule for this group

Android reads each of the four settings **at the moment it needs it**, from `FlutterSharedPreferences` through the
existing `FlutterPrefs` helper (`FlutterPrefs.kt`). It does not cache the value and keeps no copy in a native file.
Its default equals the Dart default. Dart already writes all four keys; no Dart write changes except removing the
channel calls.

| Setting (Flutter key) | Dart writes / removes (unchanged) | Android reads after the fix | Default (both sides) |
| --- | --- | --- | --- |
| `silent_mode_enabled` | `shared_preferences_service.dart:201–202` (Settings), `prayer_screen.dart:1422` | `PrayerAlarmReceiver`, `AdhanFullScreenActivity` | `true` |
| `adhan_enabled` | `adhan_player_service.dart:94` (`setEnabled`, from `prayer_screen.dart:1385`) | `AdhanPlayer.play`, `AdhanPlayer.previewAdhan` | `true` |
| `selected_adhan_id` | `adhan_downloads_screen.dart:327` (select); removed at `:418` (reset), `:828` (delete) | `AdhanPlayer.play` through `AdhanFiles.resolve` | absent → built-in |
| `background_notification_enabled` | `prayer_screen.dart:1290` | `PrayerForegroundService` (`startServiceIfAllowed`, `shouldAutoRestart`, sticky-restart check) | `true` |

Read timing: no component in `AndroidManifest.xml` declares `android:process`, so receivers, services and activities
run in the app's single process. Android returns one shared `SharedPreferences` object per file per process, and the
legacy Dart plugin writes through it, so a native read after a Dart write sees the new value.

### Data flow after the fix

```text
 Dart (Flutter UI)                                  Android (Kotlin, app may have been killed/rebooted)
 ─────────────────                                  ───────────────────────────────────────────────────
 Settings / Prayer settings ──write──► FlutterSharedPreferences ◄──read (FlutterPrefs)── PrayerAlarmReceiver
   silent_mode_enabled                  flutter.silent_mode_enabled                        AdhanFullScreenActivity
   adhan_enabled                        flutter.adhan_enabled          ◄── AdhanPlayer.play / previewAdhan
   background_notification_enabled      flutter.background_notification_enabled ◄── PrayerForegroundService
 Adhan downloads screen                 flutter.selected_adhan_id      ◄── AdhanFiles.resolve(id, dir)
   select / reset / delete                                                     │
   download ──file──► app_flutter/adhans/adhan_<id>.mp3 ◄──────────────────────┘ (PathUtils.getDataDirectory)
   preview ──channel previewAdhan {id}──► AdhanPlayer.previewAdhan (same resolver; changes nothing stored)

 Prayer refresh   ──channel updatePrayerTimes {dhuhr_time, …, language}──► aura_prayer_times (native copy)
 Language change  ──LanguageNotifier.setLanguage → savePrayerTimes {…, language}──► aura_prayer_times
```

### §1 Silent mode (F49a; Goal 1)

Both readers switch from `aura_silent_mode.silent_mode_enabled` to `FlutterPrefs.getBoolean(context,
"silent_mode_enabled", true)`. The `aura_silent_mode` file keeps its native state keys (`is_silent_active`,
`saved_ringer_mode`, `silent_end_time`); only the setting moves. The log line `🔧 [SETTINGS] Silent mode enabled: …`
stays.

### §2 Adhan on/off (duplicate `adhan_enabled`; Goals 8, 9)

`AdhanPlayer` reads `FlutterPrefs.getBoolean(context, "adhan_enabled", true)` instead of `aura_prefs`. Dart stops
reading the native copy at start (`AdhanPlayerService.initialize` no longer calls `isAdhanEnabled`), so Flutter prefs
is the only source on both sides. What "adhan off" stops is unchanged: only the sound (F66).

### §3 Reciter (F49b; Goals 2, 3, 8)

New Kotlin object **`AdhanFiles`**:

*   `resolve(selectedId: String, adhansDir: File): File?` — returns `File(adhansDir, "adhan_<id>.mp3")` only when the
    id matches `^[a-z0-9_]+$` and the file exists and is a regular file; otherwise `null`. An empty string (what
    `FlutterPrefs.getString(…, "")` returns when the key is absent) fails the pattern. Uses only `java.io.File`, so
    plain JUnit can test it.
*   `adhansDir(context): File` — `File(io.flutter.util.PathUtils.getDataDirectory(context), "adhans")`. This is the
    call `path_provider_android` 2.2.23 uses for `getApplicationDocumentsDirectory()` (`PathProviderPlugin.java:57–58`).
    The engine source in the local Flutter SDK (`PathUtils.java:25–29`, SDK commit 3b62efc2a3d) returns
    `context.getDir("flutter", MODE_PRIVATE)`, i.e. `<app data>/app_flutter`; S26 and S43 confirm on a device that
    Kotlin finds the downloaded file.

**Android reciter rule** (recorded in `contracts/prefs-keys.md`, Android only): folder
`PathUtils.getDataDirectory(context)/adhans`, file `adhan_<id>.mp3`, id `[a-z0-9_]+`; anything else or a missing file
→ built-in adhan for a prayer, nothing for a preview. Dart's download writes `adhans/<reciter.fileName>`
(`adhan_downloads_screen.dart:152–162`), and the catalog `availableAdhans` (`:45–97`) holds the reciter ids and file
names. All five entries follow the rule today; a Dart test locks it (every entry: `fileName == 'adhan_${id}.mp3'`
and id matches `^[a-z0-9_]+$`), and a comment at `availableAdhans` points to the contract. Windows keeps its own
`adhans/<prayerName>.mp3` files (Non-Goals).

`AdhanPlayer` changes:

*   Remove `customAdhanPath`, `setCustomAdhan`, `getCustomAdhan` (no native copy).
*   Extract today's start sequence from `play` (`AdhanPlayer.kt:189–198`: `stop()`, save `appContext`, register the
    volume receiver, set up the media session) into a private `prepareOutput(context)`, used by `play` and
    `previewAdhan`.
*   `play(context, prayerName)` (prayer adhan, `@Synchronized` as today): after the enabled check, resolve the
    selected reciter with `AdhanFiles.resolve(FlutterPrefs.getString(context, "selected_adhan_id", ""),
    AdhanFiles.adhansDir(context))`. File found → the existing custom-file playback; `null` → the existing built-in
    files and fallback.
*   New `previewAdhan(context, id): Boolean`, `@Synchronized` (same monitor as `play`). Order: if
    `FlutterPrefs.getBoolean(context, "adhan_enabled", true)` is false → return `false` (as today: preview goes
    through `play`'s enabled check, `AdhanPlayer.kt:179–186`); resolve `id` → `null` → return `false` (no built-in
    fallback); otherwise `prepareOutput(context)` (stops whatever plays, including a prayer adhan, as today), native
    `vibrate(context)`, `playCustomAdhan(context, file.path, "Fajr")` (today's preview passes `"Fajr"`,
    `adhan_downloads_screen.dart:673`); return its result. Reads and writes no setting.
*   The unused `playbackLock` (`AdhanPlayer.kt:32`) is deleted; `stop()` stays unsynchronized, as today.
*   Preview only offers downloaded reciters: the play button exists only inside `if (isDownloaded)`
    (`adhan_downloads_screen.dart:613–634`).

### §4 Channel `com.aura.hala/adhan` and Dart callers (Goals 3, 8)

| Method | Status | Args → result |
| --- | --- | --- |
| `playAdhan` | unchanged | `{prayerName}` → `true` (plays the live adhan: selected reciter or built-in) |
| `stopAdhan` | unchanged | — → `true` |
| `previewAdhan` | **new** | `{id: String}` → `Boolean` (started or not; missing `id` → `false`) |
| `setAdhanEnabled`, `isAdhanEnabled`, `setCustomAdhan`, `getCustomAdhan` | **removed** (both sides) | — |

Dart `AdhanPlayerService`: remove the 4 calls and `setCustomAdhan` / `getCustomAdhan`; add `Future<bool>
previewAdhan(String id)` that keeps today's Dart-side preview steps from `playAdhan` (`:58–74`): return `false` if
`!_isEnabled`; vibrate if `_isAndroid && _vibrationEnabled`; then the channel call, in try-catch (`false` and a log on
any error). No `_isAndroid` guard on the channel call: on Windows it gets `MissingPluginException` and returns
`false` (the downloads screen is reachable on Windows; today the same call fails the same way).

Adhan downloads screen: select writes `selected_adhan_id` and no longer calls the channel; reset and delete remove the
key and no longer call the channel; preview keeps today's pre-stop (`:666–668`), then calls
`previewAdhan(reciter.id)` and sets `playingAdhanProvider` and the snackbar only when it returns `true` (otherwise the
button stays in its play state). The now-unused `getDownloadedPath` (`:278–283`) and its two local calls (`:332–333`,
`:671`) are removed.

### §5 Background notification off (F51i; Goal 4)

`PrayerForegroundService` companion gets:

*   `isAutoStartAllowed(settingEnabled: Boolean, userStopped: Boolean): Boolean` = `settingEnabled && !userStopped`
    (pure; JUnit, precedent `DailySummaryDateKeyTest.kt` calls a companion function on an Android component).
*   `startServiceIfAllowed(context, reason: String): Boolean` — reads
    `FlutterPrefs.getBoolean(context, "background_notification_enabled", true)`; calls
    `isAutoStartAllowed(setting, userStopped = false)` (an explicit start clears `fg_user_stopped`, as `startService`
    does today); if allowed, calls the existing `startService` and returns `true`; else logs
    `⏭️ [FG_SERVICE] Auto-start skipped (background notification off): <reason>` and returns `false`.

The three places that start or restart the service without a user action use the same decision:

| Path | Today | After the fix |
| --- | --- | --- |
| Boot and app update (`MY_PACKAGE_REPLACED` is registered only for `PrayerBootReceiver`, handled in the boot branch) | `PrayerBootReceiver.restartForegroundService` → `startService` | → `startServiceIfAllowed(context, "boot")`; the existing success log is written only when it returns `true` |
| Nightly recalc at 00:05 | `DailyRecalcReceiver.onReceive` → `startService` | → `startServiceIfAllowed(context, "daily_recalc")` |
| Swipe-away / destroy restart (alarm → `PendingIntent.getService`) | `scheduleRestartIfNeeded` gated by `shouldAutoRestart()` = `!fg_user_stopped` | `shouldAutoRestart()` = `isAutoStartAllowed(setting, fg_user_stopped)` |
| System `START_STICKY` recreation (`onStartCommand` with a `null` intent) | always continues | if `!isAutoStartAllowed(setting, fg_user_stopped)`: log, `stopSelf()`, return `START_NOT_STICKY`; else `START_STICKY` as today |

The sticky recreation is started by the system, not by app code, so it cannot call `startServiceIfAllowed`; it uses
the same decision instead. `onCreate` already calls `startForeground` before `onStartCommand` runs
(`PrayerForegroundService.kt:124–133`), so stopping in `onStartCommand` does not hit the foreground-start time limit;
the notification may appear for a moment before `stopSelf()` removes it. Unchanged: `MainActivity.kt:642` (the
`startForegroundService` channel method; Dart checks the setting first, `background_service_manager.dart:49–53`) and
`BackgroundServiceHandler.kt:20` (F10: a duplicate handler class with no instantiation found).

### §6 Zuhr key (F15; Goal 5)

One public function in `lib/core/utils/prayer_time_rules.dart`: `String nativePrayerKey(String name)` — lower-cases
the name; `zuhr` and `dhuhr` → `dhuhr`; every other name unchanged. Every Dart sender uses it:

*   `prayer_times_provider.dart` both sites: time key `'${nativePrayerKey(p.name)}_time'`; iqama key
    `'${nativePrayerKey(p.name)}_iqama_time'` (replaces the `p.name == 'Zuhr'` special case at `:355–357`). Loop
    shapes and the Sunrise rule stay.
*   `prayer_widget_service.dart`: `_getTimeKey` and `_getIqamaKey` (`:94–124`) become one-line wrappers or are
    replaced by `nativePrayerKey` with the suffix at the call sites; the two maps it sends (`prayerTimes`,
    `iqamaTimes`) keep their shape and its Sunrise behavior stays.
*   `prayer_refresh.dart` `buildNativeCache` (`:52`): `nativePrayerKey(p.name)` replaces its own Zuhr mapping.

An orphan `zuhr_time` already stored on a device is left in place (no reader). To make the device proof possible on a
release build (`run-as` needs a debuggable build), `PrayerForegroundService.updatePrayerTimes` (companion,
`:96–121`) logs the keys it stores: `🕌 [FG_SERVICE] Prayer time keys: <sorted key list>` (keys only, no values;
release builds keep `Log.d`, `proguard-rules.pro` has no log stripping). The `🕌` prefix is already listed for
`PrayerForegroundService` in `contracts/log-tags.md`.

### §7 Silent-mode receiver language (F49h; Goal 6)

`ToggleSilentModeReceiver.getLanguage` (`:253–256`) is removed; its three callers (`:142, :222, :238`) use the class's
existing `getLanguagePreference` (`aura_prayer_times.language`, `:373–375`).

### §8 Boot check (F49i; Goal 7)

`PrayerBootReceiver.reschedulePrayerAlarms` loses the `aura_prefs.notifications_enabled` read (`:58–65`) and always
starts `PrayerRescheduleService`, as it does today.

### §9 `aura_prefs` after the fix

No code reads or writes `aura_prefs` any more. The file stays on existing devices untouched (deleting it would add a
migration step with no user effect). `contracts/prefs-keys.md` marks it with the exact text:
"obsolete — no reader or writer since `fix/settings-bridge`; left on old installs".

### §10 Permanent scan tests (A4; Goals 1, 4, 5, 7, 8)

Two tests read source files as text, so the same class of bug fails the build the next time it is introduced:

*   **Kotlin** `NativePrefsContractTest.kt` (plain JUnit; reads `src/main/kotlin/com/aura/hala/*.kt`, relative to the
    module directory Gradle runs unit tests in). Lines whose trimmed text starts with `//`, `*` or `/*` are skipped.
    Fails when:
    1.  any file contains the literal `"aura_prefs"`;
    2.  a line contains `"silent_mode_enabled"`, `"adhan_enabled"`, `"background_notification_enabled"` or
        `"selected_adhan_id"` and does not contain `FlutterPrefs.` (so each such read is written on one line,
        e.g. `FlutterPrefs.getBoolean(context, "adhan_enabled", true)`);
    3.  a file other than `PrayerForegroundService.kt`, `MainActivity.kt` (Dart-initiated channel start) and
        `BackgroundServiceHandler.kt` (F10, Dart-initiated) contains `PrayerForegroundService.startService(`.
*   **Dart** `test/contracts/native_keys_scan_test.dart` (reads `lib/**/*.dart`). Fails when a file contains
    `toLowerCase()}_time`, `toLowerCase()}_iqama_time`, `'zuhr_time'`, `"zuhr_time"`, `'zuhr_iqama_time'` or
    `"zuhr_iqama_time"`.

Both fail on today's code (rule 1: `aura_prefs` is read in 5 places; Dart: `prayer_times_provider.dart:350, :543`), so
they are regression tests. Limits: they check where a read goes, not that it works at runtime; a key built
dynamically (not a literal) would escape them.

## Risks & Mitigations

| # | Risk | Failure mode | Mitigation | Proof |
| --- | --- | --- | --- | --- |
| R1 | **Security:** the reciter id comes from prefs and reaches a file path | A crafted id such as `../x` reads a file outside the reciter folder | Android accepts only ids matching `^[a-z0-9_]+$` and only the name `adhan_<id>.mp3` in the reciter folder (§3); preview takes an id, not a path (Alternative H) | `AdhanFilesTest` (`../x`, upper case, empty) |
| R2 | Device impact of the bugs is not observed yet (S25, S26 not run) | A fix is shipped for a path that behaves differently on a device | Device checks S25, S26, S42, S43 before merge; nothing marked PASS unless it ran | device checklist |
| R3 | Reciter catalog drifts from the Android rule | A new reciter downloads but Android plays the built-in adhan | Dart catalog test (§3) | `adhan_catalog_test.dart` |
| R4 | Goal 9 disagreement case cannot be reproduced | An affected user sees the toggle change after update | Stated as approved behavior change 2; follows from one reader | Goal 8 scan test |
| R5 | A later move of Dart to `SharedPreferencesAsync` stores data in DataStore | Every `FlutterPrefs` reader silently returns defaults | Non-Goal; `contracts/prefs-keys.md` keeps the FlutterPrefs rule | — |
| R6 | `START_STICKY` recreation while the setting is off | Notification shows for a moment, then `stopSelf()` | Accepted (§5) | S43 F51i step |
| R7 | `PrayerTimesNotifier` cannot be driven in a test without production changes | Provider regression test missing | Fallback: Dart scan test + S43 logcat key step | §6, §10 |
| R8 | Reverting the adhan commit (commit 3) after users changed adhan on/off | Old build reads the stale `aura_prefs` copy (and overwrites the Dart toggle with it); the change is lost, e.g. adhan turned on → silent adhan | Accepted, documented here (A5); no resync | — |
| R9 | `PrayerAlarmReceiver.kt` and `prayer_times_provider.dart` are "edit carefully" files (`CLAUDE.md`: known regressions; change only what the spec names) | Unrelated change slips in | One read changes in `PrayerAlarmReceiver.kt`; two key expressions change in the provider | PR diff review |
| R10 | A Dart caller of a removed channel method is missed | The call fails: `MissingPluginException`, caught and logged where the call has try-catch; `setCustomAdhan` has none today (`adhan_player_service.dart:136`) | The Dart methods are removed, so a missed caller does not compile; static search in the PR | Verification Plan |

**Known limitations (pre-existing, not changed):** a corrupt reciter file that passes `File.exists()` makes
`playCustomAdhan` fail and call `releasePlayer()` (`AdhanPlayer.kt:273, :277`), which unregisters the volume receiver
and media session; the built-in fallback then plays without volume-key stop. This path is hit more often after the
fix because the selected reciter now survives process death. After a prayer adhan stops a preview, the downloads
screen still shows the stop button; tapping it stops the prayer adhan (F66 note).

## Alternatives Considered

Decisions are recorded in `.project-docs/reference/reviews/settings-bridge/precheck.md` § User decisions (ids below).

### Alternative A: Native keeps its own copy of the reciter path (F49b)

*   **Mechanism:** `setCustomAdhan` saves the path in a native prefs file; native reads it at adhan time.
*   **Pros:** small change to today's flow; no folder rule in Kotlin.
*   **Cons:** a second stored copy of the same choice; users who selected a reciter before the update have no native
    copy until Dart re-sends it; the copy drifts from `selected_adhan_id` if a channel call fails.
*   **Reason for Rejection:** a second copy plus a start-up migration step, where resolving from the existing key
    needs neither (D3).

### Alternative B: Native `fg_user_stopped` owns "background notification off" (F51i)

*   **Mechanism:** boot, update and recalc paths read `fg_user_stopped` and stop clearing it.
*   **Pros:** no Flutter key read in the service.
*   **Cons:** two values for one choice; the flag is cleared by every `startService`, so its meaning depends on call
    order.
*   **Reason for Rejection:** keeps two owners whose values can disagree (D2).

### Alternative C: Map the boot check to a real setting (F49i)

*   **Mechanism:** the boot receiver skips re-arming adhan alarms when, for example, `flutter.adhan_enabled` is false.
*   **Pros:** the check would mean something.
*   **Cons:** with adhan off, no notification, full-screen screen or vibrate mode after a reboot until the app is
    opened, while Dart still arms them on open.
*   **Reason for Rejection:** changes behavior that F66 has not decided (D1). These cons are judged against current
    behavior; if F66 is decided differently, review this alternative again.

### Alternative D: Move every native language read to `flutter.language` now

*   **Mechanism:** all native `language` reads use `FlutterPrefs` (16 `getString("language"` reads in 12 Kotlin files
    by search on c5a848e: 13 in `aura_prayer_times`, 2 in `TasksWidget.kt` from the tasks-widget file, 1 in
    `aura_prefs` = F49h).
*   **Pros:** meets the one-key goal for language; removes the push gap.
*   **Cons:** about 12 files, including `PrayerAlarmReceiver.kt` and the widgets.
*   **Reason for Rejection:** outside the closed group scope; scheduled as F67 (D4).

### Alternative E: F49h reads `flutter.language` only in the silent-mode receiver

*   **Mechanism:** one receiver uses `FlutterPrefs`; the other native reads keep the copy.
*   **Pros:** that receiver never lags.
*   **Cons:** two language sources on the native side; screens can disagree during the push gap.
*   **Reason for Rejection:** inconsistent sources until F67 (D4).

### Alternative F: Keep the 4 adhan channel methods and re-wire them

*   **Mechanism:** `isAdhanEnabled` / `setAdhanEnabled` backed by `FlutterPrefs`; `setCustomAdhan` a no-op;
    `getCustomAdhan` returns the resolved file; plus a preview method.
*   **Pros:** no channel methods removed.
*   **Cons:** two writers of `flutter.adhan_enabled`; method names that no longer do what they say.
*   **Reason for Rejection:** two writers and misleading names (D5).

### Alternative G: Preview plays in Dart with `audioplayers`

*   **Mechanism:** the downloads screen plays the file with the existing `audioplayers` dependency.
*   **Pros:** no new native method.
*   **Cons:** preview would play with adhan off; different audio stream and volume-key handling; not verified on
    Android.
*   **Reason for Rejection:** an unapproved behavior change (D5).

### Alternative H: `previewAdhan {path}` instead of `{id}`

*   **Mechanism:** Dart sends the file path, as `setCustomAdhan` does today.
*   **Pros:** no id rule for preview.
*   **Cons:** preview and the live adhan find files by different rules; Dart could send any path (R1).
*   **Reason for Rejection:** two file rules and an unrestricted path (D5).

### Alternative I: Add Robolectric so `SharedPreferences` reads are unit-tested

*   **Mechanism:** new test dependency; Kotlin tests run receivers against a fake Android context.
*   **Pros:** F49a, F49h and the update path would get unit tests.
*   **Cons:** new Level B tooling (test infrastructure, separate approval in `CLAUDE.md`) inside a Level C fix.
*   **Reason for Rejection:** needs a separate tooling approval (D6).

### Alternative J: Separate PRs per repair type

*   **Mechanism:** one PR each for the adhan settings, the service restarts, the Zuhr key and the small reads.
*   **Pros:** smaller reviews on the "edit carefully" files.
*   **Cons:** the contracts are edited and reviewed several times; the one-key goal is met only after the last PR.
*   **Reason for Rejection:** repeated contract edits (D7); commits are split by repair type instead.

### Alternative K: Fix F49a by writing the setting into `aura_silent_mode`

*   **Mechanism:** Dart sends the toggle over a channel (the `silent_mode` channel, F9) and native stores it in
    `aura_silent_mode`.
*   **Pros:** native readers stay unchanged.
*   **Cons:** a second copy of the setting; needs a Kotlin handler for a channel that has none (F9).
*   **Reason for Rejection:** a second copy, against the `CLAUDE.md` rule that Kotlin reads Flutter prefs through
    `FlutterPrefs.kt` (precheck § 5.5).

### Alternative L: A shared map builder for F15

*   **Mechanism:** `buildNativePrayerTimesMap(prayers, includeIqama)` used by the provider and the widget service.
*   **Pros:** one place builds the whole map.
*   **Cons:** the senders send different map shapes (merged vs separate iqama map, different Sunrise rules), so the
    builder needs flags and fits only the provider.
*   **Reason for Rejection:** more mechanism than the one key rule needs (A2).

### Alternative M: Refuse a preview while a prayer adhan plays

*   **Mechanism:** a playback-kind flag (`AdhanPlaybackState`) in `AdhanPlayer`; `previewAdhan` returns `false` while a
    prayer adhan plays.
*   **Pros:** a preview cannot cut off a prayer adhan.
*   **Cons:** a second behavior change; new state that every playback ending must clear; Dart's pre-stop would still
    stop the prayer adhan.
*   **Reason for Rejection:** keep today's behavior; the question is recorded under F66 (A1).

### Alternative N: Gate the setting inside `startService` itself

*   **Mechanism:** `startService` reads `background_notification_enabled` and returns early when it is off.
*   **Pros:** every caller follows the setting with no call-site change.
*   **Cons:** does not cover the self-restart paths, which do not call `startService` (§5).
*   **Reason for Rejection:** incomplete; the named paths plus the scan test cover all callers (A3).

### Alternative O: One-time searches pasted into the PR instead of scan tests

*   **Mechanism:** run the searches once and paste the results.
*   **Pros:** no source-scanning tests to maintain.
*   **Cons:** protects only this PR; `contracts/prefs-keys.md` history shows this bug class came back several times.
*   **Reason for Rejection:** no lasting guard (A4).

### Alternative P: Resync Flutter → native `adhan_enabled` for rollback safety

*   **Mechanism:** keep writing `aura_prefs.adhan_enabled` from Flutter prefs so a reverted build reads a fresh copy.
*   **Pros:** reverting commit 3 would not lose adhan on/off changes.
*   **Cons:** keeps the duplicate this fix removes, only for a rollback that may never happen.
*   **Reason for Rejection:** documented as risk R8 instead (A5).

--------------------------------------------------------------------------------

## Non-Functional Requirements

*   **Rollout & rollback:** one PR on `fix/settings-bridge`; each repair commit can be reverted alone. No prefs key is
    renamed or deleted. Rolling back is expected (static reading, not tested) not to crash: an older build reads its
    old copies again and today's bugs return; reverting commit 3 also loses adhan on/off changes made under the fix
    (R8).
*   **Data on existing installs:** nothing is migrated or deleted. Old `aura_prefs` values and an orphan `zuhr_time`
    stay unread.
*   **Performance:** each setting is one prefs lookup at the moment of use (the file is loaded once per process; the
    first read after a reboot or process kill loads it from disk); the reciter check is one `File.exists()` at adhan
    or preview time.

--------------------------------------------------------------------------------

## Detailed Implementation Plan

### Branch, commits and order

Branch `fix/settings-bridge` from `main`. One PR. Commits are split by repair type; each commit carries its own Dart,
Kotlin, `contracts/` and folder-README changes together (`CLAUDE.md`: native keys change in Dart, Kotlin and
`.project-docs/contracts/` in one commit). Inside each commit the tests are written first. Regression tests must
fail before the production change; structural and guard tests are listed as such and are not expected to fail first.

| # | Commit summary (imperative, < 72 chars) | Goals |
| --- | --- | --- |
| 0 | Add settings-bridge spec | — |
| 1 | Use one native key rule for Zuhr in all Dart senders (F15) | 5 |
| 2 | Read the silent-mode setting from Flutter prefs (F49a, F49h) | 1, 6 |
| 3 | Read adhan settings from Flutter prefs and add reciter preview | 2, 3, 8, 9 |
| 4 | Respect background notification setting on restarts (F51i, F49i) | 4, 7 |
| 5 | Document settings-bridge fix, device results and PR description | — |

### Target Files to Create/Modify

#### Commit 0 — spec

1.  `docs/designs/fix-settings-bridge.md` (Create) — this design.
2.  `.project-docs/reference/reviews/settings-bridge/` (Create) — `precheck.md` (decision record) and the six EGM
    review reports.
3.  `.project-docs/reference/findings.md` (Modify; F66, F67 already written) — findings recorded while drafting; tag
    F9 "moved to P6 cleanup (settings-bridge spec)" and F49i "joined settings-bridge".
4.  `.project-docs/STATE.md`, `.project-docs/log/<commit date>.md` (Modify) — record the spec and the group. Log file
    rule for every commit below: `.project-docs/log/YYYY-MM-DD.md` of the commit date.

#### Commit 1 — Zuhr key (F15)

5.  `lib/core/utils/prayer_time_rules.dart` (Modify) — add `String nativePrayerKey(String name)` (§6).
6.  `lib/core/providers/prayer_times_provider.dart` (Modify, "edit carefully") — `:350` and `:543` time keys and
    `:355–357` iqama key use `nativePrayerKey`. Nothing else in the file changes.
7.  `lib/core/services/prayer_widget_service.dart` (Modify) — `_getTimeKey` / `_getIqamaKey` (`:94–124`) are removed;
    their call sites build `'${nativePrayerKey(name)}_time'` / `'${nativePrayerKey(name)}_iqama_time'`. Both maps
    keep their shape; Sunrise behavior unchanged.
8.  `lib/core/utils/prayer_refresh.dart` (Modify) — `buildNativeCache` `:51–52` uses `nativePrayerKey`.
9.  `android/app/src/main/kotlin/com/aura/hala/PrayerForegroundService.kt` (Modify) — companion `updatePrayerTimes`:
    add the key log line (§6) after `:120`.
10. `test/core/utils/prayer_time_rules_native_key_test.dart` (Create, structural) — `nativePrayerKey`: `Fajr`,
    `Sunrise`, `Zuhr`, `Dhuhr`, `zuhr`, `Asr`, `Maghrib`, `Isha` → `fajr`, `sunrise`, `dhuhr`, `dhuhr`, `dhuhr`, `asr`,
    `maghrib`, `isha`.
11. `test/core/services/prayer_widget_service_native_keys_test.dart` (Create, **guard**: the widget service already
    sends `dhuhr_time`) — mock `com.aura.hala/widgets` and `com.aura.hala/background_service` with
    `TestDefaultBinaryMessenger`, `SharedPreferences.setMockInitialValues({})`; call `savePrayerTimes` with today's
    prayers incl. `Zuhr` with an iqama time; assert the `updatePrayerTimes` arguments' `prayerTimes` has
    `dhuhr_time`, `iqamaTimes` has `dhuhr_iqama_time`, and neither has a `zuhr_` key.
12. `test/core/providers/prayer_times_provider_native_keys_test.dart` (Create, **regression**) — a test subclass of
    `PrayerTimesNotifier` built with fakes that `implements` `PrayerTimesService` and `LocationService` (fixed
    location; prayers for today with times relative to `DateTime.now()`: Fajr −6 h, Sunrise −5 h, Zuhr +1 h, Asr
    +3 h, Maghrib +5 h, Isha +6 h, each with an iqama time), `SharedPreferences.setMockInitialValues({})`, and the
    `background_service` and `widgets` channels mocked to record every call. Let `_init` finish (`pumpEventQueue`),
    which runs `loadPrayerTimes`; then call `updateNextPrayer`; then `dispose()` (cancels the timer). Assert: at least
    one captured `updatePrayerTimes` call, and **no** captured call's `prayerTimes` map has a key starting with
    `zuhr_`. Fails before the fix. If the notifier cannot be built without production changes, the file is not
    added, the PR says so, and Goal 5 rests on the Dart scan test (item 16) and the S43 logcat step (R7).
13. `test/core/utils/prayer_refresh_test.dart` (existing, **guard**) — its `buildNativeCache` cases (`:143–146`) must
    still pass.
14. `.project-docs/contracts/prefs-keys.md` (Modify) — row `:42`: prayer-time keys cell becomes "`fajr_time`,
    `sunrise_time`, `dhuhr_time` (Dart builds every key with `nativePrayerKey`, `prayer_time_rules.dart`), `asr_time`,
    `maghrib_time`, `isha_time`"; row `:45`: iqama keys "built with `nativePrayerKey` + `_iqama_time`" instead of
    `_getIqamaKey`; add "an orphan `zuhr_time` may exist on old installs (no reader)".
15. `lib/core/utils/README.md` (Modify) — `nativePrayerKey` in the interface table. `lib/core/providers/README.md`
    (Modify) — delete the `:56` warning that the foreground-service map uses `'${name.toLowerCase()}_time'`.
    `lib/core/services/README.md` (Modify) — widget service uses `nativePrayerKey`.
16. `test/contracts/native_keys_scan_test.dart` (Create, **regression**) — §10 Dart rules; fails on today's provider
    (`prayer_times_provider.dart:350, :543`) and passes after this commit.

#### Commit 2 — silent mode (F49a) and receiver language (F49h)

17. `android/app/src/main/kotlin/com/aura/hala/PrayerAlarmReceiver.kt` (Modify, "edit carefully") — `:497–498`:
    `FlutterPrefs.getBoolean(context, "silent_mode_enabled", true)` replaces the `aura_silent_mode` read; `:499`
    unchanged. No other line changes.
18. `android/app/src/main/kotlin/com/aura/hala/AdhanFullScreenActivity.kt` (Modify) — `:294` reads through
    `FlutterPrefs`; `silentPrefs` stays for `is_silent_active` (`:293`).
19. `android/app/src/main/kotlin/com/aura/hala/ToggleSilentModeReceiver.kt` (Modify) — remove `getLanguage`
    (`:253–256`); `:142, :222, :238` call `getLanguagePreference`.
20. `.project-docs/contracts/prefs-keys.md` (Modify) — `aura_silent_mode` row (`:19`) and `:59–61`: native state only;
    `silent_mode_enabled` is read from `FlutterSharedPreferences` (2 readers). `aura_prefs` row: `language` reader
    removed. Row `:44` (`language`): replace "R ×20" with "R: 14 × `aura_prayer_times`, 2 × `aura_tasks_widget`
    (search `getString("language"` on c5a848e, after F49h); known channel-pushed duplicate of `flutter.language`,
    F67".
21. `android/app/src/main/kotlin/com/aura/hala/README.md` (Modify) — silent-mode setting source.

#### Commit 3 — adhan on/off, reciter and preview (F49b, `adhan_enabled`)

22. `android/app/src/main/kotlin/com/aura/hala/AdhanFiles.kt` (Create) — §3; imports `io.flutter.util.PathUtils`.
23. `android/app/src/main/kotlin/com/aura/hala/AdhanPlayer.kt` (Modify) — §3: remove `customAdhanPath` (`:47`),
    `setCustomAdhan` (`:53–60`), `getCustomAdhan` (`:65`), `playbackLock` (`:32`); `:180–181` read through
    `FlutterPrefs`; extract `prepareOutput` from `:189–198`; `:200–211` resolve with `AdhanFiles`; add
    `@Synchronized previewAdhan(context, id): Boolean`.
24. `android/app/src/main/kotlin/com/aura/hala/MainActivity.kt` (Modify) — adhan channel (`:353–391`): remove
    `setAdhanEnabled`, `isAdhanEnabled`, `setCustomAdhan`, `getCustomAdhan`; add `previewAdhan`
    (`call.argument<String>("id")`; `null` → `result.success(false)`; else
    `result.success(AdhanPlayer.previewAdhan(this, id))`).
25. `lib/core/services/adhan_player_service.dart` (Modify) — §4: `initialize` drops the `isAdhanEnabled` call
    (`:37–45`); `setEnabled` drops the `setAdhanEnabled` call (`:96–100`); remove `setCustomAdhan` /
    `getCustomAdhan` (`:133–150`); add `previewAdhan`. `isEnabled` / `setEnabled` signatures unchanged
    (`prayer_screen.dart:1128, :1385` untouched).
26. `lib/features/settings/adhan_downloads_screen.dart` (Modify) — §4: select (`:336`), reset (`:416`), delete
    (`:831`) drop the channel calls; delete `:332–333`, `:671` and `getDownloadedPath` (`:278–283`); preview
    (`:670–676`) calls `previewAdhan(reciter.id)` and sets state only on `true`; comment at `availableAdhans`
    (`:45`): "Android resolves `adhan_<id>.mp3`; see `.project-docs/contracts/prefs-keys.md`". No string changes.
27. `android/app/src/test/kotlin/com/aura/hala/AdhanFilesTest.kt` (Create, structural) — temporary folder: empty id,
    `../x`, `Alafasy` (upper case), unknown id with no file → `null`; a 0-byte existing file → resolves (a failed start
    is the player's job); existing `adhan_alafasy.mp3` → that file; a directory named `adhan_x.mp3` → `null`.
28. `test/features/settings/adhan_catalog_test.dart` (Create, **guard**) — every `availableAdhans` entry:
    `fileName == 'adhan_${id}.mp3'` and `RegExp(r'^[a-z0-9_]+$').hasMatch(id)`.
29. `test/core/services/adhan_player_service_test.dart` (Create, structural) — mocked `com.aura.hala/adhan`:
    `previewAdhan('x')` sends exactly `previewAdhan` with `{id: 'x'}` and returns the mocked result; a
    `PlatformException` → `false`; `setEnabled(false)` makes `prefs.getBool('adhan_enabled')` return `false` and sends
    no channel call. (`initialize` returns early when not on Android, `:27`, so it is not tested; the removal of
    `isAdhanEnabled` is covered by the Dart method being deleted.)
30. `test/features/settings/adhan_preview_test.dart` (Create, **regression**) — pump the downloads screen with one
    reciter shown as downloaded (`path_provider` mocked to a temp folder containing `adhans/adhan_alafasy.mp3`,
    `SharedPreferences.setMockInitialValues({'selected_adhan_id': 'sudais'})`, adhan channel mocked to record calls
    and return `true` for `previewAdhan`); tap the alafasy play button. Assert: no recorded `setCustomAdhan`; a
    `previewAdhan` call with `{id: 'alafasy'}`; `selected_adhan_id` still `sudais`. Fails before the fix. If the
    screen cannot be pumped without production changes, the file is not added, the PR says so, and Goal 3 rests on
    test 29 and S26 step (e).
31. `.project-docs/contracts/method-channels.md` (Modify) — `com.aura.hala/adhan`: 4 methods removed; `previewAdhan
    {id: String} → bool` added (false when adhan off, id invalid or file missing; stops current playback first).
32. `.project-docs/contracts/prefs-keys.md` (Modify) — `adhan_enabled` and `selected_adhan_id` rows (Flutter file,
    writer, native reader); the Android reciter rule (§3), marked "Android only; Windows uses
    `adhans/<prayerName>.mp3`"; `aura_prefs.adhan_enabled` reader and writer removed.
33. `lib/core/services/README.md`, `lib/features/settings/README.md`,
    `android/app/src/main/kotlin/com/aura/hala/README.md` (Modify) — channel and setting sources.

#### Commit 4 — service restarts (F51i) and boot check (F49i)

34. `android/app/src/main/kotlin/com/aura/hala/PrayerForegroundService.kt` (Modify) — §5: companion
    `isAutoStartAllowed`, `startServiceIfAllowed`; `shouldAutoRestart()` (`:773–776`) uses the decision;
    `onStartCommand` (`:135–137`) handles the `null`-intent sticky case. `startService` / `stopService` unchanged.
35. `android/app/src/main/kotlin/com/aura/hala/PrayerBootReceiver.kt` (Modify) — `:89` →
    `startServiceIfAllowed(context, "boot")`, `:90` success log only on `true`; remove `:58–65`.
36. `android/app/src/main/kotlin/com/aura/hala/DailyRecalcReceiver.kt` (Modify) — `:73` →
    `startServiceIfAllowed(context, "daily_recalc")`.
37. `android/app/src/test/kotlin/com/aura/hala/ForegroundAutoStartTest.kt` (Create, structural) —
    `isAutoStartAllowed`: (true, false) → true; (true, true) → false; (false, false) → false; (false, true) → false.
38. `android/app/src/test/kotlin/com/aura/hala/NativePrefsContractTest.kt` (Create, **regression**) — §10 Kotlin
    rules 1–3. Rule 1 fails on today's code; it passes only after commits 2–4.
39. `.project-docs/contracts/prefs-keys.md` (Modify) — `background_notification_enabled` gets its native readers;
    one clause: "`foreground_service_enabled` is Dart-only running state, not the setting"; `aura_prefs` row → §9 text.
40. `android/app/src/main/kotlin/com/aura/hala/README.md` (Modify) — boot / recalc / restart rule.

#### Commit 5 — docs

41. `.project-docs/reference/device-checklist.md` (Modify) — S25 (Arabic run, Goal 6); S26 step (e) (Goal 3); new
    **S42** and **S43** (steps in the Verification Plan).
42. `.project-docs/reference/findings.md` (Modify) — F49a, F49b, F51i, F15, F49h, F49i statuses with their commits.
43. `.project-docs/modules/notifications-native.md`, `.project-docs/modules/prayer.md` (Modify) — setting sources,
    adhan channel, restart rule.
44. `.project-docs/reference/reviews/settings-bridge/pr-description.md` (Create), `.project-docs/STATE.md`,
    `.project-docs/log/<commit date>.md` (Modify).

Not changed: `pubspec.yaml`, `pubspec.lock`, `android/app/build.gradle.kts`, `AndroidManifest.xml`, translations,
`contracts/notification-ids.md`, `contracts/intent-extras.md`, `contracts/firestore-paths.md`, `contracts/log-tags.md`.

### Verification Plan

*   **Unit tests:** `flutter test` (all pass; new files 10, 11, 12, 16, 28, 29, 30); from `android/`,
    `.\gradlew.bat :app:testDebugUnitTest` (all pass; new files 27, 37, 38). Regression tests (12, 16, 30, 38) are run
    once before their production change and must fail; the failure is recorded in the log.
*   **Static analysis:** `flutter analyze` — 0 errors, 0 new issues vs the base count of 418 (run 2026-11-09 on main
    5d37798; commits after it up to c5a848e are docs-only); `dart format --output=none --set-exit-if-changed` on
    changed Dart files.
*   **Static search (pasted in the PR, in addition to the scan tests):** none of `setAdhanEnabled`, `isAdhanEnabled`,
    `setCustomAdhan`, `getCustomAdhan` in `lib/` or `android/app/src/main/kotlin/`.
*   **Builds:** `flutter build apk --release --obfuscate --split-debug-info=build/debug-info`; Windows release build
    (shared Dart files changed): start the exe, open Settings → Adhan downloads, tap a preview (expected: nothing
    plays, no crash), compare console errors with a run of the main build.
*   **Device (nova 5T, release APK):**
    *   **S25:** English and Arabic (Goal 1, Goal 6).
    *   **S26:** select reciter → swipe app away → next adhan plays it; reset → built-in; step (e): select A, preview B,
        let the adhan fire → A plays (Goal 2, Goal 3).
    *   **S42 (restarts):** setting off → (1) reboot → no service (`adb shell dumpsys activity services
        com.aura.hala`), adhan alarms re-armed (`dumpsys alarm`); (2) update in place (`adb install -r`) → no service;
        (3) nightly recalc: Settings → Date & time → automatic off, set 00:03, wait past 00:05, logcat
        `DailyRecalcReceiver` "Daily recalc fired" and `⏭️ [FG_SERVICE] Auto-start skipped … daily_recalc`, no
        service; restore automatic time; (4) setting on → service starts.
    *   **S43 (update in place from main):** on the main build set silent mode off, a reciter, adhan off, background
        notification off; reboot once (main restarts the service: the F51i state); `adb install -r` the fix build; then
        (a) no service after the update and after swiping the app away; (b) each setting holds at the next adhan or
        restart; (c) open the app and check logcat: every `🕌 [FG_SERVICE] Prayer time keys` line contains
        `dhuhr_time` and no `zuhr_time`.
    *   **Android regression:** start-up, alarms armed (`dumpsys alarm`), next prayer and widget times match the times
        shown in the app.
    *   Results go in the device checklist; nothing is marked PASS unless it ran.

--------------------------------------------------------------------------------

<!-- Provenance: Indicates initial structural drafting via EGM. -->

*Drafted with EGM*
