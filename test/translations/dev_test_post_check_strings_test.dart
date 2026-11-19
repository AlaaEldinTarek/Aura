import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _keys = [
  'dev_test_post_check_title',
  'dev_test_post_check_subtitle',
  'dev_test_post_check_sent',
];

Map<String, dynamic> _load(String lang) =>
    jsonDecode(File('assets/translations/$lang.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  for (final lang in ['en', 'ar']) {
    test('$lang.json has every dev_test_post_check key, non-empty', () {
      final map = _load(lang);
      for (final k in _keys) {
        expect(map[k], isA<String>(), reason: '$lang missing $k');
        expect((map[k] as String).trim(), isNotEmpty, reason: '$lang empty $k');
      }
    });
  }
}
