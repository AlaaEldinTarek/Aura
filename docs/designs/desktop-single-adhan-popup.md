# Fix: one adhan popup on Windows (keep the toast, remove the in-app card)

- **Author:** Alaa Eldin Tarek (drafted with Claude)
- **Status:** A1 (code) approved by the owner on 2026-11-16 and built (commit 7c0f406). A2 (the owner's
  device check) done on 2026-11-16 on a build with A1, the tray fix and the toast fix: steps 1 to 5 and 7
  pass, step 6 FAILS as built and is accepted by the owner, step 8 NOT RUN. See "A2 results". Open
  Questions 2, 3 and 5 decided by the owner on 2026-11-16.
- **Date:** 2026-11-16
- **Level:** C (production code: `lib/`, `test/` cases; needs this spec approved and the phrase
  "approve phase A1", per `CLAUDE.md` Rules). This file itself is Level A (docs).
- **Branch:** `fix/desktop-single-adhan-popup`, from `main` at `d167929` (this spec; the code phase uses it too).
- **Platform:** Windows desktop only. Android must not change.
- **Line references:** `main` at `d167929`. Plugin: `local_notifier` 0.1.6 (version from `pubspec.lock`).
- **Marks:** VERIFIED (read in code, 2026-11-16), REPORTED (told by the owner, not observed by Claude),
  UNVERIFIED (not read or not checked), GUESS (inference).

--------------------------------------------------------------------------------

## Background

**REPORTED by Aladdin, 2026-11-16, with a screenshot (not seen by Claude in this session):** when the
adhan fires on Windows (seen with the tray item "Test Notification"), TWO popups appear:

1. the Windows toast above the taskbar, with "Prayed ✓" and "Stop Adhan";
2. an in-app card titled "Prayer Time" inside the Aura window, with "Stop Adhan" and "Prayed ✓".

**Owner's decision, 2026-11-16:** keep ONLY the Windows toast; remove the in-app card.

**What the code does today (VERIFIED):**

- At prayer time, and in `fireTestAdhan()`, the scheduler does two separate things: it emits an event on
  `prayerTimeStream` and it shows the toast (`desktop_prayer_scheduler.dart:82-84` and `:107-109`).
- `MainWrapperScreen` listens to that stream and shows the card (`main_wrapper_screen.dart:179-183`,
  `_showAdhanOverlay` at `:309-334`, widget `_AdhanOverlay` at `:1765-1920`). The card's title is
  "Prayer Time" (`:1852`), which matches the report.
- Before showing the card, `_showAdhanOverlay` calls `windowManager.show()` (`:310-313`), so a window
  hidden in the tray comes back at every adhan.
- The two "Prayed ✓" buttons do not do the same thing: the card records the prayer AND stops the adhan
  (`main_wrapper_screen.dart:322-326`); the toast only records it (`desktop_notification_service.dart:283`).

--------------------------------------------------------------------------------

## Goals

1. On Windows, an adhan (real or "Test Notification") shows one popup: the Windows toast.
2. The toast's "Prayed ✓" records the prayer as on time AND stops the adhan, as the card did.
3. A window hidden in the tray stays hidden when the adhan fires.

## Non-Goals

- **Removing the temporary quit file log** (`tray_quit_log.txt`, `desktop_tray_service.dart`). It is a
  follow-up of `docs/designs/tray-quit-fix.md` and needs its own go-ahead.
- Any change to `desktop_prayer_scheduler.dart`. `prayerTimeStream` stays, even with no listener.
- The other desktop popups and toasts: pre-prayer reminder, post-prayer check, tasks, wird, daily digest,
  achievements, and the popup queue (`_enqueuePopup`, `_NotifPopup`).
- The unused adhan branch of the popup queue (`isAdhan`, see Open Questions).
- Toast text, labels, identifier, duration, and anything on Android.

--------------------------------------------------------------------------------

## Approach (per file)

### 1. `lib/features/main/main_wrapper_screen.dart` (remove the card)

**Every use, by search over `lib/` and `test/` (VERIFIED):**

| Name | Uses |
|---|---|
| `prayerTimeStream` | defined `desktop_prayer_scheduler.dart:31-32`; ONE listener, `main_wrapper_screen.dart:180`. (Also named in a doc comment, `desktop_prayer_scheduler.dart:10`.) |
| `_prayerSchedulerSub` | `main_wrapper_screen.dart:76` (field), `:179` (assigned), `:289` (cancelled). Nowhere else. |
| `_showAdhanOverlay` | defined `:309`; ONE call, `:182`. |
| `_AdhanOverlay`, `_AdhanOverlayState` | defined `:1766`, `:1785`; ONE use, `:318`. Both are private to this file. |
| `DesktopPrayerScheduler`, `DesktopPrayerEvent` in this file | only `:76` and `:180`, so the import at `:23` becomes unused. |
| tests | no file under `test/` mentions any of these names or these three source files. |

Nothing else uses the subscription or the card, so all of the following are removed.

**(a) The field, `:76`:**

```dart
  StreamSubscription<DesktopPrayerEvent>? _prayerSchedulerSub;
```

**(b) The subscription, `:178-183`** (inside `if (_isDesktop) {` that starts at `:167`; the
`_desktopNotifSub` listener above it stays):

```dart
      // Desktop: adhan overlay with action buttons when prayer time fires.
      _prayerSchedulerSub =
          DesktopPrayerScheduler.instance.prayerTimeStream.listen((event) {
        if (!mounted) return;
        _showAdhanOverlay(event.name, event.nameAr);
      });
```

**(c) The cancel in `dispose`, `:289`:**

```dart
    _prayerSchedulerSub?.cancel();
```

**(d) `_showAdhanOverlay`, `:309-334`:**

```dart
  void _showAdhanOverlay(String prayerName, String prayerNameAr) {
    // Make window visible first (it may be hidden in tray)
    try {
      windowManager.show();
    } catch (_) {}

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _AdhanOverlay(
        prayerName: prayerName,
        prayerNameAr: prayerNameAr,
        onDismiss: () => entry.remove(),
        onPrayed: () {
          entry.remove();
          DesktopNotificationService.instance.recordPrayerOnTime(prayerName);
          DesktopAdhanService.instance.stop();
        },
        onStopAdhan: () {
          entry.remove();
          DesktopAdhanService.instance.stop();
        },
      ),
    );
    overlay.insert(entry);
  }
```

**(e) The widget, `:1765-1920`** (`_AdhanOverlay` and `_AdhanOverlayState`, with the separator comment at
`:1763`). Its head, as it is now:

```dart
/// Desktop in-app adhan popup overlay (bottom-right corner, stays for 5 min).
class _AdhanOverlay extends StatefulWidget {
  final String prayerName;
  final String prayerNameAr;
  final VoidCallback onDismiss;
  final VoidCallback onPrayed;
  final VoidCallback onStopAdhan;
```

Read in this range: `:1765-1832` and `:1876-1920`. Lines `:1833-1875` (the card's layout) were seen only
through a search (`:1852` title, `:1870` body text): UNVERIFIED in full; they are deleted with the class.
**Lines 1833-1875 must be read before the code phase.**

**(f) The import, `:23`**, which nothing else in the file uses after (a) and (b):

```dart
import '../../core/services/desktop_prayer_scheduler.dart';
```

**Kept, because other code still uses them (VERIFIED):** `import 'dart:async'` (`:1`, the other
`StreamSubscription` fields), the `desktop_adhan_service.dart` import (`:22`, used at `:1254` and `:1274`),
`windowManager` (popup queue, `:354-450`), `recordPrayerOnTime` (`:1272`).

No other line of this file changes. Android is not affected: the subscription is inside `if (_isDesktop)`.

### 2. `lib/core/services/desktop_prayer_scheduler.dart` (no change)

`prayerTimeStream` and the two `_prayerTimeController.add(...)` calls (`:82`, `:107`) stay. After the
change the stream has no listener. It is a broadcast stream (`:26-27`), so events with no listener are
dropped (GUESS from Dart's broadcast-stream rule; harmless). Its doc comments (`:10`, `:29-30`, `:78`)
will still mention the in-app overlay; they are left as they are (owner's decision, Open Question 3).

### 3. `lib/core/services/desktop_notification_service.dart` ("Prayed ✓" also stops the adhan)

Current code, `showAdhanNotification`, `:282-285`:

```dart
      onActionClick: (idx) {
        if (idx == 0) _recordPrayerStatus(prayerName, PrayerStatus.onTime);
        if (idx == 1) DesktopAdhanService.instance.stop();
      },
```

Proposed:

```dart
      onActionClick: (idx) {
        if (idx == 0) {
          _recordPrayerStatus(prayerName, PrayerStatus.onTime);
          DesktopAdhanService.instance.stop();
        }
        if (idx == 1) DesktopAdhanService.instance.stop();
      },
```

This is the card's order (record, not awaited, then stop; `main_wrapper_screen.dart:324-325`).
`recordPrayerOnTime` is `_recordPrayerStatus(..., PrayerStatus.onTime)` (`:191-192`), so the record is
the same call. `DesktopAdhanService.instance.stop()` catches its own errors
(`desktop_adhan_service.dart:54-61`) and is already imported here (`:12`).

**Two doc comments in this file are corrected (owner's decision 2026-11-16, Open Question 3).** They
describe the in-app overlay that A1 removes. Comments only, no behavior.

Current, class comment, `:29-33`:

```dart
/// Windows/macOS/Linux in-app notification service.
/// Emits [DesktopInAppNotif] events to [notificationStream];
/// [MainWrapperScreen] listens and shows the in-app banner overlay.
/// Prayer-time popups are handled separately by the [DesktopPrayerScheduler]
/// overlay in MainWrapperScreen.
```

Proposed: the last two lines become

```dart
/// Prayer-time (adhan) popups are Windows toasts only, see
/// [showAdhanNotification]; there is no in-app adhan overlay.
```

Current, `:190`:

```dart
  /// Record a prayer as prayed on-time (called from in-app adhan popup button).
```

Proposed (its one remaining caller is the popup queue's adhan layout, `main_wrapper_screen.dart:1272`,
see Open Question 4):

```dart
  /// Record a prayer as prayed on-time (called from the adhan layout of the
  /// desktop popup queue in MainWrapperScreen).
```

Nothing else in the file changes. The scheduler's comments stay as they are (section 2).

--------------------------------------------------------------------------------

## Risks

- **The toast is the only popup left.** REPORTED by the owner: the toast fades to the Action Center after
  a few seconds. GUESS: the adhan can still be stopped from the toast in the Action Center. How long the
  toast stays, and whether its buttons work from the Action Center, are not read in `local_notifier` and
  not tested. Device step 5 checks it.
- **The tray "Stop Adhan" item may not be there (GUESS; a finding, not re-checked).** That the adhan can
  be stopped from the tray item is itself a GUESS. `findings.md:135` says the
  item is hidden right after play starts: the scheduler sets `setAdhanPlaying(true)`, awaits
  `playAdhan`, then sets it to `false` (`desktop_prayer_scheduler.dart:85-87`, VERIFIED), and `playAdhan`
  returns once playback has started, not when it ends (GUESS, `audioplayers` not read). If so, the tray
  item is not a working way to stop the adhan, and the toast is the only one. Today the card covers this.
  Device step 6 checks it.
- **A failure in device steps 5 or 6 blocks A1 sign-off.** Changed for step 6 by the owner on 2026-11-16:
  step 6 fails as built and is accepted for A1 (see "A2 step 6 result and the owner's decision").
- **No toast, no control.** If Windows notifications are off for Aura, or "Do not disturb" hides the
  toast, the adhan plays with nothing on screen to stop it (GUESS; today the card would still show).
  **Accepted by the owner** (2026-11-16). With step 6 failing, the tray item is not a way out either:
  this is a known limit of A1.
- **A hidden window stays hidden** at adhan time. This is wanted by the owner, and it changes today's
  behavior. The toast body click still brings the window back (`_bringToFront`, `:123`, `:135-140`).
- **Shared file.** `main_wrapper_screen.dart` is used on Android. The removed code is desktop-only
  (inside `if (_isDesktop)` or reached only from it), and the Android build is run to show it.
- **Removed code drops two known issues with it** (`findings.md:348`: the card's buttons and a possible
  double `onDismiss`). No fix is needed for code that is deleted.

## Rollback

Revert the A1 code commit. The card, the subscription and the old "Prayed ✓" behavior come back.

--------------------------------------------------------------------------------

## Verification Plan

**Automated (A1):**

- `flutter analyze`: no new issue (baseline on `main` d167929: 409 issues, 0 errors, UNVERIFIED on this
  exact commit; last real run 409 on 57195dd, same `lib/`). The unused import in 1(f) must not be left.
- `flutter test`: all pass (last real run: 806 passed, 0 failed, on 57195dd).
- **Unit test for the toast action:** none (owner's decision 2026-11-16, Open Question 2). The handler is
  a closure inside `showAdhanNotification`, and both of its effects go through singletons with platform
  plugins (prayer tracking, audio player) that have no fake in the project. Device steps 2 and 3 cover it.
- **Search check:** after the edit, `prayerTimeStream` has no listener and `_AdhanOverlay`,
  `_showAdhanOverlay`, `_prayerSchedulerSub` appear nowhere in `lib/`.

**Builds (A1):** `flutter build windows --release` with `aura_app.exe` closed first, and the Android
release APK build (shared file).

**Device steps (A2, the owner's check on Windows; NOT RUN):**

1. Window visible, tray "Test Notification": the adhan plays, the Windows toast shows, and NO card
   appears inside the Aura window.
2. Toast "Stop Adhan": the adhan stops.
3. "Test Notification" again, toast "Prayed ✓": the adhan stops, and the prayer is recorded as on time.
   The test fires as Fajr, so today's Fajr will show as on time afterward (accepted by the owner,
   Open Question 5).
4. Press X (window hidden in the tray), "Test Notification": the window stays hidden; the toast shows.
5. Let the toast fade, open the Action Center, press "Stop Adhan" there: the adhan stops. A failure
   here blocks A1 sign-off.
6. During an adhan, open the tray menu: is "Stop Adhan" listed, and does it work? (Checks the finding
   under Risks.) A failure here blocks A1 sign-off. (Result 2026-11-16: FAILS; accepted by the owner for
   A1, see "A2 step 6 result and the owner's decision".)
7. A real prayer time, when convenient: one toast, no card.
8. Other popups unchanged: a pre-prayer reminder or a task reminder still shows as before.

Android: no device step planned; the build result is reported.

--------------------------------------------------------------------------------

## Phases

Each phase needs the owner's own "approve phase".

| Phase | Content | Status |
|---|---|---|
| A0 | This spec only. | DONE 2026-11-16 (docs only); merged to main via PR #34 (merge d92080d). |
| A1 | DONE 2026-11-16 (commit 7c0f406, merged via PR #34); see "A1 as built". Scope: code in the two files above (including the two doc comments in `desktop_notification_service.dart`), `flutter analyze`, `flutter test`, the Windows and Android release builds, docs (`STATE.md`, the log, `lib/features/main/README.md`, which names the adhan overlay at lines 8, 76, 83, 87, 107). Branch `fix/desktop-single-adhan-popup` from `main`. | DONE 2026-11-16 (commit 7c0f406); merged to main via PR #34 (merge d92080d). |
| A2 | The owner's check on Windows (device steps above). A failure in step 5 blocks A1 sign-off; step 6 was accepted by the owner. | Run 2026-11-16 on the build of 4f7da95 (A1 + tray fix + toast fix), PID 4608. Steps 1, 2, 3, 4, 5, 7: pass (marks VERIFIED or REPORTED per step in "A2 results"). Step 6: FAILS as built (VERIFIED in the log), accepted by the owner for A1; the toast and the Notification Center are the stop controls. Step 8 (other popups): NOT RUN. |

### A1 as built (2026-11-16)

- **Pre-check (VERIFIED):** lines 1833-1875 of `main_wrapper_screen.dart` (the card's layout) use nothing
  outside `_AdhanOverlay`: standard widgets, the build method's own locals, two inline strings and
  `_dismiss` of `_AdhanOverlayState`. The tree was clean before the edit.
- **Code (VERIFIED by the diff):** `main_wrapper_screen.dart` -196 lines, none added: the import, the
  `_prayerSchedulerSub` field, listener and cancel, `_showAdhanOverlay`, `_AdhanOverlay` and
  `_AdhanOverlayState`. `desktop_notification_service.dart` +8 -4: the toast's "Prayed ✓" (index 0)
  records on time and then calls `DesktopAdhanService.instance.stop()`; the two doc comments of Approach 3.
  `desktop_prayer_scheduler.dart` and `desktop_tray_service.dart` (temporary quit file log) have no diff.
- **Search check (VERIFIED):** `_AdhanOverlay`, `_showAdhanOverlay` and `_prayerSchedulerSub` appear nowhere
  in `lib/` or `test/`. `prayerTimeStream` remains only in `desktop_prayer_scheduler.dart` (its definition
  and a doc comment) and now has no listener.
- **Automated (VERIFIED, real runs):** `flutter analyze` 408 issues, 0 errors (last real run before the
  change: 409 on 57195dd, same `lib/` apart from this change; one issue fewer, GUESS: the `withOpacity`
  notice on the removed card, not compared issue by issue). `flutter test` 806 passed, 0 failed.
- **Builds (VERIFIED, real runs, `aura_app.exe` ended first, none running):** `flutter build windows
  --release` passed, 13:10:01 to 13:11:09, 68 s, exit code 0, `build\windows\x64\runner\Release\aura_app.exe`
  (`data\app.so` rebuilt 13:10:56). `flutter build apk --release --obfuscate
  --split-debug-info=build/debug-info` passed, 13:11:19 to 13:14:15, 177 s, exit code 0,
  `build\app\outputs\flutter-apk\app-release.apk` (88.7 MB), not installed.
- **NOT RUN at the time of the A1 build:** all device steps (A2). Step 6 was checked later the same day,
  see below.

### A2 step 6 result and the owner's decision (2026-11-16)

Checked on the Windows release build of commit 4f7da95 (branch `fix/toast-listener-leak`: A1 plus the
tray once-per-click fix 93ca04c and the adhan toast release fix 4f7da95), PID 4608, output captured.

- **Step 6 FAILS as built (VERIFIED in the log):** `menu click: stop_adhan` appears 0 times across 15
  "Test Notification" clicks. Around every `DesktopAdhanService: Playing bundled adhan` line the tray menu
  is rebuilt twice, immediately before and immediately after it (`🔁 [TRAY] menu rebuilt`): the "Stop
  Adhan" item is added and then removed again as soon as playback starts.
- **Cause (VERIFIED in code):** `desktop_prayer_scheduler.dart:85-87` (real prayer) and `:110-112` (test)
  call `setAdhanPlaying(true)`, await `playAdhan(...)`, then `setAdhanPlaying(false)`. `playAdhan` returns
  when playback starts, not when it ends, so the flag flips back at once. This is older behavior
  (`findings.md:135`), not something A1 changed; before A1 the in-app card covered the gap.
- **Owner's decision, 2026-11-16: accepted for A1.** Step 6 no longer blocks A1 sign-off. The stop controls
  are the Windows toast and the same toast in the Notification Center. This replaces the rule "a failure
  in device steps 5 or 6 blocks A1 sign-off" for step 6 only; it still holds for step 5.
- **Known limit:** if Windows notifications are off for Aura, or "Do not disturb" hides the toast, nothing
  on screen can stop the adhan. Before A1 the in-app card covered this case.
- **Also seen in the same run (VERIFIED in the log):** every stop from a toast button logs
  `DesktopAdhanService: Error stopping adhan - TimeoutException after 0:00:30.000000: Future not completed`
  about 30 s after the press, one per press. Cause UNKNOWN (`audioplayers` on Windows not read).

### A2 results (2026-11-16)

**Tested build:** the Windows release build of commit 4f7da95, PID 4608, output captured to a file. It
contained A1 (7c0f406), the tray once-per-click fix (93ca04c, branch `fix/tray-double-fire`) and the adhan
toast release fix (4f7da95, branch `fix/toast-listener-leak`). Marks: VERIFIED (read in the captured log or
in code), REPORTED (told by the owner, not observed by Claude), NOT RUN.

| Step | Result |
|---|---|
| 1. One popup per adhan, no in-app card | One toast per event: VERIFIED in the log (16 toasts for 16 adhan plays: 15 Test Notification clicks and the real Isha; 0 duplicates). No in-app card: REPORTED by the owner ("only toast", with a screenshot of the toast). |
| 2. Toast "Stop Adhan" stops the sound | REPORTED by the owner: the sound stops in under 1 s. The log shows one stop call per press. |
| 3. Toast "Prayed ✓" | Stops the sound: REPORTED. Records once: VERIFIED in the log (one `Recorded Fajr` line, the fourth toast with that identifier; before the toast fix that press would have recorded four times). |
| 4. Hidden window stays hidden | VERIFIED: after the adhan fired with the window closed by X, the window read `visible=False`; the same after a toast button press. Checked after the adhan, not at the instant it fired. |
| 5. Notification Center "Stop Adhan" | Stops the sound: REPORTED by the owner. One stop call: VERIFIED in the log. The buttons are behind the arrow on the collapsed card. |
| 6. Tray "Stop Adhan" during the adhan | FAILS as built, accepted by the owner for A1; see "A2 step 6 result and the owner's decision". Not changed here. |
| 7. A real prayer time | VERIFIED in the log: real Isha at 18:51, one toast (`adhan_isha`), one adhan. |
| 8. Other popups unchanged | NOT RUN. To be checked at the next real pre-prayer reminder or task reminder. |

- **Every stop logs a 30 s timeout:** each toast button press logged
  `Error stopping adhan - TimeoutException after 0:00:30` about 30 s later (VERIFIED), although the sound
  stopped (REPORTED). Cause UNKNOWN; see the `fix/adhan-stop` follow-up.
- **PR order, bottom first:** A1 (`fix/desktop-single-adhan-popup`), tray (`fix/tray-double-fire`), toast
  (`fix/toast-listener-leak`). Each branch is an ancestor of the next (VERIFIED with `git merge-base
  --is-ancestor`). Nothing is pushed and no PR is open.

### Findings from the A2 run (not part of A1)

1. **Windows location is the hard-coded Makkah fallback (VERIFIED in code and in the saved prefs).**
   `getBestLocation()` (`location_service.dart:173-192`) uses a manual location first, then a cached IP
   location, then Mecca (21.4225, 39.8262). The IP lookup `_updateIpLocationInBackground()` has no caller,
   so the cached step never succeeds. No location key is saved on this PC. Picking a city manually (Prayer
   screen, location tile) is used first (VERIFIED in code; NOT RUN on the device). Do not press
   "Auto-detect" in that dialog: it clears the manual location and calls `getBestLocation()`, which returns
   Mecca again (VERIFIED in code). Today's Mecca vs Riyadh difference: 22 to 33 minutes earlier in Riyadh
   (computed with the app's `adhan` package, Muslim World League, Shafi). Firestore sync cannot overwrite
   the desktop location: no sync code touches the location keys (VERIFIED by search).
2. **Other toasts have the same listener leak (VERIFIED in code; not tested on the device).** Only the adhan
   toast is released now (`releasePrevious`). The post-prayer check (`post_prayer_<prayer>`) records its
   status once per toast ever shown with that identifier, and the task reminder (`task_<id>`) runs "Mark
   Done" once per toast. Pre-prayer, Wird and daily-digest toasts have the same build-up with harmless
   callbacks.
3. **A reload after the adhan cancels that prayer's post-prayer check (VERIFIED in code; older behavior).**
   `schedulePrayerTimers` cancels all timers and skips any prayer whose time has passed
   (`desktop_prayer_scheduler.dart:42, 50-51`), and the post-prayer check is scheduled inside that loop. The
   app reloads prayer times several times an hour, so after the adhan the check is usually dropped.
4. **"Test Notification" is to be removed after A2 (branch `chore/remove-test-notification`, NOT STARTED).**
   The `test_notif` once-per-click guard in `desktop_tray_service.dart` is then unneeded. The `stop_adhan`
   guard and `SameTurnGuard` itself stay until `fix/adhan-stop` decides about the Stop Adhan item.

--------------------------------------------------------------------------------

## Follow-ups (not part of this spec)

- **Branch `fix/adhan-stop`:** keep the tray "Stop Adhan" item until playback ends or is stopped, and
  diagnose the 30 s stop timeout together with it. It needs its own "approve phase", and a read-only
  diagnosis first. Likely files: `desktop_prayer_scheduler.dart`, `desktop_adhan_service.dart` (neither is
  touched by this spec).
- **Branch `chore/remove-test-notification`:** remove the tray "Test Notification" item after A2 (NOT
  STARTED, needs its own approval).
- **Device check of step 8** at the next real pre-prayer reminder or task reminder.
- **Findings 1 to 3 under "Findings from the A2 run"** (Windows location fallback, the listener leak of
  the other toasts, the post-prayer check dropped by a reload): each needs its own spec if the owner
  wants a fix.

--------------------------------------------------------------------------------

## Open Questions

1. **Is the toast alone enough to stop the adhan?** If device step 6 shows the tray "Stop Adhan" item is
   missing while the adhan plays, the only control is a toast that fades in seconds. Options: accept it;
   or fix the tray item in a later phase (a change in `desktop_prayer_scheduler.dart`, which this spec
   does not touch). Recommendation: run A2 first, decide after.
2. **Unit test for the toast action. DECIDED by the owner, 2026-11-16: skip the unit test.** Option considered: move the choice into a small pure function (index in,
   "record on time" and "stop adhan" flags out) and test that. It adds a few lines to
   `desktop_notification_service.dart` beyond the two-line change. Recommendation: skip it; the change is
   two lines and A2 covers it.
3. **Stale doc comments. DECIDED by the owner, 2026-11-16: fix only the two doc comments in
   `desktop_notification_service.dart`; the scheduler's stay.** After A1, `desktop_notification_service.dart:32-33` and `:190`, and
   `desktop_prayer_scheduler.dart:10`, `:29-30`, `:78`, would still describe the in-app overlay. The
   proposed wording is in Approach 3.
4. **The unused adhan popup branch.** The popup queue has its own adhan layout with "Dismiss", "Stop
   Adhan" and "Prayed ✓" (`main_wrapper_screen.dart:1175-1182`, `:1236-1280`, `_NotifPopup.isAdhan` at
   `:1929`), but no code creates a popup with `isAdhan: true` (VERIFIED by search in the file; the class
   is private). It is not what the screenshot shows and it never appears. Left in place by this spec
   ("not found by search" is not treated as permission to delete). Remove it later, or keep?
5. **"Test Notification" + "Prayed ✓" records a real Fajr. DECIDED by the owner, 2026-11-16: accept.**
   `fireTestAdhan` uses the name "Fajr"
   (`desktop_prayer_scheduler.dart:107-109`), so pressing "Prayed ✓" on a test toast writes today's Fajr
   as on time. This is the same today with the toast and the card; it only matters for the A2 steps.
   Today's Fajr will show as on time after device step 3.
