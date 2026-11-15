// Spec: docs/designs/permissions-status-screen.md (phase PS1). The nine new strings.
// The Arabic is a DRAFT until the owner has read it.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _keys = [
  'settings_permissions_title',
  'settings_permissions_subtitle',
  'permissions_page_title_all',
  'permissions_all_set',
  'permissions_all_set_plus_hand',
  'permissions_some_missing',
  'permissions_check_by_hand',
  'permissions_check_by_hand_button',
  'permissions_denied_hint',
];

Map<String, dynamic> _load(String lang) =>
    json.decode(File('assets/translations/$lang.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  for (final lang in ['en', 'ar']) {
    test('$lang.json has every permissions key, non-empty', () {
      final map = _load(lang);
      for (final k in _keys) {
        expect(map[k], isA<String>(), reason: '$lang missing $k');
        expect((map[k] as String).trim(), isNotEmpty, reason: '$lang empty $k');
      }
    });
  }

  test('Arabic strings have no ASCII digits', () {
    final map = _load('ar');
    for (final k in _keys) {
      expect(RegExp(r'[0-9]').hasMatch((map[k] ?? '') as String), isFalse, reason: k);
    }
  });

  test('English summary strings say what the spec says', () {
    final en = _load('en');
    expect(en['permissions_all_set'], 'All set');
    expect(en['permissions_all_set_plus_hand'], 'All set, plus one item to check by hand');
    expect(en['permissions_check_by_hand'], 'Check by hand');
  });
}
