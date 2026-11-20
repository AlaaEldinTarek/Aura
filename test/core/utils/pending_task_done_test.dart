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

  // Same rule as the Home and Tasks screens: completing the LAST incomplete active task (due today or no due date)
  // counts for the streak. Done never counts an already-done task, and never twice for the same task.
  group('streakCountingIds', () {
    test('last active task completed counts', () {
      expect(streakCountingIds(pendingIds: ['a'], openIds: {'a', 'x'}, activeOpenIds: {'a'}), ['a']);
    });

    test('not the last active task: no streak', () {
      expect(streakCountingIds(pendingIds: ['a'], openIds: {'a', 'b'}, activeOpenIds: {'a', 'b'}), isEmpty);
    });

    test('an already completed (or unknown) task never counts', () {
      expect(streakCountingIds(pendingIds: ['a'], openIds: {'b'}, activeOpenIds: {'b'}), isEmpty);
    });

    test('the same id twice counts once', () {
      expect(streakCountingIds(pendingIds: ['a', 'a'], openIds: {'a'}, activeOpenIds: {'a'}), ['a']);
    });

    test('several ids: only the completion that empties the active list counts', () {
      expect(streakCountingIds(pendingIds: ['a', 'b'], openIds: {'a', 'b'}, activeOpenIds: {'a', 'b'}), ['b']);
    });

    test('a task that is open but not active today (future date) does not count', () {
      expect(streakCountingIds(pendingIds: ['f'], openIds: {'f'}, activeOpenIds: <String>{}), isEmpty);
    });
  });
}
