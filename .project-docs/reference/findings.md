# Findings — investigate, do not fix (without an approved spec)
Created 2026-11-06 from analyzer run at 75d38b9 and the CLAUDE.md relocation.

## F1 — equal_keys_in_map — VERIFIED harmless
- `lib/core/services/location_service.dart:327, 356` — `'Istanbul'` twice in `cityTranslations`, identical values →
  no behavior change; lint only.

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

## F16 — Offline queue is never populated — VERIFIED (static)
- `OfflineQueueService.enqueue()` (`offline_queue_service.dart:55`) has no caller in `lib/`; `SyncService` replay
  (`sync_service.dart:33–66`, triggered by `connectivity_provider.dart`) only ever pushes Wird. Offline writes rely on
  the Firestore SDK cache instead (UNVERIFIED — device scenario **S19** offline task create → sync). Replay also uses
  `.add()` (non-idempotent). Not a bug yet. If S19 passes on device, `OfflineQueueService` + queue replay = dead code → P6 cleanup.

## F17 — Desktop IP location code is never called → Mecca default — code VERIFIED; DECISION: deliberate (not a bug)
- `_updateIpLocationInBackground` / `_getIpLocation` (`location_service.dart:131–170`) have no callers, so
  `desktop_ip_*` is never written; `getBestLocation` (`:182–192`) falls back to Mecca unless a manual location is set.
  Comment there says "user can set actual location in Settings".
- **Decision (user, 2026-11-06): deliberate for now** — desktop users set their location manually. Not a bug; the unused
  IP-location helpers stay until a phase decides to remove or re-enable them.

## F18 — Desktop in-app notification stream never emits — VERIFIED (static)
- `DesktopNotificationService._notifController` (`desktop_notification_service.dart:39`) is never `add`ed to, but
  `main_wrapper_screen.dart:175` subscribes to `notificationStream` → in-app banners never show on desktop.
- Decision (user): dead code → **P6 cleanup**.

## F19 — Cleanup deletes prayers marked within 20 min of adhan — code VERIFIED, impact UNVERIFIED
- **Tag: likely user-visible bug → fix track** (with F7, F15; needs an approved spec; do not fix during refactor phases).
- `cleanupFuturePrayerRecords` (`prayer_tracking_service.dart:716–741`) deletes today's records with
  `prayedAt < adhan + 20 min`. Desktop adhan toast "Prayed ✓" records `prayedAt: now` at adhan time
  (`desktop_notification_service.dart:158–162`); `NotificationService._handleMarkPrayed` (`notification_service.dart:541`)
  does the same. Such records would be deleted on the next app start that day.

## F20 — Scout-reported issues in lib/core/services
Verified 2026-11-06 (read-only, user picked these three):
- **F20a streak counts missed/excused prayers — VERIFIED.** `_streakFromRecords` (`prayer_tracking_service.dart:477–500`)
  and `_calculateBestStreak` (`:524–544`) count distinct `prayerName` per day (`>= 5`) with no status filter.
- **F20b recurring-task duplicates — NOT CONFIRMED (toggle path).** Guest `_completeRecurringTask`
  (`task_service.dart:560–590`) skips the existing-child check, but un-completing runs `_deleteChildTasks` (`:519–523`)
  first, so repeated toggles leave one next instance. Concurrent double-tap race: UNVERIFIED.
- **F20c daily task digest never repeats on its own — VERIFIED.** `scheduleDailyTaskDigest`
  (`notification_service.dart:1040–1068`) is a one-shot `zonedSchedule` (no `matchDateTimeComponents`); it is re-armed
  only by `PrayerTimesNotifier.loadPrayerTimes` side effects (once per date per app process), so days without an app
  start get no digest and counts are frozen at schedule time.

**UNVERIFIED backlog** — check only when a phase touches that area:
- notification_service: task snooze uses plugin path on Android and skips `cancelNativeTaskReminder` (:606–654);
  digest channel `task_digest` not pre-created, raw digits in Arabic (:1016–1070);
  `prayer_check` channel created twice (:166, :212); `cancelAllNotifications` leaves native alarms (:920);
  enabling a prayer in `togglePrayerNotification` doesn't reschedule (:1205); unguarded `int.parse` on wird times (:1088).
- prayer_tracking_service: best streak reads the oldest
  5000 records (:517); `deletePrayerRecord` fetches all records of a prayer (:646); no guest branch in `watchDay` /
  `getStatistics` (:227, :302).
- task_service: recurring child drops subtasks/focus fields
  (:581); recurring completion skips achievements (:519); `scheduleDailyTaskSummary` called on desktop (:730);
  migrated tasks keep reminders under old local ids (:104).
- wird_service: pages read past goal not counted (:100–112); juz-mode undo subtracts pages (:176, :204).
- achievement_service: dhikr 100/200 effectively need sessions within 30 days (:190–204).
- desktop: tray actions may fire twice (`desktop_tray_service.dart:86–145`); "Stop Adhan" item hidden right after
  play starts (`desktop_prayer_scheduler.dart:86`); adhan/post-check toasts ignore notify flags (:83, :98).
- auth_service: desktop OAuth has no `state` param and no loopback timeout (:144–179); email logged (:101).
- quran_svg_service: partial download served as cached page (:41–44). rating_service: doc says khatm/records rule,
  code checks only 7-day install age (:8, :33).

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
