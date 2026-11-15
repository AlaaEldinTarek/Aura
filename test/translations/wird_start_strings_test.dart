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

  test('wird_move_sheet_title exists in both languages and keeps its %d', () {
    for (final lang in [en, ar]) {
      final v = lang['wird_move_sheet_title'];
      expect(v, isA<String>());
      expect((v as String).trim(), isNotEmpty);
      expect(v, contains('%d'));
    }
  });

  test('the completed-day setup keys exist, are not empty, and are distinct', () {
    for (final lang in [en, ar]) {
      for (final k in ['wird_set_marker', 'wird_no_marker_hint']) {
        expect(lang[k], isA<String>(), reason: k);
        expect((lang[k] as String).trim(), isNotEmpty, reason: k);
      }
      expect(lang['wird_no_marker_hint'], isNot(contains('%d')));
      expect(lang['wird_set_marker'], isNot(lang['wird_marker_set_here']));
    }
  });

  test('tutorial_reader_topbar_body names the Wird marker, not saving the page',
      () {
    // Spec "Single bookmark-shaped Wird icon", Strings (fifth amendment, P4a-6).
    for (final lang in [en, ar]) {
      final v = lang['tutorial_reader_topbar_body'];
      expect(v, isA<String>());
      expect((v as String).trim(), isNotEmpty);
    }
    expect(en['tutorial_reader_topbar_body'], contains('Wird marker'));
    expect(en['tutorial_reader_topbar_body'], isNot(contains('save this page')));
    expect(ar['tutorial_reader_topbar_body'], contains('علامة الورد'));
    expect(ar['tutorial_reader_topbar_body'], isNot(contains('لحفظ هذه الصفحة')));
    // The sentences about verses and hiding the bars are still there.
    expect(en['tutorial_reader_topbar_body'], contains('bookmark it with a color'));
    expect(en['tutorial_reader_topbar_body'], contains('hide these bars'));
  });
}
