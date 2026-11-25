// Source-text tests for F19 + F34b — 20-minute rule applied consistently
//
// T1: cleanupFuturePrayerRecords uses adhan time (not adhan+20 min) as the
//     deletion threshold, so records made via notification at adhan time survive.
// T2: _checkUntrackedPrayers uses isPrayerTimeReached (not p.time.isBefore(now))
//     so the untracked sheet only opens after the 20-min window.

import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  group('F19 — cleanupFuturePrayerRecords threshold', () {
    test(
        'T1: cleanup deletes when prayedAt < prayer.time, '
        'not when prayedAt < prayer.time + 20 min', () {
      final file = File(
          'lib/core/services/prayer_tracking_service.dart',
      ).readAsStringSync();

      // Must use strictly-before-adhan threshold
      expect(
        file,
        contains('record.prayedAt.isBefore(prayer.time)'),
        reason: 'cleanup must use adhan time as threshold, not adhan+20 min',
      );

      // Must NOT use the old adhan+20-min threshold
      expect(
        file,
        isNot(contains(
          'record.prayedAt.isBefore(prayer.time.add(const Duration(minutes: 20)))',
        )),
        reason: 'old adhan+20-min threshold deletes valid notification records',
      );
    });
  });

  group('F34b — _checkUntrackedPrayers filter', () {
    test(
        'T2: untracked-prayer filter uses isPrayerTimeReached, '
        'not a bare p.time.isBefore(now) check', () {
      final file = File(
          'lib/features/main/main_wrapper_screen.dart',
      ).readAsStringSync();

      // Must use isPrayerTimeReached for the filter
      expect(
        file,
        contains('isPrayerTimeReached(p.name, prayerTimes)'),
        reason:
            '_checkUntrackedPrayers must wait for the 20-min window via isPrayerTimeReached',
      );
    });
  });
}
