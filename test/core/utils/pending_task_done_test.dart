import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/utils/pending_task_done.dart';

/// Notification "Done" hands task ids to Dart through `pending_complete_task_id`. It may only COMPLETE a task, never
/// un-complete one that is already done (spec docs/designs/fix-themed-notifications.md, T2b).
void main() {
  group('shouldApplyDone', () {
    test('an open task is completed', () {
      expect(shouldApplyDone(alreadyCompleted: false), isTrue);
    });

    test('an already completed task is left alone (never un-completed)', () {
      expect(shouldApplyDone(alreadyCompleted: true), isFalse);
    });
  });

  group('parsePendingTaskIds', () {
    test('null, empty and blank give no ids', () {
      expect(parsePendingTaskIds(null), isEmpty);
      expect(parsePendingTaskIds(''), isEmpty);
      expect(parsePendingTaskIds('  , '), isEmpty);
    });

    test('a single id (what the Tasks widget writes) still works', () {
      expect(parsePendingTaskIds('abc123'), ['abc123']);
    });

    test('several ids, trimmed and without duplicates, in order', () {
      expect(parsePendingTaskIds('a, b ,a,c'), ['a', 'b', 'c']);
    });
  });
}
