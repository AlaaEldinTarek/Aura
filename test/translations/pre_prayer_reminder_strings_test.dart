// Spec: docs/designs/fix-prayer-reminder.md (tile, switch subtitle). Only the
// keys of this feature are checked, not full parity of both files.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _load(String lang) =>
    json.decode(File('assets/translations/$lang.json').readAsStringSync())
        as Map<String, dynamic>;

const _keys = [
  'pre_prayer_reminder',
  'pre_prayer_reminder_option',
  'pre_prayer_reminder_option_many',
  'pre_prayer_reminder_switch_subtitle',
  'pre_prayer_reminder_switch_subtitle_many',
];

void main() {
  final en = _load('en');
  final ar = _load('ar');

  test('every key exists in both languages and is not empty', () {
    for (final k in _keys) {
      expect(en[k], isA<String>(), reason: 'en $k');
      expect(ar[k], isA<String>(), reason: 'ar $k');
      expect((en[k] as String).trim(), isNotEmpty);
      expect((ar[k] as String).trim(), isNotEmpty);
    }
  });

  test('count keys take one argument in both languages', () {
    for (final k in _keys.where((k) => k != 'pre_prayer_reminder')) {
      expect('{}'.allMatches(en[k] as String).length, 1, reason: 'en $k');
      expect('{}'.allMatches(ar[k] as String).length, 1, reason: 'ar $k');
    }
  });

  test('texts follow the owner strings', () {
    expect(ar['pre_prayer_reminder'], 'التذكير قبل الصلاة');
    expect(ar['pre_prayer_reminder_option'], '{} دقائق');
    expect(ar['pre_prayer_reminder_option_many'], '{} دقيقة');
    expect(
        ar['pre_prayer_reminder_switch_subtitle'], 'قبل كل صلاة بـ {} دقائق');
    expect(ar['pre_prayer_reminder_switch_subtitle_many'],
        'قبل كل صلاة بـ {} دقيقة');
    expect(en['pre_prayer_reminder'], 'Pre-prayer reminder');
    expect(en['pre_prayer_reminder_switch_subtitle'],
        '{} minutes before each prayer');
  });
}
