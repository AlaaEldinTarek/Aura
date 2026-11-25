# Fix F30b — Pinned tasks don't float in dated sections

**Status:** Approved for code (phase P1)  
**Branch:** `fix/f30b` (to be created from main)  
**Finding:** F30b (MEDIUM)  
**Files touched:**
- `lib/features/tasks/tasks_screen.dart`

---

## Problem

`_applySort` (`tasks_screen.dart:1013–1017`) correctly floats pinned tasks to
the top using a stable secondary sort:

```dart
// Pinned tasks always float to top
sorted.sort((a, b) {
  if (a.isPinned == b.isPinned) return 0;
  return a.isPinned ? -1 : 1;
});
```

However, `_buildDateSortedView` builds seven dated sections — Overdue, Today,
Due Soon, Tomorrow, This Week, Next Week, Later — and each one replaces the
sort with a bare `dueDate` comparison:

```dart
..sort((a, b) =>
    (a.dueDate ?? DateTime(2099)).compareTo(b.dueDate ?? DateTime(2099)));
```

This discards the pinned-first order. A pinned task lands wherever its due
date places it rather than at the top of its section.

Decision (product owner, 2026-11-25): pinned tasks must float to the top of
each dated section.

---

## Fix

After each dated section's `dueDate` sort, add the same pinned-float sort
used in `_applySort`. Dart's `List.sort` is stable (TimSort since Dart 2.3),
so the two sequential sorts guarantee: pinned tasks first, then due-date order
within each pin group.

The sections and their current sort lines:

| Section | Line |
|---------|------|
| `overdueTasks` | 1149 |
| `todayTasks` | 1155 |
| `dueSoonTasks` | 1171 |
| `tomorrowTasks` | 1179 |
| `thisWeekTasks` | 1188 |
| `nextWeekTasks` | 1196 |
| `laterTasks` | 1204 |

For each section, the cascade becomes:

```dart
// example: overdueTasks (same pattern for all 7)
..sort((a, b) =>
    (a.dueDate ?? DateTime(2099)).compareTo(b.dueDate ?? DateTime(2099)))
..sort((a, b) {
  if (a.isPinned == b.isPinned) return 0;
  return a.isPinned ? -1 : 1;
});
```

`dueSoonTasks`, `tomorrowTasks`, `thisWeekTasks`, `nextWeekTasks`, and
`laterTasks` have non-nullable `dueDate` comparators; `overdueTasks` and
`todayTasks` use a null-safe fallback. The pattern is the same for both.

No change to `otherTasks` (no due date, no explicit sort) or `completedTasks`.

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

Source-text test (1 test, file `test/features/tasks/f30b_source_test.dart`):

- **T1**: `tasks_screen.dart` contains the pinned-float sort
  `a.isPinned ? -1 : 1` **at least 7 times** — once per dated section
  (excluding the existing one in `_applySort`, the total must be ≥ 8).

---

## Device check

| ID | Description |
|----|-------------|
| S-F30b-1 | In the Tasks screen (date-sorted view), pin a task that is due today but not the first by due time. The pinned task should jump to the top of the Today section. Unpin it — it should return to its due-date position within the section. |
