# F75 — `_scheduleJumuahOnStartup()` re-arms Jumu'ah on Login screen (no session gate)

**Status: Draft. No code changed.**
Found: F70 P4 device check, 2026-11-24.
Finding: `reference/findings.md` § F75.

## Problem

`main_wrapper_screen.dart:542` (`_scheduleJumuahOnStartup`) calls
`NotificationService.scheduleJumuahReminder()` unconditionally on every cold start.
When the phone reboots and the user is logged out, the Flutter engine still starts on the
Login screen, the method runs, and alarm 8001 is rescheduled — even though no session
exists. Confirmed on device (nova 5T, 2026-11-24): after logout + reboot + Login screen,
`dumpsys alarm` showed `JumuahReminderReceiver` at `1795767120000` (same timestamp as
before logout). The native boot gate (`PrayerBootReceiver` → `SessionState.isSessionActive`)
worked correctly (no DAILY_RECALC, no prayer alarms); only this Dart path leaked.

## Impact — LOW

Alarm 8001 fires once on the next Friday; the notification is a plain Jumu'ah reminder
with no user data. The gate that prevents prayer alarms from re-arming is unaffected.

## Fix (P1)

**File:** `lib/features/main/main_wrapper_screen.dart`

Add the D1-C session check (mirrors `SessionState.kt`: `isGuest || hasUser`) before
calling `scheduleJumuahReminder`. Both reads are already in `SharedPreferences` (in-
process, no I/O wait) plus a `FirebaseAuth.instance.currentUser` read (SDK in-process).
Add one `firebase_auth` import.

```dart
// Before
Future<void> _scheduleJumuahOnStartup() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('jumua_reminder_enabled') ?? true;
    if (!enabled) return;
    await NotificationService.instance.scheduleJumuahReminder();
  } catch (e) {
    debugPrint("Error scheduling Jumu'ah on startup: $e");
  }
}

// After
Future<void> _scheduleJumuahOnStartup() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('jumua_reminder_enabled') ?? true;
    if (!enabled) return;
    final isGuest = prefs.getBool(AppConstants.keyIsGuest) ?? false;
    final hasUser = FirebaseAuth.instance.currentUser != null;
    if (!isGuest && !hasUser) return;
    await NotificationService.instance.scheduleJumuahReminder();
  } catch (e) {
    debugPrint("Error scheduling Jumu'ah on startup: $e");
  }
}
```

No new prefs key. No contract change. `firebase_auth` is already a dependency.

## Contract check

- No new SharedPreferences keys
- No notification IDs or channels changed
- No method-channel names changed
- No Firestore paths changed

## Tests

| ID | Description |
|----|-------------|
| T1 | `_scheduleJumuahOnStartup`: guest=false, hasUser=false → `scheduleJumuahReminder` NOT called |
| T2 | guest=true, hasUser=false → called |
| T3 | guest=false, hasUser=true → called |
| T4 | enabled=false → NOT called (existing guard, still passes) |

T1–T3 are unit-testable by mocking `SharedPreferences` and `FirebaseAuth`. Add to
`test/features/main/` or alongside the fix as `f75_jumuah_gate_test.dart`.

## Device check

| Step | Description |
|------|-------------|
| S70  | Logout → reboot → Login screen shown → `dumpsys alarm \| grep JumuahReminder` returns empty |

## Phases

- P1 (C, Dart): add import + session guard + tests. Needs "approve phase P1".
