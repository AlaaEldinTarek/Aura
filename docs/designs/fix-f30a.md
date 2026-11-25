# Fix F30a — Task shown twice (Today + Due Soon)

**Status:** Approved for code (phase P1)  
**Branch:** `fix/f30a` (to be created from main)  
**Finding:** F30a (LOW)  
**Files touched:**
- `lib/features/tasks/tasks_screen.dart`

---

## Problem

`_buildDateSortedView` builds sections in this order:
`overdueTasks` → `todayTasks` → (date variables) → `dueSoonTasks` → …

A task due today with a time within 3 hours qualifies for **both** sections:
- `todayTasks`: `isDueToday && !isOverdue` — matches
- `dueSoonTasks`: `dueDate.isAfter(now) && dueDate.isBefore(in3Hours)` — also matches

Both sections render the same task card (`tasks_screen.dart:1152–1171,
:1242–1265`). The existing pattern is "more-specific section wins":
`tomorrowTasks` already excludes `dueSoonTasks`, and `thisWeekTasks`
excludes both. `todayTasks` is missing the same guard because
`dueSoonTasks` is computed after it.

---

## Fix

Hoist the date-variable block and `dueSoonTasks` computation above
`todayTasks`, then add `!dueSoonTasks.contains(t)` to the `todayTasks`
filter. This matches the existing exclusion pattern for all other sections.

**Before** (abbreviated, lines ~1156–1183):

```dart
// date vars computed at line 1166 — AFTER todayTasks
final todayTasks = tasks
    .where((t) => isVisible(t) && t.isDueToday && !t.isOverdue)
    ...

final now = DateTime.now();
...
final in3Hours = now.add(const Duration(hours: 3));
...

final dueSoonTasks = tasks.where((t) {
  ...
  return t.dueDate!.isAfter(now) && t.dueDate!.isBefore(in3Hours);
}).toList()...
```

**After**:

```dart
// date vars and dueSoonTasks moved above todayTasks
final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);
final tomorrow = today.add(const Duration(days: 1));
final in3Hours = now.add(const Duration(hours: 3));
final thisWeekEnd = today.add(const Duration(days: 7));
final nextWeekEnd = today.add(const Duration(days: 14));

// Due soon computed first so todayTasks can exclude it
final dueSoonTasks = tasks.where((t) {
  if (!isVisible(t) || t.isOverdue || t.isCompleted) return false;
  if (t.dueDate == null || !t.hasDueTime) return false;
  return t.dueDate!.isAfter(now) && t.dueDate!.isBefore(in3Hours);
}).toList()
  ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!))
  ..sort((a, b) {
    if (a.isPinned == b.isPinned) return 0;
    return a.isPinned ? -1 : 1;
  });

final todayTasks = tasks
    .where((t) =>
        isVisible(t) && t.isDueToday && !t.isOverdue &&
        !dueSoonTasks.contains(t))   // ← new guard
    .toList()
  ..sort(...)
  ..sort(...);
```

The rest of the section order (`overdueTasks`, `tomorrowTasks`, …) is unchanged.

---

## Contract check

| Contract | Verdict |
|----------|---------|
| SharedPreferences key names | Unchanged |
| Firestore paths | Unchanged |
| Notification IDs / channels | Not involved |
| `Task` model fields | Unchanged |
| New keys introduced | None |

---

## Tests

Source-text test (1 test, file `test/features/tasks/f30a_source_test.dart`):

- **T1**: in `tasks_screen.dart`, `todayTasks` filter contains
  `!dueSoonTasks.contains(t)` and the `dueSoonTasks` variable is declared
  **before** `todayTasks` (line number of `dueSoonTasks` < line number of
  `todayTasks`).

---

## Device check

| ID | Description |
|----|-------------|
| S-F30a-1 | Create a task with a due time 1–2 hours from now (same day). Open the Tasks screen in date-sorted view. The task should appear in **Due Soon** only — not duplicated in **Today**. |
