// Spec: docs/designs/wird-marker.md item 26 (strings), P4a-2. Only the keys of
// this amendment are checked, not full parity of both files.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _load(String lang) =>
    json.decode(File('assets/translations/$lang.json').readAsStringSync())
        as Map<String, dynamic>;

const _newKeys = [
  'wird_restart_confirm_yes',
  'wird_start_sheet_title',
  'wird_start_here',
  'wird_choose_another_page',
  'wird_just_read',
  'wird_marker_set_here',
  'wird_marker_placed',
];

void main() {
  final en = _load('en');
  final ar = _load('ar');

  test('the seven new keys exist in English and Arabic and are not empty', () {
    for (final k in _newKeys) {
      expect(en[k], isA<String>(), reason: 'en $k');
      expect((en[k] as String).trim(), isNotEmpty, reason: 'en $k');
      expect(ar[k], isA<String>(), reason: 'ar $k');
      expect((ar[k] as String).trim(), isNotEmpty, reason: 'ar $k');
    }
  });

  test('the two templated keys keep their %d in both languages', () {
    for (final k in ['wird_start_sheet_title', 'wird_marker_placed']) {
      expect(en[k], contains('%d'), reason: 'en $k');
      expect(ar[k], contains('%d'), reason: 'ar $k');
    }
  });

  test('the Restart dialog confirm label differs from the tile label', () {
    // The key must exist first, so a missing key cannot pass as "different".
    expect(en['wird_restart_confirm_yes'], isA<String>());
    expect(ar['wird_restart_confirm_yes'], isA<String>());
    expect(en['wird_restart_confirm_yes'], isNot(en['wird_restart']));
    expect(ar['wird_restart_confirm_yes'], isNot(ar['wird_restart']));
  });

  test('tutorial_wird_actions_body says what Start Reading does with no marker',
      () {
    expect(en['tutorial_wird_actions_body'],
        contains('With no marker, it first asks where to start.'));
    expect(ar['tutorial_wird_actions_body'],
        contains('وإن لم تكن لديك علامة، فيسألك أولاً من أين تبدأ.'));
    // The other three bullets are still there.
    expect(en['tutorial_wird_actions_body'], contains('Mark Complete'));
    expect(en['tutorial_wird_actions_body'], contains('Add from Bookmarks'));
    expect(en['tutorial_wird_actions_body'], contains('Undo last move'));
  });
}
