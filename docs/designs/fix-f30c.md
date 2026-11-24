# Fix F30c — Completed tasks lose their timestamp when edited; show as "completed today" forever

**Status:** Approved for code (phase P1)  
**Branch:** `fix/f30c` (to be created from main)  
**Finding:** F30c (MEDIUM)  
**Files touched:**
- `lib/core/services/task_service.dart`
- `lib/features/tasks/tasks_screen.dart`

---

## Problem

Two bugs interact to produce the visible symptom:

### Bug 1 — `task_service.dart` wipes `completedAt` on every edit

`updateTask()` has two paths (guest local and Firestore). Both use the same ternary:

```dart
// guest path, line 415
completedAt: isCompleted == true && !current.isCompleted ? DateTime.now() : null,

// Firestore path, line 459 — identical
completedAt: isCompleted == true && !currentTask.isCompleted ? DateTime.now() : null,
```

The condition `isCompleted == true && !current.isCompleted` is only true when a task **transitions** from not-completed to completed. For any other update (editing title, tags, priority, etc. on a task that was already completed), the condition is false and `completedAt` is set to `null`.

**Effect:** editing any field of an already-completed task silently clears its completion timestamp.

### Bug 2 — `_isCompletedToday` treats null as "today"

```dart
bool _isCompletedToday(Task t) {
  if (t.completedAt == null) return true;   // ← bug
  ...
}
```

A task with no completion timestamp is assumed to have been completed today. Combined with Bug 1, any task that is completed and then edited shows up permanently in the "completed today" section — even tasks from days or weeks ago.

---

## Fix

### `task_service.dart` — preserve `completedAt` when already completed (both paths)

```dart
// Before (line 415 and line 459, same in both paths)
completedAt: isCompleted == true && !current.isCompleted ? DateTime.now() : null,

// After
completedAt: isCompleted == true
    ? (current.isCompleted ? current.completedAt : DateTime.now())
    : null,
```

Semantics:
- Completing a task (false → true): `DateTime.now()`
- Editing a completed task (true → true): preserves `current.completedAt`
- Un-completing a task (true → false, or null): `null`

### `tasks_screen.dart` — return false for null `completedAt`

```dart
// Before (line 1022)
bool _isCompletedToday(Task t) {
  if (t.completedAt == null) return true;

// After
bool _isCompletedToday(Task t) {
  if (t.completedAt == null) return false;
```

A task with no completion timestamp (old pre-schema data, or any that slipped through before this fix) is not claimed as completed today. The task remains in Firestore / local storage; it just won't appear in the "completed today" section.

---

## Contract check

| Contract | Verdict |
|----------|---------|
| SharedPreferences key names | Unchanged |
| Firestore paths | Unchanged (`completedAt` field preserved correctly) |
| Notification IDs / channels | Not involved |
| `Task` model fields | Unchanged |
| New keys introduced | None |

---

## Tests

Source-text tests (2 tests, file `test/features/tasks/f30c_source_test.dart`):

- **T1**: `task_service.dart` uses the three-arm ternary that preserves `completedAt` for already-completed tasks.
- **T2**: `_isCompletedToday` returns `false` (not `true`) when `completedAt == null`.

---

## Device check

| Step | Description |
|------|-------------|
| S69 | Complete a task today. Edit its title (without un-completing it). The task should still appear in the "completed today" section with its original completion time intact (not disappear or reappear as "completed today" after re-opening). |
