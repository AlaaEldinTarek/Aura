import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no Dart file builds a zuhr native key', () {
    final libDir = Directory('lib');
    final forbidden = RegExp(
      r'''toLowerCase\(\)\}_time'''
      r'''|toLowerCase\(\)\}_iqama_time'''
      r"""|'zuhr_time'"""
      r'''|"zuhr_time"'''
      r"""|'zuhr_iqama_time'"""
      r'''|"zuhr_iqama_time"''',
    );

    final violations = <String>[];
    for (final file in libDir.listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (forbidden.hasMatch(line)) {
          violations.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(violations, isEmpty,
        reason: 'Dart files must use nativePrayerKey, not '
            'build zuhr keys directly:\n${violations.join('\n')}');
  });
}
