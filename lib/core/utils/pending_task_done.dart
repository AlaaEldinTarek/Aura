/// Helpers for the task-reminder notification's "Done" button.
///
/// The native card cannot touch the task store (Firestore / guest tasks live in Dart), so it hands the task id to
/// Dart through the `pending_complete_task_id` pref (the same hand-off the Tasks widget uses) and the app applies it
/// on its next open or resume. Spec: docs/designs/fix-themed-notifications.md (T2b).
library;

/// The ids waiting to be completed. The pref holds one id (what the Tasks widget writes) or several separated by
/// commas (what the notification writes, so a second Done does not overwrite the first). Trimmed, no blanks, no
/// duplicates, in order.
List<String> parsePendingTaskIds(String? raw) {
  if (raw == null) return const [];
  final ids = <String>[];
  for (final part in raw.split(',')) {
    final id = part.trim();
    if (id.isNotEmpty && !ids.contains(id)) ids.add(id);
  }
  return ids;
}

/// "Done" only completes: a task that is already completed must be left alone, never un-completed.
bool shouldApplyDone({required bool alreadyCompleted}) => !alreadyCompleted;

/// Which of the pending Done ids count for the task streak. Same rule as the Home and Tasks screens: completing the
/// LAST incomplete active task (due today or no due date) counts. A task that is already completed (or unknown) never
/// counts, and an id listed twice counts once. [openIds] = every incomplete task, [activeOpenIds] = the incomplete
/// ones that are due today or undated. The caller completes the ids in order, so each completion shrinks the active
/// list for the next one.
List<String> streakCountingIds({
  required List<String> pendingIds,
  required Set<String> openIds,
  required Set<String> activeOpenIds,
}) {
  final open = {...openIds};
  final active = {...activeOpenIds};
  final counting = <String>[];
  for (final id in pendingIds.toSet()) {
    if (!open.contains(id)) continue; // already completed or unknown: Done does nothing
    final wasLast = active.length == 1 && active.contains(id);
    open.remove(id);
    active.remove(id);
    if (wasLast) counting.add(id);
  }
  return counting;
}
