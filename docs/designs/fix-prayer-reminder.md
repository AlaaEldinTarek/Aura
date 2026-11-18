# FX-S05 — Arm the Pre-Prayer Reminder (Android + Windows) with a Settings Tile

*   **Author:** Alaa Eldin Tarek
*   **Status:** Draft, not approved. Docs only: no code is written until the owner says "approve phase".
*   **Date:** 2026-11-18 (owner decisions D1–D3 added the same day)
*   **Source:** device check S05 FAIL, 2026-11-17 (nova 5T, 1.1.0+60). Known gap, listed out of scope in the FX-0 review.

Labels: VERIFIED = read in code, UNVERIFIED = not run on a device, UNKNOWN = not checked.

---

## Overview

The pre-prayer reminder never fires on Android: the receiving side exists, but nothing arms the alarm, the lead time is hard-coded to 45 min, and nothing writes `notification_reminder_minutes`. This spec (1) arms the reminder on Android through the same native path as the adhan alarm, (2) makes `notification_reminder_minutes` the single setting for Android and Windows (default 10, Off = 0), (3) adds a Settings tile to change it, and (4) makes the pre-prayer reminder information only (no tracking buttons or "Did you pray?" text).

## Owner decisions (2026-11-18)

*   **D1 — One key, one default:** `notification_reminder_minutes`, default **10** on Android, Windows and the Dart path. The hard-coded 45 in `PrayerAlarmReceiver.kt` goes away.
*   **D2 — Settings tile, not "no UI":** a "Pre-prayer reminder" tile next to "Jumu'ah Reminder" in `settings_screen.dart` (~`:225`), choices **Off / 5 / 10 / 15 / 30 min** (Off = 0), English + Arabic via `.tr()` keys in `en.json` and `ar.json`. Changing it cancels and re-arms the reminder alarms right away. The same tile controls Windows (same key). Reason: nothing writes the key today, so arming without a tile would turn on 5 notifications a day for everyone with no way to stop them.
*   **D3 — Arm inside `schedulePrayerAlarm`, with safeguards:** (a) the adhan alarm is set first and the reminder runs in its own try/catch, so a reminder failure can never block or delay the adhan; (b) every path that cancels a prayer alarm also cancels that prayer's reminder alarm (table below); (c) reminder request codes must not clash with adhan, post-check or snooze codes (code table below).
*   **Owner preference on content:** the pre-prayer reminder is information only: "Zuhr in 10 minutes" / "الظهر بعد ١٠ دقائق" (Arabic numerals in Arabic). No tracking buttons. The snooze reminder keeps its current buttons (see "What the user sees" for what that means in the current code).

## What the user sees today (VERIFIED, code read)

Both cases go through one function, `PrayerForegroundService.showReminderModeNotification` (`:593-637`), selected when `reminder_active=true` (`:470`, `:479`). It adds **no action buttons** and no tracking text beyond the title. The "Did you pray" wording is in the title.

| | Pre-prayer reminder (alarm fires N min before) | After-adhan snooze reminder |
|---|---|---|
| Producer | `scheduleReminderAlarm` (`PrayerAlarmReceiver.kt:112`). **Never called with no delay**, so never seen on a device (S05 FAIL). | `scheduleDelayedReminder` (`:186`), reached from `MainActivity.kt:433` (Dart `delayMinutes`) and from `handleReminderAction` `ACTION_REMINDER_LATER` (`:889`). |
| Live producer of the trigger? | Not today. | **No.** `ACTION_REMINDER_PRAYED/LATE/MISSED/LATER` appear only as constants and in the handler (`:35-38`, `:432`, `:853-889`); no `PendingIntent` is built with them. `open_reminder_picker` is only read (`MainActivity.kt:94`), never set. The Dart picker `_scheduleRemindLater` (`main_wrapper_screen.dart:803`) is reachable only from that picker. So the snooze buttons **do not exist in the current code**. |
| What shows in notification 9999 | Header "Aura - Prayer Reminder" / "هالة - تذكير الصلاة"; title "Did you pray Zuhr?" / "هل صليت الظهر؟"; subtitle "N min until azan" / "بعد N دقيقة أذان" (N in Eastern Arabic numerals via `toEasternArabic`, `:620`). Normal layout, no buttons, except the Stop/Keep Vibration buttons while a silent window is active (`buildContentView`, `:651-668`). | Identical (same function, same prefs). |
| Real "Done / Late / Missed / Remind Later" buttons | None | They live on the **post-prayer check** notification (IDs 6001–6006, `PrayerAlarmReceiver.kt:933-1000`), 30 min after the adhan; its Remind Later re-arms that check in 15 min (`:1046-1055`). That is the real after-adhan tracking flow and is not touched. |

Consequences for the owner preference:
*   The pre-prayer reminder as designed by this spec ("Zuhr in 10 minutes", no question, no buttons) needs a **distinguishing flag**, because both cases share `EXTRA_IS_REMINDER` and `reminder_active`. Proposal: new extra `EXTRA_REMINDER_KIND` ("pre") written by the alarm receiver to a new native pref `reminder_kind` in `aura_prayer_times` (same file as the other `reminder_*` keys; contracts/prefs-keys.md line 58 updated in the same commit). `showReminderModeNotification` renders "{Prayer} in N minutes" when `reminder_kind == "pre"` and the current text otherwise (legacy and any revived snooze). `handleReminderAction` and the snooze code stay untouched.
*   "The snooze keeps its current buttons" is true only as "unchanged": it has none today. Whether to give the snooze notification real buttons is a separate decision (D5 below).

## The Problem (VERIFIED)

1.  **Nothing arms the reminder alarm.** `scheduleReminderAlarm` is reached only from the MethodChannel handler (`MainActivity.kt:424-437`); the no-delay branch has no Dart caller (`prayer_alarm_service.dart:99` has no caller; `main_wrapper_screen.dart:823` always sends `delayMinutes`). `NotificationService.scheduleDailyPrayers` / `schedulePrayerNotification` (the Dart reminder) have no caller. S05 log: no request code outside 1001–1006, no Aura notification except 9999.
2.  **Hard-coded 45 min** (`PrayerAlarmReceiver.kt:119-123`, log `:171`).
3.  **`notification_reminder_minutes` has no writer** in `lib/`; only `desktop_prayer_scheduler.dart:46` and `notification_service.dart:312` read it (default 10). Native code never reads it.
4.  **Re-arm paths do not cover reminders.** The adhan alarm is armed through `PrayerAlarmReceiver.schedulePrayerAlarm` from Dart (`MainActivity.kt:421`, via `prayer_times_provider.dart:396`), the 00:05 native recalc (`NativePrayerCalculator.kt:216`) and boot (`PrayerRescheduleService.kt:133`).
5.  **Windows would break on Off.** `desktop_prayer_scheduler.dart:46-74` schedules `prayer.time - reminderMinutes` with no guard for 0 (a 0 would fire a "reminder" at prayer time), and `schedulePrayerTimers` runs only when prayer times load, so a tile change would not take effect until the next load.

## Answers to the open UNKNOWNs

*   **`FlutterPrefs.getInt` with a Long: VERIFIED OK.** `FlutterPrefs.kt:28-33` reads the raw value and maps `is Long -> v.toInt()`, `is Int -> v`, else the default. A Dart `setInt` (stored as Long) is read correctly. R1 still adds a unit test for Long, Int and absent.
*   **Arabic reminder text:** the current text is "هل صليت الظهر؟" / "بعد ٥ دقيقة أذان" (numerals are Eastern Arabic, correct per CLAUDE.md). The phrase "بعد N دقيقة أذان" is grammatically awkward and "دقيقة" is singular for 5–10; the new text "الظهر بعد ١٠ دقائق" needs plural handling (دقيقة 1, دقيقتان 2, دقائق 3–10, دقيقة 11+). **The owner (native Arabic speaker) must review the final Arabic strings** (as with `wird_bookmark_already_counted`). The native service uses `isArabic` ternaries, not `.tr()` (Kotlin cannot call `.tr()`); the tile strings use `.tr()`.

## Design

**1. Lead time and helper.** `reminderTriggerTime(prayerTime, minutes, now): Long?` returns `prayerTime - minutes * 60_000`, or `null` if `minutes <= 0` or the result is `<= now`. `scheduleReminderAlarm` reads `N = FlutterPrefs.getInt(context, "notification_reminder_minutes", 10)` and calls it. On `null` it **cancels** any existing reminder alarm for that prayer (otherwise a stale alarm survives a time change or Off).

**2. Arm in `schedulePrayerAlarm` (D3).** After the adhan alarm is set and logged, call `scheduleReminderAlarm` for names other than Sunrise inside `try { ... } catch (e: Exception) { Log.e(TAG, "❌ [REMINDER] ...") }`. The adhan path returns before and does not depend on the result. `PrayerAlarmReceiver.kt` is an "edit carefully" file: the change is one guarded call plus the helper, and the adhan code path is not reordered.

**3. Fire-time guard.** In the `isReminder` branch, re-read `N`; if `N <= 0` drop the alarm (belt and braces for a failed cancel). Write `reminder_kind=pre` only for alarms armed by step 2.

**4. Content.** Pre-prayer: header unchanged; title "Zuhr in 10 minutes" / "الظهر بعد ١٠ دقائق"; subtitle: the time of the prayer; no question, no buttons. The minutes shown are `ceil((prayerTime - now) / 60000)` at each service update, using `getDisplayPrayerName` (Jumu'ah on Fridays). Cleared at prayer time as today (`:465-467`).

**5. Settings tile (Dart).** New provider in `preferences_provider.dart`, modeled on `JumuahReminderNotifier` (`:472-495`): `notification_reminder_minutes`, default 10, allowed 0/5/10/15/30. Tile in the Notifications card; tapping opens a picker of the five choices (pattern of `_showReminderMinsPicker`, `:375`). New `.tr()` keys in BOTH `en.json` and `ar.json`: `pre_prayer_reminder`, `pre_prayer_reminder_subtitle`, `pre_prayer_reminder_off`, `pre_prayer_reminder_minutes` (number through `NumberFormatter.withArabicNumerals`).
*   **On change, Android:** `Off` calls a new native method `cancelReminderAlarms` (cancels the reminder request codes and clears `reminder_active`/`reminder_*`); any other value re-arms by running the existing recalculation effects (`prayerEffects` → `scheduleDailyPrayerAlarms` → `schedulePrayerAlarm`, which replaces by request code). UNKNOWN whether the provider exposes a public re-run; the first R1 task is to confirm, otherwise a small public method is added.
*   **On change, Windows:** call `DesktopPrayerScheduler.schedulePrayerTimers(currentPrayerTimes)` (it already cancels and re-creates all timers), and add a guard so `reminderMinutes <= 0` skips the reminder timer. Windows-only edits stay platform-guarded.

**6. Cancel and re-arm paths (D3b).**

| Path | Today (VERIFIED) | Reminder alarm |
|---|---|---|
| Method / madhab / location / language change | Dart `prayerEffects` re-arms every prayer at its next occurrence with the same request code, so the new alarm replaces the old one; no cancel | Re-armed inside `schedulePrayerAlarm`, replaces by request code; if the new reminder time is past it is cancelled (design step 1) |
| 00:05 native recalc | `NativePrayerCalculator.reschedule` (`:216`) re-arms | Same helper, so covered |
| Boot / app update | `PrayerRescheduleService` (`:133`) re-arms | Same helper, so covered |
| `cancelAllAlarms` (native, MethodChannel `cancelAllPrayerAlarms`) | Cancels 1001–1006 only (`:301-318`); **no Dart caller found** | Extend to cancel the reminder codes |
| Adhan switched off | **Nothing is cancelled**: the adhan alarm stays armed and the receiver skips playback at fire time (`AdhanPlayer` "Enabled" check) | Not affected: the reminder has its own Off in the tile (D4 below) |
| Logout | **Nothing is cancelled**: prayer alarms are device-level, not account-level | Not affected |
| Tile Off / change | n/a | New: cancel or re-arm immediately (design step 5) |

**7. Request codes (D3c), one table.** PendingIntent identity is component + request code, so only codes within the same receiver class can clash.

| Request code(s) | Owner / class | Meaning | Source |
|---|---|---|---|
| 1001–1006 | `PrayerAlarmReceiver` | Adhan alarm (`getNotificationId`) | `:262`, cancel `:301-318` |
| **4001–4006 (new)** | `PrayerAlarmReceiver` | **Pre-prayer reminder** (`requestCode + 3000`) | new; 4xxx is unused anywhere in `android/` (grep, VERIFIED) |
| 2001–2006 | `PrayerAlarmReceiver` | After-adhan snooze (`scheduleDelayedReminder` via `getReminderNotificationId`); the pre-prayer reminder used `+1000` = 2001–2006 before this spec, which would let a snooze replace it, so it moves to 4001–4006 | `:889-895`, `:60-92` |
| 7005, 7010, … (`7000 + delayMinutes`) | `PrayerAlarmReceiver` | Dart snooze picker (dead path) | `main_wrapper_screen.dart:823` |
| 3001–3006 | `PrayerAlarmReceiver` | Post-prayer check (`requestCode + 2000`, from 1001–1006) | `:347-372` |
| 3001–3006 | `AzkarAlarmReceiver` | Azkar after iqama | `AzkarAlarmReceiver.kt:44-52` (different class, no clash; same numbers) |
| 9999 | `PrayerAlarmReceiver` | Test adhan | `MainActivity.kt:460-466` |
| 3999 | `SilentOffReceiver`, `ToggleSilentModeReceiver` | Silent-mode off | `PrayerAlarmReceiver.kt:737`, `ToggleSilentModeReceiver.kt:35` |
| 5000–5999 | `FocusModeReceiver` | Focus alarms | `FocusModeReceiver.kt:36-49` |
| 7001, 8001, 9100 | Summary / Jumu'ah / Recalc receivers | Daily summary, Jumu'ah, 00:05 recalc | respective files |

Notification IDs are unchanged (1001–1006, 6001–6006, 9999; the 2001–2006 `REMINDER_*` IDs stay reserved). Request codes are not notification IDs, but `contracts/notification-ids.md` row 2001–2006 ("Pre-prayer reminders") is reworded and a 4001–4006 request-code row added in the same commit as the code.

**8. Doze / Android 10.** The reminder uses `setExactAndAllowWhileIdle` (API 23+); on S+ a missing exact-alarm permission only logs a warning (as for the adhan alarm). No manifest change. Android 10 (nova 5T, API 29) takes the same path. UNVERIFIED for the reminder until R2. The adhan doze check S03 is a separate run.

## Goals

*   Reminders armed for Fajr, Zuhr, Asr, Maghrib, Isha (not Sunrise) at `N` minutes before, re-armed on every path above.
*   One key, default 10, Off = 0; the tile controls Android and Windows and applies immediately.
*   The reminder cannot delay or block the adhan.
*   The pre-prayer notification is information only.

## Non-Goals

*   Real buttons on the snooze notification (D5), or changing the post-prayer check (6001–6006).
*   Changing notification IDs or channels, or renaming any prefs key.
*   Removing the dead Dart `NotificationService` reminder code and the dead picker/handler code (cleanup, P6).
*   An independent "reminder only for some prayers" setting.

## Decisions still open

*   **D4 — Reminder when the adhan is off.** Recommended: independent (the tile's Off is the control). The adhan toggle does not cancel any alarm today, so there is nothing to mirror.
*   **D5 — Snooze notification buttons.** The snooze has no live buttons or producer. Recommended: leave it as dead code now; if you want it revived, that is its own spec.
*   **D6 — Request codes 4001–4006 for the pre-prayer reminder** (recommended, avoids the snooze overlap) vs keeping 2001–2006 (matches the existing contract row but a revived snooze would replace the reminder).
*   **D7 — Arabic strings:** native-speaker review before release.

## Tests to write first

*   Kotlin unit (`./gradlew :app:testDebugUnitTest`): `reminderTriggerTime` for 5/10/15/30, 0, negative, and a past time (returns null); `FlutterPrefs.getInt` Long, Int, absent; the Arabic title builder for 1, 2, 3–10, 11+ minutes (Eastern numerals).
*   Dart: provider test (default 10, set/get, invalid value falls back to 10); a widget test for the tile if `settings_screen` has an existing harness (UNKNOWN); `DesktopPrayerScheduler` skips the reminder timer when minutes is 0 and uses the stored value; `en.json` / `ar.json` key parity (existing check if any, UNKNOWN).
*   Regression: existing Dart tests unchanged, `flutter analyze` count unchanged (408).

## Device check (after the fix)

S05 (Android 10, nova 5T), steps also recorded in `reference/device-checklist.md`:
1.  Tile **Off** → no reminder alarms (`dumpsys alarm` shows none with request codes 4001–4006), no reminder.
2.  Tile **10** → reminder 10 min before a prayer: foreground notification shows "{Prayer} in 10 minutes", no buttons, no `MainActivity` launch; the adhan still fires at prayer time.
3.  Change **10 → 5** → re-armed right away (`dumpsys alarm` shows the new trigger time; no duplicate).
4.  **Reboot** → still armed.
5.  Arabic: the same text in Arabic numerals (owner reviews wording).
6.  Windows: same tile, Off → no reminder toast, 5/10 → toast at the set time (observe only).

## Phases (proposal)

| Phase | Content | Level |
|---|---|---|
| R0 | This spec, EGM review | A |
| R1 | Tests first, then helper, arming with try/catch, flag + text, cancel paths, tile + provider, Windows guard, `.tr()` keys, contracts | C ("approve phase R1") |
| R2 | Device check S05 steps above | owner |

## Open questions

*   D4–D7 above.
*   UNKNOWN: whether OEM battery policy on the nova 5T delays the reminder alarm (same question as S02/S03).
*   UNKNOWN: whether `prayer_times_provider.dart` exposes a public way to re-run `prayerEffects` for the tile (first R1 task).
*   UNKNOWN: tap behavior of the foreground notification in reminder mode (not traced).
