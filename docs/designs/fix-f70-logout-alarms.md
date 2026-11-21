# F70 — Logout Cancels Every Aura Alarm, Scheduled Notification and Background Service (Android)

**Status: DRAFT, not approved. No code is changed by this document.** Written 2026-11-21 against `origin/main` (85457bc),
read-only inventory. Labels: VERIFIED = read in code at the cited place; UNVERIFIED = code read, never run on a device;
GUESS = reasoning without a code read; UNKNOWN = not found or not checked, needs an answer.

## Overview

Logging out today signs out of Firebase and Google and nothing else. Every alarm, scheduled notification and the
foreground service that the signed-out user armed keeps running, so on a shared phone the next person (a different
account, or a guest) still gets the previous user's task reminders, prayer alarms and notifications, and the previous
user's task titles are shown in them. Finding F70 (`reference/findings.md`) records the owner decision of 2026-11-18:
**logout must cancel all alarm kinds, in one place.**

This spec lists everything that stays armed (section "Inventory"), what logout clears today, and the design for one
cancel-everything step plus the re-arming rules for the next login or guest session.

Related findings: F59 (logout keeps local data, privacy, undecided), F66 (adhan-off keeps the whole fire path running),
F47f (logout goes to Login), F60 (guest migration), F69 (dead after-adhan reminder path).

## Owner decisions already taken (from F70, 2026-11-18)

- D0. Logout cancels all alarm kinds: adhan 1001-1006, pre-prayer reminder 2101-2106, post-checks 3001-3006, azkar,
  snooze, in **one place**. Adhan-off does NOT cancel (the reminder stays armed, D4 of the reminder spec).
- D0b. "No sign-out flag" was recorded in the same decision. **This conflicts with the re-arm paths found below** (see
  open decision D1): without any state that native code can read, the next app start, the 6-hourly worker or a reboot
  re-arms everything. D1 asks the owner to confirm or revise.

## What logout does today (VERIFIED)

- Profile → Log out → `_showLogoutDialog` → `authService.signOut()` (`profile_screen.dart:1083`) → `AuthService.signOut`
  (`auth_service.dart:244`): `_auth.signOut()` and `_googleSignIn.signOut()` only. Then, if `currentUser == null`,
  `pushNamedAndRemoveUntil('/login')` (`profile_screen.dart:1083` and the lines after it).
- `AuthStateNotifier.signOut` (`auth_provider.dart:212`) has no caller (VERIFIED by grep of `lib/`); it also only signs out.
- No cancel call runs: a grep of `lib/` for every cancel/stop function found none called from the logout path.
  The only cancel callers in `lib/` are the settings toggles (Jumu'ah `profile_screen.dart:1176`,
  `settings_screen.dart:240`; reminder switch `pre_prayer_reminder_service.dart:16`) and per-item task/wird cancels.
  Reflection and generated code were not searched.
- Local data stays (F59), prefs stay, the guest id is `'guest_user'` (`prayer_record.dart:196` `getCurrentUserId`).
- `PrayerAlarmReceiver.cancelAllAlarms` (`PrayerAlarmReceiver.kt:365`) exists and is reachable from Dart
  (`prayer_alarm_service.dart:280` → channel `cancelAllPrayerAlarms`, `MainActivity.kt:583`) but **nothing calls it**.
  It cancels the six adhan alarms and, since the reminder work, the reminder alarms (`:381` → `cancelReminderAlarms`
  `:195`). It does not touch post-checks, azkar, snooze, recalc, WorkManager, summary, Jumu'ah, tasks or the service.

## Inventory: what stays armed after logout

Every row: what, where it is armed, what re-arms it, existing cancel path. "Re-armed by" matters: a cancel that leaves
a re-armer running is undone (see D1).

### A. Prayer alarms (native, AlarmManager exact)

| # | Item | Armed at | Re-armed by | Cancel today | Label |
| --- | --- | --- | --- | --- | --- |
| A1 | Adhan alarms, request codes 1001-1006 | `PrayerAlarmReceiver.schedulePrayerAlarm` `:292` (alarm `:326`) | Dart `scheduleDailyPrayerAlarms` (`prayer_times_provider.dart:396`, `prayer_alarm_service.dart`), `NativePrayerCalculator.calculateAndSave` (calls `schedulePrayerAlarm`), the fire path itself | `cancelAllAlarms` `:365` (unused) | VERIFIED |
| A2 | Pre-prayer reminder alarms 2101-2106 | `scheduleReminderAlarm` `:139` (alarm `:184`), called from `schedulePrayerAlarm` | same as A1; `rearmReminderAlarms` `:210` | `cancelReminderAlarms` `:195`; also inside `cancelAllAlarms` `:381` | VERIFIED |
| A3 | Post-prayer check alarms, request code = adhan code + 2000 (3001-3006) | `schedulePostPrayerCheck` `:390` (alarm `:421`) | Dart `prayer_times_provider.dart:412`; the fire path and the post-check snooze path in `PrayerAlarmReceiver` | per prayer only: `cancelPostPrayerCheck` `:434` (also cancels its notification); **not in `cancelAllAlarms`** | VERIFIED |
| A4 | Azkar alarms, request codes 3001-3006 (notification 9001-9006) | `AzkarAlarmReceiver.schedule` `:58` (alarm `:87`), called at adhan fire `PrayerAlarmReceiver.kt:666` | the fire path | `AzkarAlarmReceiver.cancel` `:97` per prayer; **no caller anywhere** (no channel method, no Kotlin call) | VERIFIED |
| A5 | After-adhan snooze / delayed reminder 2001-2006 | `scheduleDelayedReminder` `:242` (alarm `:272`) | the "Remind Later" picker path | none found | UNKNOWN whether still reachable (F69 says dead path) |
| A6 | Daily recalc, exact 00:05, request code 9100 | `DailyRecalcReceiver.schedule` `:28` | itself (reschedules in `onReceive`), `PrayerBootReceiver.kt:68`, `PrayerForegroundService.kt:184` | **none** (no cancel function) | VERIFIED |
| A7 | WorkManager periodic recalc, 6 h, `aura_periodic_prayer_recalc` | `PrayerRecalcWorker.schedule` `:43` | **every app start** (`MainActivity.kt:239`, in `configureFlutterEngine`), boot (`PrayerBootReceiver.kt:69`) | **none** | VERIFIED |
| A8 | Daily prayer summary, id/request code 7001 | `DailySummaryReceiver.schedule` `:22` | itself, boot (`PrayerBootReceiver`), Dart on startup (`main_wrapper_screen.dart:532`), settings (`settings_screen.dart:537`, `preferences_provider.dart:675`) | `DailySummaryReceiver.cancel` `:60` ← Dart `cancelDailySummary` (`prayer_alarm_service.dart:462`, `MainActivity.kt:715`); called only when the tracking setting is turned off | VERIFIED |
| A9 | Jumu'ah reminder, id 8001, request code 8001 | `JumuahReminderReceiver.schedule` `:18` | itself (weekly), boot, the Jumu'ah toggle (`profile_screen.dart:1174`, `settings_screen.dart:238`); **not armed at app start** | `JumuahReminderReceiver.cancel` `:87` ← Dart `cancelJumuahReminder` (`notification_service.dart:1421`, `MainActivity.kt:723`), only from the toggle | VERIFIED |

Note on A3 and A4: the post-check and the azkar alarm both use request codes 3001-3006 but different receiver classes and
actions, so their PendingIntents are distinct objects (Android PendingIntent identity; UNVERIFIED on device).

### B. Foreground services

| # | Item | Armed at | Re-armed by | Stop today | Label |
| --- | --- | --- | --- | --- | --- |
| B1 | `PrayerForegroundService`, notification 9999, START_STICKY | `startService` `:61`; `startServiceIfAllowed` `:104` | its own restart alarm (`scheduleRestartIfNeeded` `:882`, alarm `:896/:900`), `DailyRecalcReceiver.onReceive`, `PrayerBootReceiver`, Dart `startForegroundService` (`background_service_manager.dart:45`) | `stopService` `:71` (sets `fg_user_stopped`) ← Dart `stopForegroundService` (`MainActivity.kt:776`), only from the Prayer-screen switch (`prayer_screen.dart` near `:1282`) | VERIFIED |
| B2 | `PrayerRescheduleService`, notification 2000 | `PrayerBootReceiver.reschedulePrayerAlarms`, also at `MY_PACKAGE_REPLACED` | boot / app update only; runs about 1.7 s then `stopSelf` | not needed (transient) | VERIFIED |
| B3 | `FocusModeService`, notification 5998 | `FocusModeService.start` | a focus session is user-interactive and locks the UI, so logout cannot happen during one | `FocusModeService.stop` | GUESS (never tried to reach Logout during Focus) |

B1 caveat (VERIFIED): `startServiceIfAllowed` passes `userStopped = false` (`:106`), so the recalc alarm (A6) and the boot
receiver restart the service even after a deliberate stop. A stop at logout therefore does not stay stopped unless the
re-armers are also stopped or the auto-start check reads a stored state.

### C. Scheduled notifications created from the signed-in user's data (Dart-scheduled)

| # | Item | Armed at | Re-armed by | Cancel today | Label |
| --- | --- | --- | --- | --- | --- |
| C1 | Task reminders, ids `4000 + hash % 1000`, native `TaskReminderReceiver` (plugin fallback) | `TaskReminderReceiver.schedule` `:51`; Dart `task_service.dart` `_scheduleReminder` → `scheduleNativeTaskReminder` | `rescheduleAllTaskReminders` (`task_service.dart:142`; app start and resume, `main_wrapper_screen.dart:120,222`; throttled to once per 6 h by the pref `task_reminders_rearmed_at` `:149`) | per task: `cancel` `:124` ← `cancelNativeTaskReminder` (`MainActivity.kt:626`); **no cancel-all, no registry of ids** | VERIFIED (no registry), id range from `contracts/notification-ids.md` |
| C2 | Task "due now" alarms (TC1), request code id+4, action `TASK_DUE_NOW` | `TaskReminderReceiver.scheduleDueNow` `:89` | the task reminder fire path | `cancelDueNow` `:114`, per id | VERIFIED |
| C3 | Task reminder snooze (30 min), the same id | `TaskReminderReceiver` snooze action | the user's tap | by the id cancel | VERIFIED |
| C4 | Daily task summary, id 3999 | `NotificationService.scheduleDailyTaskSummary` (`notification_service.dart`, native `scheduleNativeNotification`, repeats daily) | `task_service.dart` after task changes | `cancelDailyTaskSummary` `:911` (no logout caller) | VERIFIED |
| C5 | Daily task digest, id 4001 (plugin `zonedSchedule`, one-shot) | `NotificationService.scheduleDailyTaskDigest` `:1031` | `prayer_times_provider.dart:455`, runs for the guest too (`getCurrentUserId` returns `'guest_user'`, never empty) | `_notifications.cancel(4001)` inside the schedule function only | VERIFIED |
| C6 | Wird reminders, 5100-5119 | `NotificationService.scheduleWirdReminders` `:1096`; `WirdService.scheduleReminders` | wird settings | `cancelWirdReminders` `:1176`, `WirdService.cancelAllReminders` | VERIFIED |
| C7 | "Remind me again" 5 min before, a native notification with the +5000 offset | `NativeNotificationReceiver.kt` (reschedule in its fire path) | its fire path | `NativeNotificationReceiver.cancel` `:97` per id | UNVERIFIED which ids exist at a given time |
| C8 | Plugin-scheduled store (`flutter_local_notifications` `zonedSchedule`) | many (`notification_service.dart`) | the plugin's own boot receiver re-arms the stored list after a reboot (plugin behavior, not in the app manifest) | `cancelAllNotifications` `:935` → `_notifications.cancelAll()` (no caller) | UNKNOWN whether the plugin boot receiver is merged into the final manifest |
| C9 | Focus Mode alarms per task (`FocusModeReceiver`) | `scheduleFocusAlarm` `:40` | `NotificationService.scheduleFocusMode` | `cancelFocusAlarm` `:86` per task id | VERIFIED |

### D. Things that must NOT be cancelled by logout

- Silent-mode restore alarms: `PrayerAlarmReceiver.scheduleSilentModeRestore` `:828`, `ToggleSilentModeReceiver.scheduleSilentOff`
  `:261`. Cancelling one while the phone is in the vibrate window leaves the ringer on vibrate. GUESS (reasoned, not tested).
  The cancel step must skip them, or restore the ringer first (see Design).
- Notification channels (never deleted by this spec; CLAUDE.md: no ID/channel changes).

### E. Out of scope here, listed so nothing is forgotten

- Widget refresh alarms: `PrayerWidgets.kt:489` (60 s `setRepeating`), `TasksWidget.kt:235,403` (30 min),
  `DailyContentWidget.kt:140`. The Tasks widget shows task text of the signed-out user: that is the data question F59,
  not an alarm question. Decision needed (open question Q3).
- In-process Dart timers (`post_check_remind_timers.dart:26`) die with the process.
- Windows desktop: `DesktopPrayerScheduler` (`desktop_prayer_scheduler.dart:51`) and `DesktopNotificationService` timers.
  Whether logout on Windows should cancel them: UNKNOWN, Android first (Q4).

## The re-arm problem (why a plain cancel is not enough)

After logout the app is on the Login screen but native code keeps running. Verified re-arm paths that fire without any
login: (1) the 00:05 recalc A6 and the 6-hourly worker A7 both call `NativePrayerCalculator.calculateAndSave`, which
reschedules the adhan, reminder and post-check alarms whenever cached coordinates exist (they do: prefs stay);
(2) `MainActivity.configureFlutterEngine` enqueues the worker on **every app start** (`MainActivity.kt:239`), including a
cold start that only shows Login; (3) `PrayerBootReceiver` re-arms prayer alarms, the summary, Jumu'ah, the recalc and the
service at every reboot and every app update (`MY_PACKAGE_REPLACED`); (4) the foreground service restarts itself.
So **a cancel at logout alone would be undone within hours, or at the next reboot/update**. Anything that can still
re-arm must either be cancelled in the same step or be gated by state native code can read.

## Design (proposal)

### Behavior

On Logout, after the confirm dialog and **before** `signOut()` (so a failed sign-out still leaves the previous state
consistent, and a signed-out user cannot be left half-armed), run one function `cancelEverythingOnLogout`:

1. Cancel the prayer alarms A1-A5 (adhan, reminder, post-checks, azkar, snooze) and their posted notifications.
2. Stop the re-armers: A6 recalc alarm, A7 worker; stop B1 (the service) and its restart alarm.
3. Cancel A8 (prayer summary) and A9 (Jumu'ah).
4. Cancel the user-data notifications C1-C6 and C9, and clear the plugin store (C8). For C1: loop the known id range
   4000-4999 with a cancel that does not create a PendingIntent (`PendingIntent.getBroadcast(..., FLAG_NO_CREATE)`, cancel only if
   it exists; the existing per-id cancels use `FLAG_UPDATE_CURRENT`, which creates one), plus the due-now and snooze variants;
   5100-5119 for the wird; 3999, 4001. The id ranges are in `contracts/notification-ids.md`, so no new registry is needed.
5. Skip D (silent-mode restore). If the vibrate window is active, restore the ringer immediately (reuse the existing
   restore path) instead of cancelling its alarm.
6. Remove any Aura notification still showing (reminder, task, summary, Jumu'ah, post-check, azkar cards, foreground card).
7. Clear the throttle pref `task_reminders_rearmed_at`, so a login within 6 h still re-arms the new user's task reminders.

### Where the code lives (one place)

- Dart: one function (service) called from `_showLogoutDialog`; it calls the existing methods that fit and a native
  method for the rest.
- Native: options. **Option 1 (recommended):** one new method on `prayer_alarms`, `cancelAllAppAlarms`, that does steps
  1-3, 5 and 6 natively in one place (a new `AlarmCleanup.kt`), plus Dart doing C4-C8 with the existing notification
  methods. A new channel method is a contract change: `contracts/method-channels.md` updated in the same commit, needs
  the owner's approval. **Option 2:** no new native method; Dart composes `cancelAllPrayerAlarms`, `cancelPostPrayerCheck`
  x6, `cancelDailySummary`, `cancelJumuahReminder`, `stopForegroundService`, `cancelNativeTaskReminder` in a 1000-iteration
  loop and so on. This needs three new native cancels anyway (azkar A4, the recalc alarm A6, the worker A7), so it is a
  contract change too, with more channel round trips.

### Signed-out state (open decision D1)

To keep the re-armers from undoing the cancel, native code needs something to read. Proposal: one new pref
`alarms_suspended` (Boolean, in `aura_prayer_times`, written by the cancel step, cleared when the user enters the app
shell again as a signed-in user or as a guest). It gates: `NativePrayerCalculator.calculateAndSave` scheduling,
`PrayerBootReceiver`'s re-arm block, `PrayerRecalcWorker`, `DailyRecalcReceiver`, `startServiceIfAllowed`. This reverses the
"No sign-out flag" line of the 2026-11-18 decision, so it needs the owner's explicit answer. Without a flag
(D1 = no), the only way to keep the cancel is to also stop A6/A7/B1 and the boot block from re-arming, and none of them can
tell "signed out" from "signed in" (UNVERIFIED that nothing else can), so the cancel would last only until the next app
start or reboot. A new prefs key is a contract: `contracts/prefs-keys.md`, Dart and Kotlin in one commit.

## Guest mode

- A guest is a signed-out session with local data (`guest_user`, F46a; "Continue as guest" on Login,
  `login_screen.dart:223`). Prayer times depend on the location, not on an account.
- Decision D2 (owner): after logout, when the user chooses **Continue as guest**, the guest session re-arms everything
  the guest can use (prayer alarms, reminder, post-checks, azkar, summary, Jumu'ah, the guest's local task reminders,
  the digest, the service) exactly as a first guest start does today. Logout then means "suspend until the next session
  begins", not "never again". Proposal: yes.
- A returning guest at cold start goes straight to Home (`login_screen.dart:227`, F46a): that entry clears
  `alarms_suspended` and arms, same as above.
- Logging out while in guest mode: there is no Logout button for a guest (UNVERIFIED: only the signed-in Profile view was
  read). If a guest "exits guest mode", the same function applies.

## Re-login and re-arming (VERIFIED where marked)

Entering the shell (login, guest, or app start with a session) already re-arms most things; the gaps to close:

| Item | Re-armed on shell start today | Gap |
| --- | --- | --- |
| A1-A3 adhan, reminder, post-checks | yes, `prayerEffects` in `prayer_times_provider.dart:396,412` (VERIFIED) | `ref.invalidate(prayerTimesProvider)` must run after login so it re-runs (UNVERIFIED that the provider rebuilds on login) |
| A4 azkar | armed at the next adhan fire | none |
| A6 recalc, A7 worker | worker on every app start; recalc at boot and when the service starts | recalc is not re-armed by login unless the service starts (UNVERIFIED how the app starts the service at launch) |
| A8 prayer summary | yes, `main_wrapper_screen.dart:532` | none |
| A9 Jumu'ah | **not at app start** (only the toggle and boot) | must be armed at login/guest entry |
| B1 service | `BackgroundServiceManager.startForegroundService` (called from `prayer_screen.dart` and elsewhere UNKNOWN) | confirm it starts at launch when `background_notification_enabled` is true |
| C1 tasks | `rescheduleAllTaskReminders` at shell start (3 s delay) | the 6 h throttle (cleared at logout, step 7) |
| C4-C6 | on the next relevant change or setting | must re-arm at login (UNKNOWN which of them re-arm at start) |

## Goals

- G1. After logout confirms, no Aura alarm, scheduled notification or Aura notification of the signed-out user remains
  (inventory A-C), and the foreground service is stopped.
- G2. It stays that way across the next app start, the 6-hourly worker, 00:05, a reboot and an app update, until a user
  or guest session begins (needs D1).
- G3. The next session (login or guest) arms everything it needs again with no manual step.
- G4. One cancel function, one place; no scattered cancels.
- G5. No notification ID, channel, request code or Firestore path changes (CLAUDE.md). Any new channel method or pref key
  goes through the contracts in the same commit.
- G6. The silent-mode restore still works (the ringer is never left on vibrate by logout).

## Non-goals

- Clearing local data (F59) and the widget data. Adhan-off behavior (F66). Windows (Q4). Changing channel importance or
  any notification look.

## Critical user journeys

1. **Shared phone.** A logs out, hands the phone over. No Aura notification of A arrives (tasks, prayer, summary, Jumu'ah);
   B logs in; B's prayer and task alarms arm; A's task reminders never fire for B.
2. **Logout, then guest.** A logs out and taps Continue as guest: prayer alarms and the service come back for the guest,
   A's task reminders do not (the guest sees only guest tasks).
3. **Logout, then nothing.** A logs out and does not open the app for a day, then reboots: no alarm fires, no service runs
   (needs D1 = flag); first app open arms again only after a login or guest choice.
4. **During the vibrate window.** A logs out while the adhan vibrate window is running: the ringer returns to normal at
   the right time (or at once), never stuck on vibrate.
5. **Failed sign-out.** The network or Google sign-out throws (`profile_screen.dart` catches and keeps the user on
   Profile if `currentUser != null`): the cancel step must not leave the signed-in user without alarms. Proposal: cancel
   only after a successful sign-out, or re-arm if `currentUser != null` (decision D3).

## Decisions and questions for the owner

- **D1.** A sign-out flag (`alarms_suspended`) so the re-armers stay quiet. Recommended: yes. Confirm that this replaces
  "no sign-out flag" of 2026-11-18, or choose the weaker "stop A6/A7/B1 only, accept re-arm at boot/update".
- **D2.** Guest after logout re-arms (proposal: yes).
- **D3.** Order: cancel before `signOut()` (cleaner privacy, needs a re-arm if sign-out fails) or after a successful
  sign-out only (simpler). Proposal: after a successful sign-out; cancel failure is logged, never blocks the sign-out.
- **Q1.** Native method `cancelAllAppAlarms` (Option 1, recommended) or compose existing methods (Option 2).
- **Q2.** The task reminders of other users on the same phone: also cancel at **account switch** without logout (login
  as B while A's alarms exist)? Proposal: the same function runs at sign-in when the uid changes (UNVERIFIED how the app
  detects "different user than last time").
- **Q3.** The Tasks widget keeps showing A's task titles after logout (F59). Include a widget refresh in this phase?
- **Q4.** Windows desktop logout: same behavior, or out of scope.
- **Q5.** Should `startServiceIfAllowed` honor `fg_user_stopped` (`:106` passes false)? A small separate fix; needed here
  only if D1 = no.

## Tests to write first

- Kotlin JVM: the cancel list is complete: every request code range in the inventory is covered (a table test over the
  ranges, no device); the cancel never touches the silent-restore request code 3999 (`SilentOffReceiver`); the ids and channels
  are unchanged (guard test like `AzkarCardTest`).
- Kotlin JVM: with `alarms_suspended = true`, `calculateAndSave` returns before any `schedule*` call, the boot block
  skips the re-arm, the worker and recalc do nothing (needs the gate to be a pure function: `shouldArm(prefs)`).
- Dart: the logout flow calls the cleanup once, after a successful sign-out, and navigates to Login; a failed sign-out
  does not clear (D3); the function clears `task_reminders_rearmed_at`.
- Dart: entering the shell as a guest or as a signed-in user clears the flag and calls the arming path.

## Device check (after the fix; phone via adb, owner approval as before)

1. `adb shell dumpsys alarm | grep com.aura.hala` before and after Logout: the Aura alarm entries are gone (expected:
   none of 1001-1006, 2101-2106, 3001-3006, 7001, 8001, 9100, task ids), and `dumpsys activity services` shows no
   `PrayerForegroundService`. Capture to a file, short report.
2. Reboot the phone while logged out: still no Aura alarm after 2 minutes.
3. Cold-start the app on Login: still no alarm; Continue as guest: alarms and the service return; Log in: same.
4. Vibrate-window case (CUJ 4).
5. Owner checks the Arabic and English look is untouched (there is no UI change, only the behavior).

## Phases (proposal, each needs its own approval)

- P1 (A, docs): this spec approved, decisions D1-D3 and Q1-Q5 answered.
- P2 (C, native): `AlarmCleanup.kt` + the channel method + the gate (`alarms_suspended`) + Kotlin tests; contracts updated.
- P3 (C, Dart): the logout function, the guest/login entry points that clear the gate and re-arm, Jumu'ah/digest/wird re-arm
  gaps, Dart tests.
- P4 (owner): the device check above.
