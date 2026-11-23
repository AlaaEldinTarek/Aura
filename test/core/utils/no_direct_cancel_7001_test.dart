import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// T5 (F7): notification id 7001 belongs to the native Daily Prayer Reminder card. Dart must never cancel it directly,
/// because that removes the card while it is showing. The only allowed path is the pending-checked helper in
/// `lib/core/utils/legacy_jumuah.dart`. This scans `lib/` as text and fails on a direct `cancel(7001)` or on a
/// `cancel(<name>)` where `<name>` is a constant assigned 7001 in the same file.
void main() {
  test('no Dart file under lib/ cancels notification id 7001 directly', () {
    final offenders = <String>[];
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'run from the project root');

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll(r'\', '/');
      if (normalized.endsWith('lib/core/utils/legacy_jumuah.dart')) continue;

      final lines = entity.readAsLinesSync();
      final code = lines.where((l) => !l.trimLeft().startsWith('//')).toList();

      final names = <String>{};
      final assign = RegExp(r'(\w+)\s*=\s*7001\b');
      for (final l in code) {
        for (final m in assign.allMatches(l)) {
          names.add(m.group(1)!);
        }
      }
      final targets = ['7001', ...names].map(RegExp.escape).join('|');
      final cancelCall = RegExp(r'\bcancel\(\s*(' + targets + r')\b');

      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (l.trimLeft().startsWith('//')) continue;
        if (cancelCall.hasMatch(l)) {
          offenders.add('$normalized:${i + 1}: ${l.trim()}');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'direct cancel of 7001 found:\n${offenders.join('\n')}');
  });
}
