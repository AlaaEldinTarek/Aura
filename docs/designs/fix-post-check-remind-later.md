# FX-S08 — Make "Remind Later" Reachable in the Post-Prayer Check Notification (Android)

*   **Author:** Alaa Eldin Tarek
*   **Status:** Draft, not approved. Docs only: no code is written until the owner says "approve phase".
*   **Date:** 2026-11-18
*   **Source:** owner report during device check S08 (nova 5T, EMUI, Android 10) + code read. Finding **F72** (HIGH).

Labels: VERIFIED = read in code or seen in a log, UNVERIFIED = not run on a device, UNKNOWN = not checked.

---

## Overview

The post-prayer check (notification IDs 6001–6006, channel `prayer_tracking`) posts four action buttons: Done, Late, Missed,
Remind Later. Android shows at most three, so **Remind Later is never visible** and the 15-minute re-check cannot be reached
from the UI. This spec keeps Done / Late / Missed as the main buttons and adds Remind Later as a small text button in the
top corner of the notification (top-right in English, top-left in Arabic), using a custom layout. The tap runs the same
`ACTION_POST_LATER` intent and the same 15-minute re-arm as today.

## The Problem (VERIFIED)

*   `PrayerAlarmReceiver.showPostPrayerCheckNotification` (`PrayerAlarmReceiver.kt:996`) calls `addAction` four times:
    Done `notificationId+1` (`:1026`), Late `+2` (`:1038`), Missed `+3` (`:1050`), Remind Later `+4` (`:1062`).
*   Device log 2026-11-18 12:09:00 (Zuhr): `enqueueNotificationInternal … id=6003 … actions=4`. The owner saw three buttons.
    The only tap logged was Late (12:09:19). No `Re-scheduled for Zuhr in 15 min` line, no 3003 alarm at 12:35.
*   The handler for `ACTION_POST_LATER` (`:1139`) already works as designed in code: cancels the notification, calls
    `schedulePostPrayerCheck` for now + 15 min (request code `getNotificationId + 2000`, e.g. 3003). It has never been
    exercised from a real tap (UNVERIFIED on device).
*   Today the buttons only appear after the owner expands the notification (collapsed on the lock screen, owner report).
*   Notification visibility today is PRIVATE (`vis=PRIVATE` in the same log line). Not changed by this spec.

## Owner design (2026-11-18)

*   **R1 — Main buttons unchanged:** Done / Late / Missed stay as they are (system action buttons, request codes
    `notificationId+1..+3`, same intents and handlers).
*   **R2 — Remind Later becomes a small text button in the top corner:** "Remind Later" / "ذكّرني لاحقاً". Top-**right**
    in English, top-**left** in Arabic (mirror). Same `ACTION_POST_LATER` intent (`notificationId+4`) and same 15-minute
    re-arm as today; the handler is not changed.
*   **R3 — Custom `RemoteViews` layout,** following the pattern of the existing Stop / Keep Vibration card.
*   **R4 — Must work on Android 10 (nova 5T, EMUI) and newer Android.** This spec says what happens on the lock screen
    and when collapsed (below).

## How the existing card is built (VERIFIED, `PrayerForegroundService.kt:663-730`)

*   `buildContentView` returns a `RemoteViews` from one of four layouts: `notification_actions[_dark][_rtl].xml` (buttons)
    or `notification_large[_dark][_rtl].xml`. The language is the `language` pref of `aura_prayer_times`; dark/light is the
    `theme_mode` pref. The `_rtl` files set `android:layoutDirection="rtl"` and `android:textDirection="rtl"` on the root, so
    RTL does not depend on the phone's own locale.
*   The buttons are `TextView`s with `@drawable/bg_vibration_button[_dark]`; the click is wired with
    `RemoteViews.setOnClickPendingIntent` to a broadcast `PendingIntent` (`FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT`).
*   The builder uses `setCustomContentView` + `setCustomBigContentView` and **no** style (no `DecoratedCustomViewStyle`;
    searched `android/app/src/main/kotlin`). So that card is a full custom view.
*   The post-check notification today uses `BigTextStyle` and no custom view.

## Design

### Layout approach — two options (recommendation: B)

| | A. Full custom view (like the vibration card) | B. `DecoratedCustomViewStyle` (recommended) |
|---|---|---|
| Android 10 | Our view fills everything, no system header; the system action row is still shown when expanded | System header (icon, app name, time, expand arrow) on top, our view below it, system action row below that |
| Android 12+ | Android wraps custom views in the standard template (system header added; documented platform change, UNVERIFIED on a device here) → looks different from Android 10 | Same structure as Android 10 |
| Dark / light | Needs our own colours: 4 layouts (`_dark`, `_rtl`), a theme decision in the receiver (the receiver has no `isDarkTheme` today) | System background and text colours: 2 layouts (LTR, RTL) |
| "Top corner" | True top corner of the notification | Top corner of the content area, directly under the system header row |

Recommendation **B**: the same look on every version, fewer layouts, Done / Late / Missed keep the normal system styling.
The cost: the corner button sits under the header row, not in it. **Owner decides (Q1).**

### The layout (both options)

*   One layout used for both `setCustomContentView` (collapsed) and `setCustomBigContentView` (expanded): title ("Did you
    pray Zuhr?"), body ("Log your prayer now"), and the corner `TextView` `btn_remind_later`. Collapsed height is limited
    (about 64 dp), so one title line, one body line and the corner button must fit on one row; the title gets an end margin
    so it never runs under the button.
*   `btn_remind_later`: 12 sp, bold, accent colour (#F5B301 / light variant #B5821B per the app palette), touch area at
    least 48 dp high; `layout_alignParentEnd` in a `RelativeLayout` (or `layout_gravity=end` in a `FrameLayout`).
*   Files: `notification_post_check.xml` and `notification_post_check_rtl.xml` (option B). The RTL file sets
    `layoutDirection="rtl"` on the root, like the existing `_rtl` layouts, so the button goes top-left in Arabic whatever
    the phone language is. (Option A adds `_dark` and `_dark_rtl`.)

### Request codes and intents (unchanged)

| Button | Action | Request code | Where it lives after the fix |
|---|---|---|---|
| Done | `ACTION_POST_DONE` | `notificationId+1` | `addAction` (as today) |
| Late | `ACTION_POST_LATE` | `notificationId+2` | `addAction` (as today) |
| Missed | `ACTION_POST_MISSED` | `notificationId+3` | `addAction` (as today) |
| Remind Later | `ACTION_POST_LATER` | `notificationId+4` | corner button, `setOnClickPendingIntent`; **removed from `addAction`** |
| Tap on the body | open the app | `notificationId+5` | unchanged |

The fourth `addAction` is removed so the notification no longer depends on how an OEM treats a 4th action (`actions=3`
expected in the log). No notification ID, channel, action string, extra or request code changes (contracts untouched; a
note about the corner button goes in `contracts/notification-ids.md` if the owner wants it).

### Collapsed, expanded and lock screen

*   **Collapsed:** title + body + the corner button are all visible (this is the improvement over today, where no button is
    visible collapsed). Done / Late / Missed still appear only after expanding (system behaviour, unchanged).
*   **Expanded:** the same layout, with Done / Late / Missed below.
*   **Lock screen:** visibility stays PRIVATE (not changed). With the owner's lock-screen settings the card shows
    (owner screenshot, collapsed). Whether a tap on the corner button on a **secure** lock screen asks for unlock first:
    UNKNOWN (it is the same rule the three system buttons follow; to be observed in the device check). With "hide
    sensitive content" the system shows its own placeholder and neither the buttons nor our layout (not changed).
*   **Android 10 (EMUI):** custom `RemoteViews` clicks via `setOnClickPendingIntent` are standard API (the vibration card uses them); a tap on
    that card was not recorded as a device check yet (UNVERIFIED on this phone). EMUI-specific rendering of `DecoratedCustomViewStyle` and of `?android:attr/textColorPrimary`
    inside a notification: UNVERIFIED, covered by the device check.
*   **Android 12+:** no device here; the layout is built to be the same on both (option B). UNVERIFIED.

### Texts (existing strings, hard-coded in Kotlin like the current buttons)

| | English | Arabic | Change? |
|---|---|---|---|
| Done | Done | صلّيت | no |
| Late | Late | متأخر | no |
| Missed | Missed | فاتتني | no |
| Remind Later | Remind Later | ذكّرني لاحقاً | no |

None needs changing: all four are short enough for a button, and "ذكّرني لاحقاً" is no longer than "Remind Later" in the
12 sp corner. Like the current buttons these are native strings chosen by the `language` pref, not `.tr()` (existing
native-notification pattern; no new keys, so `en.json` / `ar.json` are untouched). The owner reviews the Arabic.

### What does not change

The handlers (`handlePostPrayerCheckAction`), the 15-minute re-arm, the alarm request codes (3001–3006), notification IDs
6001–6006, the post-check timing, Zuhr/Dhuhr handling, the Dart side, prefs keys, MethodChannels. Windows: the desktop
post-check toast was not traced (UNKNOWN); this spec is Android only.

## Goals

*   The owner can tap Remind Later on a real notification, collapsed or expanded.
*   Remind Later cancels the notification and arms the 15-minute repeat (request code 3001–3006 for that prayer, ~now+15).
*   Done / Late / Missed behave exactly as today.

## Non-Goals

*   Changing the 15-minute interval, adding a picker, or limiting how many times a user can remind.
*   Changing visibility, channel, importance, sound, or the adhan / reminder / foreground-service notifications.
*   Removing the dead `ACTION_REMINDER_*` code (F69).

## Tests to write first

*   **Kotlin unit (`./gradlew :app:testDebugUnitTest`):** the project has no Robolectric (only `junit`), so a `PendingIntent`
    cannot be built in a unit test. Plan: a small pure helper `PostCheckActions` that returns, per action, the action
    string, the request-code offset (`+1..+4`), the label for English / Arabic and the placement (button or corner). The
    notification builder uses it, and the test asserts: exactly four entries; offsets 1, 2, 3, 4 map to Done, Late,
    Missed, Remind Later; exactly three are "button" and one is "corner"; both languages return the strings in the table
    above; the request codes for each of the six notification IDs (6001–6006) are all distinct from each other and from
    `+5`. Written first, run failing (helper missing), then the helper.
*   **What the unit test does not prove:** that the `PendingIntent`s and the layout are right on a device. That is the
    device check.
*   Regression: existing Kotlin tests (51) and Dart tests (830 on `fix/prayer-reminder`) unchanged; `flutter analyze` count
    unchanged.

## Device check (after the fix; Android 10, nova 5T)

Needs a post-check, i.e. a real prayer (~30 min after the adhan) or the existing dev trigger for a post-check if one exists
(UNKNOWN; to be confirmed before the run).

1.  Post-check arrives: `dumpsys notification --noredact` shows `actions=3` for ID 600x, a custom content view, and the log
    line `📋 [POST_CHECK] Notification shown for <prayer>`.
2.  **Collapsed, screen on:** title, body and "Remind Later" (top-right, English) are visible without expanding. Switch the
    app to Arabic: the button is top-left and reads "ذكّرني لاحقاً".
3.  **Lock screen:** collapsed card shows the corner button; tap it. Record whether unlock was required.
4.  **Remind Later tap:** log shows `Re-scheduled for <prayer> in 15 min` and `Scheduled for <prayer> → HH:MM … req=300x`;
    notification 600x is gone; `dumpsys alarm` shows the 300x alarm ~15 min ahead; no `MainActivity` start in the log.
5.  **The repeat:** at HH:MM the post-check appears again (`NOT tracked → showing notification`).
6.  **Missed on the repeat:** log shows `Marked <prayer> as missed` once and `Saved to prefs: <prayer> → missed`; notification
    cancelled; the app shows the prayer as missed after opening.
7.  **Done / Late** still work (one each on later prayers): status written once, notification cancelled.
8.  **Dark theme and light theme:** the corner text is readable in both (colours).
9.  Long Arabic title and a large system font size: the title does not run under the corner button.

## Phases (proposal)

| Phase | Content | Level |
|---|---|---|
| R1 | Tests first (`PostCheckActions`); the helper; the layout files; builder change in `showPostPrayerCheckNotification`; build + tests | C |
| R2 | Device check S08 (both halves) + record | A |

## Open questions

*   **Q1:** option A (full custom view, true top corner, 4 layouts) or **B** (decorated, under the system header, 2 layouts)?
    Recommendation B.
*   **Q2:** is there a dev trigger for a post-check notification, or do we wait for a real prayer (+30 min)? UNKNOWN until
    checked; does not block the spec.
*   **Q3:** Windows post-check toast has the same four-action question? UNKNOWN, not traced here.
*   **Q4:** should the tap on a secure lock screen be allowed without unlock? Not changeable per version without a new
    visibility decision; this spec leaves it as the system decides.
