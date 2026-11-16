# Fix: one adhan popup on Windows (keep the toast, remove the in-app card)

- **Author:** Alaa Eldin Tarek (drafted with Claude)
- **Status:** Draft. Open Questions 2, 3 and 5 decided by the owner on 2026-11-16. The code phase (A1) is
  not approved yet.
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
- **A failure in device steps 5 or 6 blocks A1 sign-off.**
- **No toast, no control.** If Windows notifications are off for Aura, or "Do not disturb" hides the
  toast, the adhan plays with nothing on screen to stop it (GUESS; today the card would still show).
  **Accepted by the owner** (2026-11-16).
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
   under Risks.) A failure here blocks A1 sign-off.
7. A real prayer time, when convenient: one toast, no card.
8. Other popups unchanged: a pre-prayer reminder or a task reminder still shows as before.

Android: no device step planned; the build result is reported.

--------------------------------------------------------------------------------

## Phases

Each phase needs the owner's own "approve phase".

| Phase | Content | Status |
|---|---|---|
| A0 | This spec only. | Done 2026-11-16 on `fix/desktop-single-adhan-popup` (docs only), not pushed. |
| A1 | Code in the two files above (including the two doc comments in `desktop_notification_service.dart`), `flutter analyze`, `flutter test`, the Windows and Android release builds, docs (`STATE.md`, the log, `lib/features/main/README.md`, which names the adhan overlay at lines 8, 76, 83, 87, 107). Branch `fix/desktop-single-adhan-popup` from `main`. | NOT STARTED |
| A2 | The owner's check on Windows (device steps above). A failure in step 5 or 6 blocks A1 sign-off. | NOT STARTED |

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
