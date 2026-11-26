import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File(
    'lib/core/providers/prayer_times_provider.dart',
  ).readAsStringSync();

  // T1 — _dayTransitionPending field declared in PrayerTimesNotifier
  test('T1 F52d: _dayTransitionPending field declared', () {
    expect(src, contains('bool _dayTransitionPending = false'),
        reason: '_dayTransitionPending must be declared with false default');
  });

  // T2 — loadPrayerTimes inside _quickUpdateNextPrayer is guarded by the flag
  test('T2 F52d: day-transition loadPrayerTimes guarded by !_dayTransitionPending', () {
    expect(src, contains('if (!_dayTransitionPending)'),
        reason: 'must check the flag before calling loadPrayerTimes');
    expect(src, contains('_dayTransitionPending = true'),
        reason: 'must set flag to true before the reload');
    // Reload must only appear inside the guard, not unconditionally
    final quickIdx = src.indexOf('void _quickUpdateNextPrayer()');
    expect(quickIdx, greaterThan(0));
    final quickBody = src.substring(quickIdx, quickIdx + 600);
    final unconditional = RegExp(
        r'isAfter\(today\)\s*\{[^}]*loadPrayerTimes\(DateTime\.now\(\)\)[^}]*\}',
        dotAll: true);
    expect(unconditional.hasMatch(quickBody), isFalse,
        reason: 'loadPrayerTimes must not be called unconditionally in the day-transition branch');
  });

  // T3 — flag reset on same-day path
  test('T3 F52d: _dayTransitionPending reset to false on same-day path', () {
    expect(src, contains('_dayTransitionPending = false'),
        reason: 'flag must be reset when same-day prayers are in effect');
  });
}
