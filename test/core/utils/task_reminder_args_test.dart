import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/utils/task_reminder_args.dart';

/// The native task card counts down to the due time only for the "before" reminder (spec
/// docs/designs/fix-themed-notifications.md, TC1); Dart sends `dueAt` only then.
void main() {
  final due = DateTime(2026, 11, 20, 15, 30);

  test('before reminder sends the due time in epoch milliseconds', () {
    expect(countdownDueAtMs(bodyKind: 'before', dueDate: due), due.millisecondsSinceEpoch);
  });

  test('due now, today and any other kind send no due time', () {
    expect(countdownDueAtMs(bodyKind: 'due_now', dueDate: due), isNull);
    expect(countdownDueAtMs(bodyKind: 'today', dueDate: due), isNull);
    expect(countdownDueAtMs(bodyKind: 'pending', dueDate: due), isNull);
  });
}
