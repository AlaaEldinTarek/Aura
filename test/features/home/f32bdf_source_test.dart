import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final homeSource = File(
      'lib/features/home/home_screen.dart',
  ).readAsStringSync();
  final prayerSource = File(
      'lib/features/prayer/prayer_screen.dart',
  ).readAsStringSync();

  // T1 — F32b: streak future is cached; FutureBuilder no longer calls _getStreak() directly
  test('T1 F32b: _streakFuture field declared; FutureBuilder uses it', () {
    expect(homeSource, contains('Future<int> _streakFuture'),
        reason: 'cached streak future field must be declared');
    expect(homeSource, contains('future: _streakFuture'),
        reason: 'FutureBuilder must use the cached future');
    // The FutureBuilder must NOT pass _getStreak() as the future argument
    final futureBuilderIdx =
        homeSource.indexOf('future: _streakFuture');
    expect(futureBuilderIdx, greaterThan(0));
    // No direct call of _getStreak inside a FutureBuilder future: argument
    final badPattern = RegExp(r'future:\s*_getStreak\(\)');
    expect(badPattern.hasMatch(homeSource), isFalse,
        reason: 'FutureBuilder must not call _getStreak() directly');
  });

  // T2 — F32d: dispose() clears _pendingTutorialLaunch
  test('T2 F32d: dispose() sets _pendingTutorialLaunch = false', () {
    final disposeIdx = homeSource.indexOf('void dispose()');
    expect(disposeIdx, greaterThan(0));
    // Check the first dispose body (the _HomeScreenState one)
    final afterDispose = homeSource.substring(disposeIdx);
    final braceClose = afterDispose.indexOf('}');
    final disposeBody = afterDispose.substring(0, braceClose);
    expect(disposeBody, contains('_pendingTutorialLaunch = false'),
        reason: 'dispose() must clear _pendingTutorialLaunch');
  });

  // T3 — F32f: countdown ring uses getPrayerDisplayName
  test('T3 F32f: CircularCountdownTimer prayerName uses getPrayerDisplayName', () {
    expect(prayerSource, contains("import '../../core/utils/prayer_time_rules.dart'"),
        reason: 'prayer_screen must import prayer_time_rules');
    expect(
      prayerSource,
      contains('getPrayerDisplayName(nextPrayer.name, isArabic: isArabic)'),
      reason: 'countdown ring label must use getPrayerDisplayName',
    );
    // The old raw name pattern must be gone
    expect(
      prayerSource,
      isNot(contains('isArabic ? nextPrayer.nameAr : nextPrayer.name')),
      reason: 'raw nameAr / name ternary must be replaced',
    );
  });
}
