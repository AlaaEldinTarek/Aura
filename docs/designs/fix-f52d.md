# Fix spec: F52d — Post-Isha full reload every minute

Status: Draft

## Finding

**F52d** — LOW — After Isha `getNextPrayer` returns a tomorrow-dated Fajr.
`_quickUpdateNextPrayer` (`prayer_times_provider.dart:171–174`) sees
`nextPrayerDate.isAfter(today)` and calls `loadPrayerTimes(DateTime.now())` on every
1-minute tick from Isha time to midnight. `isLoading` toggles each time; possible
home-screen flicker. The repeated reload is a no-op — `loadPrayerTimes` is called with
today's date so it recomputes the same times; alarms are already armed.

## Root cause

The day-transition guard fires every tick because `nextPrayer.time` stays tomorrow's
Fajr until midnight. There is no one-shot protection: each tick re-enters the `if`
branch and re-calls `loadPrayerTimes`.

## Fix

**Phase P1 — `lib/core/providers/prayer_times_provider.dart`**

Add a boolean field to `PrayerTimesNotifier`:
```dart
bool _dayTransitionPending = false;
```

In `_quickUpdateNextPrayer`, gate the reload on the flag:
```dart
if (nextPrayerDate.isAfter(today)) {
  if (!_dayTransitionPending) {
    _dayTransitionPending = true;
    debugPrint('📅 [QUICK_UPDATE] Day transition detected, doing full reload');
    loadPrayerTimes(DateTime.now());
  }
  return;
}
_dayTransitionPending = false;   // ← reset when same-day prayers are back
```

After midnight, `today` advances, `nextPrayerDate` (Fajr) equals `today` (not after it),
so the `else` path naturally resets the flag. No explicit midnight timer is needed.

## Tests

| ID | File | What it checks |
|----|------|----------------|
| T1 | test/core/providers/f52d_source_test.dart | `_dayTransitionPending` field declared |
| T2 | (same) | `_quickUpdateNextPrayer` checks `!_dayTransitionPending` before calling `loadPrayerTimes` |
| T3 | (same) | `_dayTransitionPending = false` reset is present in the same method |

## Device check

| ID | How to run | Expected |
|----|-----------|---------|
| S-F52d-1 | Use date-change test tool (advance to Isha) and watch logcat for 2+ minutes | Only ONE `Day transition detected` log line; `loadPrayerTimes` NOT called on subsequent ticks |

## Contracts

No contracts change.

## Phases

| Phase | File | Scope |
|-------|------|-------|
| P1 | `lib/core/providers/prayer_times_provider.dart` | Add `_dayTransitionPending` flag; gate reload |
