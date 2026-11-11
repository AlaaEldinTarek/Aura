# Fix Tasks: Date Picker Crash & Task Streak (F30d + F32a)

*   **Author:** Alaa Eldin Tarek
*   **Status:** Draft
*   **Date:** 2026-11-11

--------------------------------------------------------------------------------

## Overview

Two bugs in the task management flow: editing a past-due task crashes the date
picker (F30d), and completing all today-tasks from the Tasks tab does not update
the streak counter that Home, Stats, achievements, and the home-screen widget
all display (F32a). Both are independent, small fixes that share one release
group.

## The Problem

**F30d — Date picker crash on past-due tasks.** When the user opens the edit
form for a task whose due date is already in the past, `showDatePicker` is
called with `initialDate: _selectedDueDate` and `firstDate: DateTime.now()`.
Flutter asserts `initialDate >= firstDate`; the assertion fails and the picker
never opens (debug mode throws; release-mode behavior UNVERIFIED on device).
The user cannot pick a new due date on a past-due task, because the picker
crashes when tapped (the date field is an `InkWell` with `onTap: _selectDueDate`;
the picker is user-triggered, not auto-invoked on form load).

**F32a — Streak only counts Home completions.** The task streak
(`task_streak_count` / `task_streak_date` in SharedPreferences) is written
exclusively by `home_screen.dart _incrementStreak()`, triggered only when the
last incomplete today-task is completed from the Home tab. The Tasks tab has its
own `_toggleTask` that celebrates but never touches the streak. A user who
manages tasks from the Tasks tab — the dedicated task screen — never builds a
streak. The streak is consumed by Home (mini-stat), task_stats_screen (overview
tab), task_widget_service (Android home-screen widget), and
achievement_service (`task_streak_7`, `task_streak_30`). All show stale or zero
values when the user completes tasks outside Home.

## Goals

*   **F30d**: The date picker must open without crashing when editing a task
    whose due date is in the past. Only the picker's opening `initialDate` is
    clamped to today; the task's stored due date stays unchanged unless the user
    explicitly picks a new date.
*   **F32a**: One shared streak function is the sole writer of
    `task_streak_count` / `task_streak_date`. It is called from both Home and
    the Tasks tab when the last today-task is completed. It increments at most
    once per calendar day (same date guard as the existing `_incrementStreak`).
*   Both fixes must be behavior-preserving everywhere except the two bugs: no
    new UI, no prefs key renames, no Firestore schema changes.

## Non-Goals

*   Refactoring the streak into a service or provider (P4 scope; F32b).
*   Fixing `_getStreak` writing `0` during a `FutureBuilder` rebuild (F32b).
*   Fixing the `_isCompletedToday` null-`completedAt` bug (F30c).
*   Adding Arabic numeral formatting to streak or stats values (F31 / F33
    scout backlog).
*   Changing how the recurrence end-date picker works (it already avoids this
    crash pattern with a +30-day fallback).

## Critical User Journeys (CUJs)

### CUJ 1: Edit a past-due task

*   **Given**: A task exists with `dueDate` = 2026-11-05 (six days ago). The
    user opens the edit form for this task.
*   **When**: The form calls `_selectDueDate()`, which calls `showDatePicker`
    with `initialDate: _selectedDueDate` (2026-11-05) and
    `firstDate: DateTime.now()` (2026-11-11).
*   **Then (before fix)**: Flutter assert fails; picker does not open.
*   **Then (after fix)**: The picker opens with `initialDate` clamped to today
    (2026-11-11). The task's stored `dueDate` remains 2026-11-05 in the form
    state until the user acts. If the user taps OK on the picker (which shows
    today), the form updates to today. If the user picks a different future
    date, that becomes the new value. If the user taps Cancel, the form keeps
    the original past date (2026-11-05) unchanged.

### CUJ 2: Complete all today-tasks from the Tasks tab

*   **Given**: The user has 3 tasks due today, 2 already completed. The streak
    counter is at 4 (last date = yesterday).
*   **When**: The user completes the last task from the Tasks tab.
*   **Then (before fix)**: Celebration plays, but `task_streak_count` stays 4
    and `task_streak_date` stays yesterday. Next day, `_getStreak` reads
    yesterday's date, the streak is still valid, but it was never incremented.
    Achievement checks see 4, not 5.
*   **Then (after fix)**: Celebration plays AND `task_streak_count` becomes 5,
    `task_streak_date` becomes today. Identical to completing from Home.

### CUJ 3: Complete last task from Home (regression check)

*   **Given**: Same setup as CUJ 2.
*   **When**: The user completes the last task from the Home tab.
*   **Then**: Behavior identical to before: streak increments to 5, celebration
    plays. The shared function is called instead of the inline one, but the
    outcome is the same.

### CUJ 4: Complete tasks on the same day from both tabs

*   **Given**: Streak is at 4 (last date = yesterday). User has 4 today-tasks.
*   **When**: User completes 3 from Tasks tab, then completes the last one
    from Home.
*   **Then**: The streak increments to 5 exactly once (whichever tab finishes
    the last task triggers it). The once-per-day guard (`lastDate == today`)
    prevents double-counting if the method is called more than once.

--------------------------------------------------------------------------------

## Technical Plan (Architecture)

### F30d — Clamp `initialDate` in the due-date picker

The fix is a one-line clamp in `_selectDueDate()` at
`task_form_screen.dart:232`. The line:

```
initialDate: _selectedDueDate ?? DateTime.now(),
```

becomes (pseudocode):

```
initialDate: clamp(_selectedDueDate ?? now, lower: now),
```

Where `clamp` picks the later of the two dates. This only affects which date
the picker opens on. `_selectedDueDate` itself is not modified by the clamp —
it retains the original past date until the user explicitly picks a new one in
the picker. If the user taps OK on the picker without navigating to a different
date, the picker returns `DateTime.now()` (the clamped initial date, which is
today), and the form state updates to today. This is the correct behavior: the
picker's "initial date" is the date shown when it opens, and confirming it
means the user chose that date.

The recurrence end-date picker (`task_form_screen.dart:1346`) already uses a +30-day fallback and
is not affected.

### F32a — Shared streak function

```text
BEFORE:
  home_screen.dart  ──→  _incrementStreak()  ──→  SharedPreferences
  tasks_screen.dart ──→  (no streak logic)

AFTER:
  home_screen.dart  ──→  TaskService.incrementTaskStreak()  ──→  SharedPreferences
  tasks_screen.dart ──→  TaskService.incrementTaskStreak()  ──→  SharedPreferences
```

Move the streak-increment logic into `TaskService` as a new public method
`incrementTaskStreak()`. The method:

1. Reads `task_streak_date` from SharedPreferences.
2. If the date is already today, returns immediately (once-per-day guard —
   same logic as the existing `_incrementStreak`).
3. If the date is yesterday, increments `task_streak_count` by 1.
4. Otherwise (broken streak), resets to 1.
5. Writes `task_streak_count` and `task_streak_date`.

Both `home_screen.dart _toggleTask` and `tasks_screen.dart _toggleTask` call
`TaskService.instance.incrementTaskStreak()` when `wasLastTask` /
`shouldCelebrate` is true. The private `_incrementStreak` / `_streakKey` /
`_streakDateKey` are removed from `home_screen.dart`.

The date-format logic (`yyyy-MM-dd` via manual string interpolation) is
preserved exactly as-is from `home_screen.dart:1739–1752` to avoid any
behavioral change. No new prefs keys, no key renames.

`_getStreak()` stays in `home_screen.dart` for now (it is a reader, not a
writer, and moving it is F32b / P4 scope).

## Alternatives Considered

### Alternative A: Clamp by setting `firstDate` to the task's due date instead of clamping `initialDate`

Set `firstDate: _selectedDueDate ?? DateTime.now()` so the picker allows past
dates. The user could then scroll back to any date.

*   **Pros**: No clamping logic; user can see and confirm the original date.
*   **Cons**: Allows the user to pick any date in the past, which is
    inconsistent with the existing design intent (new tasks cannot have past
    dates). Also changes behavior for tasks that are not past-due: a task due
    today could be moved to yesterday, which is not currently possible.
*   **Reason for Rejection**: The picker should not allow selecting past dates.
    The fix is specifically to let the picker *open* when the stored date is
    past, not to let users freely set past dates.

### Alternative B: Move streak logic into `toggleTaskCompletion` in TaskService

Instead of calling `incrementTaskStreak()` from each screen's `_toggleTask`,
embed the streak increment inside `TaskService.toggleTaskCompletion()` so it
fires automatically on every completion.

*   **Pros**: No caller needs to know about streaks; single call site.
*   **Cons**: `toggleTaskCompletion` does not know whether the completed task
    was the "last today task" — it operates on a single task ID without context
    about the full task list. Adding that query inside the service would
    duplicate the filtering logic already in both screens (`isDueToday`,
    `dueDate == null`, `!isCompleted`). It also couples streak policy to the
    toggle method, making it fire on un-toggle and recurring-task completions
    unless guarded. The once-per-day check would mask most of these, but the
    semantics are wrong: the streak should increment when the day's work is done,
    not on every toggle.
*   **Reason for Rejection**: The "last task" check belongs to the caller (it
    depends on the visible task list), and embedding it in the service muddies
    the service's responsibility.

### Alternative C: Use a Riverpod provider for the streak instead of SharedPreferences

Create a `taskStreakProvider` that manages streak state and is watched by all
consumers.

*   **Pros**: Reactive updates; all readers see the new count immediately.
*   **Cons**: This is a refactor (P4 scope, F32b) that changes how streak
    state is accessed across the app. Home, Stats, widget service, and
    achievements all currently read SharedPreferences directly. Migrating them
    is out of scope for a bug fix and risks regressions in the streak display.
*   **Reason for Rejection**: Out of scope for this fix group. The provider
    approach is the long-term direction (F32b) but not appropriate for a
    behavior-preserving bug fix.

--------------------------------------------------------------------------------

## Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| **Race condition (F32a)**: Both tabs can call `incrementTaskStreak()`. In Flutter's single-isolate model, async methods interleave at `await` points. | Could double-count the streak in theory. | The once-per-day date guard (`lastDate == today → return`) makes the outcome idempotent regardless of which call wins. |
| **Key-string duplication**: After the move, `_getStreak` and `TaskService` each hold independent copies of `'task_streak_count'` / `'task_streak_date'`. | A typo in one copy silently breaks reads or writes. | Known debt tracked in F32b (P4 scope). Both copies are `const` literals set once; the risk is low for a bug-fix change. |
| **Release-mode F30d behavior**: Pre-fix release-mode behavior is UNVERIFIED on device. | The crash path may differ (silent failure vs. assert). | The fix resolves both debug and release paths identically (clamp runs unconditionally). Post-fix device check covers release APK. |

--------------------------------------------------------------------------------

## Detailed Implementation Plan

### Target Files to Create/Modify

#### 1. `lib/core/services/task_service.dart` (Modify)

*   **Type / Scope**: Dart Service (singleton)
*   **Proposed Changes**:
    -   Add a public `Future<void> incrementTaskStreak()` method. The body is
        the exact logic currently in `home_screen.dart:1736–1752`
        (`_incrementStreak`), with the same date-format string
        (`yyyy-MM-dd` via manual interpolation), same prefs keys
        (`task_streak_count`, `task_streak_date`), and same once-per-day guard
        (`lastDate == today → return`).
    -   Add the two `static const` key strings (`_streakKey = 'task_streak_count'`,
        `_streakDateKey = 'task_streak_date'`) as private fields, same values
        as in `home_screen.dart:1711–1712`.
    -   No other changes to `TaskService`.

#### 2. `lib/features/home/home_screen.dart` (Modify)

*   **Type / Scope**: Flutter Screen (Home tab)
*   **Proposed Changes**:
    -   Replace the call `await _incrementStreak()` at `:1676` with
        `await TaskService.instance.incrementTaskStreak()`.
    -   Remove the private `_incrementStreak()` method (`:1736–1753`).
    -   Remove the private `_streakKey` and `_streakDateKey` constants
        (`:1711–1712`). `_getStreak()` is the only other reference to them.
    -   `_getStreak()` must be modified: replace its references to the removed
        `_streakKey` and `_streakDateKey` with inline string literals
        (`'task_streak_count'`, `'task_streak_date'`) at each call site within
        the method. The method both reads and writes (it resets
        `task_streak_count` to `0` at `:1730` when the streak is broken), so
        both code paths need the inline literals. Defaults stay identical
        (`?? 0` for count, `null` check for date). Moving `_getStreak` to
        TaskService is F32b / P4 scope.

#### 3. `lib/features/tasks/tasks_screen.dart` (Modify)

*   **Type / Scope**: Flutter Screen (Tasks tab)
*   **Proposed Changes**:
    -   In `_toggleTask` (`:2168–2215`), inside the existing
        `if (shouldCelebrate)` block (`:2201–2205`), add
        `await TaskService.instance.incrementTaskStreak();` before the
        `Future.delayed` call that triggers the celebration animation.
    -   Add `import` for `TaskService` if not already present.
    -   No other changes.

#### 4. `lib/features/tasks/task_form_screen.dart` (Modify)

*   **Type / Scope**: Flutter Screen (Task edit form)
*   **Proposed Changes**:
    -   In `_selectDueDate()` (`:228–238`), capture `final now = DateTime.now();`
        once at the top of the method, then use `now` in all three positions
        (`initialDate`, `firstDate`, and the fallback). Change line `:232` from:
        ```
        initialDate: _selectedDueDate ?? DateTime.now(),
        ```
        to:
        ```
        initialDate: (_selectedDueDate != null && _selectedDueDate!.isAfter(now))
            ? _selectedDueDate!
            : now,
        ```
        And change `firstDate: DateTime.now()` to `firstDate: now`.
        This eliminates a midnight-crossing race where separate `DateTime.now()`
        calls could straddle midnight, producing `initialDate` < `firstDate`.
        `_selectedDueDate` is not modified.
    -   No other changes.

#### 5. `test/core/services/task_streak_test.dart` (Create)

*   **Type / Scope**: Dart Unit Test
*   **Proposed Changes**:
    -   Test `TaskService.incrementTaskStreak()` with
        `SharedPreferences.setMockInitialValues`:
        -   **First completion**: no prior streak → count becomes 1, date
            becomes today.
        -   **Consecutive day**: last date = yesterday, count = 4 → count
            becomes 5, date becomes today.
        -   **Same day**: last date = today, count = 5 → count stays 5, date
            stays today (once-per-day guard).
        -   **Broken streak**: last date = 3 days ago, count = 10 → count
            resets to 1, date becomes today.

#### 6. `test/features/tasks/task_form_date_test.dart` (Create)

*   **Type / Scope**: Dart Unit Test
*   **Proposed Changes**:
    -   Three unit tests evaluating the clamping expression directly (no
        extraction into a separate function needed — test the inline ternary
        with controlled `now` and `_selectedDueDate` values):
        -   `_selectedDueDate` = yesterday → `initialDate` = today
            (clamped).
        -   `_selectedDueDate` = tomorrow → `initialDate` = tomorrow
            (no clamp needed).
        -   `_selectedDueDate` = null → `initialDate` = today (fallback).

### Implementation Phases

F30d (File 4) and F32a (Files 1–3) are independent fixes. Within F32a,
File 1 (`task_service.dart`) must be committed before Files 2–3 (callers
depend on the new method).

1.  **Phase 1 — F32a streak logic** (Files 1 → 2 → 3): Add
    `incrementTaskStreak()` to TaskService, update Home caller, add Tasks
    caller. One commit, buildable after each file.
2.  **Phase 2 — F30d date clamp** (File 4): Independent of Phase 1. One
    commit.
3.  **Phase 3 — Tests** (Files 5 + 6): One commit covering both fixes.

### Verification Plan

*   **Compilation/Build**: `flutter analyze` (0 new issues vs 418 baseline)
*   **Unit Tests**: `flutter test` (all 242 existing + new streak + date tests
    pass)
*   **Static Analysis & Linting**: `dart format --output=none --set-exit-if-changed .`
*   **Device Check (manual, nova 5T)**:
    -   **F30d**: Create a task with due date = yesterday. Open edit form, tap
        the date field. Verify picker opens on today, no crash. Tap OK → date
        becomes today. Tap Cancel → date stays yesterday. (CUJ 1)
    -   **F32a**: Complete all today-tasks from Tasks tab. Verify streak
        increments (check via Stats tab or Home mini-stat). (CUJ 2)
    -   **Regression**: Complete all today-tasks from Home tab. Verify streak
        still works. (CUJ 3)

*Drafted with EGM*
