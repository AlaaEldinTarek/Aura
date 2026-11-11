# Fix F36b — Prayer Tab "Next Prayer" Goes Stale

*   **Author:** Alaa Eldin Tarek
*   **Status:** Draft
*   **Date:** 2026-11-11

---

## Overview

After the countdown on the Prayer tab reaches zero, the "next prayer" card does not update. The card keeps showing the prayer that just passed until the user pulls to refresh or leaves and returns to the tab. The root cause is a single call site in `prayer_screen.dart` that refreshes the Riverpod provider but never syncs the result into local widget state.

## The Problem

`_loadPrayerTimes()` (`:128`) is the only method that reads from `prayerTimesProvider` and calls `setState` to update `_nextPrayer`, `_currentPrayer`, and `_prayerTimes`. It runs on `initState` (`:80`) and on pull-to-refresh (`:204`).

The countdown's `onComplete` callback (`:744`) calls `ref.read(prayerTimesProvider.notifier).loadPrayerTimes(DateTime.now())` directly. That updates the provider, but `_nextPrayer` / `_currentPrayer` / `_prayerTimes` are never reassigned, so the widget tree rebuilds with stale values.

```
onComplete fires
  └─ ref.read(prayerTimesProvider.notifier).loadPrayerTimes(now)
       └─ provider updated ✓
            └─ setState never called ✗
                 └─ _nextPrayer still points to the prayer that just passed
```

## Goals

*   After the countdown reaches zero the "next prayer" card updates automatically, without pull-to-refresh.
*   No behavior change to the loading shimmer, error handling, or pull-to-refresh path.

## Non-Goals

*   Adding a `ref.listen` on `prayerTimesProvider` to react to external provider changes — see **Scope Decision** below.
*   Any other F36 sub-items (F36a, F36c already done; F36d resolved).
*   Changes to prayer tracking, alarms, or notification scheduling.

---

## Scope Decision: `ref.listen` at `:401–414`

The existing `ref.listen` watches `dailyPrayerStatusProvider`, not `prayerTimesProvider`. It syncs prayer completion statuses (prayed / missed) into `_prayerStatuses` and `_explicitlyMarked`. It is unrelated to next-prayer staleness.

Adding a parallel `ref.listen` on `prayerTimesProvider` would react to any external provider change (e.g., Home screen refresh, background recalc) and keep local state in sync continuously. That is a separate architectural change with its own risk surface (double setState, interaction with the existing `_loadPrayerTimes` fast path). It is **out of scope** for this fix.

The `ref.listen` at `:401–414` is left untouched.

---

## Critical User Journeys

### CUJ 1: Countdown reaches zero while Prayer tab is open

*   **Given**: The Prayer tab is open and showing a countdown to the next prayer.
*   **When**: The countdown reaches zero (prayer time is reached).
*   **Then**: The "next prayer" card updates to the following prayer without any user interaction.

### CUJ 2: Pull-to-refresh still works

*   **Given**: The Prayer tab is open.
*   **When**: The user pulls to refresh.
*   **Then**: Prayer times reload exactly as before — no change to this path.

---

## Technical Plan

One call site changes. `onComplete` currently bypasses `_loadPrayerTimes()`. Replacing the direct provider call with `_loadPrayerTimes()` restores the correct flow:

```
onComplete fires
  └─ _loadPrayerTimes()
       ├─ reads existing provider state → setState (no shimmer)
       └─ calls provider.loadPrayerTimes(now) in background → setState again
            └─ _nextPrayer / _currentPrayer / _prayerTimes updated ✓
```

`_loadPrayerTimes()` already:
- calls `ref.read(prayerTimesProvider.notifier).loadPrayerTimes(DateTime.now())` internally
- reads the result back and calls `setState`
- handles errors with the existing try/catch
- calls `_loadCompletedPrayers()` to keep status badges consistent

No new logic is introduced.

---

## Alternatives Considered

### Alternative A: Call `setState` directly in `onComplete` after the provider call

Read the provider state after `loadPrayerTimes` returns and assign `_nextPrayer` / `_currentPrayer` / `_prayerTimes` inline.

*   **Pros**: Minimal diff; no second provider call.
*   **Cons**: Duplicates the read-and-assign logic already in `_loadPrayerTimes`, drifts independently. Misses the `_loadCompletedPrayers()` call that `_loadPrayerTimes` includes — badges would be stale.
*   **Reason for rejection**: Rejected by author — duplicates existing logic and skips badge refresh.

### Alternative B: Add `ref.listen` on `prayerTimesProvider`

Watch the provider for all changes; call `setState` whenever it emits.

*   **Pros**: Keeps local state in sync for any external change, not just countdown completion.
*   **Cons**: Wider scope than the finding; risk of double-setState interacting with `_loadPrayerTimes` fast path; belongs to a separate finding.
*   **Reason for rejection**: Rejected by author — out of scope for F36b; addressed separately.

---

## Non-Functional Requirements

None critical for this change. The fix removes two `debugPrint` calls and replaces one `await` with another; no performance or security impact.

---

## Detailed Implementation Plan

### Target Files to Modify

#### 1. `lib/features/prayer/prayer_screen.dart` (Modify)

*   **Type / Scope**: Flutter StatefulWidget — `_PrayerScreenState.onComplete` callback
*   **Line range**: `:744–757` (the `onComplete:` callback body)
*   **Current code (`:746–756`)**:
    ```dart
    Future.microtask(() async {
      if (mounted) {
        debugPrint(
            '🔔 [COUNTDOWN] Prayer time reached! Refreshing prayer times...');
        // Do a full refresh to ensure next day's prayers are loaded if needed
        await ref
            .read(prayerTimesProvider.notifier)
            .loadPrayerTimes(DateTime.now());
        debugPrint('🔔 [COUNTDOWN] Prayer times refreshed');
      }
    });
    ```
*   **Proposed change**: Replace the body of the microtask with a single call to `_loadPrayerTimes()`:
    ```dart
    Future.microtask(() async {
      if (mounted) {
        await _loadPrayerTimes();
      }
    });
    ```
*   **Why**: `_loadPrayerTimes()` calls the provider, reads back the result, and calls `setState` — the direct call did not. The two `debugPrint` lines are removed; they were debug-only noise with no replacement needed.

No other files are modified. No new files are created. No contracts (prefs keys, MethodChannels, notification IDs, Firestore paths) are touched.

### Verification Plan

*   **Static analysis**: `flutter analyze` — no new issues above the 418-issue baseline.
*   **Format**: `dart format --output=none --set-exit-if-changed .` — no formatting diff.
*   **Unit tests**: `flutter test` — all 249 existing Dart tests pass. No dedicated unit test is added: triggering `CircularCountdownTimer.onComplete` in a widget test requires mocking the third-party countdown widget's internal timer, which is not exposed; the fix is a one-line call-site swap with no branching logic, and `_loadPrayerTimes` itself is exercised via init and pull-to-refresh paths.
*   **Device check (nova 5T, nova 5T = API 29)**:
    1. Open the Prayer tab. Note the current "next prayer" name and time.
    2. Advance the device clock past the next prayer time (or wait for it naturally).
    3. The countdown reaches zero.
    4. **Pass criterion**: The "next prayer" card updates to the following prayer without pull-to-refresh.
    5. Pull to refresh and confirm the displayed data is consistent.

---

*Drafted with EGM*
