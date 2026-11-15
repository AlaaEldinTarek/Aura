// Spec: docs/designs/mode-separation.md, "Warning dialog texts" (M3). The
// three keys, with the exact English and the owner-reviewed Arabic, in both
// files, in the same order, with no duplicate key.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _en = {
  'wird_mode_switch_title': 'Switch from Juz to Pages?',
  'wird_mode_switch_body':
      'Your checked juz cards will be emptied. Your khatm history and earned achievements stay. If you come back to Juz, you start with empty cards.',
  'wird_mode_switch_confirm': 'Switch',
};
const _ar = {
  'wird_mode_switch_title': 'التبديل من أجزاء إلى صفحات؟',
  'wird_mode_switch_body':
      'سيتم تفريغ بطاقات الأجزاء التي حددتها. يبقى سجل الختمات والإنجازات التي حصلت عليها. إذا عدت إلى أجزاء فستبدأ ببطاقات فارغة.',
  'wird_mode_switch_confirm': 'تبديل',
};

List<String> _keysInOrder(String raw) =>
    RegExp(r'^\s*"([^"]+)"\s*:', multiLine: true)
        .allMatches(raw)
        .map((m) => m.group(1)!)
        .toList();

void main() {
  final enRaw = File('assets/translations/en.json').readAsStringSync();
  final arRaw = File('assets/translations/ar.json').readAsStringSync();
  final en = jsonDecode(enRaw) as Map<String, dynamic>;
  final ar = jsonDecode(arRaw) as Map<String, dynamic>;

  test('both files parse and the three keys have the spec texts', () {
    _en.forEach((k, v) => expect(en[k], v, reason: 'en $k'));
    _ar.forEach((k, v) => expect(ar[k], v, reason: 'ar $k'));
  });

  test('the Cancel button reuses the existing cancel key', () {
    expect(en['cancel'], 'Cancel');
    expect(ar['cancel'], 'إلغاء');
  });

  test('no duplicate keys in either file', () {
    for (final raw in [enRaw, arRaw]) {
      final keys = _keysInOrder(raw);
      expect(keys.toSet().length, keys.length);
    }
  });

  test('en and ar have the same set of keys', () {
    expect(_keysInOrder(arRaw).toSet(), _keysInOrder(enRaw).toSet());
  });

  // The two files already differed in the order of 5 older keys before M3
  // (not reordered here). The three new keys are last, in the same order.
  test('the three new keys are the last three, in the same order, in both', () {
    final want = _en.keys.toList();
    expect(_keysInOrder(enRaw).sublist(_keysInOrder(enRaw).length - 3), want);
    expect(_keysInOrder(arRaw).sublist(_keysInOrder(arRaw).length - 3), want);
  });
}
