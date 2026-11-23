# F7 — Stop Dart from cancelling the native Daily Prayer Reminder (notification ID 7001)

*   **Author:** Alaa Eldin Tarek
*   **Status:** Draft, not approved. Docs only: no code is written until the owner says "approve phase P1".
*   **Level:** C (production code in `lib/`, contract doc in `.project-docs/contracts/`).
*   **Branch:** `fix/f7-jumuah-7001`, from `origin/main` (eea212a). Not based on `fix/f70-native`.
*   **Date:** 2026-11-23
*   **Source:** finding F7 (`.project-docs/reference/findings.md`), rated HIGH by the owner on 2026-11-23 (user-visible).

Labels: VERIFIED = read in code, UNVERIFIED = not run on a device, UNKNOWN = not checked.

---

## Problem (VERIFIED, code read)

All Dart `flutter_local_notifications` IDs and all native `NotificationManagerCompat` IDs share one notification
manager (same package, null tag), so `cancel(7001)` from Dart removes a native notification that uses 7001.

*   Native owner of 7001: the Daily Prayer Reminder card (`DailySummaryCard.NOTIFICATION_ID = 7001`,
    `DailySummaryReceiver`, channel `prayer_tracking`). The card is ongoing and is meant to stay until the user taps it,
    tracks all prayers, or the day ends (`DailySummaryCard.timeoutAfterMs`).
*   Dart legacy cleanup: `NotificationService._jumuahNotificationId = 7001` (`notification_service.dart:59`) is
    cancelled unconditionally in two places:
    *   `scheduleJumuahReminder()` (`:1413`), which runs on every app start (`initialize`, `:146-150`, when
        `jumua_reminder_enabled` is true, default true) and when the Jumu'ah toggle is switched on
        (`profile_screen.dart:1174`, `settings_screen.dart:238`).
    *   `cancelJumuahReminder()` (`:1424`), when the toggle is switched off (`profile_screen.dart:1176`,
        `settings_screen.dart:240`).
*   Effect: every app start dismisses the Daily Prayer Reminder card if it is showing. The card is not a Jumu'ah
    notification; the Dart constant is a leftover from the first Jumu'ah implementation (commit 41682de), which
    scheduled the reminder through `flutter_local_notifications`. The real Jumu'ah reminder is native and uses 8001
    (`JumuahReminderReceiver`), which is unaffected by this bug.
*   Device impact: UNVERIFIED. The owner's 2026-11-22 screenshots do not show it directly. P0 below reproduces it on
    the current build before any fix.

The same pattern was already fixed for the task digest 4001: `hasLegacyDigestAlarm` in
`lib/core/utils/legacy_digest.dart` cancels only when a leftover really is still pending.

## Goal

*   The Dart side never cancels 7001 while a native card may be showing.
*   A leftover alarm that an old build armed through `flutter_local_notifications` under 7001 is still cleaned, but only
    when it is really pending, using `pendingNotificationRequests()`.
*   The Jumu'ah reminder (8001) schedules and cancels exactly as before.

## Non-goals

*   No notification ID is renamed or moved. 7001 stays the Daily Prayer Reminder; 8001 stays the Jumu'ah reminder.
*   No new prefs key, MethodChannel, channel ID, intent extra, Firestore field or log tag.
*   No change to F4 (achievement range 7100-8099 vs 8001) or F8 (4001 vs 4000-4999). They need their own specs.
*   No change to Kotlin. No UI change. No string change.
*   No change to the Windows path (`scheduleJumuahReminder` and `cancelJumuahReminder` return early off Android).

## Design

1.  **New pure helper** `lib/core/utils/legacy_jumuah.dart`, mirroring `legacy_digest.dart`:
    `bool hasLegacyJumuahAlarm(Iterable<int> pendingIds, int id) => pendingIds.contains(id);`
    plus a small function that takes the pending-id list and a cancel callback, cancels at most once, and does
    nothing when the id is not pending:
    `Future<bool> cancelLegacyJumuahAlarmIfPending({required Future<Iterable<int>> Function() pendingIds, required Future<void> Function(int) cancel, required int id})`
    (returns true if it cancelled). Final signature is settled at P1; the behavior is fixed here.
2.  **`NotificationService`**: in `scheduleJumuahReminder()` replace
    `await _notifications.cancel(_jumuahNotificationId)` with a call to the helper (pending list from
    `_notifications.pendingNotificationRequests()`, cancel callback `_notifications.cancel`). In
    `cancelJumuahReminder()` do the same. Both keep the native `invokeMethod` calls exactly as they are.
3.  **Failure isolation:** the legacy cleanup runs inside its own try/catch, so an error there can never skip the native
    schedule or cancel call for 8001. Today a throwing `cancel(7001)` in the same try block skips the native call.
4.  **No one-time flag.** The pending-id check is idempotent and cheap, and a flag would be a new prefs key. After the
    first run on an affected device nothing is pending, so nothing is cancelled again.
5.  **Contract update in the same commit:** `.project-docs/contracts/notification-ids.md`, row 7001: drop
    "collision F7", state that Dart no longer cancels 7001 except when a legacy `flutter_local_notifications` alarm is
    pending, and that 7001 is owned by `DailySummaryCard`. `findings.md` F7 and STATE.md are updated in the day's docs
    commit, not in the code commit.
6.  **Alternative (not chosen, owner decision 2026-11-23):** delete the legacy cleanup completely. Every Android install
    of 1.1.0 has already run the unconditional cancel on each start, so a leftover alarm very likely no longer exists
    there. The cleanup is kept because users upgrading from before 1.1.0 may still have one. Note: 
    `pendingNotificationRequests()` only lists entries the plugin scheduled; it never sees the native card, so the
    check cannot cancel the Daily Prayer Reminder.

## Tests first (P1, before any production change)

New file `test/core/utils/legacy_jumuah_test.dart` (pattern of `test/core/utils/legacy_digest_test.dart`):

| # | Case | Expected |
|---|---|---|
| T1 | pending list does not contain 7001 | cancel callback is never called, returns false |
| T2 | pending list contains 7001 | cancel called once with 7001, returns true |
| T3 | pending list lookup throws | no cancel call, no exception escapes |
| T4 | called 3 times in a row with no 7001 pending (models app start, toggle on, toggle off) | cancel never called |
| T5 | guard test: scan every `.dart` file under `lib/` for a `cancel(` call whose argument is the literal `7001` or the `_jumuahNotificationId` constant | fails if any match is found outside `lib/core/utils/legacy_jumuah.dart` |

**Seam (owner decision 2026-11-23): helper-only tests.** The two `NotificationService` methods pass the plugin calls
as closures into the helper, so T1-T4 prove the behavior. `NotificationService` is a singleton that owns a
`FlutterLocalNotificationsPlugin`; it is not made testable with a fake plugin (no `@visibleForTesting` constructor).
T5 closes the gap: it is what proves the wiring, by failing if a direct `cancel(7001)` ever comes back. T5 reads
`lib/` as text from the test (`dart:io`), skips comment lines, and matches `cancel(7001`, `cancel(_jumuahNotificationId`
and `cancel(notificationId` only where `notificationId` is assigned 7001 in the same file; the exact patterns are fixed
at P1 and the test must be shown to fail against the current `notification_service.dart` before the wiring is changed.

Tests run first. Against the old behavior T5 fails (the two `cancel(_jumuahNotificationId)` calls, `:1413` and `:1424`)
and T1, T3, T4 fail until the helper exists and is wired; T2 only checks the helper itself.

## Phases

| Phase | Level | Content | Gate |
|---|---|---|---|
| P0 | device, no code | Reproduce F7 on the current build (steps below) | owner |
| P1 | C | Tests T1-T4, helper, wiring in `NotificationService`, contract row, in that order, one commit per logical change | "approve phase P1" |
| P2 | device + A | Device check on the P1 build, then record in findings, STATE and the day log | owner |

## Device checks (nova 5T, API 29)

**P0, before the fix (current build):**
The card is posted once a day at `daily_summary_time` (default 21:00) when a prayer has no stored status. It stays
until tapped, tracked or end of day, so any time it is showing is a valid start. Do not use `am force-stop` (it wipes
the app's alarms on EMUI).
1.  Before: `adb shell dumpsys notification --noredact | grep "id=7001"` must show a `NotificationRecord` for
    `com.aura.hala` (channel `prayer_tracking`). Save the output as the "before" record.
2.  Trigger, either one (the toggle is the deterministic one: it always reaches `cancel(7001)`):
    *   Settings: switch the Jumu'ah reminder off, then on; or
    *   open Aura from the launcher after its Flutter engine has stopped (`initialize` runs `scheduleJumuahReminder`).
3.  After: run the same `dumpsys` grep. Expected on the current build, UNVERIFIED: no `id=7001` line.
4.  Evidence of who removed it: `adb logcat -b events -d -v time | grep notification_cancel | grep 7001` (the events
    buffer logs package, id and reason; reason 8 is an app cancel, 2 a user dismiss; availability on EMUI UNVERIFIED).
    Dart log lines for the same window: `[JUMUA] Jumu'ah reminder scheduled via native` / `cancelled`.
5.  Record before, after and the events line in the day log. For P2, the same steps must show the `id=7001` line
    still present after the trigger.

**P2, after the fix (P1 build):** repeat 1-3. **PASS:** the card is still there after the app opens, and again after
switching the Jumu'ah toggle off and on in Settings.

**8001 still works (both before and after):**
*   Toggle Jumu'ah off: `adb shell dumpsys alarm | grep -i JumuahReminder` shows no alarm; log line
    `✅ Jumu'ah reminder cancelled` (`JumuahReminder` tag) and Dart `✅ [JUMUA] Jumu'ah reminder cancelled`.
*   Toggle on: an alarm for the next Friday at Zuhr minus 30 min is armed; Dart `✅ [JUMUA] Jumu'ah reminder scheduled via native`.
*   Boot path unchanged (`PrayerBootReceiver.rescheduleJumuahReminder`, no Dart involved).

## Risks

*   **A real leftover legacy alarm exists on some device:** handled by the pending check, which cancels it once.
*   **`pendingNotificationRequests()` unavailable or slow at app start:** the helper catches the error and skips the
    cleanup; startup is not blocked and 8001 scheduling still runs (design step 3).
*   **Contract drift:** the contract row is changed in the same commit as the code (CLAUDE.md native-keys rule).

## Owner decisions (2026-11-23)

1.  Test seam: helper-only tests, plus the T5 guard test over `lib/`.
2.  Keep the pending-check cleanup (design step 6).

No open questions remain.

## Related decisions recorded 2026-11-23 (not part of this spec)

*   **F66 intended behavior (owner):** adhan OFF = the normal prayer notification only (normal vibration is fine). No
    `AdhanFullScreenActivity`, no foreground-service adhan mode. A reciter preview may play with adhan off. A preview
    must never interrupt a real prayer adhan. Becomes its own spec later.
*   **F74 (LOW, new):** the post-prayer azkar card should stay about 30 minutes or until dismissed, not 60 seconds
    (`AzkarAlarmReceiver.kt:155`, `setTimeoutAfter(60_000)`).
*   **F73 (MEDIUM, new, next after F7):** the 3999 task summary uses Dart text frozen at schedule time (language, counts,
    Arabic plural).
*   **F52e** raised to MEDIUM and **F51c** gets the owner's 2026-11-22 screenshots as device evidence. Docs edits wait
    for the day's single docs commit.
