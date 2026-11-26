// Source-text test for F52n fix.
// Verifies that _applySort uses a stable partition instead of a second sort.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('F52n — stable pinned-float sort', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/tasks/tasks_screen.dart').readAsStringSync();
    });

    test('_applySort uses partition-and-concat for pinned float', () {
      final applyIdx = src.indexOf('List<Task> _applySort(');
      expect(applyIdx, isNot(-1));
      // Extract the _applySort body (up to 400 chars past the closing return)
      final body = src.substring(applyIdx, applyIdx + 1200);
      expect(body, contains('final pinned = sorted.where'));
      expect(body, contains('final unpinned = sorted.where'));
      expect(body, contains('return [...pinned, ...unpinned]'));
    });

    test('_applySort does not use a second sorted.sort for pinned float', () {
      final applyIdx = src.indexOf('List<Task> _applySort(');
      expect(applyIdx, isNot(-1));
      final body = src.substring(applyIdx, applyIdx + 1200);
      // After the first sort blocks, there must be no second sorted.sort
      // that compares isPinned (the old unstable approach)
      final badPattern = RegExp(r'sorted\.sort\([^)]*isPinned');
      expect(badPattern.hasMatch(body), isFalse);
    });
  });
}
