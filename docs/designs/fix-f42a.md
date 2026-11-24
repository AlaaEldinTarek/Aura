# Fix F42a — Stale azkar streak shown after skipped day

**Status:** Approved for code (phase P1)  
**Branch:** `fix/f42a` (to be created from main)  
**Finding:** F42a (LOW)  
**Files touched:**
- `lib/core/providers/azkar_provider.dart`

---

## Problem

`AzkarNotifier._load()` restores state from SharedPreferences JSON, including `streakCount`, but never checks whether `azkar_streak_date` is recent. If the user skipped azkar for one or more days, the stale streak value is loaded and displayed until the next session completion — at which point `_onSessionComplete()` correctly resets it to 1 (non-consecutive branch). The user sees an incorrect, inflated streak on every cold start until they complete another session.

**Root cause:** `AzkarState.fromJson()` always copies `streakCount` from the stored JSON unconditionally. The streak date (`azkar_streak_date`) is stored separately in prefs under `_kStreakDateKey` and is never consulted during `_load()`.

**Example:**
- Monday: user completes morning azkar, `azkar_streak_date = "2026-11-23"`, `streakCount = 5`.
- Tuesday and Wednesday: user skips.
- Thursday morning: user opens app. `_load()` restores `streakCount = 5`. The home screen shows streak 5. Only if the user completes a session on Thursday does `_onSessionComplete()` see `lastDate != yesterday` and reset to 1.

---

## Fix

In `_load()`, after restoring `state` from JSON, read `_kStreakDateKey` from prefs. If the stored date is neither today nor yesterday, `streakCount` is stale — reset it to 0 immediately so the display is correct on cold start.

This matches the logic already in `_onSessionComplete()`: the same `today`/`yesterday` check controls whether the streak increments, stays, or resets. `_load()` now enforces the same invariant eagerly.

No new state, no new prefs keys, no Firestore changes.

---

## Change (Dart)

**File:** `lib/core/providers/azkar_provider.dart` — `_load()` method

```dart
// Before
Future<void> _load() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kPrefsKey);
  if (raw == null) return;
  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    state = AzkarState.fromJson(json, _todayKey());
  } catch (_) {}
}

// After
Future<void> _load() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kPrefsKey);
  if (raw == null) return;
  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    state = AzkarState.fromJson(json, _todayKey());
    final lastDate = prefs.getString(_kStreakDateKey) ?? '';
    if (lastDate != _todayKey() && lastDate != _yesterdayKey()) {
      state = state.copyWith(streakCount: 0);
    }
  } catch (_) {}
}
```

---

## Contract check

| Contract | Verdict |
|----------|---------|
| SharedPreferences key names | Unchanged (`azkar_state`, `azkar_streak_date`) |
| Firestore paths | Not involved |
| Notification IDs / channels | Not involved |
| `AzkarState` model fields | Unchanged |
| New keys introduced | None |

---

## Tests

Source-text test (1 test, file `test/core/services/f42a_source_test.dart`):

- **T1**: `_load()` reads `_kStreakDateKey` after restoring state and resets `streakCount` to 0 when the date is neither today nor yesterday.

---

## Device checks

| Step | Description |
|------|-------------|
| S66 | Complete azkar today. Force-stop the app. Open it the next day (or simulate by advancing device date by 2 days). The streak shown on the home screen must be 0 (not yesterday's value) before any session is completed. |
