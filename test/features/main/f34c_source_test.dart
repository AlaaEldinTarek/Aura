import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Source-text test for F34c (docs/designs/fix-f34c.md).
/// Pins the snapshot-parameter fix so a future editor who removes it
/// sees an immediate failure — no device needed.
void main() {
  String src(String path) => File(path).readAsStringSync();

  // F34c — T1: snapshot passed to _checkUntrackedPrayers; no provider read inside
  test(
    'T1: _checkUntrackedPrayers takes a List<PrayerTime> parameter and '
    'does not read prayerTimesProvider internally',
    () {
      final s = src('lib/features/main/main_wrapper_screen.dart');
      expect(
          s,
          contains(
              'Future<void> _checkUntrackedPrayers(List<PrayerTime> prayerTimes)'),
          reason:
              'Function signature must accept a List<PrayerTime> parameter');
      expect(s, isNot(contains('prayerState.prayerTimes.isEmpty')),
          reason:
              'Internal prayerState.prayerTimes.isEmpty guard must be removed; '
              'use the passed prayerTimes parameter instead');
    },
  );

  // F34c — T2: empty-list guard fires before getPrayersForDate
  test(
    'T2: prayerTimes.isEmpty guard precedes getPrayersForDate call in source',
    () {
      final s = src('lib/features/main/main_wrapper_screen.dart');
      final emptyGuardIdx = s.indexOf('if (prayerTimes.isEmpty) return;');
      final firestoreIdx = s.indexOf('getPrayersForDate(');
      expect(emptyGuardIdx, isNot(-1),
          reason: 'prayerTimes.isEmpty guard must be present');
      expect(firestoreIdx, isNot(-1),
          reason: 'getPrayersForDate call must be present');
      expect(emptyGuardIdx, lessThan(firestoreIdx),
          reason:
              'prayerTimes.isEmpty guard must appear before getPrayersForDate '
              'so an empty snapshot skips the Firestore call');
    },
  );
}
