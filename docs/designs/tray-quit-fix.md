# Fix: tray "Quit" does not close the Windows app

- **Author:** Alaa Eldin Tarek (drafted with Claude)
- **Status:** T2 approved by the owner on 2026-11-16 ("approve phase T2 ... Option B, as written in the
  spec") and built; T3 (the owner's check) NOT RUN. The fix is not yet confirmed on a running app.
- **Date:** 2026-11-16
- **Level:** C (production code: `lib/`, `test/` cases; needs an approved spec and the phrase
  "approve phase T2", per `CLAUDE.md` Rules). This file itself is Level A (docs).
- **Branch:** `docs/tray-quit-spec` (from `main` at `c9f8ba8`, docs only). The code phase gets its own branch.
- **Platform:** Windows desktop only. Android is not touched.
- **Line references:** `main` at `c9f8ba8`; plugin sources from the pub cache (`tray_manager` 0.2.4,
  `window_manager` 0.3.9, `menu_base` 0.1.1, versions from `pubspec.lock`).
- **Marks:** VERIFIED (read in code, 2026-11-16), REPORTED (told by the owner, not observed by Claude),
  UNKNOWN (not checked), GUESS (inference).

--------------------------------------------------------------------------------

## Overview

On Windows, Aura keeps a tray icon with a right-click menu. Its last item, "Quit", should end the app.
The owner reports that it does nothing. This spec records the problem, the two possible causes, and the
owner's chosen fix: an orderly quit with a hard fallback and log lines that show where the quit stops.

--------------------------------------------------------------------------------

## Problem Statement

**REPORTED by Aladdin, 2026-11-16, Windows:** choosing "Quit" in the tray icon's right-click menu does
nothing visible. The window stays, the tray icon stays, and `aura_app.exe` stays in Task Manager. He has
to end it there.

**What the code does today (VERIFIED):**

- The menu is built in `lib/core/services/desktop_tray_service.dart:75-112`. The item is
  `MenuItem(key: 'quit', label: 'Quit', onClick: (_) => _quit())` (`:107-111`).
- `_quit()` (`:171-174`) calls `windowManager.setPreventClose(false).ignore()` without waiting, then
  `exit(0)` from `dart:io`. It does not remove the tray icon and does not destroy the window.
- **`_quit()` is called twice per click.** The plugin calls the item's `onClick` and then the listener's
  `onTrayMenuItemClick` (`tray_manager` `lib/src/tray_manager.dart:61-64`); the listener's switch also
  calls `_quit()` for `'quit'` (`desktop_tray_service.dart:142-143`).
- The X button is a different path: `setPreventClose(true)` (`:31`) and `onWindowClose` (`:154-157`)
  hide the window. Quit does not go through it.
- The native runner is the stock Flutter template. There is no single-instance mutex and no second
  window (`windows/runner`, VERIFIED by search).

**Cause: UNKNOWN.** Two hypotheses:

1. **`_quit()` is called and `exit(0)` hangs in native shutdown (GUESS).** `exit` runs the C runtime's
   exit handlers while several native plugins are loaded (Firebase C++ SDK, `audioplayers`,
   `local_notifier`, `tray_manager`, `window_manager`). A teardown that never returns would leave the
   window, the icon and the process in place. Not reproduced by Claude; no file in the repo or in the
   plugins' README/CHANGELOG mentions it (VERIFIED by search).
2. **The click is lost because the menu item ids go stale after a menu rebuild (VERIFIED path, not
   reproduced).** Each `_rebuildMenu()` creates new items with new ids (`menu_base`
   `menu_item.dart:15-22`). Dart replaces its menu at once (`tray_manager.dart:179`) and the native side
   builds a new menu handle (`tray_manager_plugin.cpp:281`). A menu already on screen still carries the
   old ids, so a click finds no item (`tray_manager.dart:58-59`) and nothing runs. Rebuilds come from
   `updateNextPrayer` (`prayer_times_provider.dart:189`, `:264`, with a 1-minute timer at `:133`) and
   `setAdhanPlaying`. This would explain an occasional dead click, not a failure every time (GUESS).

--------------------------------------------------------------------------------

## Goals

1. Choosing "Quit" ends the app: the window closes, the tray icon is removed, and `aura_app.exe` ends.
2. The log shows whether `_quit()` is reached and at which step it stops, so the cause can be named.
3. One click runs the quit once.

## Non-Goals

- **The stale-id dead-click path** (hypothesis 2). It is a separate small bug and is listed under
  Follow-ups.
- **A native `TerminateProcess` change in `windows/`.** Only if this fix is not enough, and as a
  separate decision by the owner.
- Any change to the X button (hide to tray), the menu items, their labels, or Android.

--------------------------------------------------------------------------------

## Decision

**Owner's choice, 2026-11-16: Option B, an orderly quit plus a hard fallback, with debug logging.**
(Option A was the same orderly quit without the fallback timer.)

`_quit()` in `desktop_tray_service.dart` changes as follows:

1. It becomes `async` and **guards against the double call**: a private flag is set on the first call,
   and a second call returns at once.
2. It waits a short moment (about 100 ms) so the tray menu is closed.
3. It starts the **fallback timer of about 2 seconds**, which calls `exit(0)`. It is started before the
   awaited steps so that a step that never returns cannot block it.
4. It awaits `trayManager.destroy()` (removes the icon).
5. It awaits `windowManager.setPreventClose(false)`.
6. It awaits `windowManager.destroy()`. On Windows this is `PostQuitMessage(0)`
   (`window_manager` `windows/window_manager.cpp:233`, VERIFIED), so the runner's message loop ends.
7. Each awaited step is in a `try-catch`; an error is logged and the next step still runs.

**Logging.** A `debugPrint` line at each step, in the file's existing convention (emoji prefix and the
`[TRAY]` tag, as in `✅ [TRAY] System tray initialized`): quit requested, second call ignored, menu wait
done, tray icon destroyed, preventClose off, window destroy called, fallback timer fired, and any error.
The exact texts are chosen in T2. UNKNOWN: whether `debugPrint` output is visible in a Windows release
build on the owner's PC.

**Temporary file log (owner's decision, 2026-11-16).** Because `debugPrint` may not be visible in a
Windows release build (UNKNOWN), T2 also writes a few lines to a small text file, ONLY on the quit path:
"quit clicked", "tray destroyed", "window destroyed" and "fallback fired", each with a timestamp. Nothing
else in the app writes to this file.

- **Folder:** the app's data folder from `getApplicationSupportDirectory()` (`path_provider`, already
  used at `lib/main.dart:10, 71` for the prefs backup, VERIFIED). On Windows the plugin builds it from
  the exe's version info, `CompanyName` = `com.aura` and `ProductName` = `aura_app`
  (`windows/runner/Runner.rc:92, 98`, VERIFIED), so the expected folder is
  `%APPDATA%\com.aura\aura_app` (GUESS from the plugin's rule). The real path on the owner's PC is
  UNKNOWN (not checked there; an MSIX install may redirect it). T2 prints the full path once with
  `debugPrint` and reports it.
- **File name (a detail of this draft):** `tray_quit_log.txt`. Lines are appended and each write is
  flushed at once, so a line survives a hang or a forced exit right after it. A write error is caught
  and never stops the quit.
- **Temporary:** T2 marks the file-log code for removal (a comment at the code and the follow-up item
  below). It is removed once the owner confirms the fix works.

**Order of step 3 (a detail of this draft, GUESS on the owner's intent):** the owner's text lists the
fallback timer last. This draft starts it before the awaited steps, for the reason given above. If the
owner wants it started last, T2 follows that.

--------------------------------------------------------------------------------

## Files Touched

| File | Change |
|---|---|
| `lib/core/services/desktop_tray_service.dart` | `_quit()` only, as above, plus the temporary file-log helper used only by it. Desktop-only: the service does nothing unless `isDesktop` (`:21-25`). |
| `test/` (new case, if possible) | A pure test of the double-call guard, if the guard can be extracted without changing behavior (for example a small function or class that runs an action at most once). |

**What cannot be tested without the Windows build:** that the menu click reaches `_quit()`, that
`trayManager.destroy()` removes the icon, that `windowManager.destroy()` ends the process, that the
fallback `exit(0)` ends it when the orderly path does not, and the 100 ms and 2 s timings against the
real menu. The plugin calls are platform channels and have no fake in the project.

No prefs key, MethodChannel, notification ID, Firestore path or other contract changes. No new string
(the log lines are not UI strings). The temporary log file is a new file in the app's data folder; it is
not read by any code.

--------------------------------------------------------------------------------

## Phases

Each phase needs the owner's own go-ahead.

| Phase | Content | Status |
|---|---|---|
| T1 | This spec only. | Done (2026-11-16), merged to `main` in PR #30 (merge 1e2bd81). |
| T2 | The code change in `_quit()`, the guard test if it can be extracted, `flutter analyze`, `flutter test`, and the Windows release build. | Done on `fix/tray-quit` (2026-11-16, commit 32a8573, from `main` ae46faa), not pushed, not merged. See "T2 as built" below. |
| T3 | The owner's manual check on his PC. | NOT STARTED |

### T2 as built (2026-11-16, commit 32a8573)

- **Code (VERIFIED by the diff):** only `lib/core/services/desktop_tray_service.dart` and the new test
  `test/core/services/desktop_tray_run_once_guard_test.dart`. `_quit()` follows the Decision steps 1 to 7;
  the fallback timer is started before the awaited steps. The guard is a small class `RunOnceGuard`
  (`@visibleForTesting`) in the same file. Menu, labels and the X-button path are unchanged.
- **One addition to the Decision order:** before the 100 ms wait, `_quit()` looks up the log folder
  (`getApplicationSupportDirectory()`, bounded by a 1 s timeout, errors caught) and writes "quit clicked".
  The file writes are synchronous (`writeAsStringSync`, append, `flush: true`), so the fallback callback
  writes its line and calls `exit(0)` without waiting on anything.
- **`debugPrint` texts:** `🚪 [TRAY] Quit requested`, `⚠️ [TRAY] Quit: second call ignored`,
  `📝 [TRAY] Quit log file: <full path>`, `⏳ [TRAY] Quit: menu wait done`,
  `⏲️ [TRAY] Quit: fallback timer started (2 s)`, `✅ [TRAY] Quit: tray icon destroyed`,
  `✅ [TRAY] Quit: preventClose off`, `🚪 [TRAY] Quit: window destroy called`,
  `✅ [TRAY] Quit: window destroy returned`, `⏰ [TRAY] Quit: fallback timer fired, calling exit(0)`.
  Errors: `⚠️ [TRAY] Quit: tray destroy error: <e>`, `⚠️ [TRAY] Quit: setPreventClose error: <e>`,
  `⚠️ [TRAY] Quit: window destroy error: <e>`, `⚠️ [TRAY] Quit log path error: <e>`,
  `⚠️ [TRAY] Quit log write error: <e>`.
- **File log lines (`tray_quit_log.txt`):** `<ISO timestamp> quit clicked`, `<ISO timestamp> tray destroyed`,
  `<ISO timestamp> window destroyed`, `<ISO timestamp> fallback fired`.
- **Reading the log (GUESS):** "window destroyed" is written after `windowManager.destroy()` returns. If
  the process ends before the reply reaches Dart, that line and `window destroy returned` will be
  missing even though the quit worked. A gone process with no "fallback fired" line means the orderly
  path ended it.
- **Automated (VERIFIED, real runs):** `flutter test` 802 passed, 0 failed (799 + 3 new guard tests);
  `flutter analyze` 409 issues, 0 errors (same as the baseline).
- **Builds (VERIFIED, real runs, `aura_app.exe` not running beforehand):** `flutter build windows
  --release` passed, 12:01:53 to 12:03:01, 68 s, exit code 0, `build\windows\x64\runner\Release\aura_app.exe`
  (`data\app.so` rebuilt 12:02:49). `flutter build apk --release --obfuscate
  --split-debug-info=build/debug-info` passed, 12:04:11 to 12:12:11, 480 s, exit code 0,
  `build\app\outputs\flutter-apk\app-release.apk` (88.7 MB). The APK was not installed.
- **UNKNOWN until T3:** whether Quit now ends the app, which steps run, the real log folder, and whether
  the 100 ms and 2 s timings suit the real menu. The app was not launched in T2.

### Test plan

- **T2, automated:** the guard test (a second call does not run the action again); `flutter analyze` and
  `flutter test` with the real numbers reported.
- **T2, build:** `flutter build windows --release`, with `aura_app.exe` closed first. (On 2026-11-16 a
  Windows build on `feat/mode-separation-m1` failed at the install step while `aura_app.exe` was
  running; the cause was not confirmed, GUESS: the running exe blocked the copy.) Per the project's
  desktop rule, the Android build is also run to show the desktop change did not affect it.
- **T3, manual check by the owner:** click Quit; the window, the tray icon and the process all end. Run
  it several times, including right after a prayer-time menu rebuild. Also with the window hidden to the
  tray (after X) and with the window visible. The owner opens the temporary log file and reports which
  lines appeared (and the `[TRAY]` lines, if they are visible).

--------------------------------------------------------------------------------

## Risks

- **A forced exit can cut a pending Firestore write or prefs save.** The fallback `exit(0)` does not wait
  for them. Today's `exit(0)` has the same risk.
- **After Quit there are no Windows prayer notifications or adhan until the app is started again.** Same
  as today; this is what Quit means.
- **If `exit(0)` itself hangs, the fallback hangs too (UNKNOWN until tested).** The orderly path
  (`windowManager.destroy()`) may still end the process; if it does not, the next step is the native
  change listed under Non-Goals.
- **`trayManager.destroy()` and `windowManager.destroy()` on these plugin versions are untested here
  (UNKNOWN).** The log lines show which step fails.
- **The temporary file log adds a file write on the quit path.** It is small, its errors are caught, and
  it is removed later (Follow-ups).
- **Hypothesis 2 is not fixed.** If the click never reaches `_quit()`, Quit still does nothing after this
  change; the log (no "quit requested" line) will show it.
- **Android:** not affected if the edit stays in this desktop-only file (VERIFIED: guarded by
  `isDesktop`).

## Rollback

Revert the T2 commit. `_quit()` returns to `setPreventClose(false)` plus `exit(0)`.

--------------------------------------------------------------------------------

## Follow-ups (not part of this spec)

- **Remove the temporary file log** (the helper in `desktop_tray_service.dart` and the
  `tray_quit_log.txt` writes) once the owner confirms the fix works. It needs its own go-ahead, as a
  code change.
- **Stale menu item ids after a rebuild while the menu is open** (hypothesis 2): a click can be dropped
  silently. Needs its own small spec.
- **Native `TerminateProcess` in `windows/runner`:** only if T3 shows the process still stays.
