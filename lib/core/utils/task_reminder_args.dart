/// Arguments of `scheduleNativeTaskReminder` that depend on the reminder kind (spec
/// docs/designs/fix-themed-notifications.md, TC1).
library;

/// The task's due time (epoch ms) for the native card's live countdown, only for the "before" reminder (it fires
/// before the due time, so there is something to count down to). Null for every other kind.
int? countdownDueAtMs({required String bodyKind, required DateTime dueDate}) =>
    bodyKind == 'before' ? dueDate.millisecondsSinceEpoch : null;
