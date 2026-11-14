# Permissions status screen: one place for every permission and its state

Status: The spec and phase PS1 were approved by Aladdin on 2026-11-14, given as: 'approve the permissions spec and phase PS1, with those choices' (the choices are recorded in "Final choices" below). The Arabic strings stay DRAFT until Aladdin has read them. **PS1 is not started: it waits for `fix/boot-start-service` to be merged into `main` (open PR #22), because `isEmuiDevice` and the Auto-launch dialog live there.** Level A (this doc); implementation is Level C (production, tests). Branch `feat/permissions-status-screen` from `main` `1584deb`. Not pushed. Based on the read-only report about `lib/core/widgets/permission_dialog.dart` (2026-11-14).

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
*   The exact-alarm state is `true` below Android 12 (`MainActivity.kt:556-562`), so the Dart side cannot tell "granted" from "not applicable" below Android 12. Final choice 1 uses this: below Android 12 the row simply shows "Granted". There is no Android SDK number in Dart (grep of `lib/` for `sdkInt`, `SDK_INT`, `androidVersion`: no hits) and `device_info_plus` is not a dependency (`pubspec.yaml` has `permission_handler ^11.2.1` and no `device_info`).
*   The page is reachable only through the popup. No other code opens it (`PermissionDialogHandler` is used once, `home_screen.dart:353`).

## Decisions (owner)
1.  A new "Permissions" tile in Settings opens the existing page in a "show everything" mode: every row with its state (granted shown as done, missing with its action), recheck on resume.
2.  An "All set" summary at the top when every readable row is granted.
3.  Notifications and Location rows are added (state is readable; reuse the dead `_recheckPermission` branches and the existing title keys).
4.  An Auto-launch row on EMUI only: a third state "Check by hand" (the app cannot read it), a button that opens the existing explanation dialog, never "granted". The summary then reads "All set, plus 1 to check by hand".
5.  No full-screen-intent row. The unused storage permissions are not touched (separate manifest cleanup, below).
6.  The automatic popup keeps showing ONLY missing items, as today.
7.  ~~The exact-alarm row stays hidden below Android 12;~~ **superseded by final choice 1 (below):** the exact-alarm row shows as "Granted" below Android 12. The overlay row stays only in tasks mode.

### Final choices (owner, 2026-11-14, with the approval)
1.  **No `getSdkInt` native method.** The exact-alarm row is always shown and reads "Granted" below Android 12 (always granted there: `canScheduleExactAlarms` returns `true`, `MainActivity.kt:556-562`). No Kotlin change and no new contract row.
2.  **The Location row is hidden in tasks-only mode** (`needsPrayer` is false when the mode is `tasks_only`, `permission_dialog.dart:70`).
3.  **Notifications and Location rows stay out of the automatic popup** (as in this spec).
4.  **A short line "turn it on in the app's settings"** is added for a permanently denied Notifications or Location row (new string, below).
5.  **The Arabic strings stay DRAFT** until the owner has read them.

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
| Exact alarm | `PlatformChannelService.canScheduleExactAlarms()` (`:231`) | Opens the system screen (`openExactAlarmSettings`, `:88`) | Always on Android (final choice 1). Below Android 12 the state is always granted, so the row reads "Granted" | Prayer |
| Battery optimization | `isIgnoringBatteryOptimizations()` (`:229`) | Opens the whitelist screen | Always on Android (as today, no mode filter, `:91-101`) | Prayer |
| Do Not Disturb | `Permission.accessNotificationPolicy.status` (`:237`) | `Permission.accessNotificationPolicy.request()`, then app settings (`:119-120`) | Always; group Focus Mode if the app mode has tasks, else Prayer (as `:112`) | Focus or Prayer |
| Overlay | `NotificationService.instance.canDrawOverlays()` (`:239`) | Opens the system overlay screen | Tasks mode only (`:125`) | Focus Mode |
| **Notifications (new)** | `Permission.notification.status` (`:235`) | `Permission.notification.request()`; if not granted, `openAppSettings()` (the existing `_grantPermission` flow, `:208-221`) | Always | Prayer |
| **Location (new)** | `Permission.location.status` (`:233`) | `Permission.location.request()`; if not granted, `openAppSettings()` | When the app mode is not `tasks_only` (final choice 2; `needsPrayer`, `:70`) | Prayer |
| **Auto-launch (new, EMUI only)** | None (not readable). State is always "Check by hand". | "How to check" opens `showAutoLaunchDialog` (on `boot`) | `PlatformChannelService.isEmuiDevice()` is true (Huawei by manufacturer; on `boot`) | Prayer |

*   **Where each new row is requested from on this page:**
    *   **Notifications:** `Permission.notification.request()` through the row's Enable button. Before today it was requested only at the end of onboarding (`preference_screen.dart:251`). The splash request `_requestNotificationPermission` exists but is never called (`splash_screen.dart:38`; VERIFIED: no call to it in `lib/`), so a user who denied it at onboarding is never asked again.
    *   **Location:** `Permission.location.request()` through the row's Enable button. Before today it was asked only inside the prayer-time flow, as `Geolocator.requestPermission()` (`location_service.dart:49-51`, reached from `prayer_times_provider.dart:124` through `getBestLocation`, `location_service.dart:173,197`). Nothing else calls `requestLocationPermission` (VERIFIED by grep). The page's request is the same permission, so the state stays consistent (GUESS that `Permission.location` and `Geolocator` report the same grant; both are the same Android permission).
*   **Already denied permanently:**
    *   The existing flow handles it with no change: the request returns "not granted" (without a system dialog, GUESS: standard `permission_handler` behavior for a permanently denied permission), so `_grantPermission` falls through to `openSettings()` (`:218`), which here is `openAppSettings()`. The user lands on Aura's App info screen and turns the permission on there. On return the page rechecks (`:199-203`, extended to all rows in this mode) and the row flips to granted.
    *   Not verified on a device (UNKNOWN). No new text is planned; an optional line "Turn it on in the app's settings" is possible (new string, not in this spec's list).
    *   **The hint line (final choice 4):** when Enable on a Notifications or Location row ends not granted, the page remembers it for that row (page state, not stored) and shows the short line `permissions_denied_hint` under the row text, because the system will not ask again and the user has to use the app's settings. It is shown only after such an attempt, not before (GUESS: before the first request `permission_handler` cannot tell "never asked" from "denied for good", so reading `isPermanentlyDenied` up front is not reliable).
*   **Notifications on Android 10:** there is no runtime prompt below Android 13 (GUESS). If the user turned notifications off in system settings, the state reads not granted (GUESS: `permission_handler` reports the notification state), Enable goes to app settings.
*   **Location services off:** the row checks the permission only, not whether the GPS switch is on (`isLocationServiceEnabled` exists, `location_service.dart:38`, but is not used). Not part of this spec.

### The third state, and the summary
*   Row state is `granted`, `missing` or `checkByHand`, replacing `List<bool> _granted` (`:183`). A `checkByHand` row never counts as granted and has no "Granted" label; its trailing button reads "How to check".
*   **Summary header** (replaces the fixed header text at `:285`, in show-everything mode):
    *   every readable row granted, no check-by-hand row: "All set";
    *   every readable row granted and one check-by-hand row: "All set, plus one item to check by hand" (the spec text "plus 1" is written as a word so no digit appears in Arabic; there is only ever one such row);
    *   any readable row missing: "Some permissions are missing".
*   The popup keeps its current header (`:285`).

### Android version (decision 7, final choice 1)
No Android SDK number is needed. The exact-alarm row is always built; below Android 12 `canScheduleExactAlarms` returns `true` (`MainActivity.kt:556-562`), so it reads "Granted" with no button action needed. On Android 12 and later it reads the real state. A new native method (`getSdkInt`) and `device_info_plus` were considered and rejected by the owner (a native contract change, and a new dependency). Cost of this choice: on the owner's Android 10 phone the page shows one extra "Granted" row that is not strictly relevant there.

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
*   **Strings** (below) and the denied-hint state. No contract row and no Kotlin change (final choice 1).

**Bigger parts**
*   **A probe seam, so the logic is testable.** Today the checks call static services directly (`PlatformChannelService`, `Permission.*`, `NotificationService.instance`, `SharedPreferences`), so there is no way to test the row rules without a device. A small `PermissionProbe` (with a real default) provides: exact-alarm state, battery state, DND state, overlay state, notification state, location state, `isEmuiDevice`, and the app mode. A pure function `buildPermissionRows(probe, ...)` returns the rows and states.
*   **The third state and its summary logic** in the model and the page (above).
*   **Rules per row** (app mode for overlay and location, EMUI for Auto-launch; the exact-alarm row is always built) in one place.
*   **Tests** (below); the page has none today (VERIFIED: `test/core/widgets` has only `prayer_card_test.dart` and `tutorial_overlay_test.dart` on `main`; no test mentions `PermissionDialogHandler` or `_PermissionsPage`).

**Prerequisite:** the Auto-launch row uses `isEmuiDevice` and `showAutoLaunchDialog`, which exist only on `fix/boot-start-service`. Implementation starts after that branch is merged into `main` (or this branch is rebased onto it). Until then the code for that row cannot compile on `main`.

## Strings (new keys in BOTH `assets/translations/en.json` and `ar.json`, via `.tr()`; the Arabic is a DRAFT until the owner has read it, final choice 5)
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
| `permissions_denied_hint` | If it stays off, turn it on in the app's settings. | إن بقي الإذن مغلقًا، فعّله من إعدادات التطبيق. |

Reused, no new key: `notification_permission_title` / `_desc`, `location_permission_title` / `_desc` (`en.json:193-196`), `auto_launch_title` / `auto_launch_subtitle` (on `boot`), and the existing Arabic map entries in `_PermTile` (`:460-461,477-478`).

## Tests (write first, red run shown before any code)
There is no test for the page today. Pure and widget tests, with a fake `PermissionProbe`:
1.  **Row rules (pure):** exact alarm always built (reads granted when the probe says granted, which is always true below Android 12); overlay only when the app mode is not `prayer_only` (`needsTasks`, `:71`); location only when the mode is not `tasks_only` (`needsPrayer`, `:70`); DND group is Focus Mode when tasks are in the mode, else Prayer; Auto-launch only when `isEmuiDevice`; notification always; no full-screen-intent row; no storage row.
2.  **States (pure):** each row's state follows its probe value; Auto-launch is always `checkByHand`, never `granted`.
3.  **Summary (pure):** all granted gives "All set"; all granted plus an Auto-launch row gives "All set, plus one item to check by hand"; any missing gives "Some permissions are missing"; a `checkByHand` row alone never turns the summary to "All set".
4.  **Popup mode unchanged (pure):** the popup list has only the missing rows of the four existing checks, never Notifications, Location or Auto-launch, and is empty when all four are granted.
5.  **Page, show-everything (widget):** back arrow present; granted rows show "Granted", missing rows an Enable button; the Auto-launch row shows "How to check" and the button calls the dialog open callback once; resume with a changed fake state flips a granted row to missing and back (all rows, not only ungranted); Enable on a row whose request is not granted calls the row's open-settings callback (permanent denial path); Arabic at 360 dp: no overflow.
6.  **Page, popup mode (widget):** no back arrow; rechecks only ungranted rows on resume (current behavior pinned before the change).
7.  **Strings:** the nine keys in both files, not empty; no ASCII digits in the Arabic.
8.  **Denied hint (widget):** after Enable on a Notifications or Location row that ends not granted, `permissions_denied_hint` shows under that row and the open-settings callback is called; before any attempt it is not shown; a granted row never shows it.

**Device-only (nova 5T, Android 10, Huawei) and not testable here:**
*   The Settings tile opens the page; Android 10 shows no exact-alarm row.
*   Granting and revoking Notifications, Location, Battery, DND and overlay in system settings and returning: rows update on resume.
*   Permanent denial of Location and Notifications: Enable opens Aura's App info.
*   The Auto-launch row shows "Check by hand", the dialog opens, and the summary reads "All set, plus one item to check by hand" when every readable row is granted.
*   Arabic RTL layout and wording.
*   Not testable: Android 12+ (exact-alarm row showing a real state, Android 13 notification prompt) and non-Huawei phones (no Auto-launch row); no such device is available.

## Behavior by Android version and phone
*   **Android 10 (the owner's phone):** the exact-alarm row shows "Granted" (final choice 1; `canScheduleExactAlarms` is always true below Android 12, `MainActivity.kt:556-562`). Notifications has no runtime prompt (GUESS). Location offers "allow while using" (GUESS). Huawei: the Auto-launch row appears.
*   **Android 12 and later:** the exact-alarm row shows the real state and links to the system screen (`openExactAlarmSettings`, `MainActivity.kt:564`). Android 13 and later: the Notifications request shows a system dialog; once denied permanently it falls back to App info. Android 11 and later: an "only this time" location grant may read as missing again on the next open (GUESS). Not run on any device here.
*   **Non-Huawei phones:** no Auto-launch row (`isEmuiDevice` is false). Honor is not treated as EMUI (the manufacturer check is "HUAWEI" only, `boot` spec section 3a).
*   **Windows and other desktops:** the popup returns early off Android and iOS (`:42`) and the new tile is Android only, so desktop is unaffected (VERIFIED code path; not run).

## Not done here
*   **No full-screen-intent row** (decision 5). `USE_FULL_SCREEN_INTENT` is declared (`AndroidManifest.xml:16`), nothing reads its state in code (VERIFIED by grep).
*   **Storage permissions are untouched.** `WRITE_EXTERNAL_STORAGE` (max SDK 28), `READ_EXTERNAL_STORAGE` (max SDK 32) and `READ_MEDIA_AUDIO` are declared (`AndroidManifest.xml:32-36`) and never requested; adhan files go to the app documents folder (`adhan_downloads_screen.dart:153,257`). Removing them is a **separate manifest cleanup**, with its own spec and gate (GUESS that they are unneeded; not tested). `INTERNET` is also declared twice (`:3,:37`), harmless, part of the same cleanup.
*   No change to the popup timing, to what the popup lists, or to when it shows (`:33-35`).
*   No migration of the page's existing `isArabic ?` literals to `.tr()`.
*   No state badge on the Settings tile (it would need an async check on every Settings open; possible later).

## Phase and gate
*   **Phase PS1 (approved by Aladdin on 2026-11-14, given as: 'approve the permissions spec and phase PS1, with those choices'; NOT started):** Level C (production: `lib/`, `assets/`, test cases; no `android/` and no `.project-docs/contracts/` change after final choice 1).
*   **Prerequisite (why PS1 has not started):** `fix/boot-start-service` must be merged into `main` first (PR #22 is open, not merged); `isEmuiDevice` and `showAutoLaunchDialog` and the Auto-launch strings exist only on that branch (VERIFIED: not on `main`). Implementation starts after the merge, on this branch rebased onto `main`.
*   **Order:** tests first (red run shown), then separate commits: (1) the probe, the row model, the pure rules and summary; (2) the page: show-everything mode, states, summary, back arrow, denied hint, `.tr()` fallback; (3) the public wrapper, the Settings tile and the strings. `flutter test`, `flutter analyze` after each commit, numbers against the baseline.
*   **Review size:** touches no "edit carefully" file (VERIFIED: the list is `prayer_times_service.dart`, `prayer_times_provider.dart`, `PrayerAlarmReceiver.kt`, `DailySummaryReceiver.kt`), no native change and no contract change, so one lightweight review.
*   **Decided by the owner (2026-11-14):** the Android version approach (no native method), Location hidden in tasks-only mode, Notifications and Location out of the popup, and the denied-permission line. **Still open:** the Arabic wording (DRAFT, awaiting the owner's reading).

## Device results (2026-11-15, reported by Aladdin; not observed by Claude)
Supersedes the "PS1 is not started" and "Not pushed" statements above: PS1 is implemented (commits `a6b49ad`, `8fe6089`, `fa8138d`) and `fix/boot-start-service` is merged (`db78e98`, PR #22).

*   **Build:** test build `test/all-edits-final4` (tip `f701741`, merges this branch), installed on the phone (nova 5T, Huawei, Android 10) on 2026-11-15.
*   **Reported by Aladdin: all 8 checks PASSED.** Claude did not run or watch these checks.
    1.  The Settings "Permissions" tile opens the page in show-everything mode.
    2.  Every row shows its state: Notifications and Location granted; exact alarms shown as "Granted" on Android 10.
    3.  The EMUI Auto-launch row shows "Check by hand", never "granted", and opens the explanation dialog.
    4.  The summary at the top.
    5.  Rows recheck after returning from the system settings.
    6.  The denied-permission line.
    7.  The automatic popup. First attempt: it did not appear, because Aura was still on the battery whitelist and nothing counted as missing (read-only investigation, 2026-11-15: not a regression; trigger code matches `main`). After Aladdin changed the phone state himself (battery whitelist off), it showed and Enable opened the system battery dialog: PASS.
    8.  The "Fire test adhan" tile and the reader top bar still work.
*   **Arabic strings: still DRAFT.** Aladdin has not said he has read or approved them.
*   **Not covered by any test (UNVERIFIED by tests):** `PermissionDialogHandler` itself (the 2 s delay, the `mounted` check, the push of the page); the row and page tests use a fake probe. Android 12+ and non-Huawei phones were not tested (no device).
