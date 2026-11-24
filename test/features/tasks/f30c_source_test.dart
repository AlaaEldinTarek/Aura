import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Source-text tests for F30c (docs/designs/fix-f30c.md).
/// Pins the completedAt preservation in task_service and the null-guard in
/// _isCompletedToday so a future editor who reverts either sees a failure.
void main() {
  String src(String path) => File(path).readAsStringSync();

  // F30c — T1: task_service preserves completedAt when task was already completed
  test(
    'T1: task_service preserves completedAt for already-completed tasks',
    () {
      final s = src('lib/core/services/task_service.dart');
      // The three-arm ternary must be present (both paths share this pattern)
      expect(
        s,
        contains('current.isCompleted ? current.completedAt : DateTime.now()'),
        reason: 'completedAt preservation missing for guest path in task_service',
      );
      expect(
        s,
        contains(
            'currentTask.isCompleted ? currentTask.completedAt : DateTime.now()'),
        reason:
            'completedAt preservation missing for Firestore path in task_service',
      );
      // The old one-arm ternary that always wiped completedAt must be gone
      expect(
        s,
        isNot(contains(
            '!current.isCompleted ? DateTime.now() : null')),
        reason: 'old wipe-on-edit ternary still present (guest path)',
      );
      expect(
        s,
        isNot(contains(
            '!currentTask.isCompleted ? DateTime.now() : null')),
        reason: 'old wipe-on-edit ternary still present (Firestore path)',
      );
    },
  );

  // F30c — T2: _isCompletedToday returns false (not true) for null completedAt
  test(
    'T2: _isCompletedToday returns false when completedAt is null',
    () {
      final s = src('lib/features/tasks/tasks_screen.dart');
      expect(s, contains('if (t.completedAt == null) return false'),
          reason: '_isCompletedToday still returns true for null completedAt');
      expect(s, isNot(contains('if (t.completedAt == null) return true')),
          reason: 'old true-for-null guard still present');
    },
  );
}
