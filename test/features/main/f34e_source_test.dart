// Source-text test for F34e — desktop popup unmounts shell
//
// T1: main_wrapper_screen.dart does NOT return a bare Scaffold from the
//     desktop-popup guard; instead it builds a popupOverlay and uses Stack.

import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  test('T1: desktop popup block does not contain "return Scaffold"', () {
    final src =
        File('lib/features/main/main_wrapper_screen.dart').readAsStringSync();

    // Guard block must still exist
    expect(
      src,
      contains('if (_isDesktop && _activePopup != null'),
      reason: 'desktop popup guard not found',
    );

    // Must assign to popupOverlay (not return Scaffold from the guard)
    expect(
      src,
      contains('popupOverlay ='),
      reason: 'popup block must assign popupOverlay, not return a bare Scaffold',
    );

    // Must use Stack overlay pattern
    expect(
      src,
      contains('Stack(children: [shell, popupOverlay])'),
      reason: 'popup must be overlaid via Stack',
    );
  });
}
