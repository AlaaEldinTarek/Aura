# FX-S05 — Arm the Pre-Prayer Reminder (Android + Windows) with a Settings Tile

*   **Author:** Alaa Eldin Tarek
*   **Status:** Draft, not approved. Docs only: no code is written until the owner says "approve phase".
*   **EGM review:** replaced by owner review 2026-11-18 (3ae9feb); the review points are applied in this revision.
*   **Date:** 2026-11-18 (owner decisions D1–D11 added the same day)
*   **Source:** device check S05 FAIL, 2026-11-17 (nova 5T, 1.1.0+60). Known gap, listed out of scope in the FX-0 review.

Labels: VERIFIED = read in code, UNVERIFIED = not run on a device, UNKNOWN = not checked.

---

## Overview

The pre-prayer reminder never fires on Android: the receiving side exists, but nothing arms the alarm, the lead time is hard-coded to 45 min, and nothing writes `notification_reminder_minutes`. This spec (1) arms the reminder on Android through the same native path as the adhan alarm, (2) makes `notification_reminder_minutes` the single lead-time setting for Android and Windows (default 10; values 5 / 10 / 15 / 30), (3) keeps the existing "Reminder Prayer" switch (`prayer_notifications_enabled`) as the only on/off and adds a Settings tile for the lead time only, and (4) makes the pre-prayer reminder information only (no tracking buttons or "Did you pray?" text).

## Owner decisions (2026-11-18)

*   **D1 — One key, one default:** `notification_reminder_minutes`, default **10** on Android, Windows and the Dart path. The hard-coded 45 in `PrayerAlarmReceiver.kt` goes away.
*   **D2 (revised by D9) — Lead-time tile only:** a "Pre-prayer reminder" tile next to "Jumu'ah Reminder" in `settings_screen.dart` (~`:225`) with the choices **5 / 10 / 15 / 30 min** (no Off; a stored 0 or any other value is treated as 10), English + Arabic via `.tr()` keys in `en.json` and `ar.json`, default 10. Changing it cancels and re-arms the reminder alarms right away. The same tile controls Windows (same key). The tile is shown disabled (greyed) with its value kept while the "Reminder Prayer" switch is off. The on/off is the existing switch, so the 5-a-day notifications can be stopped.
*   **D3 — Arm inside `schedulePrayerAlarm`, with safeguards:** (a) the adhan alarm is set first and the reminder runs in its own try/catch, so a reminder failure can never block or delay the adhan; (b) every path that cancels a prayer alarm also cancels that prayer's reminder alarm (table below); (c) reminder request codes must not clash with adhan, post-check or snooze codes (code table below).
*   **D4 — Independent of the adhan toggle:** the "Reminder Prayer" switch is the only on/off (D9); the adhan toggle does not affect the reminder. Switching the adhan off does not cancel or change it.
*   **D5 — Snooze/reminder-button code stays as is** (dead code). Recorded as finding F69 for P6 cleanup; not part of this fix.
*   **D6 — Request codes 2101–2106, confirmed 2026-11-18.** 4001–4006 was checked and is not free (see "Request codes").
*   **D7 — Texts (the owner reviews the Arabic himself):** see "Texts".
*   **Logout and adhan-off (owner, 2026-11-18, revised):** adhan-off does not touch the reminder (D4). **Logout is not handled by this spec:** a reminder-only cancel on logout would be half a fix (all other prayer alarms stay armed, F70, and the reminder returns at the 00:05 re-arm). Finding F70 now says logout must cancel all alarm kinds in one place, including the pre-prayer reminder 2101–2106. No sign-out flag.
*   **D8 — Master switch respected, per-prayer keys ignored.** See "Gates" below. The master `prayer_notifications_enabled` is written by a visible switch, so master off means no reminders on both platforms. `notify_<prayer>` is never written by any UI and is ignored for the reminder; the tile is the per-app control.
*   **Fixed N, no countdown** is accepted, but the reminder text must not stay up after the prayer time; see design step 9.
*   **D9 — One feature, one on/off, one lead time:** the existing "Reminder Prayer" switch (`prayer_notifications_enabled`, Prayer screen sheet) is the ONLY on/off. The tile is lead time only (5/10/15/30; no Off; 0 or a bad value reads as 10) and is disabled while the switch is off, value kept. The armed-and-shown rule is: the switch is on. The switch subtitle gets a `.tr()` key that shows the current N (EN "{N} minutes before each prayer", AR "قبل كل صلاة بـ {N} {unit}") and updates when the tile changes (see "Texts").
*   **D10 — Existing users:** the master switch defaults to true, so after the update every Android user starts getting up to 5 reminders a day. Accepted: the switch subtitle already promised "10 minutes before" and this fix makes the app keep that promise. **Release notes draft (no code):** "The pre-prayer reminder now works on Android: you get a notification before each prayer (default 10 minutes). Change the time in Settings, or switch it off with the Reminder Prayer switch on the Prayer screen settings page."
    **Device observation 2026-11-18 (R1 release APK installed over 1.1.0+60, data kept; log-confirmed, `S05-S08-asr-2026-11-18.txt`):** the update path arms the reminders by itself. Install finished 12:54:00; at 12:54:35 the log shows `[REMINDER SCHEDULED] Asr at 14:33 (10 min before 14:43), req=2104`, then Maghrib 16:55 (2105) and Isha 18:09 (2106); `dumpsys alarm` at 13:11 shows 14:33, 16:55 and 18:09 as Aura alarms. So D10 holds: existing users get reminders ~30 s after the update, no app action needed. Why (code, `PrayerBootReceiver.kt:37,63`): `MY_PACKAGE_REPLACED` re-runs the alarm scheduling after a 30 s delay. A first `dumpsys` at 12:54:27 showed no 14:33 alarm because it ran before that 30 s delay ended (my earlier reading of it as a gap was wrong). The `Boot event received` / `Rescheduling prayer alarms` lines are not in the capture (its filter does not include the `PrayerBootReceiver` tag) and the main buffer had rolled over, so the receiver itself was not seen in the log; the arming time (about 35 s after the install) is the evidence. Later re-arms in the log (13:01:06 three reminders; 13:09:58 and 13:10:11 all five plus post-checks) have a trigger not identified here (UNKNOWN; owner actions on the phone are possible).
*   **D11 — Friday:** the Jumu'ah reminder (8001, Zuhr minus 30 min) and the pre-prayer reminder for Jumu'ah both fire. Accepted, both kept, no special case.
*   **Owner preference on content:** the pre-prayer reminder is information only: "Zuhr in 10 minutes" / "أذان الظهر بعد ١٠ دقائق" (Arabic numerals in Arabic). No tracking buttons. The snooze reminder keeps its current buttons (see "What the user sees" for what that means in the current code).

## What the user sees today (VERIFIED, code read)

Both cases go through one function, `PrayerForegroundService.showReminderModeNotification` (`:593-637`), selected when `reminder_active=true` (`:470`, `:479`). It adds **no action buttons** and no tracking text beyond the title. The "Did you pray" wording is in the title.

| | Pre-prayer reminder (alarm fires N min before) | After-adhan snooze reminder |
|---|---|---|
| Producer | `scheduleReminderAlarm` (`PrayerAlarmReceiver.kt:112`). **Never called with no delay**, so never seen on a device (S05 FAIL). | `scheduleDelayedReminder` (`:186`), reached from `MainActivity.kt:433` (Dart `delayMinutes`) and from `handleReminderAction` `ACTION_REMINDER_LATER` (`:889`). |
| Live producer of the trigger? | Not today. | **No.** `ACTION_REMINDER_PRAYED/LATE/MISSED/LATER` appear only as constants and in the handler (`:35-38`, `:432`, `:853-889`); no `PendingIntent` is built with them. `open_reminder_picker` is only read (`MainActivity.kt:94`), never set. The Dart picker `_scheduleRemindLater` (`main_wrapper_screen.dart:803`) is reachable only from that picker. So the snooze buttons **do not exist in the current code**. |
| What shows in notification 9999 | Header "Aura - Prayer Reminder" / "هالة - تذكير الصلاة"; title "Did you pray Zuhr?" / "هل صليت الظهر؟"; subtitle "N min until azan" / "بعد N دقيقة أذان" (N in Eastern Arabic numerals via `toEasternArabic`, `:620`). Normal layout, no buttons, except the Stop/Keep Vibration buttons while a silent window is active (`buildContentView`, `:651-668`). | Identical (same function, same prefs). |
| Real "Done / Late / Missed / Remind Later" buttons | None | They live on the **post-prayer check** notification (IDs 6001–6006, `PrayerAlarmReceiver.kt:933-1000`), 30 min after the adhan; its Remind Later re-arms that check in 15 min (`:1046-1055`). That is the real after-adhan tracking flow and is not touched. |

Consequences for the owner preference:
*   The pre-prayer reminder as designed by this spec ("Zuhr in 10 minutes", no question, no buttons) needs a **distinguishing flag**, because both cases share `EXTRA_IS_REMINDER` and `reminder_active`. Proposal: new extra `EXTRA_REMINDER_KIND` ("pre") written by the alarm receiver to a new native pref `reminder_kind` in `aura_prayer_times` (same file as the other `reminder_*` keys; contracts/prefs-keys.md line 58 updated in the same commit). `showReminderModeNotification` renders the "Texts" below when `reminder_kind == "pre"` and the current text otherwise (legacy and any revived snooze). `handleReminderAction` and the snooze code stay untouched.
*   "The snooze keeps its current buttons" is true only as "unchanged": it has none today. Whether to give the snooze notification real buttons is a separate decision (D5 below).

## The Problem (VERIFIED)

1.  **Nothing arms the reminder alarm.** `scheduleReminderAlarm` is reached only from the MethodChannel handler (`MainActivity.kt:424-437`); the no-delay branch has no Dart caller (`prayer_alarm_service.dart:99` has no caller; `main_wrapper_screen.dart:823` always sends `delayMinutes`). `NotificationService.scheduleDailyPrayers` / `schedulePrayerNotification` (the Dart reminder) have no caller. S05 log: no request code outside 1001–1006, no Aura notification except 9999.
2.  **Hard-coded 45 min** (`PrayerAlarmReceiver.kt:119-123`, log `:171`).
3.  **`notification_reminder_minutes` has no writer** in `lib/`; only `desktop_prayer_scheduler.dart:46` and `notification_service.dart:312` read it (default 10). Native code never reads it.
4.  **Re-arm paths do not cover reminders.** The adhan alarm is armed through `PrayerAlarmReceiver.schedulePrayerAlarm` from Dart (`MainActivity.kt:421`, via `prayer_times_provider.dart:396`), the 00:05 native recalc (`NativePrayerCalculator.kt:216`) and boot (`PrayerRescheduleService.kt:133`).
5.  **Windows has no guard for a bad value.** `desktop_prayer_scheduler.dart:46-74` schedules `prayer.time - reminderMinutes` and a stored 0 (or any bad value) would fire a "reminder" at prayer time; `schedulePrayerTimers` also runs only when prayer times load, so a tile change would not take effect until the next load.

## Answers to the open UNKNOWNs

*   **`FlutterPrefs.getInt` with a Long: VERIFIED OK.** `FlutterPrefs.kt:28-33` reads the raw value and maps `is Long -> v.toInt()`, `is Int -> v`, else the default. A Dart `setInt` (stored as Long) is read correctly. R1 still adds a unit test for Long, Int and absent.
*   **Arabic reminder text:** the current text is "هل صليت الظهر؟" / "بعد ٥ دقيقة أذان" (Eastern Arabic numerals via `toEasternArabic`, correct per CLAUDE.md). It is replaced by the owner's strings under "Texts". The native service uses `isArabic` ternaries, not `.tr()` (Kotlin cannot call `.tr()`); the tile strings use `.tr()`. The current Windows toast interpolates a raw number into the Arabic text (`desktop_notification_service.dart:246`); the new text fixes that.

## Texts (owner-provided, 2026-11-18; the owner reviews the Arabic)

| Where | English | Arabic |
|---|---|---|
| Notification / toast title | Prayer reminder | تذكير بالصلاة |
| Body | `{prayer} in {N} minutes` | `أذان {prayer} بعد {N} {unit}` |
| Tile title | Pre-prayer reminder | التذكير قبل الصلاة |
| Tile options | 5 min / 10 min / 15 min / 30 min | ٥ دقائق / ١٠ دقائق / ١٥ دقيقة / ٣٠ دقيقة (each option carries its own unit, same helper) |
| Switch subtitle ("Reminder Prayer", Prayer screen sheet) | `{N} minutes before each prayer` | `قبل كل صلاة بـ {N} {unit}` |

*   Arabic numerals in Arabic (٥ / ١٠ / ١٥ / ٣٠): Dart through `NumberFormatter.withArabicNumerals`, Kotlin through `toEasternArabic`.
*   **The unit is chosen by N, never built by concatenating one word:** N = 5 and 10 give "دقائق"; N = 15 and 30 give "دقيقة". Examples: "أذان الظهر بعد ١٠ دقائق", "أذان العصر بعد ١٥ دقيقة". A helper `arabicMinuteUnit(n)` returns the unit; the tile offers only these four values and any other stored value falls back to 10, so no other N reaches the text.
*   **Windows uses the same text:** the toast built by `showPrePrayerNotification` (`desktop_notification_service.dart:233-251`) is changed to this title and body. The strings live in two places (Kotlin and Dart), so a Kotlin unit test and a Dart unit test assert the same expected strings.
*   **Switch subtitle (D9):** replaces the hard-coded "Remind 10 minutes before prayer time" (`prayer_screen.dart:1251-1257`) with a `.tr()` key carrying the current N. Examples: EN "10 minutes before each prayer"; AR "قبل كل صلاة بـ ١٠ دقائق", "قبل كل صلاة بـ ١٥ دقيقة" (Arabic numerals, unit chosen by N with the same helper as the reminder text, never concatenated). It updates right away when the tile changes (the sheet reads the same provider; UNKNOWN whether `PrayerSettingsPage` can watch a provider as it is a plain `StatefulWidget`, first R1 task: make it a `ConsumerStatefulWidget` or listen to the value).
*   Keys in BOTH `en.json` and `ar.json`: `pre_prayer_reminder` (tile title), `pre_prayer_reminder_minutes` (tile option), `pre_prayer_reminder_switch_subtitle` (switch subtitle), plus keys for the notification/toast title and body used by the Windows toast. No "off" key.

## Design

**1. Lead time and helper.** `normalizeReminderMinutes(v)` returns `v` if it is 5, 10, 15 or 30, otherwise **10** (this covers a stored 0, a negative number or a hand-edited value). `reminderTriggerTime(prayerTime, minutes, now): Long?` returns `prayerTime - normalizeReminderMinutes(minutes) * 60_000`, or `null` if the result is `<= now`. `scheduleReminderAlarm` reads `N = FlutterPrefs.getInt(context, "notification_reminder_minutes", 10)` and calls it. On `null` it **cancels** any existing reminder alarm for that prayer (otherwise a stale alarm survives a time change).

**2. Arm in `schedulePrayerAlarm` (D3).** After the adhan alarm is set and logged, call `scheduleReminderAlarm` for names other than Sunrise inside `try { ... } catch (e: Exception) { Log.e(TAG, "❌ [REMINDER] ...") }`. The adhan path returns before and does not depend on the result. `PrayerAlarmReceiver.kt` is an "edit carefully" file: the change is one guarded call plus the helper, and the adhan code path is not reordered.

**3. Fire-time guard.** In the `isReminder` branch, re-read the master `prayer_notifications_enabled`; if it is off, drop the alarm (belt and braces for a failed cancel). The lead time is not re-read here: the text uses the `reminder_minutes` the alarm was armed with. Write `reminder_kind=pre` and `reminder_minutes=N` (new native prefs beside the other `reminder_*` keys) only for alarms armed by step 2.

**4. Content.** Pre-prayer: title "Prayer reminder" / "تذكير بالصلاة", body per "Texts" below; no question, no buttons. `{prayer}` comes from `getDisplayPrayerName` (Jumu'ah on Fridays); `{N}` is the lead time the alarm was armed with (5/10/15/30), stored with `reminder_kind`, so the text is fixed and never counts down (a countdown would show values such as 7 min that have no unit rule). Cleared at prayer time as today (`:465-467`). **Friday (D11):** the Jumu'ah reminder (8001, `JumuahReminderReceiver`) and this reminder both appear; they are different notifications (8001 vs the foreground notification 9999) with different request codes, so there is no clash and no special case.

**5. Settings tile (Dart).** New provider in `preferences_provider.dart`, modeled on `JumuahReminderNotifier` (`:472-495`): `notification_reminder_minutes`, default 10, allowed 5/10/15/30; any other stored value reads as 10 (`normalizeReminderMinutes`, also in Dart). Tile in the Notifications card; tapping opens a picker of the four choices (pattern of `_showReminderMinsPicker`, `:375`). The tile watches the master switch value and is disabled (greyed, value kept, no tap) while it is off. Keys: see "Texts".
*   **On change, Android: reminders only, through a new native `rearmReminderAlarms`** (not `prayerEffects`). Why (code refs, 2026-11-18):
    *   The tile change would not even reach `prayerEffects`: the refresh is guarded by `if (fingerprint == _lastFingerprint) return;` (`prayer_times_provider.dart:302-303`) and the fingerprint covers method, madhab, iqama and the day lists, not the lead time. `prayerEffects` is a closure (`:316`), not a public method.
    *   Forcing it would redo far more than needed: widget save, foreground-service update, the 7-day native cache write, `scheduleDailyPrayerAlarms` for all five adhan alarms (`:396-397`) and `schedulePostPrayerCheck` for every prayer whose check is still ahead (`:409-421`), and on Windows `schedulePrayerTimers`.
    *   Re-arming an adhan alarm uses the same request code with `FLAG_UPDATE_CURRENT` (`PrayerAlarmReceiver.kt:262-267`), so it replaces rather than duplicates, and `AdhanPlayer` is separate from the alarm, so a playing adhan is not stopped. A post-check already armed keeps its trigger because `postChecksToSchedule` only re-sends checks whose time is still ahead (`prayer_refresh.dart:81-87`). So the existing path is probably safe, but "probably" is not verified and it does more than the tile needs, so the spec does not use it.
    *   `rearmReminderAlarms` touches only request codes 2101–2106. To work without today's times, `scheduleReminderAlarm` records every prayer's target time in a new native pref `reminder_target_<Prayer>` (Long, file `aura_prayer_times`, written on each call even when the reminder is skipped); `rearmReminderAlarms` re-arms each target that is still in the future with the current lead time, and does nothing when the master is off. It is also what master-on calls. Tile change, master-on: `rearmReminderAlarms`; master-off: `cancelReminderAlarms` (cancels 2101–2106, clears `reminder_active` and `reminder_*`, keeps the `reminder_target_*` values). Both new MethodChannel methods and the new prefs are added to `contracts/method-channels.md` and `contracts/prefs-keys.md` in the R1 code commit.
    *   Consequence: no adhan alarm, post-check or azkar alarm is read or written by a tile or switch change, so none can be cancelled or duplicated by it.
*   **On change, Windows: reminder timers only.** `schedulePrayerTimers` is not used on a tile or switch change: it calls `cancelAll()` (`desktop_prayer_scheduler.dart:42`) and skips prayers whose time has passed (`:51`), so it would drop the pending post-prayer check timer of a prayer whose adhan already played (the check is `iqama + 30 min`, `:90-99`; this is the known "reload cancels the post-check" behavior). Instead the scheduler keeps the reminder timers in their own list and gets `rescheduleReminders()`, which cancels and re-creates only those. Reading the lead time goes through `normalizeReminderMinutes` (a bad value becomes 10), the reminder is skipped when the master is off, and the per-prayer `notify_<prayer>` check is dropped from the reminder path (design step 8). Windows-only edits stay platform-guarded.

**6. Cancel and re-arm paths (D3b).**

| Path | Today (VERIFIED) | Reminder alarm |
|---|---|---|
| Method / madhab / location / language change | Dart `prayerEffects` re-arms every prayer at its next occurrence with the same request code, so the new alarm replaces the old one; no cancel | Re-armed inside `schedulePrayerAlarm`, replaces by request code; if the new reminder time is past it is cancelled (design step 1) |
| 00:05 native recalc | `NativePrayerCalculator.reschedule` (`:216`) re-arms | Same helper, so covered |
| Boot / app update | `PrayerRescheduleService` (`:133`) re-arms | Same helper, so covered |
| `cancelAllAlarms` (native, MethodChannel `cancelAllPrayerAlarms`) | Cancels 1001–1006 only (`:301-318`); **no Dart caller found** | Extend to cancel the reminder codes |
| Adhan switched off | **Nothing is cancelled** (existing issue, F66 and F70, not fixed here): the adhan alarm stays armed and only the sound is skipped at fire time (`AdhanPlayer.kt:162-164`, `:220`) | **Unchanged by design (D4):** the reminder keeps working; only the tile controls it |
| Logout (`profile_screen.dart:1038` → `AuthService.signOut`, `auth_service.dart:244`) | **Nothing is cancelled** (finding F70, not fixed here); local data stays (F47f, F59) | **Not handled here.** F70 owns the fix: logout cancels all alarm kinds in one place, including the reminder alarms 2101–2106. No sign-out flag. |
| Tile lead-time change (5/10/15/30) | n/a | New: `rearmReminderAlarms` (Android) / `rescheduleReminders()` (Windows) with the new N, reminders only (design step 5); the tile is disabled while the master is off |
| Master "Reminder Prayer" switch (`prayer_screen.dart:1262`) off / on | Writes the pref only; nothing native reads it | New: off cancels the reminder alarms (`cancelReminderAlarms`) and greys the tile, on re-arms (design step 8). This is the only on/off |
| Prayer time reached | The service clears reminder mode on its next tick | Cleared by the prayer alarm itself and the service is nudged (design step 9) |

**7. Request codes (D3c / D6), one table.** Grep result (2026-11-18, `android/app/src`, `lib`, `test`; Kotlin and Dart): every ID and request code found is listed. PendingIntent identity is component + request code, so only codes within the same receiver class can clash with each other; notification IDs share one namespace (contracts/notification-ids.md).

**4001–4006 is NOT free.** `notification_service.dart:1021` posts the daily task digest as notification **4001**, and `:669` gives task reminders `4000 + hash % 1000` (4000–4999, Dart and native via `scheduleNativeTaskReminder`). A request code on `PrayerAlarmReceiver` would not technically collide with those notification IDs (different namespaces and receivers), but it would sit inside a range the contract reserves for tasks and invite a wrong future edit. The spec therefore proposes **2101–2106** (`requestCode + 1100`): grep finds no 21xx value in Kotlin, Dart or tests, and it sits beside the 2001–2006 reminder family. Confirmed by the owner 2026-11-18.

| Request code / ID | Kind | Owner / class | Meaning | Source |
|---|---|---|---|---|
| 1–6 | Notification ID | Dart `NotificationService` | Flutter prayer notifications (no caller) | `notification_service.dart:74-79` |
| 1001–1006 | Request code + notification ID | `PrayerAlarmReceiver` | Adhan alarm and adhan notification | `PrayerAlarmReceiver.kt:48-53`, `:262`, cancel `:301-318` |
| 2000 | Notification ID | `PrayerRescheduleService` | Boot reschedule foreground notification | `PrayerRescheduleService.kt:30` |
| 2001–2006 | Request code (+ unused `REMINDER_*` IDs) | `PrayerAlarmReceiver` | After-adhan snooze (`scheduleDelayedReminder`, dead path F69). Before this spec the pre-prayer reminder also used 2001–2006 (`requestCode + 1000`) | `:56-61`, `:889-895` |
| **2101–2106 (new)** | Request code only | `PrayerAlarmReceiver` | **Pre-prayer reminder** (`requestCode + 1100`); posts no notification of its own | new |
| 3001–3006 | Request code | `PrayerAlarmReceiver` | Post-prayer check (`requestCode + 2000`) | `:347-372` |
| 3001–3006 | Request code | `AzkarAlarmReceiver` | Azkar after iqama (other class, same numbers) | `AzkarAlarmReceiver.kt:44-52` |
| 3999 | Request code / Dart ID | `SilentOffReceiver`, `ToggleSilentModeReceiver`; Dart | Silent-mode restore; task daily summary notification | `ToggleSilentModeReceiver.kt:35`, `PrayerAlarmReceiver.kt:737`, `notification_service.dart:805` |
| 4000–4999 (incl. 4001) | Notification ID (+ native request codes id, id+1, id+2 on their own receivers) | Dart, `NativeNotificationReceiver`, `TaskReminderReceiver` | Task reminders `4000 + hash % 1000`; daily task digest 4001 | `notification_service.dart:669`, `:1021` |
| 5000–5999 | Request code | `FocusModeReceiver` | Focus alarms (`5000 + abs(hash % 1000)`) | `FocusModeReceiver.kt:36-49` |
| 5001–5006 | Notification ID | Dart | Flutter-side prayer notifications | `notification_service.dart:431` |
| 5100–5119 | Notification ID | Dart / native | Wird reminders | `notification_service.dart:1105-1159` |
| 5996, 5998, 5999 | Notification ID | Focus Mode | Relaunch, service, end (dead) | `FocusModeService.kt`, `FocusModeReceiver.kt:38` |
| 6001–6006 | Notification ID | `PrayerAlarmReceiver` | Post-prayer check notifications | `:65-70` |
| 7001 | Request code + notification ID | `DailySummaryReceiver` | Daily prayer summary (also the legacy Dart Jumu'ah ID, F7) | `DailySummaryReceiver.kt:21-22` |
| 7005, 7010, 7015 … (`7000 + delayMinutes`) | Request code | `PrayerAlarmReceiver` | Dart snooze picker (dead path F69) | `main_wrapper_screen.dart:823` |
| 7100–8099 | Notification ID | Dart | Achievements (`7100 + hash % 1000`) | `notification_service.dart:1171` |
| 8001 | Request code + notification ID | `JumuahReminderReceiver` | Jumu'ah reminder | `JumuahReminderReceiver.kt:19-21` |
| 9000–9006 | Notification ID | `AzkarAlarmReceiver` | Post-prayer azkar | contracts/notification-ids.md |
| 9100 | Request code | `DailyRecalcReceiver` | 00:05 recalc | `DailyRecalcReceiver.kt:25` |
| 9101, 9102 | Request code | `PrayerForegroundService` to `ToggleSilentModeReceiver` | Stop / Keep Vibration | `PrayerForegroundService.kt:82-83` |
| 9999 | Notification ID; also test-adhan request code | `PrayerForegroundService`; `MainActivity` | Foreground service; test adhan | `PrayerForegroundService.kt:32`, `MainActivity.kt:460-466` |

Within `PrayerAlarmReceiver` the request codes are 1001–1006, 2001–2006, **2101–2106**, 3001–3006, 7005–7030 (Dart snooze steps) and 9999: all unique. Widget request codes (`TasksWidget` widgetId +1000/+2000/+5000, another class) are outside this table. Notification IDs are unchanged (the pre-prayer reminder posts none; it only sets the foreground notification's mode). In the same commit as the code, `contracts/notification-ids.md` is updated: row 2001–2006 becomes "After-adhan snooze request codes (dead, F69)", a new row 2101–2106 "Pre-prayer reminder request codes", and the request-code offset note gains `+1100`.

**8. Gates (D8).** Code check (2026-11-18, `lib/`, `android/`):
*   **`prayer_notifications_enabled` (master) IS written by a visible UI:** the Prayer screen's settings sheet (gear button `prayer_screen.dart:457` → `_showPrayerSettings` `:1074` → `PrayerSettingsPage`), switch "Reminder Prayer" / "تذكير الصلاة" with the hard-coded subtitle "Remind 10 minutes before prayer time" / "تنبيه قبل موعد الصلاة بـ 10 دقائق" (`:1251-1266`, writes at `:1264-1265`, default true `:1131`). **Windows path (D9 check, VERIFIED statically, not run on a device):** sidebar → Prayer (`_generateDesktopRoute` case `/prayer`, `main_wrapper_screen.dart:1398`, `PrayerScreen`) → the AppBar gear "Prayer Settings" (`prayer_screen.dart:455-458`, no platform guard around the AppBar actions; `isDesktop` appears only in the location header, `:563-590`) → `PrayerSettingsPage` (`:1074-1090`) → the switch (`:1251-1266`, no platform guard in the page). So Windows users DO have the on/off; no extra switch in Settings is needed. The same route is used on Android. Readers today: the dead Dart `schedulePrayerNotification` (`notification_service.dart:295`) and the Windows toast (`desktop_notification_service.dart:236-238`). **No Kotlin code reads it**, so on Android this switch changes nothing today.
*   **`notify_<prayer>` has no UI writer:** its only writer `togglePrayerNotification` (`notification_service.dart:1205`) has no caller; readers are `notification_service.dart:992` (dead) and the Windows toast (`desktop_notification_service.dart:239-241`). So the Windows per-prayer gate is always true today.

Rule (D9): **a reminder is armed and shown only if the master switch is on; the lead time comes from the tile.** The per-prayer keys are ignored on both platforms (the Windows per-prayer check at `:239-241` is removed from the reminder path). Implementation: Kotlin reads `FlutterPrefs.getBoolean(context, "prayer_notifications_enabled", true)` in `scheduleReminderAlarm` (skip and cancel when off) and again at fire time; Windows already reads the master. The master switch handler (`prayer_screen.dart:1262`) cancels the reminder alarms when turned off and re-arms when turned on (same Dart helper), and the tile is disabled while it is off. A user who turned all prayer notifications off therefore gets no new reminders. The switch is the only on/off; the tile is the lead time only.

**9. The reminder must end at the adhan (or at the prayer time when the adhan is off).** Today it clears only inside the foreground service's update loop (`PrayerForegroundService.kt:464-467`, `now >= reminderPrayerTime` → `reminder_active=false`), so it can linger until the next tick, or until the service next runs. Adhan mode already has priority in the service (`:471-478`), and the prayer alarm sets adhan mode even when the adhan is off (F66 (a), UNVERIFIED on a device), but the reminder must not depend on that. Fix:
*   In `PrayerAlarmReceiver.onReceive`, at the start of the real prayer-alarm branch (after the `isReminder`, post-check and action branches return, before the safety guards at `:456`), clear the reminder if it belongs to the prayer that just fired: `reminder_active=false` and remove `reminder_prayer_name(_ar)`, `reminder_prayer_time`, `reminder_kind`, `reminder_minutes`. This runs at the prayer time whether or not `adhan_enabled` is on, because the adhan alarm is armed independently of the toggle (F70, VERIFIED static) and the receiver runs the whole fire path (F66).
*   Then call `PrayerForegroundService.nudge()` (already used by the adhan-mode path in the same function) so the notification updates at once instead of after the 60 s sleep.
*   Keep the service's time-based clear as the backup (alarm delayed by doze, service restarted, boot).
*   Pure helper `shouldClearReminder(reminderPrayerName, firedPrayerName)` (name match, Zuhr/Dhuhr both handled) gets a unit test; the clear itself is two lines.
*   With the adhan on: adhan mode replaces the reminder at prayer time. With the adhan off: the reminder is cleared at prayer time and the notification returns to its normal or adhan-mode content. UNVERIFIED on a device until R2.

**10. Doze / Android 10.** The reminder uses `setExactAndAllowWhileIdle` (API 23+); on S+ a missing exact-alarm permission only logs a warning (as for the adhan alarm). No manifest change. Android 10 (nova 5T, API 29) takes the same path. UNVERIFIED for the reminder until R2. The adhan doze check S03 is a separate run.

## Goals

*   Reminders armed for Fajr, Zuhr, Asr, Maghrib, Isha (not Sunrise) at `N` minutes before, re-armed on every path above.
*   One feature, one on/off (the existing "Reminder Prayer" switch), one lead time (the tile, 5/10/15/30, default 10, key `notification_reminder_minutes`); both apply to Android and Windows and take effect immediately.
*   The reminder cannot delay or block the adhan.
*   The pre-prayer notification is information only.

## Non-Goals

*   Real buttons on the snooze notification (D5), or changing the post-prayer check (6001–6006).
*   Changing notification IDs or channels, or renaming any prefs key.
*   Removing the dead Dart `NotificationService` reminder code and the dead picker/handler code (cleanup, P6).
*   An independent "reminder only for some prayers" setting.

## Decisions still open

None. All owner decisions (D1–D11) are recorded above; the remaining UNKNOWNs are under "Open questions".

## Tests to write first

*   Kotlin unit (`./gradlew :app:testDebugUnitTest`): `reminderTriggerTime` for 5/10/15/30, 0, negative, and a past time (returns null); `FlutterPrefs.getInt` Long, Int, absent; the Arabic body builder for N = 5, 10, 15, 30 (exact strings from "Texts", Eastern numerals, unit chosen by N) and the fallback for any other N.
*   Dart: provider test (default 10, set/get, 0 / negative / unlisted value reads as 10); a widget test for the tile (disabled and value kept while the master is off; picker shows exactly 5/10/15/30) and for the switch subtitle (EN and AR strings for 5, 10, 15, 30, updates when the provider changes) if `settings_screen` / `PrayerSettingsPage` have a test harness (UNKNOWN); `DesktopPrayerScheduler` reads a bad value as 10, skips the reminder when the master is off, and uses the stored value; the Windows toast title and body equal the Kotlin strings for N = 5, 10, 15, 30 in both languages; `en.json` / `ar.json` key parity (existing check if any, UNKNOWN).
*   Re-arm scope: Kotlin test that `rearmReminderAlarms` and `cancelReminderAlarms` touch only request codes 2101–2106 (never 1001–1006, 3001–3006), that `reminder_target_*` is recorded even when the reminder is skipped, and that a past target is not re-armed; Dart test that a tile change calls the native re-arm and not `scheduleDailyPrayerAlarms`; Windows test that `rescheduleReminders()` leaves the adhan and post-check timers intact.
*   Master gate: Kotlin helper test for "armed only if the master is on" and for `normalizeReminderMinutes` (5, 10, 15, 30 kept; 0, -5, 7, 45 become 10); Dart test that the master switch off cancels and on re-arms (through the shared helper); Windows test that `notify_<prayer>` false does not suppress the reminder and master false does.
*   End of reminder: Kotlin unit test of `shouldClearReminder` (match, no match, Zuhr/Dhuhr alias).
*   Regression: existing Dart tests unchanged, `flutter analyze` count unchanged (408).

## Device check (after the fix)

S05 (Android 10, nova 5T), steps also recorded in `reference/device-checklist.md`:
1.  Tile **10** (default) → reminder 10 min before a prayer: foreground notification shows "Prayer reminder" / "{Prayer} in 10 minutes", no buttons, no `MainActivity` launch; the adhan still fires at prayer time. The Prayer-screen switch subtitle reads "10 minutes before each prayer".
2.  Change **10 → 5** → re-armed right away (`dumpsys alarm` shows the new trigger time with request codes 2101–2106; no duplicate); the switch subtitle changes to 5 at once.
3.  **Reboot** → still armed.
4.  **Reminder ends at the adhan:** leave the reminder on screen until the prayer time. With the adhan on, the "in N minutes" text is gone when the adhan starts (adhan mode shows). With the adhan toggle off, the text is gone at the prayer time (within a few seconds, not after a minute) and the notification returns to its normal content. `logcat` shows the clear at the alarm time.
5.  **Master switch (the only on/off):** Prayer screen settings, "Reminder Prayer" off → no reminder alarms (`dumpsys alarm` shows none with 2101–2106), no reminder, and the Settings tile is greyed with its value kept; on → re-armed and the tile is enabled. Per-prayer keys are not involved.
6.  Arabic: the same text and the switch subtitle in Arabic numerals with the unit chosen by N (٥ and ١٠ → دقائق, ١٥ and ٣٠ → دقيقة); the owner reviews the wording.
7.  **Friday:** the Jumu'ah reminder (8001) and the pre-prayer reminder both appear, no clash.
8.  **Re-arm scope:** change 10 → 5 while a post-prayer check is pending (after an adhan, before its +30 min): the check still fires at its time (`dumpsys alarm` request code 3001–3006 unchanged).
9.  Windows: same tile, 5/10 → toast at the set time with the same text, master off → no toast, tile greyed (observe only).

## Phases (proposal)

| Phase | Content | Level |
|---|---|---|
| R0 | This spec, EGM review | A |
| R1 | Tests first, then helper, arming with try/catch, flag + text, cancel paths, tile + provider, Windows guard, `.tr()` keys, contracts | C ("approve phase R1") |
| R2 | Device check S05 steps above | owner |

## Open questions

*   UNKNOWN: whether OEM battery policy on the nova 5T delays the reminder alarm (same question as S02/S03).
*   UNKNOWN: tap behavior of the foreground notification in reminder mode (not traced).
*   Related findings, outside this fix: F66 (adhan off only stops the sound), F69 (dead reminder-button and picker code), F70 (adhan alarms, post-checks and azkar are not cancelled on adhan-off or logout; `cancelAllAlarms` has no caller). F71 (the master "Reminder Prayer" switch does nothing on Android today; `notify_<prayer>` has no UI).
