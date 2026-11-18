# PR title: Show one adhan popup on Windows (toast only)

Base branch: `main`. Head: `fix/desktop-single-adhan-popup` (tip `c986d06`). First of three stacked PRs; merge order, bottom first: this one, then `fix/tray-double-fire`, then `fix/toast-listener-leak`.

When the adhan fired on Windows, two popups appeared: the Windows toast and an in-app "Prayer Time" card inside the Aura window (REPORTED by the owner with a screenshot, 2026-11-16). The owner decided to keep only the toast. Spec: `docs/designs/desktop-single-adhan-popup.md` (phase A1).

Marks used below: VERIFIED (read in code or in a captured log), REPORTED (told by the owner, not observed by Claude), NOT RUN.

## 1. What changed in code

Three commits: `22cdb94` (spec), `7c0f406` (code), `c986d06` (docs).

*   **`lib/features/main/main_wrapper_screen.dart` (-196 lines, none added).** Removed the `prayerTimeStream` subscription (field, listener, cancel), `_showAdhanOverlay`, the `_AdhanOverlay` and `_AdhanOverlayState` classes, and the import that became unused. Every use was checked by search over `lib/` and `test/` first (spec, Approach 1). `_showAdhanOverlay` also called `windowManager.show()`, so a window hidden in the tray no longer comes back at adhan time (the owner wants this).
*   **`lib/core/services/desktop_notification_service.dart` (+8 -4).** The toast's "Prayed ✓" button now also stops the adhan, as the removed card's button did. Two doc comments that described the removed overlay were corrected. No other change.
*   **Unchanged on purpose:** `desktop_prayer_scheduler.dart` (`prayerTimeStream` stays, now with no listener), the other desktop popups, the temporary quit file log, everything on Android.
*   **Docs:** the spec, `lib/features/main/README.md` (no longer mentions the removed overlay), `STATE.md` and the 2026-11-16 log.

## 2. Tests

*   `flutter analyze`: 408 issues, 0 errors (main before this change: 409; one issue fewer, GUESS: the `withOpacity` notice on the removed card).
*   `flutter test`: 806 passed, 0 failed (unchanged). No new test: the toast action is a closure over platform singletons with no fake in the project (owner's decision, spec Open Question 2).
*   `flutter build windows --release`: passed (68 s, exit code 0).
*   `flutter build apk --release --obfuscate --split-debug-info=build/debug-info`: passed (177 s, exit code 0); `main_wrapper_screen.dart` is shared with Android. Not installed on a device.

## 3. Device results (A2, 2026-11-16)

Run on ONE Windows release build of commit `4f7da95`, which contains this PR plus the two PRs stacked on it (tray fix, toast fix). It was not run on this PR's tip alone. PID 4608, output captured to a file.

| Step | Result |
|---|---|
| 1. One popup per adhan, no in-app card | One toast per event: VERIFIED in the log (16 toasts for 16 adhan plays: 15 Test Notification clicks and the real Isha). No in-app card: REPORTED ("only toast", screenshot). |
| 2. Toast "Stop Adhan" stops the sound | REPORTED (stops in under 1 s). |
| 3. Toast "Prayed ✓" | Stops the sound: REPORTED. Records once: VERIFIED in the log. |
| 4. Hidden window stays hidden | VERIFIED: `visible=False` after the adhan fired with the window closed by X (checked after the adhan, not at the instant it fired). |
| 5. Notification Center "Stop Adhan" | Stops the sound: REPORTED. One stop call: VERIFIED in the log. The buttons are behind the arrow on the collapsed card. |
| 6. Tray "Stop Adhan" during the adhan | FAILS as built (VERIFIED in the log). Accepted by the owner for A1. |
| 7. A real prayer time | VERIFIED in the log: real Isha 18:51, one toast, one adhan. |
| 8. Other popups unchanged | NOT RUN. To be checked at the next real reminder or task reminder. |

## 4. Known limits

*   **Step 6 FAILS as built (VERIFIED in the log) and is accepted by the owner for A1:** the tray "Stop Adhan" item is added and removed again as soon as playback starts, because `desktop_prayer_scheduler.dart:85-87` and `:110-112` clear the playing flag when `playAdhan` returns, which is when playback starts, not when it ends. Older behavior (`findings.md:135`), not caused by this PR. The toast and the same toast in the Notification Center are the stop controls. Follow-up: `fix/adhan-stop` (NOT STARTED, needs its own approval).
*   **No toast, no control:** if Windows notifications are off for Aura, or Do Not Disturb hides the toast, nothing on screen can stop the adhan. Before this PR the in-app card covered that case. Accepted by the owner.
*   **Step 8 is NOT RUN.**
*   **30 s stop timeout:** every stop logs `Error stopping adhan - TimeoutException after 0:00:30` about 30 s after the press, although the sound stops (REPORTED). Cause UNKNOWN; part of `fix/adhan-stop`.
*   **Spec status in this PR:** the spec here says A1 is built and A2 is not run. The A2 results and findings are recorded in the spec by the third PR (`fix/toast-listener-leak`), because the device run happened after this branch was committed.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
