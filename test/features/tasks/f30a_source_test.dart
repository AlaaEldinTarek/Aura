// Source-text test for F30a — task shown in both Today and Due Soon
//
// T1: in tasks_screen.dart, dueSoonTasks is declared before todayTasks
//     and todayTasks filter contains !dueSoonTasks.contains(t).

import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  test(
      'T1: dueSoonTasks declared before todayTasks, '
      'todayTasks excludes dueSoonTasks', () {
    final src = File('lib/features/tasks/tasks_screen.dart').readAsStringSync();

    final dueSoonIdx = src.indexOf('final dueSoonTasks');
    final todayIdx = src.indexOf('final todayTasks');

    expect(dueSoonIdx, isNot(-1), reason: 'dueSoonTasks not found');
    expect(todayIdx, isNot(-1), reason: 'todayTasks not found');
    expect(
      dueSoonIdx,
      lessThan(todayIdx),
      reason: 'dueSoonTasks must be declared before todayTasks',
    );

    expect(
      src,
      contains('!dueSoonTasks.contains(t)'),
      reason: 'todayTasks filter must exclude dueSoonTasks entries',
    );
  });
}
