# Fix — Vibration Buttons Inside the Foreground-Service Notification

*   **Author:** Alaa Eldin Tarek
*   **Status:** P1 implemented 2026-11-14 (device checks pending)
*   **Date:** 2026-11-14
*   **Branch:** `fix/silent-mode-buttons-in-fgs` (off `main` at `827fa5e`)
*   **Supersedes:** F68 (`docs/designs/fix-silent-mode-notification.md`), the part that adds a separate notification 8100.
*   **Approval level:** C (touches `android/`, notification IDs and a channel). Docs (this file) are level A.

---

## Overview

When the adhan fires and the user has "vibrate during prayer" on, Aura switches the phone to vibrate for a window (`silent_mode_duration`, default 20 minutes). F68 added a second notification, 8100 on channel `silent_mode_control`, with two buttons: "Stop Vibration" and "Keep Vibration". While the adhan data is showing, the user now sees two Aura notifications.

This spec moves the two buttons into the existing foreground-service notification (`PrayerForegroundService`, ID 9999), in one compact row next to the data, and removes notification 8100 and everything that belongs to it.

## The Problem

*   Two notifications for one event: the foreground-service notification (adhan data) and notification 8100 (buttons). This is confusing.
*   Notification 8100 is a standard notification. Standard action buttons normally show only when a notification is expanded (UNVERIFIED on EMUI 12), so they are easy to miss, and they are not on the lock screen collapsed view (UNVERIFIED).

## Decisions (made by the product owner, 2026-11-14)

1.  **No service, no buttons.** If `background_notification_enabled` is off or the foreground service is not running, there are no buttons. Today 8100 works without the service. The full-screen adhan screen (`AdhanFullScreenActivity`) keeps its own buttons. This loss is accepted.
2.  **Every service mode.** The buttons show in every foreground-service mode (adhan, reminder, normal) for as long as the vibration window is active.
3.  **Design A.** The buttons live in a compact custom collapsed layout. Design B (a standard notification with two standard actions) is rejected, see Alternatives.
4.  **Labels stay** "Stop Vibration" / "Keep Vibration" (Arabic "إيقاف الاهتزاز" / "إبقاء الاهتزاز").
5.  **Lock-screen behavior is checked on the device.** No lock-screen claim in this spec is verified yet.
6.  **Removal approved:** notification 8100, channel `silent_mode_control`, request codes 8100/8101 and their contracts rows, plus one `deleteNotificationChannel("silent_mode_control")` call to clean up the orphan channel on phones that ran an F68 build.

## Goals

*   One notification only. The two buttons are inside the foreground-service notification, in one compact row with the data.
*   The buttons need no expansion. They are visible in the collapsed notification.
*   Buttons are visible and tappable on the lock screen without unlocking (checked on the device).
*   The buttons behave as 8100 does today: they appear when the vibration window starts and disappear on every path that ends it (Stop, Keep, auto-restore, boot). The receiver actions are unchanged (`ToggleSilentModeReceiver`, `DISMISS_SILENT` / `EXTEND_SILENT`).
*   When the buttons disappear, the data stays.
*   Remove notification 8100, the `silent_mode_control` channel, request codes 8100/8101 and their contracts rows; delete the orphan channel once.

## Non-Goals

*   Changing what Stop and Keep do (`ToggleSilentModeReceiver`) or the F51e state (Keep leaves `is_silent_active = true`).
*   Changing `AdhanFullScreenActivity` and its buttons.
*   Changing the data shown in any service mode, or the layouts used when no buttons are visible.
*   Any change to `lib/` (Dart). Verified by `git diff --stat -- lib/` being empty.
*   Changing notification IDs other than removing 8100.
*   Starting the foreground service just to show the buttons (Decision 1).

## Current Behavior (VERIFIED from code at `827fa5e`)

| Event | Where | Effect |
|---|---|---|
| Start | `PrayerAlarmReceiver.kt:497` reads `silent_mode_enabled` (default true); `:516` calls `enableSilentModeForPrayer` | Ringer set to vibrate; `is_silent_active = true`; `silent_end_time = now + silent_mode_duration`; restore alarm (request code 3999) scheduled; 8100 posted at `:730`. |
| Stop | `ToggleSilentModeReceiver.dismissSilentMode` (`:126`) | Ringer restored; `is_silent_active = false`; 8100 cancelled. |
| Keep | `extendSilentMode` (`:196`) | Alarm cancelled; `silent_end_time = 0`; `is_silent_active` stays true; 8100 cancelled. |
| Auto-restore | `SilentOffReceiver` (`:324`) | Ringer restored; `is_silent_active = false`; `adhan_active = false`; 8100 cancelled. |
| Boot | `PrayerBootReceiver.kt:42` | Ringer restored; flags cleared. Android clears posted notifications at boot (F68 spec; UNVERIFIED on the device). |

Related facts:

*   The adhan data window is separate and fixed: `adhan_end_time = now + 20 min` (`PrayerAlarmReceiver.kt:556`). The vibration window is `silent_mode_duration`. They can differ.
*   The foreground service rebuilds its notification from prefs every 1 s in adhan mode and every 60 s otherwise (`PrayerForegroundService.kt:33`, `:396`). `PrayerForegroundService.nudge()` forces an immediate rebuild and does nothing when the service instance does not exist.
*   The foreground-service notification: `PRIORITY_MAX`, `VISIBILITY_PUBLIC`, ongoing, channel `prayer_foreground_channel_v4` (HIGH, lock-screen PUBLIC), custom view through `setCustomContentView` and `setCustomBigContentView` (the same `RemoteViews`, no `DecoratedCustomViewStyle`). It has no actions today.
*   Layouts: four variants (`notification_large`, `_dark`, `_rtl`, `_dark_rtl`), about 80 dp tall (author's estimate from the XML, UNVERIFIED on the device).
*   Device: YAL-L21 (nova 5T), Android 10 (SDK 29), EMUI 12.0. `Notification.Action.Builder.setAuthenticationRequired` needs SDK 31 and does not exist here.

## Technical Plan

### 1. One visibility rule, evaluated on every rebuild

`PrayerForegroundService.createNotification()` reads the silent state each time it builds:

```
buttonsVisible = aura_silent_mode.is_silent_active
              && aura_silent_mode.silent_end_time > 0
              && now < aura_silent_mode.silent_end_time
```

There is no extra stored state. The rule applies in every service mode (adhan, reminder, normal).

*   **Stop** sets `is_silent_active = false`: the buttons go.
*   **Keep** sets `silent_end_time = 0`: the buttons go.
*   **Auto-restore** sets `is_silent_active = false`: the buttons go. If the alarm is late, `now >= silent_end_time` already hides them.
*   **Boot** clears both flags before the service restarts (30 s delay): no buttons.
*   The data (prayer name, iqama countdown or next-prayer countdown) is built exactly as today. Only the layout choice and the click handlers depend on `buttonsVisible`.

### 2. Layout: a compact row with the data

When `buttonsVisible`, the service uses a new compact layout in place of the current four. Otherwise it uses the current layouts, unchanged.

*   Four new layout files, the same matrix as today (light/dark by LTR/RTL): `notification_actions.xml`, `notification_actions_dark.xml`, `notification_actions_rtl.xml`, `notification_actions_dark_rtl.xml`.
*   One row: the logo (about 36 dp), then a column with the prayer name and the time text (iqama / countdown), then the two buttons "Stop Vibration" and "Keep Vibration". The header row and the divider are dropped while the buttons show. The data ids (`notification_title`, `notification_time`, `notification_logo`) are reused so the existing text-setting code is shared.
*   Buttons are clickable `TextView`s with a small rounded background drawable (one for light, one for dark), single line, 12 sp, ellipsized. `RemoteViews` cannot shrink text to fit.
*   **As built (P1):** the two buttons are stacked one above the other (28 dp each) at the end of the row, not side by side. Side by side needed about 180 dp of the 360 dp width, which left too little for the data (my estimate, not measured). The row is about 72 dp tall. If the device check shows clipping, this layout is what to adjust.
*   Same `RemoteViews` for `setCustomContentView` and `setCustomBigContentView`, as today, so the collapsed and expanded states show the same row.
*   Height target: no taller than the current layout (about 80 dp). The stock Android collapsed limit is about 64 dp (UNVERIFIED on EMUI 12); the current layout already exceeds it, and the compact row is shorter.
*   **Fallback if one row does not fit at 360 dp with the default font:** two lines inside the same notification (data on top, buttons below), still without expansion. Decided at the first device check, not now.

### 3. Click handling

*   `RemoteViews.setOnClickPendingIntent` on each button, with explicit `PendingIntent.getBroadcast` to `ToggleSilentModeReceiver` and `FLAG_IMMUTABLE | FLAG_UPDATE_CURRENT`, as 8100 does today.
*   Actions: `com.aura.hala.DISMISS_SILENT` and `com.aura.hala.EXTEND_SILENT`, both with `EXTRA_PRAYER_NAME` and `EXTRA_PRAYER_NAME_AR` (the receiver reads them, and defaults to "Prayer" without them). The prayer name comes from the adhan prefs (`adhan_prayer_name`, `adhan_prayer_name_ar`) when present; otherwise the extras are omitted and the receiver uses its default (it only uses them for logs and toasts).
*   Two new request codes, `9101` and `9102` (proposed; must be re-checked by grep against `contracts/notification-ids.md` and the Kotlin sources at implementation, because 9100 is daily recalc and 9999 is the foreground-service ID).
*   Lock screen: broadcast PendingIntents are the only mechanism available on SDK 29. Whether the system lets them run without unlocking on EMUI 12 is UNVERIFIED and is checked on the device (Verification Plan).

### 4. Starting and stopping the buttons

*   **Start:** no new call is needed. `onReceive` runs `enableSilentModeForPrayer` (`:516`) and then, in the same flow, writes the adhan state and calls `PrayerForegroundService.nudge()` (`:570`). Both are inside `if (prayerName != "Sunrise")`, and Sunrise never starts silent mode, so the existing nudge always comes after the silent prefs are written. P1 re-checks that no early return sits between them.
*   **Stop, Keep, auto-restore:** each receiver calls `PrayerForegroundService.nudge()` after changing state, in place of `cancelSilentModeNotification`. Without it, outside adhan mode the buttons would stay up to 60 s.
*   **No service:** `nudge()` is a no-op and no buttons exist (Decision 1).
*   **Same notification ID** (9999): each rebuild replaces the previous one; `setOnlyAlertOnce(true)` is already set, so showing or removing the buttons does not re-alert.

### 5. What is removed (F68 code)

*   `PrayerAlarmReceiver.postSilentModeNotification` and its call (`:729-779`), and imports that become unused.
*   Notification 8100 and PendingIntent request codes 8100/8101.
*   `ToggleSilentModeReceiver.cancelSilentModeNotification` and its call sites in `dismissSilentMode`, `extendSilentMode` and `SilentOffReceiver`.
*   The `silent_mode_control` channel creation in `MainActivity.kt` (`:157-171`).
*   Contracts rows (see Contracts below).

### 6. Orphan channel cleanup

*   One `NotificationManager.deleteNotificationChannel("silent_mode_control")` in `MainActivity.createNotificationChannel()` (inside the existing SDK >= O block), wrapped in `try/catch`. It is a no-op when the channel does not exist.
*   Without it, phones that ran an F68 build keep an unused "Silent Mode Control" channel in the system notification settings.
*   The call stays for at least one release so skipped versions are cleaned up too; removing it is a later cleanup.

## Teardown Coverage

| # | Path | Location | Change |
|---|---|---|---|
| a | Stop | `ToggleSilentModeReceiver.dismissSilentMode` | `nudge()` instead of `cancelSilentModeNotification` |
| b | Keep | `extendSilentMode` | `nudge()` instead of `cancelSilentModeNotification` |
| c | Auto-restore | `SilentOffReceiver.onReceive` | `nudge()` instead of `cancelSilentModeNotification` |
| d | Boot | `PrayerBootReceiver` | None. Flags are cleared before the service restarts. |
| e | Late alarm | `createNotification()` | None. `now < silent_end_time` hides the buttons. |
| f | Legacy `SilentModeScheduler` | `SilentModeAutomation.kt` | None. Dead code (F68 spec, Path f). |

## Critical User Journeys

1.  **Stop from the collapsed notification.** Vibration window active. The user pulls the shade down. The foreground-service notification shows the data and the two buttons, no expansion. They tap "Stop Vibration". The ringer is restored and the buttons vanish within about 1 s. The data stays.
2.  **Keep.** Same start. They tap "Keep Vibration". Vibrate stays on and no auto-restore happens. The buttons vanish. The data stays.
3.  **Auto-restore.** No action. When the window ends, the ringer is restored and the buttons vanish. The data stays for as long as its own mode lasts.
4.  **Lock screen.** The phone is locked. The buttons are visible on the lock screen. A tap runs the action without unlocking (UNVERIFIED, checked on the device).
5.  **Reboot during the window.** After boot the ringer is restored, `is_silent_active = false`, and the rebuilt notification has no buttons.
6.  **Vibration window longer than adhan mode.** The service leaves adhan mode at 20 minutes and shows the normal countdown with the buttons until the vibration window ends (Decision 2).
7.  **Vibration window shorter than adhan mode.** The buttons go when the window ends; the adhan data stays until `adhan_end_time`.
8.  **Background notification off.** No foreground-service notification, so no buttons (Decision 1). The adhan screen buttons still work.

## Alternatives Considered

### Design B: standard notification with two standard actions

Data in the title and text, two `addAction` buttons, no custom view.

*   **Rejected.** Standard actions normally show only when the notification is expanded (UNVERIFIED on EMUI 12), which fails "no expansion". It also drops the custom look (logo, large name, colored time) while the buttons show, and F68 already records that `addAction` buttons are not rendered on this custom layout. `setAuthenticationRequired(false)` is not available on SDK 29, so it would not improve lock-screen taps on this phone.

### `DecoratedCustomViewStyle` with standard actions

Rejected in F68 (changes the notification's visual design). Standard actions would still be expanded-only (UNVERIFIED). Not reconsidered here.

## Known Issues (outside the scope of this change)

*   **Phone clock moved backwards.** If the phone clock is moved backwards while `adhan_active` is set, the adhan view and the Stop/Keep Vibration buttons stay visible until the real clock passes the stored `adhan_end_time` / `silent_end_time`. Cause: both are stored as absolute times and nothing checks for `now < start`. This was already the case before `d335140`. Possible future fix: treat the state as stale when `now` is earlier than its start time, or when the end time is more than the maximum window ahead. It needs its own spec because it changes `android/` behavior.

## Risks (all UNVERIFIED until run on the device)

*   EMUI 12 may replace or hide custom views on the lock screen, or require unlocking for `RemoteViews` taps.
*   The collapsed custom view may be clipped (stock Android limit about 64 dp).
*   Arabic labels are longer; large system fonts can clip button text (`RemoteViews` cannot auto-fit).
*   Battery management may stop the foreground service; then no buttons (accepted, Decision 1).
*   Rebuilding every 60 s outside adhan mode: a tap on a button that is about to disappear. The receiver ignores `DISMISS_SILENT` when `is_silent_active` is false, as today.

## Files That Would Change (phase P1)

| File | Change |
|---|---|
| `android/.../PrayerForegroundService.kt` | Visibility rule, compact layout selection, click `PendingIntent`s, request-code constants |
| `android/app/src/main/res/layout/` | 4 new `notification_actions*.xml` layouts |
| `android/app/src/main/res/drawable/` | 1-2 small button background drawables |
| `android/.../PrayerAlarmReceiver.kt` | Remove `postSilentModeNotification` and its call (no new nudge: the existing one at `:570` covers the start) |
| `android/.../ToggleSilentModeReceiver.kt` | Remove `cancelSilentModeNotification` and its call sites; `nudge()` after Stop, Keep and auto-restore |
| `android/.../MainActivity.kt` | Remove `silent_mode_control` channel creation; add `deleteNotificationChannel` |
| `android/.../README.md` | Update the `MainActivity`, `ToggleSilentModeReceiver` and layout entries |
| `.project-docs/contracts/notification-ids.md` | Remove the 8100 row, the F68 request-code note and the `silent_mode_control` channel row; record request codes 9101/9102 and the removal |
| `docs/designs/fix-silent-mode-notification.md` | "Superseded" note (done with this spec) |

Contracts and Kotlin change in the same commit (CLAUDE.md native-keys rule). No change under `lib/`.

## Tests

There is no Kotlin unit-test setup in the repo that I have seen (UNVERIFIED). A JVM test of the visibility rule would need test infrastructure ("approve B") and is not part of P1. The rule is kept as one small pure function in `PrayerForegroundService`'s companion so it can be tested later. P1 is checked on the device.

## Verification Plan (device, YAL-L21)

1.  Fire a prayer with vibration on. The buttons appear in the collapsed foreground-service notification with no pull-down. There is no second notification.
2.  Lock the phone (once with a PIN, once with a plain swipe lock). The buttons are visible. Tap Stop and Keep without unlocking.
3.  Tap Stop. The ringer is restored, the buttons vanish within about 1 s, the data stays.
4.  Tap Keep. Vibrate stays on and the buttons vanish.
5.  Do nothing. The buttons vanish at auto-restore, including outside adhan mode (the 60 s refresh).
6.  Reboot during the window. No buttons afterwards; ringer restored.
7.  Set `silent_mode_duration` below and above 20 minutes. The buttons and the data behave as in journeys 6 and 7.
8.  Dark mode, Arabic (RTL), and the largest system font. Button labels are not clipped.
9.  Background notification off. No buttons; the adhan screen buttons still work.
10. On a phone that ran an F68 build, "Silent Mode Control" no longer appears in the app's notification settings after one launch.
11. `git diff --stat -- lib/` is empty.

## Phases

*   **P0:** this spec (docs, level A).
*   **P1:** all Kotlin, layouts, drawables, README and contracts changes above, in one commit (or the minimum number of commits that keeps contracts and Kotlin together). Needs "approve phase P1".
*   **P2:** device checks and logging in `.project-docs/` (STATE, log, device checklist).
