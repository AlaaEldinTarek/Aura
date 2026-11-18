# FX-S05 — Arm the Pre-Prayer Reminder on Android

*   **Author:** Alaa Eldin Tarek
*   **Status:** Draft, not approved. Docs only: no code is written until the owner says "approve phase".
*   **Date:** 2026-11-18
*   **Source:** device check S05 FAIL, 2026-11-17 (nova 5T, 1.1.0+60). Known gap, listed out of scope in the FX-0 review.

Labels: VERIFIED = read in code, UNVERIFIED = not run on a device, UNKNOWN = not checked.

---

## Overview

The Android pre-prayer reminder never fires. The receiving side exists (reminder mode in the foreground notification, four action buttons, a picker), but nothing arms the 45-minute alarm. This spec arms it, reads the lead time from `notification_reminder_minutes` instead of the hard-coded 45, and keeps the snooze path unchanged.

## What the reminder is today (VERIFIED, code read)

*   It is **not a separate notification.** When the reminder alarm fires, `PrayerAlarmReceiver.onReceive` (`isReminder` branch, `:439-449`) writes `reminder_active=true`, `reminder_prayer_name(_ar)`, `reminder_prayer_time` to `aura_prayer_times` and returns. `PrayerForegroundService` (`:459-470`, `showReminderModeNotification`) then shows reminder mode in notification 9999 with Prayed / Late / Missed / Remind Later (`handleReminderAction`, `:845-897`). It clears itself when the prayer time is reached (`:465-467`). The old separate notification code was removed.
*   The device checklist S05 expected result says "Notification 2001–2006". The 2001–2006 values are the `REMINDER_*` constants and PendingIntent request codes, not a visible notification (`contracts/notification-ids.md` row 2001–2006 has no channel). **The S05 row needs a wording fix** as part of this work.

## The Problem (VERIFIED)

1.  **Nothing arms the reminder alarm.** `PrayerAlarmReceiver.scheduleReminderAlarm` (`:112`) is reached only from the `scheduleReminderAlarm` MethodChannel handler (`MainActivity.kt:424-437`). With no `delayMinutes` it takes the 45-minute branch. The Dart callers: `prayer_alarm_service.dart:99` (`PrayerAlarmService.scheduleReminderAlarm`, no caller found) and `main_wrapper_screen.dart:823` (snooze, always sends `delayMinutes`). `NotificationService.scheduleDailyPrayers` / `schedulePrayerNotification` (the Dart 10-minute reminder) have no caller. S05 log (14:03–14:42): no request code outside 1001–1006, no Aura notification other than 9999.
2.  **The lead time is hard-coded 45 min** (`PrayerAlarmReceiver.kt:112-123`, log text `:171`).
3.  **`notification_reminder_minutes` has no writer** anywhere in `lib/` (grep: the constant, `desktop_prayer_scheduler.dart:46` and `notification_service.dart:312` only read it), and no Android setting exposes it. Native code never reads it.
4.  **Three different defaults exist:** native 45 (hard-coded), Windows scheduler 10 (`desktop_prayer_scheduler.dart:46`), dead Dart path 10 (`notification_service.dart:312`).
5.  **Re-arm paths do not cover reminders.** Adhan alarms are armed through `PrayerAlarmReceiver.schedulePrayerAlarm` from: Dart (`MainActivity.kt:421`, via `prayerEffects` in `prayer_times_provider.dart:396`), the 00:05 native recalc (`NativePrayerCalculator.kt:216`) and boot (`PrayerRescheduleService.kt:133`). Post-prayer checks are armed from Dart (`:412`) and after each adhan (`PrayerAlarmReceiver.kt:581`). A reminder armed only from Dart would be lost after boot and not re-armed for the new day by the native recalc.

## Decisions to take (owner)

*   **D1 — Default lead time on Android.** Recommended: **45 min** when the key is unset (preserves the shipped design and the picker's minute choices). Windows keeps 10. UNKNOWN whether 45 is what the owner wants for an unset key.
*   **D2 — "Reminders off".** No off switch exists today (no key, no UI). Recommended for this fix: no new UI (a new setting is a feature and needs its own spec); treat a stored value `<= 0` as off so a future toggle has a defined meaning. With the key unset, reminders are ON at the default.
*   **D3 — Where to arm.** Recommended: arm natively, from one helper called inside `schedulePrayerAlarm` (covers Dart, 00:05 recalc and boot with one change), skipping Sunrise. Alternative: arm only from the Dart provider (rejected: misses boot and recalc).

## Goals

*   Each of Fajr, Zuhr, Asr, Maghrib, Isha gets a reminder alarm `N` minutes before its time, where `N` = `FlutterPrefs.getInt(context, "notification_reminder_minutes", 45)` (D1). Sunrise gets none.
*   The alarm is re-armed on every path that arms the adhan alarm: Dart recalculation (method, madhab, location, language change), 00:05 native recalc, boot, app update.
*   `scheduleReminderAlarm` reads `N` instead of `45 * 60 * 1000`; log lines say `N`.
*   Snooze (`scheduleDelayedReminder`, the Dart `delayMinutes` path, 15 min from the notification) works exactly as today.
*   The Windows pre-prayer reminder is checked and left as is.

## Non-Goals

*   A settings UI for the lead time, or an on/off toggle (D2).
*   Changing reminder mode content, buttons, picker, or when it clears.
*   Changing notification IDs, channels, or the 1001–1006 / 6001–6006 ranges.
*   Windows changes. `desktop_prayer_scheduler.dart:45-75` already schedules a reminder (VERIFIED in code, UNVERIFIED on a device); its default 10 vs Android 45 is recorded, not changed.
*   Removing the dead Dart `NotificationService` reminder code (cleanup, P6).
*   Any prefs key rename.

## Design

1.  **Pure helper (testable):** `reminderTriggerTime(prayerTime, minutes, now): Long?` returns `prayerTime - minutes * 60_000`, or `null` if `minutes <= 0` or the result is `<= now`. `scheduleReminderAlarm` calls it; behavior for 45 is unchanged.
2.  **Read the lead time** inside `scheduleReminderAlarm` via `FlutterPrefs.getInt` (file `FlutterSharedPreferences`, `flutter.` prefix; never `${packageName}_preferences`). Dart `setInt` stores a Long: UNVERIFIED that `FlutterPrefs.getInt` (`FlutterPrefs.kt:28`) handles a Long; the first step of R1 must confirm it with a unit test.
3.  **Arm from `schedulePrayerAlarm`** (D3): after the adhan alarm is set, call `scheduleReminderAlarm(context, name, nameAr, prayerTime, requestCode)` for names other than Sunrise. `PrayerAlarmReceiver.kt` is an "edit carefully" file: the change is additive, one call plus the helper.
4.  **Request codes:** the reminder alarm uses `requestCode + 1000` = 2001–2006. Adhan alarms use the 1001–1006 request codes and post-checks 3001–3006 (`+2000`), so there is no clash with 1001–1006 or 6001–6006 (6001–6006 are notification IDs, not request codes). **Overlap to record, not change:** `scheduleDelayedReminder` is called with `getReminderNotificationId` = 2001–2006 (`:889-895`), the same request code, so a snooze replaces the armed 45-minute alarm for that prayer (intended: the snooze happens after the reminder fired). The Dart snooze path uses `7000 + delayMinutes` and does not collide. `FLAG_UPDATE_CURRENT` makes re-arming idempotent, so a re-arm after a method change replaces the old alarm without a cancel. UNVERIFIED: the adhan alarm's request-code range in `schedulePrayerAlarm` (read the `getBroadcast` call at `:262` in R1).
5.  **Exact alarm / doze:** the code already uses `setExactAndAllowWhileIdle` (API 23 and up) and only logs a warning on S and up when exact alarms are not allowed; no manifest change. Android 10 (API 29) takes the same path as the adhan alarm. UNVERIFIED for the reminder until the device run. The doze check S03 is a separate run.
6.  **Edge cases:** a reminder time already past (app opened late) is skipped with the existing log. If a reminder fires while the previous adhan window is active, `PrayerForegroundService` shows adhan mode first (`:471-477`) and reminder mode after the window; UNVERIFIED on a device. After the reminder fires the display can lag up to one 60 s update cycle (no `nudge()` call in the reminder branch, VERIFIED by reading); out of scope unless the owner asks.
7.  **Tracked prayer:** the reminder branch does not check whether the prayer is already marked, and reminder mode asks "Did you pray X?" before the prayer time, as designed. Not changed.
8.  **Contracts:** no key, ID, channel or request-code change. In the same commit as the code, update `contracts/notification-ids.md` (row 2001–2006: reminder mode, not a notification) and `contracts/prefs-keys.md` (`notification_reminder_minutes` is read natively, default 45).

## Tests to write first

*   Kotlin unit (`./gradlew :app:testDebugUnitTest`): `reminderTriggerTime` for 45, 10, 0, negative, and a past time; `FlutterPrefs.getInt` with a value stored as Long, as Int, and absent.
*   Dart: none if no Dart file changes. If D3 is decided differently, add a provider test.
*   Regression: existing Dart tests unchanged; `flutter analyze` count unchanged (408).

## Device check (after the fix)

S05 re-run on the nova 5T (Android 10), with a prayer more than the lead time away:
*   `dumpsys alarm` shows 5 reminder alarms with request codes 2001, 2003–2006 (no 2002, Sunrise).
*   Logcat shows `🔔 [REMINDER SCHEDULED]`, then at the reminder time `⏰ [REMINDER] ... activating reminder mode`.
*   The foreground notification shows reminder mode with four buttons. Prayed / Late / Missed write `prayer_status_*`. Remind Later logs `Re-scheduled ... in 15 min`.
*   No `MainActivity` launch.
*   Follow-ups: change the method (alarms replaced, no duplicates), reboot (alarms re-armed), 00:05 recalc (tomorrow's reminders armed).
*   Windows: observe the existing reminder only; no change.

## Phases (proposal)

| Phase | Content | Level |
|---|---|---|
| R0 | This spec, EGM review | A |
| R1 | Tests first, then the helper, the `N` read, arming in `schedulePrayerAlarm`; contracts and S05 wording | C ("approve phase R1") |
| R2 | Device check S05 and the reboot / recalc follow-ups | owner |

## Open questions

*   D1, D2, D3 above.
*   UNKNOWN: whether OEM battery policy on the nova 5T delays the reminder alarm (same question as S02/S03).
*   UNKNOWN: whether the Arabic text of `showReminderModeNotification` is correct (not read in this trace).
