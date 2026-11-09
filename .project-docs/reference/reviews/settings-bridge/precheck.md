# "Dart->native settings bridge" — read-only pre-check (input for /egm:egm-draft)

## User decisions (2026-11-09) — these override the proposals in §6
- **Group:** F49a, F49b, F51i (all native restarts: boot, package-replaced, nightly recalc), F15, F49h, and
  `adhan_enabled` duplicate storage (§5.4; breaks the one-file-per-key goal).
- **F49i added** (moved from P6): every native read of `aura_prefs` is in scope — `adhan_enabled`
  (`MainActivity.kt:375`, `AdhanPlayer.kt:180`), `notifications_enabled` (`PrayerBootReceiver.kt:59`, F49i),
  `language` (`ToggleSilentModeReceiver.kt:254`, F49h); the write `MainActivity.kt:369` goes with `adhan_enabled`.
  Nothing else is added to the group.
- **F9 → P6 cleanup** (out of this group).
- **Reciter preview must not change the live adhan;** only selecting a reciter does (§5.6). The spec must list this as an
  approved behavior change, old vs new:
  - Old: preview (`adhan_downloads_screen.dart:672–673`) calls `setCustomAdhan(path)`, so the previewed reciter becomes
    the live adhan for the rest of the process.
  - New: preview plays the reciter without changing the live adhan; only selecting (`_setSelectedAdhan`, `:325–336`)
    changes it.

### Decisions made while drafting the spec (2026-11-09)
- **D1 (F49i):** remove the boot receiver's `aura_prefs.notifications_enabled` check; no behavior change. "Adhan off"
  stays enforced only at alarm time and only stops the sound (logged as F66, intended behavior undecided).
- **D2 (F51i owner):** Dart's `background_notification_enabled` is the single owner of "background notification off";
  `fg_user_stopped` stays only as the service's internal self-restart flag.
- **D3 (F49b reciter path, existing users):** Android resolves the reciter from `flutter.selected_adhan_id` plus the
  download folder; no native copy. Rule: folder `PathUtils.getDataDirectory(context)/adhans`, file `adhan_<id>.mp3`,
  id `[a-z0-9_]+`; anything else or a missing file → built-in adhan. Documented in `contracts/prefs-keys.md`.
- **D4 (Goal 8 vs F49h):** Goal 8 covers only this group's four settings; F49h reads `aura_prayer_times.language` like
  the other native language reads; the copy is a known channel-pushed duplicate. Moving all native language reads to
  `flutter.language` is F67 (later).
- **D5 (adhan channel):** remove `setAdhanEnabled`, `isAdhanEnabled`, `setCustomAdhan`, `getCustomAdhan`; add
  `previewAdhan {id}` using the same resolver (missing file → nothing plays). Channel name unchanged;
  `contracts/method-channels.md` updated in the same commit.
- **D6 (tests):** no Robolectric or other new test dependency; device checks cover F49a, F49h and the update path.
- **D7 (delivery):** one spec, one PR, commits split by repair type; each commit carries its own Dart, Kotlin and
  `contracts/` changes.
- **D8 (`adhan_enabled` conflict):** if the old Flutter and `aura_prefs` copies disagree, Flutter prefs wins.

### Decisions made after the EGM review (2026-11-09, `consolidated_review_report.md` A1–A5)
- **A1 (preview during an adhan):** drop "preview does nothing while an adhan plays" and `AdhanPlaybackState`; keep
  today's behavior (a preview stops whatever is playing, including a prayer adhan, and plays). "Preview can
  interrupt a prayer adhan" is added to F66.
- **A2 (F15):** one shared Zuhr key function used at all call sites, including `buildNativeCache`; no map builder.
- **A3 (F51i scope):** gate `shouldAutoRestart` and the `START_STICKY` restart with the same decision as
  `startServiceIfAllowed`.
- **A4 (regression guard):** permanent scan tests (Kotlin and Dart), not one-time greps.
- **A5 (rollback):** document that reverting the adhan commit loses adhan on/off changes made under the fixed build;
  no resync mechanism.
- **Fixes F1–F15 and N1–N13** of the consolidated report applied; for the two device proofs that could not run on a
  release APK, the spec uses a clock-change step (nightly recalc) and a logcat key line (Zuhr) instead.

Date: 2026-11-09 · Code: main @ c5a848e · Method: static read of current code (grep + line reads). No device run,
no build, no test run for this check. Labels: VERIFIED (static) = read in current code; UNVERIFIED = not shown by code
alone; UNKNOWN = needs device/user.

## 1. Per finding

| Finding | Status now | Evidence (current code) |
| --- | --- | --- |
| F49a silent-mode toggle never reaches native (HIGH) | **Still present** — VERIFIED (static) | Dart writers: `settings_screen.dart:142` → `shared_preferences_service.dart:201–202` `setBool('silent_mode_enabled')`; `prayer_screen.dart:1421–1422` `prefs.setBool(AppConstants.keySilentModeEnabled)` (`app_constants.dart:68`). Both go to `FlutterSharedPreferences` as `flutter.silent_mode_enabled` (§2). Native readers use another file: `PrayerAlarmReceiver.kt:497–498` (`aura_silent_mode`, default `true`) gates `enableSilentModeForPrayer` at `:515–517`; `AdhanFullScreenActivity.kt:292–297` (same file/key, gates vibration buttons). No writer of `silent_mode_enabled` in `aura_silent_mode` anywhere (grep: only `getBoolean`). Contrast: the duration already crosses correctly via `FlutterPrefs.getInt(context, "silent_mode_duration", 20)` (`PrayerAlarmReceiver.kt:722`, `ToggleSilentModeReceiver.kt:102`). Device impact: UNKNOWN (S25 not run). |
| F49b chosen reciter not persisted natively (HIGH) | **Still present** — VERIFIED (static) | `AdhanPlayer.kt:47` `private var customAdhanPath: String? = null`, set only by `setCustomAdhan` (`:53–54`) from the channel (`MainActivity.kt:379–381`); used at play time `AdhanPlayer.kt:201–204`. Dart persists only `selected_adhan_id` in Flutter prefs (`adhan_downloads_screen.dart:327`); nothing re-sends the path on start (`adhan_player_service.dart:28–49` `initialize` does not call `setCustomAdhan`). Related, also still present: `AdhanPlayerService.setCustomAdhan(null)` sends nothing (`adhan_player_service.dart:134–139`, `if (path != null)`), so Reset (`adhan_downloads_screen.dart:416`) and deleting the selected reciter (`:831`) leave the native path set for the process; preview (`:672–673`) calls `setCustomAdhan(path)` and makes it the live adhan. New detail: `setCustomAdhan` has **no try-catch** (`adhan_player_service.dart:136`), against the CLAUDE.md platform-channel rule. Device impact: UNKNOWN (S26 not run). |
| F9 `com.aura.hala/silent_mode` has no Kotlin handler | **Still present** — VERIFIED (static) | Dart: `silent_mode_service.dart:14–15` channel, calls `setEnabled` (`:58`), `setDuration` (`:71`), `cancelAll` (`:86`). Kotlin registers 8 channels (`MainActivity.kt:24–31`), none is `silent_mode`. No file in `lib/` or `test/` imports `silent_mode_service.dart` (grep). "Not found" ≠ unused, but no importer exists in the repo → dead code is likely (UNVERIFIED at runtime). |
| F15 Dart sends `zuhr_time` to native (impact UNVERIFIED) | **Still present, changed** — now two call sites, and one path is correct | Wrong key: `prayer_times_provider.dart:350` and `:543` build `'${p.name.toLowerCase()}_time'` → `zuhr_time`; sent by `BackgroundServiceManager.updatePrayerTimes` (`background_service_manager.dart:102`) → `MainActivity.kt:656` → `PrayerForegroundService.kt:104–110` stores every key as-is into `aura_prayer_times`. Correct path: `prayer_widget_service.dart:79` sends the same channel with keys from `_getTimeKey` (`:107–124`, `'dhuhr'`/`'zuhr'` → `dhuhr_time`). Native readers all use `dhuhr_time` (`PrayerAlarmReceiver.kt:619`, `JumuahReminderReceiver.kt:32`, `PrayerForegroundService.kt:195, :300, :320, :825`, `PrayerWidgets.kt:105, :111`, `PrayerRescheduleService.kt:120`); `NativePrayerCalculator.kt:75` writes it. Effect: orphan `zuhr_time`; whether `dhuhr_time` goes stale depends on whether the widget-service path runs after the provider path — UNVERIFIED. Iqama key is already special-cased correctly (`prayer_times_provider.dart:355–357`). |
| F49h silent-mode receiver reads language from `aura_prefs` (LOW) | **Still present** — VERIFIED (static) | `ToggleSilentModeReceiver.kt:253–255` `getLanguage` reads `aura_prefs.language`; used at `:142, :222, :238`. No Kotlin writes `language` to `aura_prefs` (writers: `MainActivity.kt:285, :330`, `PrayerForegroundService.kt:116`, `FocusModeService.kt:241` — other files). Same class has the correct reader `getLanguagePreference` (`:373–375`, `aura_prayer_times`) used at `:342`. Messages at `:142/:222/:238` are therefore always English (static). |
| F51i boot restarts a foreground service the user turned off (MEDIUM) | **Still present, wider than recorded** — VERIFIED (static) | Off switch: `prayer_screen.dart:1288–1297` writes `background_notification_enabled` and calls `stopForegroundService` → `PrayerForegroundService.stopService` sets `fg_user_stopped = true` (`PrayerForegroundService.kt:71–74`). `startService` clears it unconditionally (`:59–62`). Native callers of `startService` that never read `background_notification_enabled`: `PrayerBootReceiver.kt:44, :89` (boot + `MY_PACKAGE_REPLACED`, `:36`); **new:** `DailyRecalcReceiver.kt:73` (every nightly recalc, when `calculateAndSave` succeeds); `BackgroundServiceHandler.kt:20` (no instantiation found, F10). `MainActivity.kt:642` is the Dart-initiated path (Dart checks the flag at `background_service_manager.dart:49–53`). So a user's "off" is undone on reboot, on app update and every night — not only on reboot. |

## 2. Dart prefs API (Android)

- **Legacy `SharedPreferences` only.** Every Dart use is `SharedPreferences.getInstance()` (e.g. `shared_preferences_service.dart:38, :48`,
  `prayer_screen.dart:1421`, `adhan_downloads_screen.dart:326`; ~90 call sites, grep). No `SharedPreferencesAsync` or
  `SharedPreferencesWithCache` anywhere in `lib/`.
- Versions (`pubspec.lock`): `shared_preferences` 2.5.5 (`:1103`), `shared_preferences_android` 2.4.23 (`:1111`).
- Plugin source (pub cache, 2.4.23): the legacy API is served by `LegacySharedPreferencesPlugin.java:34`,
  `SHARED_PREFERENCES_NAME = "FlutterSharedPreferences"`; keys get the Dart-side `flutter.` prefix. DataStore is used
  only by the async API (`SharedPreferencesPlugin.kt:41–42`, `useDataStore` option), which the app does not use.
- **Result:** Dart settings live in `FlutterSharedPreferences` with `flutter.` prefix — exactly what `FlutterPrefs.kt:16–17` reads.
  Risk to note in the spec: migrating Dart to `SharedPreferencesAsync` later would move data to DataStore and silently
  break every `FlutterPrefs` reader.

## 3. Every native prefs access (Kotlin, `android/app/src/main/kotlin/com/aura/hala/`)

R = read, W = write. Line = `getSharedPreferences(...)` / `FlutterPrefs.*` call.

**`FlutterSharedPreferences` via `FlutterPrefs.kt` (`:16–20`)** — the only correct bridge to Dart settings
- R `jumua_reminder_enabled`: `JumuahReminderReceiver.kt:24, :105`
- R `prayer_tracking_notifications_enabled`: `PrayerAlarmReceiver.kt:580`, `DailySummaryReceiver.kt:97`, `PrayerBootReceiver.kt:97`
- R `silent_mode_duration`: `PrayerAlarmReceiver.kt:722`, `ToggleSilentModeReceiver.kt:102`
- R `daily_summary_time`: `DailySummaryReceiver.kt:158`, `PrayerBootReceiver.kt:99`
- R `theme_mode`: `PrayerForegroundService.kt:662`
- W `widget_navigate_to_tab`: `MainActivity.kt:57`; W `pending_complete_task_id`: `TasksWidget.kt:52, :290`; W `widget_open_task_form`: `TasksWidget.kt:63`

**`aura_silent_mode`** (native state + the F49a key)
- `AdhanFullScreenActivity.kt:292` (R `is_silent_active`, `silent_mode_enabled`)
- `PrayerAlarmReceiver.kt:497` (R `silent_mode_enabled`), `:691` (W `saved_ringer_mode` :707, `is_silent_active` :719, `silent_end_time` :724), `:779` (R `is_silent_active`)
- `PrayerForegroundService.kt:568` (R `is_silent_active`)
- `SilentModeAutomation.kt:78` (R `saved_ringer_mode`, W `is_silent_active`)
- `ToggleSilentModeReceiver.kt:27` (`PREFS_NAME`), `:70` (W `saved_ringer_mode` :86, `is_silent_active` :99, `silent_end_time` :104), `:120` (R `is_silent_active` :121, W :139), `:189` (W `silent_end_time` :205), `:333` (W `is_silent_active` :334), `:384` (R `saved_ringer_mode`)

**`aura_prefs`** (5 sites)
- `MainActivity.kt:369` (W `adhan_enabled`, channel `setAdhanEnabled`), `:375` (R `adhan_enabled`)
- `AdhanPlayer.kt:180` (R `adhan_enabled`)
- `PrayerBootReceiver.kt:59` (R `notifications_enabled`, no writer — findings F49i, P6)
- `ToggleSilentModeReceiver.kt:254` (R `language`, no writer — F49h)

**`aura_prayer_times`** (native prayer state; Dart writes into it only through channels)
- `AdhanFullScreenActivity.kt:257`; `AzkarFullScreenActivity.kt:71`; `AzkarAlarmReceiver.kt:131`; `DailyContentWidget.kt:76`;
  `NativeNotificationReceiver.kt:118`; `JumuahReminderReceiver.kt:31, :107`; `PrayerWidgets.kt:60, :79`;
  `PrayerRescheduleService.kt:114`; `StopAdhanReceiver.kt:57`; `NativePrayerCalculator.kt:37`;
  `DailySummaryReceiver.kt:105, :166`; `ToggleSilentModeReceiver.kt:337, :374`
- `MainActivity.kt:282, :539, :553, :667, :700`
- `PrayerAlarmReceiver.kt:195, :387, :417, :441, :469, :487, :543, :604, :773, :851, :922, :1022`
- `PrayerForegroundService.kt:61, :73` (W `fg_user_stopped`), `:104` (W channel map, F15), `:174, :257, :283, :296, :369, :383, :413, :774`

**`aura_tasks_widget`**: `TasksWidget.kt:19/:261` (names), `:49, :75, :287, :301`; `MainActivity.kt:323`
**`aura_focus_state`**: `FocusModeService.kt:33` (name), `:236, :247`
**`aura_focus_mode`**: `FocusModeReceiver.kt:153`
**`${packageName}_preferences`** (Focus Mode only, per CLAUDE.md): `FocusModeActivity.kt:455`, `FocusModeService.kt:172`, `MainActivity.kt:760`

No DataStore and no `PreferenceManager` use in app Kotlin (grep).

## 4. MethodChannels used for settings

| Channel | Dart caller | Methods | Kotlin handler |
| --- | --- | --- | --- |
| `com.aura.hala/adhan` | `adhan_player_service.dart:15` | `isAdhanEnabled` (:39), `setAdhanEnabled` (:97), `setCustomAdhan` (:136), `getCustomAdhan` (:144), `playAdhan` (:73), `stopAdhan` (:83) | **Yes**, all 6: `MainActivity.kt:353` (`:355, :362, :367, :374, :379, :385`). `setCustomAdhan` stores in memory only (F49b) |
| `com.aura.hala/silent_mode` | `silent_mode_service.dart:14` | `setEnabled` (:58), `setDuration` (:71), `cancelAll` (:86) | **No** (F9). Service has no importer |
| `com.aura.hala/background_service` | `background_service_manager.dart:13`; also `main_wrapper_screen.dart:848` | `isForegroundServiceRunning` (:33), `startForegroundService` (:56), `stopForegroundService` (:73), `updatePrayerTimes` (:102), `cacheAccuratePrayerTimes` (:127) | **Yes**, all 5: `MainActivity.kt:638` (`:640, :645, :650, :656, :698`). Duplicate handler class `BackgroundServiceHandler.kt:12` (no instantiation found, F10) |
| `com.aura.hala/prayer_alarms` | `prayer_alarm_service.dart:18`, `notification_service.dart:42, :1382`, `platform_channel_service.dart:10`, `main_wrapper_screen.dart:849, :1048` | settings-related: `scheduleDailySummary` (reads `daily_summary_time` via FlutterPrefs natively) | Yes: `MainActivity.kt:394` (method-by-method check not done here — outside this group) |
| `com.aura.hala/ringer_mode` | none found (F10) | `getRingerMode`, `setRingerMode` | Yes `MainActivity.kt:204` (no Dart caller) |
| `com.aura.hala/focus_mode` | `notification_service.dart:1411` | Focus Mode settings | Yes `MainActivity.kt:714` (Focus Mode, not this group) |

## 5. Conflicts / unclear points for the spec

1. **Contract doc conflict (F15):** `contracts/prefs-keys.md:42` says prayer-time keys are `dhuhr_time` "(never `zuhr_time`)"
   and written by channel `updatePrayerTimes`, but the provider path sends `zuhr_time` (`prayer_times_provider.dart:350, :543`).
2. **F51i is broader than recorded:** nightly `DailyRecalcReceiver.kt:73` and app-update (`PrayerBootReceiver.kt:36`)
   also clear `fg_user_stopped`. The spec must say which of these should respect the user's off switch (likely all).
3. **Two sources of truth for "service off":** Dart `background_notification_enabled` (Flutter prefs) and native
   `fg_user_stopped` (`aura_prayer_times`). The spec should pick one key/file the native side reads.
4. **`adhan_enabled` is stored twice:** Flutter prefs (`adhan_player_service.dart:94`) and `aura_prefs` via channel
   (`MainActivity.kt:370`); native reads only `aura_prefs` (`AdhanPlayer.kt:181`). Works while the channel call succeeds;
   it does not meet "one documented file + key per native-read setting". Not a recorded finding — UNKNOWN whether in scope.
5. **F49a fix shape:** the existing pattern (`silent_mode_duration` via `FlutterPrefs`) suggests native should read
   `flutter.silent_mode_enabled` via `FlutterPrefs` rather than adding a writer to `aura_silent_mode`. Spec decision.
6. **F49b fix shape:** either persist the path natively in `setCustomAdhan`, or have native resolve it from
   `flutter.selected_adhan_id` + the download dir. Also: should preview stop changing the live adhan, and must
   `setCustomAdhan(null)` reach native? (Preview behavior change = UI/behavior decision for the user.)
7. **F9 vs F49a:** if F49a uses `FlutterPrefs`, the `silent_mode` channel is not needed; F9 becomes removal of an
   unused service (cleanup), not a bridge fix.
8. **F15 impact:** whether `dhuhr_time` goes stale depends on call order between the provider and widget-service paths —
   UNVERIFIED; a device check (dump `aura_prayer_times` after a refresh) would settle it.
9. **No tests cover any of this:** no file in `test/` or `android/app/src/test/` mentions `silent_mode`,
   `aura_silent_mode`, `selected_adhan`, `zuhr_time`, `dhuhr_time`, `fg_user_stopped` or `background_notification` (grep).
10. **Group list differs between docs:** `findings.md:533` = F49a + F49b + F15 + F9; STATE line 23 adds F51i + F49h.

## 6. Proposed final group membership

**In:**
- **F49a (HIGH)** — core of the group: a Dart setting native reads from the wrong file.
- **F49b (HIGH)** — core: a Dart setting native never persists; same adhan path. Include the `setCustomAdhan(null)` and
  missing try-catch fixes (same method), and decide preview behavior explicitly.
- **F51i (MEDIUM)** — a Dart setting (`background_notification_enabled`) native ignores; scope widened to all native
  `startService` callers (boot, package-replaced, nightly recalc).
- **F15 (MEDIUM-ish, impact UNVERIFIED)** — wrong key on a Dart→native write; two-line Dart fix using the existing
  `_getTimeKey` rule, and it fixes a contract-doc conflict. Same "one key per native-read value" rule.
- **F49h (LOW)** — one-line native read from a file nobody writes; same receiver family as F49a; cheap to include.

**Out (move):**
- **F9 → P6 cleanup**, if the spec fixes F49a through `FlutterPrefs`: the channel then has no purpose and removing an
  unused service is cleanup, not a bridge. If the spec instead chooses the channel route for F49a, F9 stays in.

**Ask the user (not in any finding yet):**
- `adhan_enabled` dual storage (§5.4) — include for the "one file + key" rule, or leave as-is (it works)?
- F49i (`aura_prefs.notifications_enabled`, P6) — same file family; keep in P6 unless the spec consolidates `aura_prefs`.
