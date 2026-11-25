// Source-text test for F38d — English weekday labels off by one
//
// T1: quran_stats_screen.dart uses day.weekday - 1 (not weekday % 7)
//     to index the English day array.

import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  test('T1: English day array indexed with weekday - 1', () {
    final src =
        File('lib/features/quran/quran_stats_screen.dart').readAsStringSync();

    expect(
      src,
      isNot(contains('enDays[day.weekday % 7]')),
      reason: 'weekday % 7 shifts every label by one for English',
    );

    expect(
      src,
      contains('enDays[day.weekday - 1]'),
      reason: 'must use weekday - 1 to map Monday(1)->index 0',
    );
  });
}
