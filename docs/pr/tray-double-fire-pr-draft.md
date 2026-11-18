# PR title: Run tray Test Notification and Stop Adhan once per click

Base branch: `fix/desktop-single-adhan-popup` (the A1 PR). Head: `fix/tray-double-fire` (tip `93ca04c`). Second of three stacked PRs. After the A1 PR is merged, retarget this PR to `main` (GitHub does it automatically if the A1 branch is deleted on merge).

The tray plugin reports one menu click twice: the item's `onClick`, then `onTrayMenuItemClick`, in the same synchronous run (`tray_manager` `lib/src/tray_manager.dart:61-64`, VERIFIED). Both paths called `fireTestAdhan()` and `DesktopAdhanService.stop()`, so one "Test Notification" click showed two toasts and started the adhan twice. This was already known (`findings.md:135`); the Quit item had been guarded earlier in `docs/designs/tray-quit-fix.md`, the other two items had not.

Marks used below: VERIFIED (read in code or in a captured log), REPORTED (told by the owner), NOT RUN.

## 1. What changed in code

One commit, `93ca04c`. Only `lib/core/services/desktop_tray_service.dart` (+50 -8) and one new test file.

*   New `SameTurnGuard`: lets a key through once per event-loop turn, so the duplicate call of one click is ignored and the next click runs. The Quit guard (`RunOnceGuard`) could not be reused, because it blocks every call after the first for the life of the app.
*   `_fireTestAdhanFromMenu()` and `_stopAdhanFromMenu()` check the guard and log `second call ignored`. The item's `onClick` and the listener switch both call them.
*   Unchanged: Quit and its guard, "Open Aura" (still called twice, harmless), the menu, the temporary quit file log.
*   New test `test/core/services/desktop_tray_same_turn_guard_test.dart` (3 cases): duplicate in the same turn blocked; next click in a later turn runs; keys independent.

## 2. Tests

*   `flutter analyze`: 408 issues, 0 errors (unchanged).
*   `flutter test`: 809 passed, 0 failed (806 + 3 new).
*   `flutter build windows --release`: passed (101 s, exit code 0).
*   Android build: NOT RUN for this PR. The file is desktop-only (guarded by `isDesktop`), and `flutter analyze` compiles it with 0 errors.

## 3. Device results

*   **Before the fix (REPORTED from earlier runs; those logs were overwritten and are not kept):** every Test Notification click (6 of 6) logged one `menu click: test_notif` line, then two `[TOAST] show` and two `Playing bundled adhan` lines. The mechanism that causes it is VERIFIED in code (`tray_manager.dart:61-64`, and the two call sites in `desktop_tray_service.dart`).
*   **After the fix, build of `4f7da95` (this PR plus the other two), PID 4608:** 15 Test Notification clicks gave 15 Fajr toasts and 15 adhan plays, plus the real Isha (16 toasts, 16 plays in total): VERIFIED in the log.
*   **`stop_adhan` guard:** NOT RUN on the device; the tray "Stop Adhan" item is never on screen long enough to click (see Known limits). Covered by the unit test only.

## 4. Known limits

*   The tray "Stop Adhan" item still disappears as soon as playback starts (A1 spec, step 6). This PR makes its click run once; it does not make the item stay. Follow-up: `fix/adhan-stop` (NOT STARTED).
*   The "Test Notification" item is to be removed after the A1 device check (`chore/remove-test-notification`, NOT STARTED); the `test_notif` guard is then unneeded.
*   Not run on its own: the device results above come from the combined build.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
