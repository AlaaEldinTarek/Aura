# Fix spec: F30f — focus-resume refresh invalidates a provider nobody watches

Status: Draft — awaiting `approve phase P1`

Branch: `fix/f30f` (from main 8a15f76). Tag in findings: P3 (provider duplication); the one-line fix below does not depend on that refactor.
Behavior-preserving except for the intended refresh. No UI text, prefs, Firestore or channel change.

Static checks only (2026-11-28). Not run on a device.

## Finding

`tasks_screen.dart:153-167` (`_checkFocusTaskCompleted`) completes the task that Focus Mode finished while the app was in the background, then refreshes with:

```dart
ref.invalidate(tasksProvider(const TaskFilterParams()));   // :164
```

- VERIFIED: the screen watches `allTasksProvider` and `taskStatisticsProvider` (`tasks_screen.dart:215-216`), not `tasksProvider`. Every other refresh in the file invalidates that pair (about 20 places, e.g. `:130-131`, `:388-389`).
- VERIFIED: `tasksProvider(const TaskFilterParams())` has no watcher I could find. The only `tasksProvider` watchers are `todayTasksProvider`, `upcomingTasksProvider` and `highPriorityTasksProvider` (`task_provider.dart:76,95,125`), each with different params, and none of those three is used outside `task_provider.dart` (searched `lib/` and `test/`).
- So the call refreshes nothing. `allTasksProvider` is a stream and probably updates itself after the write (UNVERIFIED), but `taskStatisticsProvider` is a `FutureProvider` (`task_provider.dart:63`): it is not refreshed, so after a Focus Mode completion the done / total / streak numbers on the Tasks screen can stay stale until something else invalidates them (UNVERIFIED on device).

## Fix (phase P1, one commit)

Replace the single line at `:164` with the pair every other call site uses:

```dart
ref.invalidate(allTasksProvider);
ref.invalidate(taskStatisticsProvider);
```

Nothing else changes: the completion call, the `mounted` and `userId` guards, and the debug print stay as they are. The unused `tasksProvider` / `TaskFilterParams` usage in this file goes away; if the imports become unused the analyzer will say so and they are removed in the same commit.

## Out of scope

- The ~20 repeated invalidate pairs (the "provider duplication" in the tag): a helper for them belongs to refactor phase P3.
- The three unused derived providers in `task_provider.dart` (dead-code question, UNVERIFIED beyond the search above).

## Files changed

- `lib/features/tasks/tasks_screen.dart` (one line)
- new `test/features/tasks/f30f_source_test.dart`: in the body of `_checkFocusTaskCompleted`, assert `ref.invalidate(allTasksProvider)` and `ref.invalidate(taskStatisticsProvider)` are present and `tasksProvider(` is not (same style as `f30b_source_test.dart`).
- `.project-docs/STATE.md` after merge (separate docs branch).

## Verification

- `flutter analyze` and `flutter test` (pass/fail only). The build is not needed for a one-line Dart change, but the project rule is to build after edits; follow the owner's usual "build and install" step if wanted.
- Device (owner-observed, optional): start Focus Mode on a task, finish it with the app in the background, reopen: the task is checked and the done/total numbers match. Whether stale numbers showed before the fix is UNVERIFIED, so a "before" run is optional.

## Risks

- Two extra invalidations after a Focus Mode completion: one stream re-subscribe and one statistics read. Negligible.
- No prayer, alarm, notification or contract code is touched.
