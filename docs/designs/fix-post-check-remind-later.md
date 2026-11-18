# FX-S08 — Make "Remind Later" Reachable in the Post-Prayer Check Notification (Android)

*   **Author:** Alaa Eldin Tarek
*   **Status:** Draft, not approved. Docs only: no code is written until the owner says "approve phase".
*   **Date:** 2026-11-18 (owner answers to Q1-Q3 added the same day)
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

## Owner answers (2026-11-18)

*   **Q1 — Option B** (`DecoratedCustomViewStyle`). Remind Later just under the system header is fine. Corner = right in
    English, left in Arabic.
*   **Q2 — Dev trigger:** checked, there is none (see "Test post-check (hidden dev tile)"). A "Test post-check" item is added, **not** debug-only (owner correction, same day).
*   **Q3 — Windows:** traced read-only (see "Windows"). Remind Later is missing there, so a Windows part is added.

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

### Layout approach — option B chosen by the owner (table kept for the record)

| | A. Full custom view (like the vibration card) | B. `DecoratedCustomViewStyle` (recommended) |
|---|---|---|
| Android 10 | Our view fills everything, no system header; the system action row is still shown when expanded | System header (icon, app name, time, expand arrow) on top, our view below it, system action row below that |
| Android 12+ | Android wraps custom views in the standard template (system header added; documented platform change, UNVERIFIED on a device here) → looks different from Android 10 | Same structure as Android 10 |
| Dark / light | Needs our own colours: 4 layouts (`_dark`, `_rtl`), a theme decision in the receiver (the receiver has no `isDarkTheme` today) | System background and text colours: 2 layouts (LTR, RTL) |
| "Top corner" | True top corner of the notification | Top corner of the content area, directly under the system header row |

**Option B** (owner, Q1): the same look on every version, fewer layouts, Done / Late / Missed keep the normal system
styling. The corner button sits under the header row, not in it (accepted). Option A is not built.

### The layout (both options)

*   One layout used for both `setCustomContentView` (collapsed) and `setCustomBigContentView` (expanded): title ("Did you
    pray Zuhr?"), body ("Log your prayer now"), and the corner `TextView` `btn_remind_later`. Collapsed height is limited
    (about 64 dp), so one title line, one body line and the corner button must fit on one row; the title gets an end margin
    so it never runs under the button.
*   `btn_remind_later`: 12 sp, bold, accent colour (#F5B301 / light variant #B5821B per the app palette), touch area at
    least 48 dp high; `layout_alignParentEnd` in a `RelativeLayout` (or `layout_gravity=end` in a `FrameLayout`).
*   Files: `notification_post_check.xml` and `notification_post_check_rtl.xml`. The RTL file sets
    `layoutDirection="rtl"` on the root, like the existing `_rtl` layouts, so the button goes top-left in Arabic whatever
    the phone language is.

### Request codes and intents (unchanged)

| Button | Action | Request code | Where it lives after the fix |
|---|---|---|---|
| Done | `ACTION_POST_DONE` | `notificationId+1` | green button in the expanded custom view (was `addAction`; see "Design change") |
| Late | `ACTION_POST_LATE` | `notificationId+2` | orange button in the expanded custom view |
| Missed | `ACTION_POST_MISSED` | `notificationId+3` | red button in the expanded custom view |
| Remind Later | `ACTION_POST_LATER` | `notificationId+4` | corner button (collapsed and expanded), `setOnClickPendingIntent`; **no action uses `addAction` any more** |
| Tap on the body | open the app | `notificationId+5` | unchanged |

No `addAction` is used after the design change (expected `actions=0` in the log), so the card no longer depends on how an
OEM treats a 4th action. No notification ID, channel, action string, extra or request code changes (contracts untouched; a
note about the corner button goes in `contracts/notification-ids.md` if the owner wants it).

### Collapsed, expanded and lock screen

*   **Collapsed:** title + body + the corner button are all visible. Done / Late / Missed appear only after expanding
    (see "Design change": they are now coloured buttons in the expanded custom view, not system actions).
*   **Expanded:** the same layout, with the coloured Done / Late / Missed row below.
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

### Test post-check in the hidden dev tile (Q2; owner correction: NOT debug-only)

*   **Checked (VERIFIED):** no dev trigger for a post-check exists. The only one is the hidden dev tile in
    `lib/features/profile/profile_version_tile.dart` (seven taps on the Version tile; `fireTestAdhan` → `testAdhanNow`,
    native `MainActivity.kt:440`, request code 9999, `EXTRA_IS_TEST`), and it fires the adhan only. A real post-check
    appears ~30 min after a real adhan, or 15 min after a Remind Later.
*   **Added (owner):** a second item in that same hidden dev tile, "Test post-check". It has **the same visibility rule as
    the test adhan: seven taps on the Version tile, and it works in release builds** (the tile has no `kDebugMode` gate
    today; VERIFIED in the file). It posts the post-check for the **next prayer** right away (no 30-minute wait).
*   **Why not debug-only (owner):** a debug build has a different signing key, so installing it on the nova 5T would need an
    uninstall and would wipe the owner's data. The check must run on the release APK.
*   **How:** Dart: a second tile under the existing one, shown by the same `_unlocked` flag, with an injectable
    `firePostCheck` function (default `PrayerAlarmService.testPostCheckNow(prayerName, prayerNameAr, prayerTime)`) so a widget
    test can drive it. New MethodChannel method `testPostCheckNow` on `prayer_alarms` (**`contracts/method-channels.md`**,
    listed under "planned" until the code lands; updated in the same commit as the code) → `PrayerAlarmReceiver` shows the
    notification through the same `showPostPrayerCheckNotification` (not a copy), so the test exercises the real path,
    including the corner button and the real `ACTION_POST_LATER` re-arm. Like `testAdhanNow`, the native handler has no
    debuggable guard.
*   **Safety of a release-visible dev item:** it only posts a notification for the next prayer (same as a real post-check)
    and does not write any status by itself; the owner reaches it only after seven taps. A confirm dialog like the adhan
    one is optional (open: Q5).
*   Strings for the dev item go through `.tr()` in `en.json` and `ar.json` like the existing `dev_test_adhan_*` keys.

### Windows (Q3)

*   **Traced (VERIFIED, read-only):** `DesktopNotificationService.showPostPrayerCheck`
    (`desktop_notification_service.dart:254`) shows a toast with **three** buttons: On Time ✓ / Late ⏰ / Missed ✗
    (Arabic: في الوقت ✓ / متأخر ⏰ / فاتت ✗). **Remind Later is not there.** It is scheduled by
    `DesktopPrayerScheduler` (`desktop_prayer_scheduler.dart:96-99`) as a one-shot `Timer` after the adhan. Windows allows
    up to five toast buttons (owner), so there is room.
*   **Change (because it is missing):** add a fourth button "Remind Later" / "ذكّرني لاحقاً" (index 3) that starts a
    15-minute one-shot `Timer` and then calls `showPostPrayerCheck` again for the same prayer; no status is recorded.
    Platform-guarded (`isDesktop`), no effect on Android. Open: where the timer lives (scheduler vs. service) so that
    `rescheduleReminders()` or a tile change does not cancel it, and whether a repeated tap replaces the pending timer
    (suggest: yes, one pending timer per prayer). A pure Dart test of the timer helper is written first.
*   Not in this spec: the Windows adhan toast and the pre-prayer reminder toast (separate specs).

### Design change after the first phone check (owner, 2026-11-18, "approve phase R1b")

First phone check (PR #60 head, screenshots 15:54 Arabic / 15:55 English): Remind Later is visible in the corner in both
languages (owner-observed PASS for F72's main goal). Changes requested, same branch:

*   **Buttons move into the custom expanded layout.** Done / Late / Missed are no longer system `addAction` buttons
    (standard action buttons cannot be coloured per button on EMUI). Same `PendingIntent`s, same request codes
    `notificationId+1..+4`, same handlers.
*   **Colours:** Done green `#4CAF50`, Late orange `#FF9800`, Missed red `#F44336` (the app's `AppConstants.success` /
    `warning` / `error`), as filled pills with dark text `#212121`, readable on a light and on a dark notification
    background (dark text on these fills, same fill in both themes). Remind Later keeps its gold (`#B5821B` light,
    `#F5B301` dark).
*   **Sizes:** question title 16 sp bold, subtitle 14 sp, Done / Late / Missed 15 sp bold in 40 dp high pills (three
    equal-weight buttons, about 95 dp each at 360 dp, one line), Remind Later 13 sp bold.
*   **Collapsed vs expanded:** collapsed = the question, the subtitle and Remind Later in the corner. The coloured
    buttons do **not** fit the collapsed height (about 64 dp for two text lines plus a 40 dp button row), so they show
    **only when expanded** (decision recorded; owner asked "tell me which").
*   **Arabic (RTL):** question and subtitle pinned to the right edge, Remind Later at the top left, the row mirrored:
    صلّيت (right) · متأخر · فاتتني (left). The direction follows the **app language** (`language` pref), not the system
    locale: separate `_rtl` layouts set `layoutDirection="rtl"` on the root, as before. Child order is Done, Late,
    Missed in both files; the RTL root mirrors the row.
*   **Files:** `notification_post_check[_rtl].xml` (collapsed), `notification_post_check_expanded[_rtl].xml` (expanded),
    `bg_post_check_{done,late,missed}.xml`, colours in `values/colors.xml`.
*   **Test:** `PostCheckActionsTest` unchanged except a new check of the action keys (`done`, `late`, `missed`,
    `later`). The layout is checked on the device.
*   **Windows part unchanged.**

#### Phase R1c (owner decision, 2026-11-18; replaces the R1b/R1c styling above)

R1b phone check (screenshots 16:12 Arabic, 16:13 English): English positions OK; Arabic **wrong on the device** (my R1b report
said it was right without a device check): "ذكّرني لاحقاً" at the right next to the question, the question in the middle, the
row not mirrored. Owner then asked for the card to match Aura's existing notification design (the foreground "Next Prayer"
card and the Stop / Keep Vibration buttons). What is built:

*   **How the existing card is built (VERIFIED, `PrayerForegroundService.kt`, `notification_large*.xml`):** full custom
    view (no `DecoratedCustomViewStyle`), the background is drawn by the layout (`bg_notification` `#FFF8EB`,
    `bg_notification_dark` `#1A1B1E`), four layout files by theme and language (`_dark`, `_rtl`, `_dark_rtl`), theme from
    the `theme_mode` pref (`dark`/`amoled` dark, `light` light, `system` the phone), language from the `language` pref.
    The post-check card now does exactly that (no `DecoratedCustomViewStyle`).
*   **Files:** `notification_post_check.xml`, `_dark`, `_rtl`, `_dark_rtl` (the owner wrote `post_check*.xml`; I kept the
    existing `notification_` prefix). The receiver picks the file by `PostCheckActions.isDark(theme_mode, phone night)` and
    the app language, never by the system locale. Collapsed and expanded use the same layout: the collapsed view hides the
    button row with `setViewVisibility(GONE)`, so the collapsed card is the top row only. The three buttons need the
    expanded view (they do not fit the collapsed height).
*   **Top row:** the per-prayer icon (same mapping as the Next Prayer card: `ic_prayer_fajr` / `_dhuhr` / `_afternoon` /
    `_maghrib` / `_isha`, `ic_mosque` otherwise; `PostCheckActions.iconKey`) in a 40 dp circle with a soft gold tint
    (`bg_post_check_icon`); the question "Did you pray {prayer}?" 17 sp bold and "Log your prayer now" 12 sp; "Remind
    Later" as a small pill in the `bg_vibration_button` / `bg_vibration_button_dark` style (14 dp radius, 12 sp bold).
    English: icon at the left, Remind Later at the right end. Arabic: icon at the right, text right-aligned against it,
    "ذكّرني لاحقاً" at the far left end.
*   **Button row:** three equal tinted pills, no stroke, 14 dp radius, 32 dp high, 13 sp bold, 6 dp gaps. The Arabic file
    lists Missed, Late, Done from the left, so it reads صلّيت · متأخر · فاتتني from the right.
*   **Colours:**
    *   Dark card: title `#FFFFFF`, subtitle `#99FFFFFF`, Remind Later text `#F5B301`; Done `#4CAF50`, Late `#FF9800`,
        Missed `#F44336`, each on an 18% fill (`#2E` alpha) of the same colour.
    *   Light card: title `#2A2418`, subtitle `#992A2418`, Remind Later text `#B5821B`; Done `#2E7D32`, Late `#E65100`,
        Missed `#C62828`, each on a 15% fill (`#26` alpha).
*   **Explicit positions:** left/right only (no `start`/`end`, no `gravity="start"`), and the root and the button row are
    forced `layoutDirection="ltr"`, so the system locale cannot mirror the card a second time.
*   **Unchanged:** `PendingIntent`s and request codes (`notificationId+1..+4`, body tap `+5`), the 15-minute Remind Later
    re-arm, the handlers, the Windows part.
*   **Tests:** `PostCheckActionsTest` gained checks for `iconKey` and `isDark`. The layouts are checked on the device.

#### Phase R1d (owner decision, 2026-11-18): compact collapsed layout that always shows the buttons

After the R1c phone check the card looked right in English and Arabic, dark and light, but the Done / Late / Missed buttons
were only visible after dragging the card down (the full custom card has no system expand arrow). Owner decision: option (d).

*   **Collapsed view = a compact layout** that fits the ~64 dp collapsed slot: row 1 (~22 dp) the question "Did you pray
    {prayer}?" 14 sp bold plus a small "Remind Later" pill (11 sp) at the end (English right, Arabic far left); row 2
    (28 dp) the three tinted pills Done / Late / Missed (12 sp bold), colours per theme exactly as R1c. No icon, no
    subtitle. Padding 5 dp top and bottom (about 63 dp in total).
*   **Four files:** `notification_post_check_compact.xml`, `_compact_dark`, `_compact_rtl`, `_compact_dark_rtl`, picked by
    the same rule as R1c (app theme, app language). Arabic order from the right: صلّيت · متأخر · فاتتني (the RTL file lists
    Missed, Late, Done from the left).
*   **Expanded view unchanged** (R1c: icon, question, subtitle, Remind Later, buttons).
*   **Same PendingIntents and request codes in both views** (`notificationId+1..+4`).
*   **Device check:** shade collapsed and expanded in English dark, Arabic dark, English light, Arabic light, plus the lock
    screen; see the report of the R1d run for what was captured.

### What does not change

The handlers (`handlePostPrayerCheckAction`), the 15-minute re-arm, the alarm request codes (3001–3006), notification IDs
6001–6006, the post-check timing, Zuhr/Dhuhr handling, the Dart side, prefs keys, MethodChannels. Windows: see "Windows" above.

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
*   **Dart (dev item):** widget test for `ProfileVersionTile`: the "Test post-check" tile is hidden before seven taps and
    shown after seven (same as the test adhan tile); the tap calls the injected function with the next prayer.
*   **Dart (Windows):** test that the Remind Later action starts exactly one 15-minute timer per prayer, that a second tap
    replaces it, and that the timer calls `showPostPrayerCheck` again (fake timer / injected clock).
*   Regression: existing Kotlin tests (51) and Dart tests (830 on `fix/prayer-reminder`) unchanged; `flutter analyze` count
    unchanged.

## Device check (after the fix; Android 10, nova 5T)

Needs a post-check: a real prayer (~30 min after the adhan; release build) or the "Test post-check" item of the hidden dev tile
(seven taps on Version; release build; see above).

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
10. Release build: after seven taps on Version, "Test post-check" appears next to the test adhan and posts the card at once for the next prayer.
11. Windows (observe only): the post-check toast shows four buttons; Remind Later → the toast comes back after 15 min.

## Phases (proposal)

| Phase | Content | Level |
|---|---|---|
| R1 | Tests first (`PostCheckActions`); the helper; the layout files; builder change in `showPostPrayerCheckNotification`; build + tests | C |
| R1b | "Test post-check" in the hidden dev tile (Dart item, channel method, contract) | C |
| R1c | Windows Remind Later button + timer | C |
| R2 | Device check S08 (both halves) + record | A |

## Open questions

*   Q1-Q3 are answered above.
*   **Q4 (unchanged):** a tap on a secure lock screen is left as the system decides.
*   **Q5:** should "Test post-check" ask for confirmation like the test adhan dialog? (Suggest: no, it only posts a
    notification.)
*   **Q6:** Windows timer ownership and "replace on second tap" (see Windows).
