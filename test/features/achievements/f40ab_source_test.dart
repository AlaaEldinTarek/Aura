import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File(
    'lib/features/achievements/achievements_screen.dart',
  ).readAsStringSync();

  test('T1 — F40a: allIds guard present', () {
    expect(src, contains('allIds.contains(a.id)'));
  });

  test('T2 — F40b: achievements_screen_title.tr() present, inline Arabic title absent', () {
    expect(src, contains("'achievements_screen_title'.tr()"));
    expect(src, isNot(contains("'الإنجازات'")));
    expect(src, isNot(contains("'Achievements'")));
  });
}
