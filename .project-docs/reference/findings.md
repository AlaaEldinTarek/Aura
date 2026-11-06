# Findings — investigate, do not fix (without an approved spec)
Created 2026-11-06 from analyzer run at 75d38b9 and the CLAUDE.md relocation.

## F1 — equal_keys_in_map — UNVERIFIED (possible silent data bug)
- `lib/core/services/location_service.dart:356` — two equal keys in a map literal; the later value silently wins.

## F2 — depend_on_referenced_packages — UNVERIFIED
- `lib/core/services/auth_service.dart:7` — imports `crypto`, which is not a direct dependency (transitive only).

## F3 — use_build_context_synchronously ×19 — UNVERIFIED (possible use-after-dispose after await)
- `lib/features/onboarding/preference_screen.dart:236` (unrelated `mounted` check)
- `lib/features/quran/quran_reader_screen.dart:355` (unrelated `mounted` check)
- `lib/features/quran/wird_tab.dart:588, 589, 638, 639` (unrelated `mounted` check)
- `lib/features/settings/adhan_downloads_screen.dart:338, 692` (no guard)
- `lib/features/settings/adhan_downloads_screen.dart:373, 397, 421, 652, 653, 678, 679` (unrelated `mounted` check)
- `lib/features/tasks/task_form_screen.dart:148, 158, 199, 209` (no guard)

## F4 — Notification ID range overlap — range VERIFIED, collision UNVERIFIED
- `notification_service.dart:1171`: `7100 + (achievement.id.hashCode.abs() % 1000)` → 7100–8099 contains Jumu'ah 8001
  (`JumuahReminderReceiver.kt:19`). A collision needs an achievement id with `hashCode % 1000 == 901`; not computed
  (Dart `String.hashCode` stability across runs is not guaranteed by spec).

## F5 — MethodChannel `com.aura.hala/app_control` — VERIFIED (Kotlin side), no Dart caller found
- `MainActivity.kt:225–227`: single method `openUrl`. No Dart reference to the channel name. See F10.

## F6 — Stale KDoc in `PrayerForegroundService.kt:842-846` — UNVERIFIED
- Comment says "Request Flutter to recalculate prayer times by launching MainActivity briefly" but sits above
  `getDisplayPrayerName()`; the real `requestFlutterUpdate()` (line 857) recalculates natively. Misleading; Level C to fix.

## F7 — ID 7001 used by both Dart Jumu'ah (legacy) and native Daily Summary — code VERIFIED, impact UNVERIFIED
- **Tag: likely user-visible bug → fix track** (needs an approved spec; do not fix during refactor phases).
- `notification_service.dart:57` `_jumuahNotificationId = 7001`; `scheduleJumuahReminder()`/`cancelJumuahReminder()`
  call `_notifications.cancel(7001)` (:1390, :1401) as "legacy cleanup". Native `DailySummaryReceiver.kt:20` posts 7001.
  Same package + null tag → calling either Dart method while the daily summary is shown would dismiss it.

## F8 — Task digest 4001 inside task-reminder hash range 4000–4999 — code VERIFIED, impact UNVERIFIED
- `notification_service.dart:1021` (digest 4001) vs `:669` (`4000 + taskId.hashCode.abs() % 1000`). A task whose hash
  maps to 1 would replace/cancel the digest (or vice versa).

## F9 — Dart channel `com.aura.hala/silent_mode` has no Kotlin handler — VERIFIED (static)
- `silent_mode_service.dart:14` invokes `setEnabled`/`setDuration`/`cancelAll`; no Kotlin registers `silent_mode`
  (calls would throw `MissingPluginException`, caught). No importer of `silent_mode_service.dart` found in `lib/`/`test/`
  → likely dead code (UNVERIFIED; "not found" ≠ unused). Silent mode works natively via prefs (contracts/prefs-keys.md).

## F10 — Kotlin handlers with no Dart caller found — UNVERIFIED (possibly dead)
- `ringer_mode`: `getRingerMode`, `setRingerMode` (`MainActivity.kt:206,210`); `app_control`: `openUrl` (:227);
  `focus_mode`: `isAccessibilityServiceEnabled`, `requestAccessibilityPermission` (:767,:771) — likely leftovers of the
  accessibility service removed in bc765f6.
- `BackgroundServiceHandler.kt` duplicates the `background_service` handler; no instantiation found (MainActivity
  registers its own at :638).

## F11 — Dart handler `onPrayerAlarmTriggered` has no Kotlin sender — UNVERIFIED
- `prayer_alarm_service.dart:42`; Kotlin only calls `invokeMethod` on the navigation channel (`MainActivity.kt:66–102`).

## F12 — `NotificationService.schedulePostPrayerCheck` has no caller found — UNVERIFIED
- `notification_service.dart:1265` schedules 6001–6006 from Dart; the only caller found uses
  `PrayerAlarmService.instance.schedulePostPrayerCheck` (`prayer_times_provider.dart:269`) → native path.

## F13 — MainActivity reads picker intent extras that nothing writes — UNVERIFIED
- `open_reminder_picker`, `update_prayer_status`, `open_post_prayer_picker` (+ payload extras) read at
  `MainActivity.kt:71–102`; no `putExtra` or constant found in Kotlin. Post-prayer actions may be handled by receivers
  instead; device scenario S09 records actual tap behavior.

## F15 — Dart writes `zuhr_time` into native `aura_prayer_times` — code VERIFIED, impact UNVERIFIED
- **Tag: likely user-visible bug → fix track** (with F7; needs an approved spec; do not fix during refactor phases).
- `prayer_times_provider.dart:370` builds `'${p.name.toLowerCase()}_time'` → `zuhr_time` and sends it via
  `BackgroundServiceManager.updatePrayerTimes`; `MainActivity.kt:656–679` → `PrayerForegroundService.kt:108` stores every
  map key as-is. Kotlin readers use `dhuhr_time` (`PrayerAlarmReceiver.kt:619`, `JumuahReminderReceiver.kt:32`), which
  only `NativePrayerCalculator.kt:63` writes. Result: orphan `zuhr_time` key, and `dhuhr_time` is not refreshed by this
  Dart path. Breaks the CLAUDE.md rule "prefs key always `dhuhr_time`". Found during EGM batch 2.

## F14 — Contract doc errors corrected in Step 2 — VERIFIED
- Foreground channel is `prayer_foreground_channel_v4` (not `prayer_foreground_channel`).
- `ringer_mode` handler is in `MainActivity`, not `SilentModeAutomation.kt`.
- `_syncNativePrayerStatuses()` → renamed `_syncThenLoadPrayerStatus()` in 088d2cb (sync to Firestore, then load
  provider once). `focus_a11y_ever_enabled` → removed in bc765f6 with the accessibility service; no replacement.
  Both resolved via `git log -S` (read-only).
- Undocumented prefs files `aura_tasks_widget`, `aura_focus_state`; undocumented IDs 1–6, 2000, 4001, 5001–5006,
  5998, 5999, 9999 and channels `prayer_check`, `azkar_reminder`, `focus_mode`, `focus_mode_service`, `prayer_reschedule`.

## Doc conflicts found while relocating old CLAUDE.md (code wins; resolve in Step 2)
| # | Old CLAUDE.md said | Observed 2026-11-06 | Status |
| --- | --- | --- | --- |
| D1 | Version 1.0.0+42 | `pubspec.yaml` 1.0.0+59, msix 1.0.3.114 (doc said last msix 1.0.3.64) | VERIFIED |
| D2 | "20 named routes" and "Routes (21)" | 25 `case` routes in `main.dart` (+`/azkar`, `/quran_stats`, `/islamic_events`, `/khatma_dua`) | VERIFIED |
| D3 | 22 Kotlin files | 30 `.kt` files | VERIFIED |
| D4 | 7 MethodChannels; MainActivity "8 handlers" | 8 channel names in Kotlin incl. undocumented `com.aura.hala/app_control` | VERIFIED (Kotlin side) |
| D5 | Foreground service "launches MainActivity with `refresh_prayer_times` extra" on day transition | Code calls `NativePrayerCalculator.calculateAndSave()` (`PrayerForegroundService.kt:857`); no activity launch. Doc corrected | VERIFIED — resolved |
| D6 | Translations "~280 keys" and "~265 strings" | 450 top-level keys in each of en.json / ar.json | VERIFIED (top-level only) |
| D7 | Widget tab handoff writes `widget_navigate_to_tab` to `${packageName}_preferences` | Prefs table lists it in `FlutterSharedPreferences` and says `${packageName}_preferences` is Focus Mode only | VERIFIED — resolved: `MainActivity.kt:57` uses `FlutterPrefs.putInt` |
| D8 | Native table row "NativePrayerCalculator.kt → MainActivity.kt" for widget tab handling | Handling described is in MainActivity only | Mislabeled row; dropped |
| D9 | "Day transition" also in notification section | Same claim as D5 | VERIFIED — resolved with D5 |
