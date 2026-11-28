// Source-text test for F30f — focus-resume refresh
//
// T1: _checkFocusTaskCompleted refreshes the providers the Tasks screen
//     watches (allTasksProvider + taskStatisticsProvider), not
//     tasksProvider(default params), which nothing watches.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('T1: focus-resume refresh invalidates the watched providers', () {
    final src = File('lib/features/tasks/tasks_screen.dart').readAsStringSync();

    final start = src.indexOf('Future<void> _checkFocusTaskCompleted()');
    expect(start, isNot(-1), reason: '_checkFocusTaskCompleted not found');

    // Body ends at the next member declaration (the sort pref key constant).
    final end = src.indexOf("static const _sortPrefKey", start);
    expect(end, greaterThan(start));
    final body = src.substring(start, end);

    expect(body, contains('ref.invalidate(allTasksProvider);'));
    expect(body, contains('ref.invalidate(taskStatisticsProvider);'));
    expect(body, isNot(contains('tasksProvider(')),
        reason: 'tasksProvider(params) is not watched by the Tasks screen');
  });
}
