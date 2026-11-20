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
