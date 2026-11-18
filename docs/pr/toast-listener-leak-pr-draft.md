# PR title: Release the previous adhan toast so one press runs one callback

Base branch: `fix/tray-double-fire` (the tray PR). Head: `fix/toast-listener-leak` (tip `6d2f266`). Third of three stacked PRs. After the two below it are merged, retarget this PR to `main`.

Every `LocalNotification` in `local_notifier` 0.1.6 registers itself as a plugin listener when it is created (`lib/src/local_notification.dart:20`) and stays registered until `destroy()` (`lib/src/local_notifier.dart:119-123`). A toast button press is sent to every listener with a matching identifier (`local_notifier.dart:32-57`, and `local_notification.dart` `onLocalNotificationClickAction`). All VERIFIED in code. Adhan toasts reuse one identifier per prayer (`adhan_fajr`, ...) and our code never called `destroy()`, so after N adhan toasts one press of "Stop Adhan" or "Prayed ✓" ran N callbacks: N `stop()` calls and N prayer records.

Marks used below: VERIFIED (read in code or in a captured log), REPORTED (told by the owner), NOT RUN.

## 1. What changed in code

Three commits: `4f7da95` (code and test), `637ea97` and `6d2f266` (docs).

*   **`lib/core/services/desktop_notification_service.dart` (+26).** `_showSystemToast` takes `releasePrevious` (default false). When set, the previous toast with the same identifier is destroyed before the new one is created; if `destroy()` fails, its listener is still removed. Only `showAdhanNotification` passes `releasePrevious: true`. The toast's button handler and every other toast type are unchanged.
*   **New test `test/core/services/desktop_adhan_toast_release_test.dart` (2 cases).** Three adhan toasts for one prayer leave one listener and two close calls; toasts of different prayers do not release each other. VERIFIED: the first case failed before the fix (expected 2 releases, got 0) and passes after.
*   **Docs (`637ea97`, `6d2f266`):** the A1 spec (`docs/designs/desktop-single-adhan-popup.md`) now records the A2 device results, the owner's decision on step 6, the findings below and the follow-ups; plus `STATE.md` and the 2026-11-16 log. They sit on this branch because the device run happened after the A1 branch was committed.

## 2. Tests

*   `flutter analyze`: 408 issues, 0 errors (unchanged).
*   `flutter test`: 811 passed, 0 failed (809 + 2 new).
*   `flutter build windows --release`: the first attempt FAILED at the install step (`MSB3073` in `INSTALL.vcxproj`) while `aura_app.exe` was running (VERIFIED; the cause, a locked exe, is a GUESS); passed after closing it (44 s, exit code 0).
*   Android build: NOT RUN for this PR. The file is imported by shared code (`main.dart`, `task_service.dart` and others) but the toast code is guarded by `isDesktop`; `flutter analyze` compiles it with 0 errors.

## 3. Device results (2026-11-16, build of `4f7da95`, PID 4608)

*   **Before the fix (REPORTED from earlier runs; those logs were overwritten and are not kept):** the stop errors came in bursts of about 90. The mechanism that produces them is VERIFIED in code (see the first paragraph).
*   **After the fix:** `[TOAST] released previous id=adhan_fajr` appeared before every repeat toast, 14 times, with 0 release or toast failures (VERIFIED in the log).
*   **One press, one callback:** each button press logged exactly one `Error stopping adhan` line, at least 12 at the last log read (VERIFIED in the log; the run continued after that count and was not recounted).
*   **"Prayed ✓" on the fourth `adhan_fajr` toast:** exactly one `Recorded Fajr` line (VERIFIED in the log). By the mechanism above, before the fix that press would have recorded four times; that was not observed. The sound stopped (REPORTED).
*   The full A2 table is in the A1 PR and in the spec section "A2 results".

## 4. Known limits and findings

*   **Only the adhan toast is released.** The other toasts have the same leak (VERIFIED in code, not tested on the device): the post-prayer check (`post_prayer_<prayer>`) records its status once per toast ever shown, the task reminder (`task_<id>`) runs "Mark Done" once per toast; pre-prayer, Wird and daily-digest toasts have it with harmless callbacks. Not changed here; needs its own spec.
*   **30 s stop timeout remains** (cause UNKNOWN), and **the tray "Stop Adhan" item** still disappears when playback starts (A1 step 6, accepted by the owner). Both are in the follow-up `fix/adhan-stop` (NOT STARTED).
*   **A2 step 8 is NOT RUN** (other popups unchanged; to be checked at the next real reminder or task reminder).
*   **Other findings recorded in the spec (not part of this PR):** the Windows location is the hard-coded Makkah fallback; a reload after the adhan cancels that prayer's post-prayer check (older behavior).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
