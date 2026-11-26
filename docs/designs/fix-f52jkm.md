# Fix spec: F52j + F52k + F52m — Windows desktop batch

Status: Draft

## Findings

| ID | Severity | Summary |
|----|----------|---------|
| F52j | LOW | Desktop reminder timers (wird, digest) are today-only and drift after sleep |
| F52k | LOW | Home countdown stops when the Windows window loses focus |
| F52m | LOW | "Start with Windows" defaults to opt-out (should be opt-in) |

All three are Dart-only, Windows-only, no native contracts changed.

---

## F52j — Desktop reminder timers drift after sleep and are today-only

### Root cause

`scheduleWirdReminders` (`desktop_notification_service.dart:446`) schedules `Timer`s only for
**today's remaining** times (`DateTime(now.year, now.month, now.day, h, m).isBefore(now)` → skip).
`scheduleDailyTaskDigest` (`:491`) schedules once at today's 08:00 and returns early if 08:00 has
already passed. Neither method re-arms for the next day, so an app left running overnight delivers no
wird or digest notifications the following morning.

The wake-detection gap in `prayer_times_provider.dart:141` reschedules prayer timers via
`DesktopPrayerScheduler` but does not touch wird or digest `Timer`s, so those also drift by the
sleep duration.

### Fix

**Phase J1 — `desktop_notification_service.dart`**

1. Add two private fields to store the last-call params so they can be re-used without a new callee:
   ```dart
   List<String>? _wirdReminderTimes;
   int _wirdDailyGoal = 0;
   bool _wirdIsJuzMode = false;
   Future<List<int>> Function()? _digestFetchCounts;
   ```

2. `scheduleWirdReminders`: at the top, store the params in the new fields before the existing logic.

3. `scheduleDailyTaskDigest`: at the top, store `fetchCounts` in `_digestFetchCounts`.
   Replace the early-return when today's 08:00 has passed with a next-day schedule:
   ```dart
   // was: if (digestTime.isBefore(now)) return;
   final target = digestTime.isBefore(now)
       ? digestTime.add(const Duration(days: 1))
       : digestTime;
   ```
   Inside the timer callback, after `_showDailyTaskDigest`, self-reschedule for the next day:
   ```dart
   unawaited(scheduleDailyTaskDigest(0, 0, fetchCounts: _digestFetchCounts));
   ```

4. Add a public method:
   ```dart
   Future<void> rescheduleAfterWake() async {
     if (_wirdReminderTimes != null) {
       await scheduleWirdReminders(
         reminderTimes: _wirdReminderTimes!,
         dailyGoal: _wirdDailyGoal,
         isJuzMode: _wirdIsJuzMode,
       );
     }
     await scheduleDailyTaskDigest(0, 0, fetchCounts: _digestFetchCounts);
   }
   ```

**Phase J2 — `prayer_times_provider.dart`**

In the wake-detection block (`:141–147`), after `schedulePrayerTimers`, add:
```dart
DesktopNotificationService.instance
    .rescheduleAfterWake()
    .catchError((e) => debugPrint('⚠️ [DESKTOP] Reminder reschedule after wake failed: $e'));
```

---

## F52k — Home countdown stops when the desktop window loses focus

### Root cause

`home_screen.dart:208–209` cancels `_countdownTimer` on both `AppLifecycleState.paused` and
`AppLifecycleState.inactive`. On Windows, losing window focus triggers `inactive` (not `paused`);
the countdown stops whenever the user switches to another app.

On mobile, `inactive` is a brief transient state before `paused` (call overlays, system dialogs),
so the existing guard is correct on mobile — removing it from the mobile path is harmless because
`paused` follows immediately.

### Fix

**Phase K — `home_screen.dart`**

Guard the `inactive` cancel with `!_isDesktop` (the getter is already defined at line 370 of the
same file):
```dart
if (state == AppLifecycleState.paused ||
    (state == AppLifecycleState.inactive && !_isDesktop)) {
  _countdownTimer?.cancel();
}
```

---

## F52m — "Start with Windows" defaults to opt-out

### Root cause

`windows_startup_service.dart:20`:
```dart
return prefs.getBool(prefKey) ?? true;
```
The fallback is `true`, so a fresh install silently adds Aura to the Windows startup list without
user consent. The expected default was opt-in (user decision 2026-11-07).

### Fix

**Phase M — `windows_startup_service.dart`**

Change the fallback:
```dart
return prefs.getBool(prefKey) ?? false;
```

**Migration**: existing users who never changed the setting currently have `windows_startup_enabled`
unset in prefs, so after the update they get `false` and Aura stops auto-starting. Users who
explicitly enabled or disabled it are unaffected (prefs key is set). This is the intended behaviour;
no migration needed.

---

## Tests

| ID | File | What it checks |
|----|------|----------------|
| T1 | test/core/services/f52jkm_source_test.dart | `scheduleDailyTaskDigest`: when called after 08:00, next timer fires tomorrow at 08:00 |
| T2 | (same) | `rescheduleAfterWake` re-arms wird timers using stored params |
| T3 | (same) | `rescheduleAfterWake` re-arms digest timer |
| T4 | test/features/home/f52jkm_source_test.dart | Countdown timer NOT cancelled on `inactive` on desktop |
| T5 | (same) | Countdown timer IS cancelled on `paused` on desktop |
| T6 | test/core/services/f52jkm_source_test.dart | `WindowsStartupService.isEnabled()` returns false when no pref set |

---

## Device checks

| ID | How to run | Expected |
|----|-----------|---------|
| S-F52k-1 | Build release, open Home, switch to another window for 60 s, return | Countdown keeps ticking; jumps to correct value on return |
| S-F52m-1 | Fresh install (or clear the `windows_startup_enabled` pref via Registry), launch | Aura NOT listed in `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run` |

F52j: sleep-overnight test is not practical in a one-off check; covered by the self-reschedule unit
tests (T1–T3) instead.

---

## Contracts

No prefs keys, Firestore paths, notification IDs, channels, or MethodChannel names change.

---

## Phases

| Phase | File(s) | Scope |
|-------|---------|-------|
| J1 | `lib/core/services/desktop_notification_service.dart` | store params, next-day digest, self-reschedule, `rescheduleAfterWake` |
| J2 | `lib/core/providers/prayer_times_provider.dart` | call `rescheduleAfterWake` on wake detection |
| K | `lib/features/home/home_screen.dart` | guard `inactive` with `!_isDesktop` |
| M | `lib/core/services/windows_startup_service.dart` | default `false` |
