# Chore: hide the tray "Test Notification" item in release builds (desktop)

*The file name `chore-remove-test-notification.md` is kept from the earlier plan to remove the item.
The change is to hide it in release builds (Decision 5).*

*   **Author:** Alaa Eldin Tarek (drafted with Claude)
*   **Status:** Implemented on branch `chore/hide-test-notification-release` on 2026-11-17 (owner's "approve phase"); merged via PR #40 on 2026-11-17 (merge commit 8513586). Owner's Windows checks: release REPORTED pass, debug log-confirmed (owner has not yet observed the tray or heard the adhan). See "Results".
*   **Date:** 2026-11-16
*   **Level:** C (production code: `lib/`, `test/` cases; needs this spec approved and the phrase
    "approve phase", per `CLAUDE.md` Rules). This file itself is Level A (docs).
*   **Branch:** `chore/hide-test-notification-release` from `main` (not created yet; created only after the
    owner says "approve phase").
*   **Platform:** Desktop only: the `isDesktop` guard in `desktop_tray_service.dart` covers Windows,
    macOS and Linux. The device check is on Windows. Android must not change.

--------------------------------------------------------------------------------

## Overview

The desktop tray menu has a "🔔 Test Notification" item. It plays the Fajr adhan and shows the adhan
toast on demand. The one-adhan-popup work (`docs/designs/desktop-single-adhan-popup.md`, PRs #34 to
#37) is finished and merged. The owner first decided on 2026-11-16 to remove the item; the same
day he reopened that decision (Decision 5): the owner uses the item to debug notifications and
the adhan. This chore now hides the item in release builds and keeps it in debug builds, with one
compile-time check, `kDebugMode`.

## The Problem

A menu item that plays the adhan is a risk in a shipped build: one wrong click starts the adhan on a
user's PC. The same item is useful in debug builds for testing notifications and the adhan by hand.
Today one build behaves the same in both modes, so a release build ships the item. The fix is to
build the menu without the item (and its separator) unless the build is a debug build. The click
handler, the `test_notif` guard key and `fireTestAdhan()` stay, because debug builds use them.

## Goals

*   In release builds the tray menu no longer shows "Test Notification". The release menu is: next
    prayer, separator, (Stop Adhan and its separator while the adhan plays), Open Aura, separator,
    Quit. In debug builds the menu is unchanged and still shows "Test Notification" and its
    separator. The choice is made by one compile-time check, `kDebugMode`
    (`package:flutter/foundation.dart`, already imported in `desktop_tray_service.dart`): the item
    is shown only when `kDebugMode` is true. Profile and release builds both hide it.
*   The `test_notif` code stays (the menu item, its separator, the `case 'test_notif'` branch,
    `_fireTestAdhanFromMenu` with its guard key, and the import of `desktop_prayer_scheduler.dart`):
    debug builds still use it. Only the two `buildMenu` entries become conditional.
*   `DesktopPrayerScheduler.fireTestAdhan()` is unchanged and still has a caller in debug builds
    (the tray handler `_fireTestAdhanFromMenu`). The scheduler file is not edited.
*   The menu-ids test covers both build modes (item hidden and item shown), and the suite stays
    green (baseline: `flutter test` 811 passed, `flutter analyze` 408 issues, 0 errors).

## Non-Goals

*   No change to the file `desktop_prayer_scheduler.dart`, including `fireTestAdhan()` and the
    playing-flag lines (`:85-87` and `:110-112`). `desktop_tray_service.dart` keeps its import of
    it. The line numbers cited in `docs/designs/desktop-single-adhan-popup.md` stay valid and that
    spec is not edited.
*   No change to debug-build behavior: the item, its label, its position and its click handling
    stay as they are. Only the two entries in `buildMenu` become conditional.
*   No change to the adhan stop path: `_stopAdhanFromMenu`, `setAdhanPlaying`, and the Stop Adhan
    item stay exactly as they are. Fixing the Stop Adhan item is the separate
    `fix/adhan-stop` follow-up.
*   `_clickGuard` (`SameTurnGuard`) stays: Stop Adhan uses it.
*   No change to the toast, the notification service, `DesktopAdhanService`, or any Android file.
*   No change to the Profile "test adhan" tool (PR #24). It is a different feature: it uses
    `PrayerAlarmService.testAdhanNow`, not the desktop scheduler.
*   No translation keys are removed. The `test_notification*` keys in `en.json` and `ar.json` are
    not used by this item (its label is hard-coded English) and this chore does not touch them.
*   No removal of the temporary `tray_quit_log.txt` file log. That is a separate follow-up.

## Decisions

*   **Decision 1 (closed): `fireTestAdhan()`.** Kept, unchanged. It still has a caller in debug
    builds, the tray handler `_fireTestAdhanFromMenu` (VERIFIED by search in `lib/` and `test/`),
    and any change to it belongs to `fix/adhan-stop`.
*   **Decision 2 (closed): `fix/adhan-stop` device checks.** Debug builds keep the item, so
    `fix/adhan-stop` can start the adhan on demand there; a release build needs a real prayer time.
*   **Decision 3 (closed): `desktop_tray_same_turn_guard_test.dart`.** No change; it uses
    `'test_notif'` only as a sample key string (VERIFIED by reading).
*   **Decision 4 (closed): other docs.** `lib/core/services/README.md:41` stays correct, the A1 spec
    is not edited (its device steps stay valid for debug builds), and only the usual STATE and log
    entries are added.
*   **Decision 5 (decided 2026-11-16): hide the item in release builds instead of removing it.** The
    owner first decided to remove it, then reopened that decision because the owner uses the item
    to debug notifications and the adhan. The item is shown only when `kDebugMode` is true, so
    profile and release builds both hide it (Alternative D covers `!kReleaseMode`). The branch is
    `chore/hide-test-notification-release`.

## Technical Plan (Architecture)

One file of production code changes: `lib/core/services/desktop_tray_service.dart`. The change is
small and adds one parameter. The menu is still built from the same reused items, so ids stay
stable (`docs/designs/tray-quit-fix.md`, "T3 result and T2b").

**Changed in `desktop_tray_service.dart`** (line numbers on main 96ddbcc):

*   `buildMenu` (`:157`) gets a new named parameter `bool includeTestItem = kDebugMode`.
    `kDebugMode` is a compile-time constant from `package:flutter/foundation.dart` (already
    imported, `:3`), so it is allowed as a default value. The existing parameters `nextLabel` and
    `adhanPlaying` do not change.
*   In the list inside `buildMenu`, the two entries `_testNotifItem` and `_sepAfterTestNotif`
    (`:166-167`) each get the same collection-if form the Stop Adhan entries already use:
    `if (includeTestItem) _testNotifItem,` and `if (includeTestItem) _sepAfterTestNotif,`.
*   The caller `_rebuildMenu` (`:172-183`) does not pass the parameter, so production code always
    uses the default: `kDebugMode`.

**Kept unchanged:** `_testNotifItem` (`:132-139`), `_sepAfterTestNotif` (`:148`),
`case 'test_notif':` (`:209-211`), `_fireTestAdhanFromMenu` and its guard key (`:252-260`), the
import of `desktop_prayer_scheduler.dart` (`:10`), `_stopAdhanFromMenu`, `_clickGuard`,
`_openItem`, `_quitItem`, the other separators, `setAdhanPlaying`, `_quit`. The file
`desktop_prayer_scheduler.dart` is not opened for edit. The fields `_testNotifItem` and
`_sepAfterTestNotif` are `late final`, so they are built only when first read. The `🔔 [TRAY]` log
prefix and the `test_notif` log lines stay; no log-tag contract lists them (VERIFIED: no `TRAY`
line in `.project-docs/contracts/`).

```text
Debug build (unchanged)   Release build (idle)     Release build (adhan playing)
Next: Asr at 3:16 PM      Next: Asr at 3:16 PM     Next: Asr at 3:16 PM
------------              ------------             ------------
Open Aura                 Open Aura                🔇 Stop Adhan
------------              ------------             ------------
🔔 Test Notification      Quit                     Open Aura
------------                                       ------------
Quit                                               Quit
```

In a debug build with the adhan playing, the menu is the debug column with Stop Adhan and its
separator added after the first separator, as today.

**Behavior after the change:** a release build has no menu item that starts the adhan. A prayer
time still plays it through the scheduler timer, unchanged. A debug build behaves exactly as
today. The Stop Adhan item behaves as before in both modes, including its known fault (it fails
as built; see "A2 step 6 result" in `docs/designs/desktop-single-adhan-popup.md`), which
`fix/adhan-stop` will fix.

**Risks & Mitigations:**

*   Risk: the `case 'test_notif':` branch, `_fireTestAdhanFromMenu` and the scheduler import are
    still compiled into release builds. Mitigation: they cannot be reached there, because no item
    with the key `test_notif` is in the release menu. Test R4 (the release-mode menu test) checks the menu built
    with `includeTestItem: false`; the release default itself is covered by the release-build
    device check.
*   Risk: profile builds also hide the item. Mitigation: the check is `kDebugMode`, which is true
    only in debug builds, and no profile build is shipped.

**Tests** (`test/` cases are Level C, same approval). Only `desktop_tray_menu_ids_test.dart`
changes: the existing tests keep pinning the menu with the item, and a new release-mode group pins
the menu without it. The tests are described once, in the Detailed Implementation Plan.

## Alternatives Considered

### Alternative A: Remove the item entirely (the earlier plan)

*   **Pros**: No test-only item in any build. The code for it (item, separator, handler case,
    guard key, and the scheduler import) goes away.
*   **Cons**: Removes the only on-demand adhan trigger on Windows, including for the owner's own
    debug builds. Manual adhan testing then needs a real prayer time or `fix/adhan-stop`. It also
    leaves `fireTestAdhan()` with no caller.
*   **Reason for Rejection**: Rejected by author (2026-11-16, Decision 5): the owner uses the
    item to debug notifications and the adhan, so it stays in debug builds.

### Alternative B: Remove the item and also `fireTestAdhan()`

*   **Pros**: No dead code is left.
*   **Cons**: With the item kept in debug builds (the chosen plan), `fireTestAdhan()` has a caller,
    so removing it would break the debug item. It would also edit the scheduler file, which the A1
    spec cites by line number.
*   **Reason for Rejection**: Rejected by author: the item stays in debug builds, and its handler
    needs `fireTestAdhan()`. Any later change to that method belongs to `fix/adhan-stop`.

### Alternative C: Keep the item and fix its remaining faults instead

*   **Pros**: No loss of the on-demand trigger.
*   **Cons**: The risk in the Problem section (one wrong click starts the adhan on a user's PC)
    stays in release builds.
*   **Reason for Rejection**: Rejected by author: "keep and fix" does not fit this chore, because
    the remaining fault is the Stop Adhan fault, and the fix for that belongs to `fix/adhan-stop`.

### Alternative D: Show the item in every non-release build (`!kReleaseMode`)

*   **Pros**: The item is also available in profile builds.
*   **Cons**: It also shows the item in profile builds. We do not ship profile builds, and a
    profile build would need its own check.
*   **Reason for Rejection**: Rejected by author: it also shows the item in profile builds, which
    we do not ship and which would need their own check. `kDebugMode` hides the item in every
    build except debug.

### Follow-ups for `fix/adhan-stop`

*   **The idea**: add these to the `fix/adhan-stop` entry (spec and STATE.md): (1) `fix/adhan-stop` reproduces
    the Stop Adhan fault with the debug-build Test Notification item; (2) when it changes the
    playing-flag lines (`desktop_prayer_scheduler.dart:85-87`, `:110-112`) it keeps the real timer
    and `fireTestAdhan()` consistent; (3) if it ever removes `fireTestAdhan()`, it removes the tray
    item and its handler in the same change; (4) the Stop Adhan fault stays as it is in this chore
    (it fails as built, see "A2 step 6 result" in the A1 spec), and `fix/adhan-stop` owns it; (5) a
    fix for that fault can be reproduced in debug builds but not triggered on demand in a release
    build, so `fix/adhan-stop` confirms the fix in a release build at a real prayer time.

--------------------------------------------------------------------------------

## Detailed Implementation Plan

The line numbers below are on main 96ddbcc and were re-checked on 2026-11-16 (`lib/` and `test/` had
no diff against the branch where this spec was written). At the start of the implementation phase,
check them again and re-run the baselines: `flutter test` 811 passed, `flutter analyze` 408 issues
with 0 errors.

### Target Files to Create/Modify

#### 1. `lib/core/services/desktop_tray_service.dart` (Modify)

*   **Type / Scope**: Dart service for the desktop tray, desktop-only code path (the `isDesktop`
    guard covers Windows, macOS and Linux). No Android file is touched. Only `buildMenu`
    (`:154-170`) changes.
*   **Proposed Changes** (no deletions; one new parameter and two conditions):
    1.  In the list inside `buildMenu` (`:166-167`), change `_testNotifItem,` to
        `if (includeTestItem) _testNotifItem,` and `_sepAfterTestNotif,` to
        `if (includeTestItem) _sepAfterTestNotif,`. Make this edit first, because it is lower in
        the file.
    2.  Change the signature (`:157`) to
        `Menu buildMenu({required String? nextLabel, required bool adhanPlaying, bool includeTestItem = kDebugMode})`
        and let `dart format` wrap it.
    3.  Add one sentence to the doc comment above `buildMenu` (`:154-155`): the Test Notification
        item and its separator are in the menu only when `includeTestItem` is true, and it
        defaults to `kDebugMode`, so only debug builds show the item.
    4.  Do not touch `_rebuildMenu` (`:172-183`). It calls `buildMenu` without the parameter, so
        production code uses the default.
    5.  Run `dart format lib/core/services/desktop_tray_service.dart` and keep the file as the
        formatter writes it.

#### 2. `test/core/services/desktop_tray_menu_ids_test.dart` (Modify)

*   **Type / Scope**: Unit test (Level C, because it is a `test/` case). The only function under
    test is `DesktopTrayService.buildMenu`.
*   **Proposed Changes**:
    1.  Add `import 'package:flutter/foundation.dart' show kDebugMode;` next to the other imports
        (`:1-3`).
    2.  Leave the existing group `DesktopTrayService.buildMenu` and its four tests (`:19-98`)
        untouched: no rename and no edit to any existing `buildMenu` call. They run in debug mode,
        so the default already gives the menu with Test Notification.
    3.  Add one new group in the same file, named exactly this string:

        `DesktopTrayService.buildMenu, release build (Test Notification hidden)`

        The group holds exactly two new tests, R4 (the release-mode menu test) and D1 (the default test).
    4.  R4 (the release-mode menu test) calls `buildMenu(..., includeTestItem: false)` and checks the exact key order and the
        labels, and that no item has the key `test_notif`. Idle: keys
        `next_prayer, null, open, null, quit`, labels `Next: ...`, `Open Aura`, `Quit`. Adhan
        playing: keys `next_prayer, null, stop_adhan, null, open, null, quit`, and
        `playing.items![2].label` is `'🔇 Stop Adhan'`.
    5.  D1 (the default test): a `buildMenu` call without `includeTestItem` returns the same keys as a `buildMenu` call
        with `includeTestItem: kDebugMode`. Tests run in debug mode, so D1 pins the default.

#### 3. Files read but NOT changed

*   `lib/core/services/desktop_prayer_scheduler.dart`: `fireTestAdhan()` stays (Decision 1).
*   `test/core/services/desktop_tray_same_turn_guard_test.dart`: no change (Decision 3).
*   `lib/core/services/README.md:41`: still lists `fireTestAdhan`, which stays. No README or module
    doc lists tray menu items (VERIFIED by a search of `lib/core/services/README.md` and
    `.project-docs/modules/desktop.md`).
*   `assets/translations/en.json` and `ar.json`: the tray label is hard-coded English, so no
    translation key changes.
*   `.project-docs/contracts/`: no prefs key, channel, notification ID or log tag changes.

#### 4. Docs after the code (Level A, in the same PR or a follow-up docs PR)

*   `.project-docs/STATE.md`: one line for this chore (result, test and analyze numbers), and update
    the follow-up line that lists `chore/remove-test-notification` as NOT STARTED, because the
    branch is now `chore/hide-test-notification-release`.
*   The `.project-docs/log/` file for the day the work is done: an entry with the commit hashes.
*   `docs/designs/chore-remove-test-notification.md`: the Status line and a results section.

### Verification Plan

Verification has seven items: build, unit tests, static analysis, test coverage, search, the
owner's release-build check and the owner's debug-build check. The first five belong to the
implementer; the last two are run by the owner.

*   **Compilation/Build**: `flutter build windows --release` passes. An Android release build is
    optional because no shared code is touched; if it is run, its result is reported either way.
*   **Unit Tests**: `flutter test` passes in full. The baseline is 811 passed. This chore adds
    exactly two tests (R4 (the release-mode menu test) and D1 (the default test), described in the Detailed Implementation Plan) and removes or
    renames none, so 811 + 2 = 813 passed are expected. Report the real number.
*   **Static Analysis & Linting**: `flutter analyze` reports no more than the baseline of 408
    issues and 0 errors. `dart format --output=none --set-exit-if-changed` passes on both changed
    files: `lib/core/services/desktop_tray_service.dart` and
    `test/core/services/desktop_tray_menu_ids_test.dart`.
*   **Test Coverage Requirement**: none beyond the menu-ids test.
*   **Search check**: after the edits, a search for `includeTestItem` in
    `desktop_tray_service.dart` finds only the parameter and the two conditions, and a search for
    `test_notif` in `test/` finds only the menu-ids test and the guard test's sample key.
*   **Release-build check (owner, Windows)**: The owner builds with
    `flutter build windows --release` and runs the built executable, because a debug run cannot
    show release behavior. The tray menu must show next prayer, Open Aura and Quit, with no Test
    Notification. Open Aura must bring the window back after X, and Quit must end the app
    (window, icon and process). This check is NOT RUN until the owner does it, and the result is
    recorded as REPORTED, not VERIFIED.
*   **Debug-build check (owner, Windows)**: The owner runs `flutter run -d windows`. The tray menu
    must show Test Notification, and clicking it must play the adhan and show the toast, as
    before. This check is NOT RUN until the owner does it, and the result is recorded as REPORTED,
    not VERIFIED.

## Results (2026-11-17)

*   Code commit b45fbf8; spec and review reports in commit bae6155. Branch from origin/main fad84b6.
*   `flutter analyze`: 408 issues, 0 errors (baseline 408). VERIFIED by a real run.
*   `flutter test`: 813 passed, 0 failed (baseline 811 + 2 new tests). VERIFIED by a real run.
*   `dart format --output=none --set-exit-if-changed` on both changed files: exit 0. VERIFIED.
*   `flutter build windows --release`: passed (70 s, exit code 0, aura_app.exe not running beforehand). VERIFIED.
*   Search check: `includeTestItem` appears in `desktop_tray_service.dart` only in the parameter, its doc comment and the two conditions; `test_notif` in `test/` appears only in the menu-ids test and the guard test's sample key. VERIFIED.
*   Release-build check: REPORTED pass by the owner on 2026-11-17 (not observed by Claude): the tray menu of the release build showed no Test Notification item.
*   Debug-build check (`flutter run -d windows`): log-confirmed that the item was in the menu and was clicked (`test_notif onClick fired`, `menu click: test_notif`), the toast `show` returned OK, and `Playing bundled adhan for Fajr` was logged. Owner has not yet observed the tray or heard the adhan.
*   Not run: the optional Android build.

--------------------------------------------------------------------------------

*Drafted with EGM*
