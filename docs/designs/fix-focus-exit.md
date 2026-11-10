# Fix: Focus Mode volume-up emergency exit (F52f)

- **Author:** Alaa Eldin Tarek
- **Status:** Draft
- **Date:** 2026-11-10
- **Level:** C (production code: `android/`, `lib/`, `test/` cases; needs an approved spec and the phrase
  "approve phase focus-exit", per `CLAUDE.md` Rules) - branch `fix/focus-exit`
- **Line references:** based on commit `e64bf95` (current `main`)

--------------------------------------------------------------------------------

## Terminology

- **F##** — finding number from `.project-docs/reference/findings.md`
- **S##** — device-check sequence number from `.project-docs/reference/device-checklist.md`
- **Level A/B/C** — approval levels defined in `CLAUDE.md` Rules (A = docs, B = tooling, C = production code)

--------------------------------------------------------------------------------

## Overview

Focus Mode locks the phone for a user-chosen duration (5-60+ min). The activity enters lock-task
mode (`startLockTask()` in `onCreate` and `onResume`), blocks Back/Home/Recents keys, and a
foreground service relaunches the activity within 100 ms if the user manages to leave. A full-screen
`TYPE_APPLICATION_OVERLAY` touch blocker prevents all touch input, including the notification shade.

The confirmation dialog promises an emergency exit -- "You can exit by pressing volume up 3 times
quickly" -- but the code never implemented this. Once locked in, the only way out is waiting for the
timer to end or force-restarting the phone.

This fix implements the promised volume-up x3 exit, updates the Focus screen's hint text to match,
and makes sure the service stops cleanly after an early exit so it does not relaunch the activity.

--------------------------------------------------------------------------------

## Problem Statement

`task_form_screen.dart:1209-1210` shows a confirmation dialog before Focus Mode starts:

> *"This will lock your phone and silence all notifications for N minutes. You can exit by pressing
> volume up 3 times quickly."*

The native `FocusModeActivity.onKeyDown` (`:221-231`) handles only BACK, HOME, APP_SWITCH, and
RECENT_APPS -- all consumed while the timer is running. Volume keys fall through to `super` and
adjust system volume, but nothing counts presses or triggers an exit.

Meanwhile, the Focus screen itself tells the user the opposite -- `exitHint` (`:573`) reads "You
cannot exit until timer ends" and the close button (`:576`) reads "Locked until timer ends". These
contradict the Dart dialog, and both are wrong once the volume-up exit is implemented.

The `FocusModeService` (`FocusModeService.kt`) adds a second layer of lock:

- A `monitorRunnable` (`:107-119`) checks every 100 ms whether `isActivityVisible` is true; if not,
  it relaunches the activity.
- A `TYPE_APPLICATION_OVERLAY` touch blocker (`:271-308`) consumes all touch events on the screen.
- `onTaskRemoved` (`:203-212`) restarts the service when `!isTimerFinished && isRunning`.
- `onDestroy` (`:214-229`) restarts the service when `!isTimerFinished` (note: `isRunning` is
  already set to `false` at `:219` before the check at `:221`, so only `isTimerFinished` matters).

All three layers must be stopped for an early exit to work.

--------------------------------------------------------------------------------

## Goals

1. **Volume-up x3 exits Focus Mode (F52f):** pressing VOLUME_UP three times within ~1.5 s while the
   timer is running triggers an early exit. The exit shows the same "Did you complete your task?"
   prompt as when the timer ends naturally (Yes -> mark done, No -> restart options). The completion
   subtitle shows the **actual time focused** (elapsed), not the planned duration. Before the prompt,
   the ringer is restored, the touch blocker is removed, and the service is stopped (no relaunch).
   - **Proof:** Kotlin unit test of the press-counter logic (timestamp list, threshold, reset);
     device check **S44** on nova 5T (start Focus Mode -> press volume up x3 quickly -> "Did you
     complete?" prompt appears with correct elapsed time, activity closes on answer, service does not
     relaunch).

2. **Service does not relaunch after early exit:** after the volume-up exit, the `FocusModeService`
   monitor loop stops, the touch blocker is removed, and `onDestroy` / `onTaskRemoved` do not
   schedule a restart. This must hold if the user answers the "Did you complete?" prompt, and also
   if the process is killed (swipe-away) while the prompt is showing.
   - **Proof:** device check **S44** includes a swipe-away test after the prompt appears -- the
     service and activity must not come back.

3. **Exit hint text updated (EN + AR):** the Focus screen's `exitHint` and `closeBtn` text are
   changed to tell the user about the volume-up exit instead of saying exit is impossible. The Dart
   confirmation dialog (`task_form_screen.dart:1209-1210`) already has the correct text and is not
   changed.
   - **Proof:** visual check in S44 (English); Arabic text reviewed in code.

4. **No other Focus Mode behavior changes:** timer countdown, DND activation/restoration, the
   completion prompt flow (Yes -> mark done, No -> restart options), the touch blocker during the
   timer, and the relaunch logic during the timer (when NOT triggered by volume-up exit) all stay
   exactly as they are.

--------------------------------------------------------------------------------

## Non-Goals

- Changing the number of presses or the time window (3 presses / 1.5 s is the promise in the
  existing dialog).
- Adding a visual indicator during the press sequence (e.g., "2 of 3 presses").
- Changing how Focus Mode interacts with adhan -- whether adhan audio should break through Focus
  Mode silence (that is F51f, a separate finding).
- Changing the confirmation dialog text in `task_form_screen.dart` (it already says volume up x3).
- Implementing a Dart/Flutter-side exit -- this is purely native (Kotlin).

--------------------------------------------------------------------------------

## Alternatives Considered

### Option B: Only change the exit-hint message (no code change)

Update the `exitHint` and `closeBtn` text to remove the false "cannot exit" claim, without
implementing the volume-up detector. The Dart confirmation dialog would also need updating to remove
the volume-up promise.

**Rejected:** this removes the only emergency exit. The user is still locked in with no escape
except waiting or force-restarting the phone. Focus Mode intentionally blocks Back, Home, Recents,
touch, and the notification shade. A session can be up to 60+ minutes. Leaving no exit at all is a
safety issue -- the user cannot answer a phone call, respond to an emergency, or even unlock the
phone for someone else.

### Option C: Shake-to-exit gesture via accelerometer

Register a `SensorEventListener` for `TYPE_ACCELEROMETER` and detect a shake pattern.

**Rejected:** (a) shake detection is notoriously noisy across devices -- thresholds that work on
one phone produce false positives or false negatives on another; (b) the user's phone may be lying
on a desk during Focus Mode, making shake impractical; (c) the existing Dart dialog already
promises volume-up x3, so implementing a different gesture would still require a dialog text change
and user re-education; (d) accelerometer access requires `SENSOR` permission on some OEM skins.

### Option A (chosen): Intercept VOLUME_UP in the activity's `onKeyDown`

The activity already intercepts hardware keys in `onKeyDown`. Adding VOLUME_UP to the same handler
is the simplest path -- no new permissions, no cross-component communication, no sensor noise. The
Dart dialog already promises this exact gesture.

--------------------------------------------------------------------------------

## Proposed Design

### A. `VolumeExitDetector` class

Extract the press-counter logic into a standalone testable class:

```kotlin
// Add constants to the existing companion object in FocusModeActivity
companion object {
    // ... existing constants ...
    const val VOLUME_EXIT_COUNT = 3
    const val VOLUME_EXIT_WINDOW_MS = 1500L
}
```

```kotlin
class VolumeExitDetector(
    private val requiredCount: Int = 3,
    private val windowMs: Long = 1500L,
    private val clock: () -> Long = { SystemClock.elapsedRealtime() }
) {
    private val timestamps = mutableListOf<Long>()

    fun recordPress(): Boolean {
        val now = clock()
        timestamps.add(now)
        timestamps.removeAll { now - it > windowMs }
        return timestamps.size >= requiredCount
    }

    fun reset() {
        timestamps.clear()
    }
}
```

The `clock` parameter allows unit tests to inject a fake clock. In production, the detector uses
`SystemClock.elapsedRealtime()` (monotonic -- immune to NTP/user time changes). Pruning drops
entries where `now - entry > windowMs` (relative to current time).

### B. Volume-up detection in `onKeyDown` / `onKeyUp`

**`onKeyDown` change (`:221-231`):** add a `KEYCODE_VOLUME_UP` branch before the existing `when`.
When the timer is running (`!isTimerFinished`):

1. If `event?.repeatCount != 0`, return `true` (consume held-key repeats without recording -- a
   single long-press generates rapid `onKeyDown` events with incrementing `repeatCount`; only
   `repeatCount == 0` is a discrete physical press).
2. Call `volumeExitDetector.recordPress()`.
3. If it returns `true`, call `performExit(isEarly = true)`.
4. Return `true` (consume the key -- don't adjust volume during Focus Mode).

Volume-down and other keys continue to `super` (no change).

**`onKeyUp` change (`:233-243`):** add `KEYCODE_VOLUME_UP` -> `return true` when
`!isTimerFinished || volumeExitInProgress`. The second flag (`private var volumeExitInProgress =
false`, set `true` at the start of `performExit`) ensures the key-up for the 3rd press is consumed
even though `isTimerFinished` is already `true` by the time `onKeyUp` fires. The flag is cleared
when the completion prompt appears.

### C. Shared `performExit(isEarly: Boolean)` method

Extract the teardown sequence shared by `onCountdownComplete()` and the volume-exit path into a
single private method. Both callers invoke `performExit(isEarly)` -- the only differences controlled
by the flag:

```
performExit(isEarly: Boolean):
  1. volumeExitInProgress = isEarly    // guard for onKeyUp (Section B)
  2. isTimerFinished = true
  3. isActivityVisible = true           // prevents the service's 100 ms monitor from
                                        // relaunching the activity during the brief
                                        // window before the service is stopped
  4. stopLockTask()
  5. FocusModeService.allowTouch(this)  // removes touch blocker
  6. restoreSoundMode()                 // restores ringer / DND
  7. FocusModeService.stop(this)        // sets isTimerFinished=true inside service,
                                        // so onDestroy/onTaskRemoved skip restart
  8. countDownTimer?.cancel()
  9. Update timer text:
     - isEarly=true:  "Exited" / "تم الخروج"
     - isEarly=false: "Done!" / "تم!"
  10. Update completion subtitle with actual elapsed time (see Section D)
  11. showCompletionPrompt() after 800 ms delay
  12. stopPulseAnimation()
  13. if (isEarly) volumeExitDetector.reset()
  14. Log: isEarly -> "[FOCUS] Volume-up x3 detected -- early exit"
           else   -> "[FOCUS] Countdown complete!"
```

`onCountdownComplete()` becomes: `performExit(isEarly = false)`.
The volume-exit path becomes: `performExit(isEarly = true)`.

**Note on double sound restoration:** `restoreSoundMode()` in the activity (step 6) always sets
`RINGER_MODE_NORMAL`. Then `FocusModeService.stop()` (step 7) triggers `stopFocusMode()` in the
service, which calls its own `restoreSoundMode()` that restores `savedRingerMode`. If the user's
original mode was vibrate, the two calls conflict. This is a pre-existing pattern in
`onCountdownComplete()` -- not introduced by this fix, and out of scope to change here.

### D. Elapsed-time-aware completion prompt

`showCompletionPrompt()` currently reads `durationMinutes` (the planned duration) for the subtitle:

> "Great job! You stayed focused for 25 minutes."

On early exit, this is wrong -- the user may have focused for only 3 minutes. Compute the actual
elapsed time:

```kotlin
val elapsedMs = System.currentTimeMillis() - startedAtMs
val elapsedMinutes = elapsedMs / 60_000
```

If `elapsedMinutes < 1` (exit within the first minute), the subtitle reads "less than a minute" /
"أقل من دقيقة" instead of a number. Otherwise it uses `elapsedMinutes` as before. On normal
completion, `elapsedMinutes` equals `durationMinutes` (within a second), so the displayed text is
the same. Arabic numerals use `toArabicNumerals(elapsedMinutes.toString())` as before.

### E. Service clean stop (`FocusModeService.kt`)

No new logic needed. The existing `stopFocusMode()` (`:459-471`) already sets `isTimerFinished =
true` and `isRunning = false`, stops monitoring, removes the touch blocker, clears state, restores
sound, releases wakelocks, and calls `stopSelf()`.

The restart guards:
- `onTaskRemoved` (`:203-212`) checks `!isTimerFinished && isRunning` -- both flags.
- `onDestroy` (`:214-229`) sets `isRunning = false` at `:219`, then checks only `!isTimerFinished`
  at `:221`. Since `stopFocusMode()` sets `isTimerFinished = true` before `stopSelf()`, `onDestroy`
  sees the flag and skips the restart.

**Verification:** add a log line in `onDestroy` and `onTaskRemoved` that prints whether the restart
path was taken or skipped, so S44 can confirm via logcat.

### F. Exit hint text (`FocusModeActivity.kt:573, :576`)

Replace the hardcoded strings in `setupUI()`:

| Location | Current | New |
|---|---|---|
| `exitHint` (`:573`) | EN: "You cannot exit until timer ends" | EN: "Press volume up 3 times quickly to exit" |
| | AR: "لن يمكنك الخروج حتى ينتهي المؤقت" | AR: "اضغط على زر رفع الصوت " + `toArabicNumerals("3")` + " مرات بسرعة للخروج" |
| `closeBtn` (`:576`) | EN: "Locked until timer ends" | EN: "Volume Up x3 to Exit" |
| | AR: "مقفل حتى انتهاء الوقت" | AR: "ارفع الصوت " + `toArabicNumerals("3")` + " مرات للخروج" |

Arabic numerals use `toArabicNumerals("3")` -- matching the existing pattern throughout the file
(`:350`, `:366`, `:417`, `:470-475`, `:570`). No hardcoded Eastern Arabic digits.

Also update `assets/translations/en.json:215` to add "quickly" for alignment with the Dart
confirmation dialog: `"focus_mode_exit_hint": "Press volume up 3 times quickly to exit"`. The
`ar.json:215` equivalent gets the same "بسرعة" addition. These JSON keys are not currently used by
the native screen (Kotlin hardcodes its strings, matching the existing pattern), but keeping them
aligned avoids confusion if the keys are referenced later.

### G. Unit test (`VolumeExitDetectorTest.kt`)

Test file: `android/app/src/test/kotlin/com/aura/hala/VolumeExitDetectorTest.kt`, alongside the
existing 5 Kotlin test files.

Tests use the injectable `clock` parameter for deterministic timing:

1. **3 presses within window -> exit detected:** timestamps at 0, 500, 1000 ms; `recordPress()`
   returns `true` on 3rd call.
2. **2 presses within window -> no exit:** timestamps at 0, 500 ms; returns `false`.
3. **3 presses spread over > 1.5 s -> no exit:** timestamps at 0, 800, 2000 ms; the first entry
   is pruned, only 2 remain.
4. **4 rapid presses -> exit on the 3rd:** timestamps at 0, 400, 800, 1200 ms; returns `true` on
   3rd, still `true` on 4th (no crash or error).
5. **Reset clears state:** call `recordPress()` twice, call `reset()`, call `recordPress()` once;
   returns `false` (fresh start).

### H. Files changed (summary)

| File | Change |
|---|---|
| `android/.../FocusModeActivity.kt` | `VolumeExitDetector` class, `performExit(isEarly)`, volume-up handling in `onKeyDown`/`onKeyUp`, elapsed-time subtitle, updated `exitHint`/`closeBtn` text |
| `android/.../FocusModeService.kt` | Diagnostic log lines in `onDestroy`/`onTaskRemoved` only (no logic change) |
| `android/.../VolumeExitDetectorTest.kt` | New: 5 unit tests for press-counter logic |
| `assets/translations/en.json` | Update `focus_mode_exit_hint` to add "quickly" |
| `assets/translations/ar.json` | Update `focus_mode_exit_hint` to add "بسرعة" |

**Not changed:** `task_form_screen.dart` (dialog already correct), `FocusModeService.kt` logic (no
new stop path needed), `pubspec.yaml`, `pubspec.lock`.

### I. Ordering

1. Create `VolumeExitDetector` class + `VolumeExitDetectorTest.kt`; run
   `./gradlew :app:testDebugUnitTest` to green.
2. Extract `performExit(isEarly)` from `onCountdownComplete()` -- behavior-preserving refactor;
   `onCountdownComplete()` now calls `performExit(isEarly = false)`.
3. Wire the detector into `onKeyDown` / `onKeyUp` + call `performExit(isEarly = true)` on
   detection (A, B).
4. Add elapsed-time computation to `showCompletionPrompt()` (D).
5. Update `exitHint` / `closeBtn` text (F) + translation JSON files.
6. Add diagnostic logs in service (E).
7. Build release APK -> install -> device check S44.

All changes go in one commit on `fix/focus-exit`.

--------------------------------------------------------------------------------

## Risks & Mitigations

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | Volume-up consumed during Focus Mode prevents the user from turning volume up | Low -- Focus Mode is a short timed session; DND is already on | Low | The existing confirmation dialog already promises this behavior, and volume-down is unaffected. |
| R2 | On some OEMs, `onKeyDown(KEYCODE_VOLUME_UP)` may not fire while a `TYPE_APPLICATION_OVERLAY` is active | Low -- overlay has `FLAG_NOT_FOCUSABLE` and does not set `onKeyListener`; volume keys go to the activity | High (exit does not work) | S44 on nova 5T (Huawei, EMUI) is the proof. If volume keys do not reach the activity on the test device, **stop implementation and report** -- a different approach is needed and will require a new design cycle. Do not proceed with an untested fallback. |
| R3 | Accidental exit -- held volume-up key fires 3+ `onKeyDown` events in 1.5 s | Eliminated | N/A | The detector filters `event.repeatCount == 0`. Held-key repeats produce `repeatCount > 0` and are ignored. Only distinct physical presses count. |
| R4 | Race between `FocusModeService.stop()` and `onDestroy` -- could the service restart before `isTimerFinished` is visible to `onDestroy`? | Low | High | `stopFocusMode()` sets `isTimerFinished = true` synchronously before calling `stopSelf()`. When `onDestroy` runs, the flag is already set. Confirmed by reading `stopFocusMode()` (`:459-471`). |

--------------------------------------------------------------------------------

## Rollback

Revert the single commit on `fix/focus-exit`. No Firestore schema, prefs key, notification channel,
or method-channel changes -- a clean revert restores the previous behavior (volume keys ignored, old
hint text). The only user-visible regression on rollback: the exit hint goes back to "You cannot
exit until timer ends", which contradicts the Dart dialog but matches the pre-fix behavior.

--------------------------------------------------------------------------------

## Checklist

### Pre-implementation
- [ ] Spec reviewed and approved ("approve phase focus-exit")

### Implementation
- [ ] `VolumeExitDetector` class created with injectable clock
- [ ] Press-counter unit test written and passing (`./gradlew :app:testDebugUnitTest`)
- [ ] `performExit(isEarly)` extracted from `onCountdownComplete()` (behavior-preserving)
- [ ] `onKeyDown`/`onKeyUp` updated with VOLUME_UP handling + `repeatCount` filter
- [ ] Completion subtitle uses actual elapsed time, not planned duration
- [ ] `exitHint` and `closeBtn` text updated (EN + AR, using `toArabicNumerals`)
- [ ] `en.json` / `ar.json` `focus_mode_exit_hint` updated to add "quickly" / "بسرعة"
- [ ] Diagnostic log lines added in `FocusModeService.onDestroy`/`onTaskRemoved`
- [ ] `flutter analyze` -- no new issues
- [ ] Kotlin tests pass (5 existing files + new VolumeExitDetectorTest)
- [ ] Release APK builds

### Device check S44 (nova 5T)
- [ ] Start Focus Mode (any duration, e.g. 5 min)
- [ ] Verify exit hint shows "Press volume up 3 times quickly to exit" (not "cannot exit")
- [ ] Press volume up 3 times quickly -> "Did you complete?" prompt appears
- [ ] Verify prompt subtitle shows actual elapsed time (e.g., "1 minute"), not planned duration
- [ ] Tap "Yes" -> task marked done, activity closes, service stopped (logcat: no restart)
- [ ] Repeat: press volume up x3 -> prompt appears -> tap "No" -> restart options shown
- [ ] Pick a restart duration -> Focus Mode restarts, volume exit works again in the new session
- [ ] Press volume up x3 -> prompt appears -> swipe app away from recents -> service does NOT relaunch
- [ ] Press volume up only twice -> nothing happens (no exit)
- [ ] Press volume up 3 times slowly (> 2 s apart) -> nothing happens
- [ ] Hold volume up (single long press) -> nothing happens (repeatCount filter)
- [ ] Arabic language: exit hint shows Arabic text with Arabic numerals, prompt shows Arabic
