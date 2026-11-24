import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Source-text test for F42a (docs/designs/fix-f42a.md).
/// Pins the stale-streak reset in _load() so a future editor who removes it
/// sees an immediate failure — no device needed.
void main() {
  String src(String path) => File(path).readAsStringSync();

  // F42a — T1: _load() resets streakCount when azkar_streak_date is stale
  test(
    'T1: _load() reads _kStreakDateKey and resets streakCount when date is stale',
    () {
      final s = src('lib/core/providers/azkar_provider.dart');
      // The streak date must be read inside _load
      expect(s, contains('prefs.getString(_kStreakDateKey)'),
          reason: '_kStreakDateKey not read in _load()');
      // The guard resets the streak when date is neither today nor yesterday
      expect(s, contains('state = state.copyWith(streakCount: 0)'),
          reason: 'streakCount reset missing from _load()');
      // The reset must be conditional on the date check
      expect(
          s,
          contains(
              "lastDate != _todayKey() && lastDate != _yesterdayKey()"),
          reason: 'stale-date guard condition missing in _load()');
    },
  );
}
