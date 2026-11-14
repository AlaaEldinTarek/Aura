// Spec: docs/designs/fix-boot-start-service.md, section 3 and phase P1. The two
// strings of the "App launch" tile. The Arabic is a DRAFT for the owner's review.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _load(String lang) =>
    json.decode(File('assets/translations/$lang.json').readAsStringSync())
        as Map<String, dynamic>;

const _keys = ['auto_launch_title', 'auto_launch_subtitle'];

void main() {
  final en = _load('en');
  final ar = _load('ar');

  test('both keys exist in English and Arabic and are not empty', () {
    for (final lang in [en, ar]) {
      for (final k in _keys) {
        expect(lang[k], isA<String>(), reason: k);
        expect((lang[k] as String).trim(), isNotEmpty, reason: k);
      }
    }
  });

  test('the subtitle tells the user to turn on all three EMUI switches', () {
    final sub = en['auto_launch_subtitle'] as String;
    expect(sub, contains('Auto-launch'));
    expect(sub, contains('Secondary launch'));
    expect(sub, contains('Run in background'));
  });

  test('the tile is not the battery tile and has no number placeholder', () {
    for (final lang in [en, ar]) {
      // The keys must exist first, so a missing key cannot pass as "different".
      expect(lang['auto_launch_title'], isA<String>());
      expect(lang['auto_launch_subtitle'], isA<String>());
      expect(
          lang['auto_launch_title'], isNot(lang['battery_optimization_title']));
      expect(lang['auto_launch_title'], isNot(contains('%d')));
      expect(lang['auto_launch_subtitle'], isNot(contains('%d')));
    }
  });
}
