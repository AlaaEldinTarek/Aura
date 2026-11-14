# Permissions status screen: one place for every permission and its state

Status: DRAFT for review (Level A, this doc only). Not approved. Implementation would be Level C (production, tests) and needs an explicit "approve phase PS1" after the owner reviews this spec. Branch `feat/permissions-status-screen` from `main` `1584deb`. Not pushed. Based on the read-only report about `lib/core/widgets/permission_dialog.dart` (2026-11-14).

Labels: VERIFIED = read in code at the cited line (on `main` unless marked) · UNKNOWN = not checked, or not checkable by reading · GUESS = inference. Line numbers refer to `main` `1584deb` unless marked `boot` (branch `fix/boot-start-service`, commit `f80dc82`, not yet merged into `main`).

## Goal
One page that shows every permission the user can act on, each with its state. A new "Permissions" tile in Settings opens it. The automatic popup that appears 2 s after the home screen keeps showing only what is missing.

## What exists today (VERIFIED)
*   `PermissionDialogHandler` is placed once, in `home_screen.dart:353`. It waits 2 s (`permission_dialog.dart:33-35`) and then runs the checks (`:38`, `_runChecks` at `:66`). `_hasChecked` stops a second run in the same screen instance (`:28,39`).
*   `_runChecks` builds a list of only the missing items, for four permissions: exact alarm (`:80`), battery optimization (`:94`), Do Not Disturb (`:110`), overlay, only when the app mode includes tasks (`:125-127`). If nothing is missing it returns without showing a page (`:142`).
*   The page `_PermissionsPage` is private (`:174`) and is shown as a full-screen dialog route (`:159-165`). It has no back arrow (`automaticallyImplyLeading: false`, `:266`).
*   Row state is `List<bool> _granted`, all false at the start (`:183,188`). On resume it rechecks only the rows not yet granted (`:199-203`). A granted row shows a green check and "Granted" (`_PermTile`, `:450` on).
*   The header already has an "All permissions granted" state (`:285`), and the bottom button becomes "Done" when every listed row is granted (`:369`).
*   `_grantPermission` (`:208-221`): runs the row's `action` (a system request) if it has one; when that does not grant, it calls the row's `openSettings` (`:218`), waits 1 s and rechecks.
*   `_recheckPermission` already has branches for `location_permission_title` (`:233`) and `notification_permission_title` (`:235`), but no row is ever created with those titles (VERIFIED: `_runChecks` builds only the four above). These are the "dead branches".
*   `_PermTile._title()` and `_desc()` look the Arabic text up in a local map, which already has location and notification entries (`:460-461,477-478`), and fall back to the raw key when a key is not in the map (`ar[perm.title] ?? perm.title`, `:466,483`). A key missing from the map therefore shows as the raw key in Arabic.
*   Existing keys for the two new rows: `location_permission_title` / `_desc` and `notification_permission_title` / `_desc` in both `en.json` and `ar.json` (`en.json:193-196`, `ar.json:193-196`).
*   `isEmuiDevice` and `showAutoLaunchDialog` exist only on `boot` (`platform_channel_service.dart` `isEmuiDevice`, `lib/core/widgets/auto_launch_dialog.dart`). The Auto-launch hint inside the popup page is also on `boot` only (`permission_dialog.dart:351-361` on `boot`).
*   The exact-alarm state is `true` below Android 12 (`MainActivity.kt:556-562`), so the Dart side cannot tell "granted" from "not applicable" below Android 12. There is no Android SDK number in Dart (grep of `lib/` for `sdkInt`, `SDK_INT`, `androidVersion`: no hits) and `device_info_plus` is not a dependency (`pubspec.yaml` has `permission_handler ^11.2.1` and no `device_info`).
*   The page is reachable only through the popup. No other code opens it (`PermissionDialogHandler` is used once, `home_screen.dart:353`).

## Decisions (owner)
1.  A new "Permissions" tile in Settings opens the existing page in a "show everything" mode: every row with its state (granted shown as done, missing with its action), recheck on resume.
2.  An "All set" summary at the top when every readable row is granted.
3.  Notifications and Location rows are added (state is readable; reuse the dead `_recheckPermission` branches and the existing title keys).
4.  An Auto-launch row on EMUI only: a third state "Check by hand" (the app cannot read it), a button that opens the existing explanation dialog, never "granted". The summary then reads "All set, plus 1 to check by hand".
5.  No full-screen-intent row. The unused storage permissions are not touched (separate manifest cleanup, below).
6.  The automatic popup keeps showing ONLY missing items, as today.
7.  The exact-alarm row stays hidden below Android 12; the overlay row stays only in tasks mode.

## Design

### Two modes of one page
| | Popup mode (today, unchanged) | Show-everything mode (new, from Settings) |
| --- | --- | --- |
| Opened by | `PermissionDialogHandler`, 2 s after home (`home_screen.dart:353`) | New Settings tile |
| Rows | Only the missing ones of the four checks (`:80,94,110,127`). No Notifications, Location or Auto-launch row. | Every applicable row, granted or not |
| Back arrow | None (`:266`) | Yes (a normal pushed page) |
| Resume recheck | Only rows not yet granted (`:199-203`) | Every readable row (the user may also revoke a permission in system settings) |
| Bottom button | "Enable All", then "Done" (`:369-370`) | "Enable All" while a readable row is missing, "Done" when all readable rows are granted |
| Auto-launch | The existing hint row, unchanged (on `boot`). It stays there, because in the popup it is shown only when something else is missing and is never part of the missing list. | The new third-state row (below), not the hint |

*   **The popup does not gain Notifications or Location rows.** Reason: "keeps showing only missing items, as today" (decision 6). Adding them would make the popup appear for users who today get no popup (GUESS). If you want them in the popup too, that is a separate decision.

### Rows in show-everything mode
| Row | State source | Enable button | Shown when | Group |
| --- | --- | --- | --- | --- |
| Exact alarm | `PlatformChannelService.canScheduleExactAlarms()` (`:231`) | Opens the system screen (`openExactAlarmSettings`, `:88`) | Android 12+ only (decision 7; needs the SDK number, below) | Prayer |
| Battery optimization | `isIgnoringBatteryOptimizations()` (`:229`) | Opens the whitelist screen | Always on Android (as today, no mode filter, `:91-101`) | Prayer |
| Do Not Disturb | `Permission.accessNotificationPolicy.status` (`:237`) | `Permission.accessNotificationPolicy.request()`, then app settings (`:119-120`) | Always; group Focus Mode if the app mode has tasks, else Prayer (as `:112`) | Focus or Prayer |
| Overlay | `NotificationService.instance.canDrawOverlays()` (`:239`) | Opens the system overlay screen | Tasks mode only (`:125`) | Focus Mode |
| **Notifications (new)** | `Permission.notification.status` (`:235`) | `Permission.notification.request()`; if not granted, `openAppSettings()` (the existing `_grantPermission` flow, `:208-221`) | Always | Prayer |
| **Location (new)** | `Permission.location.status` (`:233`) | `Permission.location.request()`; if not granted, `openAppSettings()` | When the app mode includes prayer (GUESS: location is for prayer times and Qibla; UNKNOWN whether Qibla needs it in tasks-only mode, so this is an open point) | Prayer |
| **Auto-launch (new, EMUI only)** | None (not readable). State is always "Check by hand". | "How to check" opens `showAutoLaunchDialog` (on `boot`) | `PlatformChannelService.isEmuiDevice()` is true (Huawei by manufacturer; on `boot`) | Prayer |

*   **Where each new row is requested from on this page:**
    *   **Notifications:** `Permission.notification.request()` through the row's Enable button. Before today it was requested only at the end of onboarding (`preference_screen.dart:251`). The splash request `_requestNotificationPermission` exists but is never called (`splash_screen.dart:38`; VERIFIED: no call to it in `lib/`), so a user who denied it at onboarding is never asked again.
    *   **Location:** `Permission.location.request()` through the row's Enable button. Before today it was asked only inside the prayer-time flow, as `Geolocator.requestPermission()` (`location_service.dart:49-51`, reached from `prayer_times_provider.dart:124` through `getBestLocation`, `location_service.dart:173,197`). Nothing else calls `requestLocationPermission` (VERIFIED by grep). The page's request is the same permission, so the state stays consistent (GUESS that `Permission.location` and `Geolocator` report the same grant; both are the same Android permission).
*   **Already denied permanently:**
    *   The existing flow handles it with no change: the request returns "not granted" (without a system dialog, GUESS: standard `permission_handler` behavior for a permanently denied permission), so `_grantPermission` falls through to `openSettings()` (`:218`), which here is `openAppSettings()`. The user lands on Aura's App info screen and turns the permission on there. On return the page rechecks (`:199-203`, extended to all rows in this mode) and the row flips to granted.
    *   Not verified on a device (UNKNOWN). No new text is planned; an optional line "Turn it on in the app's settings" is possible (new string, not in this spec's list).
*   **Notifications on Android 10:** there is no runtime prompt below Android 13 (GUESS). If the user turned notifications off in system settings, the state reads not granted (GUESS: `permission_handler` reports the notification state), Enable goes to app settings.
*   **Location services off:** the row checks the permission only, not whether the GPS switch is on (`isLocationServiceEnabled` exists, `location_service.dart:38`, but is not used). Not part of this spec.

### The third state, and the summary
*   Row state is `granted`, `missing` or `checkByHand`, replacing `List<bool> _granted` (`:183`). A `checkByHand` row never counts as granted and has no "Granted" label; its trailing button reads "How to check".
*   **Summary header** (replaces the fixed header text at `:285`, in show-everything mode):
    *   every readable row granted, no check-by-hand row: "All set";
    *   every readable row granted and one check-by-hand row: "All set, plus one item to check by hand" (the spec text "plus 1" is written as a word so no digit appears in Arabic; there is only ever one such row);
    *   any readable row missing: "Some permissions are missing".
*   The popup keeps its current header (`:285`).

### Android SDK number (needed for decision 7)
Hiding the exact-alarm row below Android 12 needs the SDK number, which Dart does not have (above). Options:

| Option | What | Trade-offs |
| --- | --- | --- |
| **A (recommended)** | A new channel method `getSdkInt → int` on `com.aura.hala/prayer_alarms`, returning `Build.VERSION.SDK_INT` | One Kotlin line plus a Dart wrapper. It is a native contract change: Dart, Kotlin and `.project-docs/contracts/method-channels.md` in one commit (CLAUDE.md). Exact and testable. |
| B | Do not hide the row below 12: show it as "granted" | No native change, but it breaks decision 7 and shows a meaningless row on the owner's Android 10 phone. |
| C | Add `device_info_plus` | Changes `pubspec.*` (Level C, and `pubspec.lock` is git-ignored and must be preserved). Heavier than A. |

The owner decides; the spec assumes A.

## Changes to make

**Smaller parts**
*   **A public wrapper:** `Future<void> showPermissionsStatusPage(BuildContext)` in `permission_dialog.dart`, which collects all rows and pushes the page in show-everything mode. The page class stays private behind it.
*   **Collect all rows with a state:** `_runChecks` (`:66-155`) is split so the same row builders (`:77-139`) can return every row with its state, and the popup keeps filtering to missing ones.
*   **Initial state from the checks:** `_granted` starts from the collected states, not all false (`:188`).
*   **Recheck on resume for every row** in show-everything mode (`:199-203`).
*   **"All set" summary** and the back arrow in show-everything mode (`:266,285`).
*   **Notifications and Location rows:** new `_PermInfo` entries; the dead `_recheckPermission` branches (`:233,235`) now run.
*   **Tile text fallback:** `_title()` and `_desc()` fall back to `.tr()` when a key is missing from the local Arabic map (`:466,483`), so the new Auto-launch row (keys `auto_launch_title`, `auto_launch_subtitle`, on `boot`) does not show raw keys in Arabic.
*   **Settings tile:** one "Permissions" `SettingTile` in the Android block, next to "Exact Alarms" and "Battery Optimization" (`settings_screen.dart:257-276`), Android only.
*   **Strings** (below) and the contract row for `getSdkInt` (option A).

**Bigger parts**
*   **A probe seam, so the logic is testable.** Today the checks call static services directly (`PlatformChannelService`, `Permission.*`, `NotificationService.instance`, `SharedPreferences`), so there is no way to test the row rules without a device. A small `PermissionProbe` (with a real default) provides: exact-alarm state, battery state, DND state, overlay state, notification state, location state, the SDK number, `isEmuiDevice`, and the app mode. A pure function `buildPermissionRows(probe, ...)` returns the rows and states.
*   **The third state and its summary logic** in the model and the page (above).
*   **Rules per row** (SDK 31+ for exact alarm, app mode for overlay and location, EMUI for Auto-launch) in one place.
*   **Tests** (below); the page has none today (VERIFIED: `test/core/widgets` has only `prayer_card_test.dart` and `tutorial_overlay_test.dart` on `main`; no test mentions `PermissionDialogHandler` or `_PermissionsPage`).

**Prerequisite:** the Auto-launch row uses `isEmuiDevice` and `showAutoLaunchDialog`, which exist only on `fix/boot-start-service`. Implementation starts after that branch is merged into `main` (or this branch is rebased onto it). Until then the code for that row cannot compile on `main`.

## Strings (new keys in BOTH `assets/translations/en.json` and `ar.json`, via `.tr()`; the Arabic is a DRAFT for the owner's review)
No digits appear in any new string, so the Arabic-numerals rule does not apply. The existing page uses `isArabic ? ... : ...` literals (`:265,285,369-370`); the new text uses `.tr()` as CLAUDE.md requires, and the old literals are not migrated here.

| Key | English | Arabic (DRAFT) |
| --- | --- | --- |
| `settings_permissions_title` | Permissions | الأذونات |
| `settings_permissions_subtitle` | See every permission and its state | اعرض كل إذن وحالته |
| `permissions_page_title_all` | App permissions | أذونات التطبيق |
| `permissions_all_set` | All set | كل شيء جاهز |
| `permissions_all_set_plus_hand` | All set, plus one item to check by hand | كل شيء جاهز، وبقي عنصر واحد للتحقق منه يدويًا |
| `permissions_some_missing` | Some permissions are missing | بعض الأذونات غير ممنوحة |
| `permissions_check_by_hand` | Check by hand | تحقّق يدويًا |
| `permissions_check_by_hand_button` | How to check | كيف أتحقق؟ |

Reused, no new key: `notification_permission_title` / `_desc`, `location_permission_title` / `_desc` (`en.json:193-196`), `auto_launch_title` / `auto_launch_subtitle` (on `boot`), and the existing Arabic map entries in `_PermTile` (`:460-461,477-478`).

## Tests (write first, red run shown before any code)
There is no test for the page today. Pure and widget tests, with a fake `PermissionProbe`:
1.  **Row rules (pure):** exact alarm shown only at SDK 31 and above; overlay only when the app mode is not `prayer_only` (`needsTasks`, `:71`); location only when the mode is not `tasks_only` (`needsPrayer`, `:70`); DND group is Focus Mode when tasks are in the mode, else Prayer; Auto-launch only when `isEmuiDevice`; notification always; no full-screen-intent row; no storage row.
2.  **States (pure):** each row's state follows its probe value; Auto-launch is always `checkByHand`, never `granted`.
3.  **Summary (pure):** all granted gives "All set"; all granted plus an Auto-launch row gives "All set, plus one item to check by hand"; any missing gives "Some permissions are missing"; a `checkByHand` row alone never turns the summary to "All set".
4.  **Popup mode unchanged (pure):** the popup list has only the missing rows of the four existing checks, never Notifications, Location or Auto-launch, and is empty when all four are granted.
5.  **Page, show-everything (widget):** back arrow present; granted rows show "Granted", missing rows an Enable button; the Auto-launch row shows "How to check" and the button calls the dialog open callback once; resume with a changed fake state flips a granted row to missing and back (all rows, not only ungranted); Enable on a row whose request is not granted calls the row's open-settings callback (permanent denial path); Arabic at 360 dp: no overflow.
6.  **Page, popup mode (widget):** no back arrow; rechecks only ungranted rows on resume (current behavior pinned before the change).
7.  **Strings:** the eight keys in both files, not empty; no ASCII digits in the Arabic.
8.  **`getSdkInt` (option A):** channel call returns the int; a Dart error returns a safe default (design: treat as "unknown, hide the row" or "show"? decide at implementation; UNKNOWN).

**Device-only (nova 5T, Android 10, Huawei) and not testable here:**
*   The Settings tile opens the page; Android 10 shows no exact-alarm row.
*   Granting and revoking Notifications, Location, Battery, DND and overlay in system settings and returning: rows update on resume.
*   Permanent denial of Location and Notifications: Enable opens Aura's App info.
*   The Auto-launch row shows "Check by hand", the dialog opens, and the summary reads "All set, plus one item to check by hand" when every readable row is granted.
*   Arabic RTL layout and wording.
*   Not testable: Android 12+ (exact-alarm row visible, Android 13 notification prompt) and non-Huawei phones (no Auto-launch row); no such device is available.

## Behavior by Android version and phone
*   **Android 10 (the owner's phone):** no exact-alarm row (decision 7). Notifications has no runtime prompt (GUESS). Location offers "allow while using" (GUESS). Huawei: the Auto-launch row appears.
*   **Android 12 and later:** the exact-alarm row appears and links to the system screen (`openExactAlarmSettings`, `MainActivity.kt:564`). Android 13 and later: the Notifications request shows a system dialog; once denied permanently it falls back to App info. Android 11 and later: an "only this time" location grant may read as missing again on the next open (GUESS). Not run on any device here.
*   **Non-Huawei phones:** no Auto-launch row (`isEmuiDevice` is false). Honor is not treated as EMUI (the manufacturer check is "HUAWEI" only, `boot` spec section 3a).
*   **Windows and other desktops:** the popup returns early off Android and iOS (`:42`) and the new tile is Android only, so desktop is unaffected (VERIFIED code path; not run).

## Not done here
*   **No full-screen-intent row** (decision 5). `USE_FULL_SCREEN_INTENT` is declared (`AndroidManifest.xml:16`), nothing reads its state in code (VERIFIED by grep).
*   **Storage permissions are untouched.** `WRITE_EXTERNAL_STORAGE` (max SDK 28), `READ_EXTERNAL_STORAGE` (max SDK 32) and `READ_MEDIA_AUDIO` are declared (`AndroidManifest.xml:32-36`) and never requested; adhan files go to the app documents folder (`adhan_downloads_screen.dart:153,257`). Removing them is a **separate manifest cleanup**, with its own spec and gate (GUESS that they are unneeded; not tested). `INTERNET` is also declared twice (`:3,:37`), harmless, part of the same cleanup.
*   No change to the popup timing, to what the popup lists, or to when it shows (`:33-35`).
*   No migration of the page's existing `isArabic ?` literals to `.tr()`.
*   No state badge on the Settings tile (it would need an async check on every Settings open; possible later).

## Phase and gate
*   **Phase PS1 (DRAFT, not approved):** Level C (production: `lib/`, `android/`, `assets/`, `.project-docs/contracts/`, test cases). Own gate: an explicit "approve phase PS1" after the owner reviews this spec.
*   **Prerequisite:** `fix/boot-start-service` merged into `main` (for `isEmuiDevice`, `showAutoLaunchDialog`, the Auto-launch strings).
*   **Order:** tests first (red run shown), then separate commits: (1) the probe, the row model, the pure rules and summary, plus `getSdkInt` and its contract row (Dart and Kotlin in one commit); (2) the page: show-everything mode, states, summary, back arrow, `.tr()` fallback; (3) the public wrapper, the Settings tile and the strings. `flutter test`, `flutter analyze` and the Kotlin tests after each commit, numbers against the baseline.
*   **Review size:** touches no "edit carefully" file (VERIFIED: the list is `prayer_times_service.dart`, `prayer_times_provider.dart`, `PrayerAlarmReceiver.kt`, `DailySummaryReceiver.kt`) and adds one native contract row, so one lightweight review.
*   **Open for the owner:** (a) the SDK number option A, B or C; (b) whether Location is hidden in tasks-only mode; (c) whether Notifications and Location should also appear in the automatic popup (this spec says no); (d) the Arabic wording; (e) whether to add the optional "turn it on in the app's settings" line for permanent denial.
