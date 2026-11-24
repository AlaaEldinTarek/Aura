import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Source-text test for F30e (docs/designs/fix-f30e.md).
/// Pins the List.from copy so a future editor who reverts to the bare alias
/// sees an immediate failure — no device needed.
void main() {
  String src(String path) => File(path).readAsStringSync();

  // F30e — T1: _loadTaskData copies tags list instead of aliasing it
  test(
    'T1: _loadTaskData copies task.tags via List.from, not a bare alias',
    () {
      final s = src('lib/features/tasks/task_form_screen.dart');
      expect(s, contains('List<String>.from(task.tags'),
          reason: 'List.from copy missing — tags list is still aliased');
      // Confirm the bare alias pattern is gone
      expect(s, isNot(contains('_tags = task.tags ?? []')),
          reason: 'bare alias _tags = task.tags ?? [] still present');
    },
  );
}
