// Source-text test for F30b — pinned tasks must float in dated sections
//
// T1: the pinned-float sort (a.isPinned ? -1 : 1) appears at least 8 times
//     in tasks_screen.dart — once in _applySort plus once per dated section (7).

import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  test(
      'T1: pinned-float sort appears in every dated section '
      '(≥ 8 occurrences in tasks_screen.dart)', () {
    final src = File('lib/features/tasks/tasks_screen.dart').readAsStringSync();

    final count =
        RegExp(r'a\.isPinned \? -1 : 1').allMatches(src).length;

    expect(
      count,
      greaterThanOrEqualTo(8),
      reason: 'Expected pinned-float sort in _applySort (1) + 7 dated sections, '
          'found $count occurrences',
    );
  });
}
