import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Source-text test for F34a (docs/designs/fix-f34a.md).
/// Pins the app-mode guard on the PageView physics so a future editor
/// who removes it sees an immediate failure — no device needed.
void main() {
  String src(String path) => File(path).readAsStringSync();

  // F34a — T1: PageView physics disables swipe when tabs are hidden by app mode
  test(
    'T1: PageView physics includes appMode != AppMode.both guard',
    () {
      final s = src('lib/features/main/main_wrapper_screen.dart');
      expect(s, contains('appMode != AppMode.both'),
          reason: 'appMode guard missing from PageView physics');
      expect(s, contains('NeverScrollableScrollPhysics'),
          reason: 'NeverScrollableScrollPhysics removed from PageView');
    },
  );
}
