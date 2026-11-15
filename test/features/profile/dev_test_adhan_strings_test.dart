import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _keys = [
  'dev_test_adhan_title',
  'dev_test_adhan_subtitle',
  'dev_test_adhan_dialog_title',
  'dev_test_adhan_dialog_body',
  'dev_test_adhan_fire',
  'dev_test_adhan_scheduled',
  'dev_test_adhan_no_exact_alarm',
];

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/translations/$lang.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  for (final lang in ['en', 'ar']) {
    test('$lang.json has every dev_test_adhan key, non-empty', () {
      final map = _load(lang);
      for (final k in _keys) {
        expect(map[k], isA<String>(), reason: '$lang missing $k');
        expect((map[k] as String).trim(), isNotEmpty, reason: '$lang empty $k');
      }
    });
  }

  test('Arabic strings contain no ASCII digits', () {
    final map = _load('ar');
    for (final k in _keys) {
      expect(RegExp(r'[0-9]').hasMatch((map[k] ?? '') as String), isFalse,
          reason: '$k has a raw digit');
    }
  });
}
