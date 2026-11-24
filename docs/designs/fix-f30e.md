# Fix F30e — Task form aliases the tags list of the original Task

**Status:** Approved for code (phase P1)  
**Branch:** `fix/f30e` (to be created from main)  
**Finding:** F30e (MEDIUM)  
**Files touched:**
- `lib/features/tasks/task_form_screen.dart`

---

## Problem

`_loadTaskData()` in `_TaskFormScreenState` sets:

```dart
_tags = task.tags ?? [];   // line 69 — reference to task.tags, not a copy
```

`_tags` is then mutated in-place by:
- `onDeleted: () => setState(() => _tags.remove(tag))`  (line 1650)
- `setState(() { _tags.add(tag); })` (line 1671)

Because `_tags` is the same `List<String>` object as `task.tags`, those mutations directly modify the in-memory `Task` model **before** the form is saved. The same issue does not exist for subtasks, which are correctly copied on line 76:

```dart
_subtasks = List<SubTask>.from(task.subtasks);  // copied ✓
```

**Impact:** When a user opens the edit form for a task that has tags and adds or removes a tag, the original `Task` object (held by the provider) is silently mutated. If the user then cancels the form, the in-memory task reflects the edit even though it was never saved. This can cause:
- Tags shown as changed in the task list before saving.
- Cancelled edits leaving mutated state until the next Firestore sync.

---

## Fix

Copy the tags list in `_loadTaskData()`, matching the pattern already used for subtasks:

```dart
// Before
_tags = task.tags ?? [];

// After
_tags = List<String>.from(task.tags ?? []);
```

One character change. No other code paths are affected.

---

## Contract check

| Contract | Verdict |
|----------|---------|
| SharedPreferences key names | Unchanged |
| Firestore paths | Unchanged (the save path is unaffected) |
| Notification IDs / channels | Not involved |
| `Task` model fields | Unchanged |
| New keys introduced | None |

---

## Tests

Source-text test (1 test, file `test/features/tasks/f30e_source_test.dart`):

- **T1**: `_loadTaskData` uses `List<String>.from(...)` for tags (not a bare alias).

---

## Device check

| Step | Description |
|------|-------------|
| S68 | Edit a task that has tags. Remove one tag. Cancel without saving. Verify the original tag is still visible in the task list (not removed). |
