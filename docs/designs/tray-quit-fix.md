# Fix: tray "Quit" does not close the Windows app

- **Author:** Alaa Eldin Tarek (drafted with Claude)
- **Status:** T2 and T2b approved by the owner on 2026-11-16 and built. T3 (the owner's check): FAILED on
  the T2 build (no tray menu item works), then PASS on the T2b build for one run, REPORTED by Aladdin
  2026-11-16; Quit on the orderly path VERIFIED in the logs. See "T3 result and T2b". NOT RUN: Quit with
  the window hidden, repeated runs.
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

- ~~The stale-id dead-click path (hypothesis 2).~~ No longer a Non-Goal: after the T3 failure it is
  fixed in phase T2b (owner's go-ahead 2026-11-16), see "T3 result and T2b".
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
| T3 | The owner's manual check on his PC. | Run on 2026-11-16 on the T2 build: FAIL, REPORTED by Aladdin (no tray menu item works). See "T3 result and T2b". Run again on the T2b build (57195dd), 2026-11-16: PASS for one run, REPORTED by Aladdin (Test Notification, Open Aura after X, Quit); Quit reaching Dart and ending the app on the orderly path VERIFIED in the logs. NOT RUN: Quit with the window hidden, repeated runs. See "T3 re-check on the T2b build". |
| T2b | Stable tray menu item ids (hypothesis 2), added after the T3 failure. Owner's go-ahead 2026-11-16 ("approve phase T2b"). | Done on `fix/tray-quit` (2026-11-16, commit 57195dd), not pushed, not merged. |

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

## T3 result and T2b

### T3 result, 2026-11-16: FAIL

- **REPORTED by Aladdin (not observed by Claude):** on the T2 build the tray menu opens (from the `^`
  hidden icons area), but NO item works: Test Notification (no adhan), Open Aura after X (the window did
  not come back), Quit (nothing closed). So all tray menu clicks are lost, not only Quit.
- **VERIFIED in the captured logs** (release exe, output redirected to a file; runs PID 17184, 12204,
  16904): no `test_notif onClick fired` line and no `Quit requested` line in any run, and
  `tray_quit_log.txt` was never created. The output file was being written live, so the lines were not
  lost in a buffer. The click never reached Dart code.
- **VERIFIED in the same logs:** full prayer-time reloads (`[PRAYER_TIMES] Loading prayer times`) come in
  bursts while the app is in use, not only at start-up. Run 12204: 12:22:36, 12:22:50, then nothing for
  over two minutes, then 12:25:14, 12:25:25, 12:25:29, 12:25:37, inside the window in which Quit was
  clicked (between 12:23:38 and 12:26:39). The exact click times were not recorded, so that each reload
  matches a menu opening is a GUESS.
- The T2 quit code was therefore never run on a real click. Whether it ends the app is still UNKNOWN.

### Cause (hypothesis 2, now the working cause)

1. **VERIFIED:** a click is matched to an item by id only. Native sends `id = (int)wParam` from
   `WM_COMMAND` (`tray_manager` `windows/tray_manager_plugin.cpp:178-184`); Dart looks it up in the
   current menu and does nothing, with no log, if it is not found (`lib/src/tray_manager.dart:57-70`).
2. **VERIFIED:** every `_rebuildMenu()` created new items, and each new item takes a new id from a global
   counter (`menu_base` `menu_item.dart:13-22`). Dart's menu is replaced at once
   (`tray_manager.dart:179`); a menu already on screen keeps its old ids.
3. **VERIFIED:** opening the menu calls `SetForegroundWindow(hWnd)` on the main window just before
   `TrackPopupMenu` (`tray_manager_plugin.cpp:306-308`).
4. **VERIFIED:** on the app's "resumed" event, `lib/features/main/main_wrapper_screen.dart:106-114`
   invalidates `prayerTimesProvider`; the reload calls `DesktopTrayService.instance.updateNextPrayer`
   (`prayer_times_provider.dart:264`), which calls `_rebuildMenu()`.
5. **GUESS:** the focus change in step 3 fires "resumed", so each time the menu opens the ids are replaced
   before the click is looked up. Not read in the Flutter engine; supported by the reload bursts above.

The tray icon left-click (restore the window) carries no id (`tray_manager_plugin.cpp:187-191`), which
fits the report that it works (REPORTED by Aladdin, 2026-11-16).

**Other ways a click can reach no Dart code, and why they do not fit:** no listener registered (the
item's `onClick` runs inside the listener loop, `tray_manager.dart:42`; ruled out, the menu opens only
through our listener, VERIFIED path); `WM_COMMAND` not reaching the plugin (the runner forwards messages,
`windows/runner/flutter_window.cpp:57`, and no other plugin in the build handles `WM_COMMAND`, VERIFIED
by search; whether `window_manager`'s hook can return early for it was not read).

**History (VERIFIED by `git log`):** the tray service and `tray_manager: ^0.2.3` were added in 7db4702
(2026-05-10); the "resumed" reload is older (2699736, 2026-04-18). No recorded tray menu click that
worked was found in `device-checklist.md`, `modules/desktop.md` or `findings.md`. `pubspec.lock` is
git-ignored, so the history of the resolved version (now 0.2.4) is not available.

### T2b: keep the menu item ids stable (owner's go-ahead 2026-11-16, "approve phase T2b")

Hypothesis 2 is moved from Non-Goals and Follow-ups into this phase. Only
`lib/core/services/desktop_tray_service.dart` changes, plus one test.

- The items (`next_prayer`, `stop_adhan`, `open`, `test_notif`, `quit`) and the four separators are
  created ONCE as fields and reused in every rebuild, so their ids never change. `stop_adhan` and its
  separator are still included only while adhan plays.
- **The disabled next-prayer item is reused too**, and only its label is updated. This is safe: `label`
  is a plain non-final field of `MenuItem` and `toJson()` reads it when the menu is sent (`menu_base`
  `menu_item.dart:28, 88-100`, VERIFIED). Reusing it keeps every id in the menu stable, not only the
  clickable ones.
- `_rebuildMenu()` skips the `setContextMenu` call when the next-prayer label and the adhan state are
  unchanged since the last send.
- New log lines: `🔁 [TRAY] menu rebuilt: <label>` when a menu is actually sent, and
  `🖱️ [TRAY] menu click: <key>` at the top of `onTrayMenuItemClick`.
- Same items, labels and order. The T2 quit code and `RunOnceGuard` are unchanged. The "resumed" reload
  in `main_wrapper_screen.dart` is not touched (shared with Android).

**As built (2026-11-16, commit 57195dd on `fix/tray-quit`, not pushed, not merged):**

- **Code (VERIFIED by the diff):** as above. The menu construction is the pure method `buildMenu()`
  (`@visibleForTesting`).
- **Test (VERIFIED, real run):** `test/core/services/desktop_tray_menu_ids_test.dart`, 4 cases: two
  rebuilds keep the same ids; ids stay the same when Stop Adhan appears and disappears; every item in one
  menu has its own id; items, labels and order are unchanged.
- **Automated (VERIFIED, real runs):** `flutter test` 806 passed, 0 failed (802 + 4 new);
  `flutter analyze` 409 issues, 0 errors (same as the baseline).
- **Build (VERIFIED, real run, `aura_app.exe` not running beforehand):** `flutter build windows
  --release` passed, 12:39:29 to 12:40:37, 68 s, exit code 0,
  `build\windows\x64\runner\Release\aura_app.exe` (`data\app.so` rebuilt 12:40:24). The Android build
  was NOT run for T2b: the change is in this desktop-only file and its test, and the T2 Android build
  (same day) covered the file's imports.
- **UNKNOWN until the owner's re-check:** whether menu clicks now reach Dart, whether Quit then ends the
  app, and whether the "resumed" trigger (step 5) is the real one. The `menu rebuilt` and `menu click`
  lines are there to show it.
- **Known limit:** a rebuild that only changes the label while the menu is open leaves the old label on
  screen until the menu is opened again. Clicks still work.

### T3 re-check on the T2b build, 2026-11-16: PASS (one run)

- **REPORTED by Aladdin (not observed by Claude), about 12:44, build 57195dd, PID 14360:** PASS. Test
  Notification: the adhan played. Open Aura after X: the window came back. Quit: the window, the tray
  icon and the process were all gone.
- **VERIFIED in the captured log of PID 14360** (launched 12:42:09, copy kept as
  `%TEMP%\aura_tray_run_14360.txt`; the log was not overwritten, the later PID 21316 was started by the
  owner without capture): one menu click, Quit, and it reached Dart. Lines, in order:
  `🚪 [TRAY] Quit requested`, `🖱️ [TRAY] menu click: quit`, `⚠️ [TRAY] Quit: second call ignored`,
  `📝 [TRAY] Quit log file: C:\Users\alaae\AppData\Roaming\com.aura\aura_app\tray_quit_log.txt`,
  `⏳ [TRAY] Quit: menu wait done`, `⏲️ [TRAY] Quit: fallback timer started (2 s)`,
  `✅ [TRAY] Quit: tray icon destroyed`, `✅ [TRAY] Quit: preventClose off`,
  `🚪 [TRAY] Quit: window destroy called`. The log ends there.
- **VERIFIED, `tray_quit_log.txt`** (created 12:42:46, two lines):
  `2026-11-16T12:42:46.304797 quit clicked`, `2026-11-16T12:42:46.414287 tray destroyed`.
- **Quit path: orderly, not the fallback.** VERIFIED: no "fallback fired" line in the file (it is written
  synchronously before `exit(0)`), and no `fallback timer fired` line in the output. The process ended at
  `windowManager.destroy()`, before its reply reached Dart, so "window destroyed" and
  `window destroy returned` are missing, as expected (see "T2 as built"). The whole quit took well under
  the 2 s fallback (110 ms from "quit clicked" to "tray destroyed").
- **The double call is real and the guard works (VERIFIED):** `second call ignored` appears once.
- **The real log folder (VERIFIED):** `%APPDATA%\com.aura\aura_app`, as expected.
- **Not matched by the log:** the PID 14360 log has NO `test_notif onClick fired`, no
  `menu click: test_notif` and no `menu click: open` line, and that run ended at 12:42:46, before the
  reported 12:44. So the Test Notification and Open Aura checks are REPORTED only; GUESS: they were done
  on the later run (PID 21316, same exe, started 12:42:49, output not captured). Whether the window was
  visible or hidden when Quit was clicked on PID 14360 is not shown by the log.
- **Still GUESS:** that "resumed" was the trigger of the rebuilds (cause step 5). The fix does not depend
  on it.
- **NOT RUN:** Quit with the window hidden to the tray, repeated runs, Quit right after a next-prayer
  label change, Stop Adhan from the tray menu, the fallback path (never fired).
- The temporary file log stays in the code; its removal is a follow-up that needs the owner's go-ahead.

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
- **Hypothesis 2 was not fixed by T2.** T3 showed exactly this: the click never reached `_quit()` (no
  "Quit requested" line). It is fixed in T2b; whether that is enough is UNKNOWN until the re-check.
- **Android:** not affected if the edit stays in this desktop-only file (VERIFIED: guarded by
  `isDesktop`).

## Rollback

Revert the T2 commit. `_quit()` returns to `setPreventClose(false)` plus `exit(0)`.

--------------------------------------------------------------------------------

## Follow-ups (not part of this spec)

- **Remove the temporary file log** (the helper in `desktop_tray_service.dart` and the
  `tray_quit_log.txt` writes) once the owner confirms the fix works. It needs its own go-ahead, as a
  code change.
- ~~Stale menu item ids after a rebuild while the menu is open (hypothesis 2).~~ Moved into this spec
  as phase T2b (2026-11-16).
- **Native `TerminateProcess` in `windows/runner`:** only if T3 shows the process still stays.
