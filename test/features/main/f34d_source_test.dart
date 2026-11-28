// Source-text test for F34d — setCurrentRoute channel call
//
// T1: _updateCurrentRoute returns early off Android, before the channel call.
// T2: the invokeMethod call sits inside a try/catch (CLAUDE.md: platform
//     channels always try-catch).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String src;
  setUpAll(() {
    src = File('lib/features/main/main_wrapper_screen.dart').readAsStringSync();
  });

  test('T1: _updateCurrentRoute has the Android guard before the call', () {
    final start = src.indexOf('void _updateCurrentRoute()');
    expect(start, isNot(-1), reason: '_updateCurrentRoute not found');
    final end = src.indexOf('Future<void> _setCurrentRoute', start);
    expect(end, greaterThan(start));
    final body = src.substring(start, end);

    expect(body, contains('if (kIsWeb || !Platform.isAndroid) return;'));
    expect(body, isNot(contains('invokeMethod')),
        reason: 'the channel call belongs in the guarded helper');
  });

  test('T2: setCurrentRoute invokeMethod is wrapped in try/catch', () {
    final start = src.indexOf('Future<void> _setCurrentRoute');
    expect(start, isNot(-1), reason: '_setCurrentRoute not found');
    final body = src.substring(start, start + 400);

    final tryIdx = body.indexOf('try {');
    final callIdx = body.indexOf("invokeMethod('setCurrentRoute'");
    final catchIdx = body.indexOf('catch (e)');
    expect(tryIdx, isNot(-1));
    expect(callIdx, greaterThan(tryIdx));
    expect(catchIdx, greaterThan(callIdx));
  });
}
