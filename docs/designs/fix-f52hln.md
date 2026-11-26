# Fix spec: F52h + F52l + F52n (+ F38e resolved)

**Status:** Draft — not yet approved for code  
**Branch:** `fix/f52hln` (from main 91d3ffd)  
**Files touched (Dart):** `lib/core/services/wird_marker_service.dart`, `lib/features/dhikl/dhikr_screen.dart`, `lib/features/tasks/tasks_screen.dart`  
**Docs:** `findings.md` (F38e resolved, F52i note)

---

## Findings

### F38e — RESOLVED (stale finding)
Finding was written before PR #29 (Wird mode separation, 2026-11-16).  
`averagePerCompletedDay` in `wird_marker_logic.dart:214–226` already returns juz/day
in juz mode (`juzKhatmCount * 30 + checkedJuzCount`); `quran_stats_screen.dart:145`
labels it `quran_stats_juz` ("juz"). Calculation and label are both correct. No fix needed.

### F52h — Wird achievements never called from Wird code
`AchievementService.checkAndAward` callers: `prayer_tracking_service.dart:134`,
`task_service.dart:531`, `profile_screen.dart:1180`. None are in Wird code.  
Result: page-mode Wird achievements (`wird_khatma`, `wird_pages_100`, `wird_pages_300`)
are never triggered by Wird activity; they fire only if the user also completes a prayer,
task or visits the Profile screen.

### F52i — Deferred to native fix group
`NotificationService.scheduleWirdReminders` shows "X pages today" in juz mode.
Full fix requires both Dart (notification_service.dart) and Kotlin
(`NativeReminderCard.bodyFor`). Deferred to the native group (F51n/p batch).

### F52l — Dhikr counter ignores vibration settings
`dhikr_screen.dart._incrementCounter` calls `HapticFeedback.mediumImpact()` (Flutter
built-in, no settings check) and `Vibration.vibrate(duration: 50)` unconditionally.
`_resetCounter` calls `HapticFeedback.lightImpact()`. `_onComplete` calls
`Vibration.vibrate(pattern: [0, 100, 50, 100])` unconditionally. The app-wide
`lib/core/utils/haptic_feedback.dart` wrapper (which checks `vibration_enabled`) is
not used here. Same family as F23 and F44 backlog.

### F52n — Pinned float relies on unstable sort
`tasks_screen.dart._applySort` ends with:
```dart
sorted.sort((a, b) {
  if (a.isPinned == b.isPinned) return 0;
  return a.isPinned ? -1 : 1;
});
```
Dart `List.sort` is not guaranteed stable, so the relative order of tasks within
each pinned/unpinned group may change, negating the first sort.

---

## Fixes

### P1 — F52h: fire checkAndAward after Wird marker events

In `wird_marker_service.dart`:
1. Add `import '../services/achievement_service.dart' show AchievementService;`
2. In `move()`, after the `Moved(...)` return value is assembled (after `creditPages`
   succeeds), add:
   ```dart
   AchievementService.instance.checkAndAward(userId: _uid() ?? 'guest_user');
   ```
   (unawaited — fire and forget, same pattern as `task_service.dart:540`)
3. In `completeKhatma()`, after the `Completed(...)` return value is assembled (after
   `creditPages` succeeds), add the same unawaited call.

Guest users: `checkAndAward` returns early for `'guest_user'` — no Firestore access.

### P1 — F52l: route dhikr haptics through the app wrapper

In `dhikr_screen.dart`:
1. Remove `import 'package:flutter/services.dart';` and `import 'package:vibration/vibration.dart';`
2. Add `import '../../core/utils/haptic_feedback.dart' as app_haptic;`
3. `_incrementCounter` (line ~113): replace `HapticFeedback.mediumImpact();` with
   `unawaited(app_haptic.HapticFeedback.medium());`
4. `_incrementCounter` (lines ~127–131): remove the entire `Vibration.hasVibrator().then(...)` block
5. `_resetCounter` (line ~135): replace `HapticFeedback.lightImpact();` with
   `unawaited(app_haptic.HapticFeedback.light());`
6. `_onComplete` (line ~148): replace `HapticFeedback.heavyImpact();` with
   `unawaited(app_haptic.HapticFeedback.heavy());`
7. `_onComplete` (lines ~159–164): remove the `Vibration.hasVibrator().then(...)` block

No behaviour change when vibration is on; vibrations suppressed when the user has
disabled them in Settings.

### P1 — F52n: stable pinned-float sort

In `tasks_screen.dart._applySort`, replace:
```dart
sorted.sort((a, b) {
  if (a.isPinned == b.isPinned) return 0;
  return a.isPinned ? -1 : 1;
});
return sorted;
```
with:
```dart
final pinned = sorted.where((t) => t.isPinned).toList();
final unpinned = sorted.where((t) => !t.isPinned).toList();
return [...pinned, ...unpinned];
```

Preserves the order from the first sort within each group. `O(n)` and always stable.

---

## Tests (test/features/tasks/f52n_source_test.dart + test/features/dhikl/f52hl_source_test.dart)

**T1 — F52h**: `wird_marker_service.dart` imports `achievement_service.dart` and calls
`checkAndAward` in both `move` and `completeKhatma` bodies (source-text).

**T2 — F52l**: `dhikr_screen.dart` does not import `flutter/services.dart` or `vibration`; imports
`haptic_feedback.dart`; does not call `Vibration.vibrate` (source-text).

**T3 — F52n**: `tasks_screen.dart._applySort` does not contain a `sorted.sort` call after
the first per-field sort (source-text: no second `sorted.sort` block).

---

## Contracts / risks

- No prefs key changes.  
- No Firestore changes (achievement writes are already in `checkAndAward`).  
- No notification IDs changed.  
- `checkAndAward` is idempotent: calling it twice will not double-award.  
- Removing `Vibration.vibrate` from dhikr: users who had vibration off and expected no
  vibration: no change. Users with it on: same Flutter haptic, no extra physical vibration.
  The physical vibration was not user-visible in Settings (it was always extra) so removing
  it is a silent cleanup.
- `F52i` deferred — no change to reminder text in this PR.

---

## Phases

| Phase | Description | Status |
|-------|-------------|--------|
| P1 | spec (this file) + findings.md update | Draft |
| P1 | F52h: checkAndAward in wird_marker_service.dart | pending approve |
| P1 | F52l: haptic_feedback wrapper in dhikr_screen.dart | pending approve |
| P1 | F52n: stable sort in tasks_screen.dart | pending approve |
| P1 | source-text tests T1–T3 | pending approve |
