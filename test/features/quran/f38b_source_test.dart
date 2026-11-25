import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Source-text tests for F38b fix.
/// T1: _saveProgress signature has {int? ayaNo} parameter.
/// T2: initState passes ayaNo: widget.scrollToAyaNo to _saveProgress.
void main() {
  const src = 'lib/features/quran/quran_reader_screen.dart';

  group('F38b source', () {
    test('T1: _saveProgress accepts optional {int? ayaNo}', () {
      final text = File(src).readAsStringSync();
      expect(
        text.contains('void _saveProgress(int page, {int? ayaNo})'),
        isTrue,
        reason: '_saveProgress must have an {int? ayaNo} named parameter',
      );
    });

    test('T2: initState passes widget.scrollToAyaNo to _saveProgress', () {
      final text = File(src).readAsStringSync();
      expect(
        text.contains('_saveProgress(_currentPage, ayaNo: widget.scrollToAyaNo)'),
        isTrue,
        reason: 'initState must pass widget.scrollToAyaNo so the initial save records the targeted ayah',
      );
    });
  });
}
