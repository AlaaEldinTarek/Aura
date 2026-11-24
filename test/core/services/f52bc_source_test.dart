import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Source-text tests for F52b + F52c (docs/designs/fix-f52bc.md).
/// Each test pins a specific guard so a future editor who removes it sees
/// an immediate failure — no device needed.
void main() {
  String src(String path) => File(path).readAsStringSync();

  // F52b — T1: home_screen skips isPrayerTimeReached when not effectiveIsToday
  test(
    'T1: home_screen guards isPrayerTimeReached with effectiveIsToday',
    () {
      final s = src('lib/features/home/home_screen.dart');
      expect(s, contains('effectiveIsToday'),
          reason: 'effectiveIsToday variable missing from home_screen');
      expect(s, contains('!effectiveIsToday || isPrayerTimeReached'),
          reason: 'gate condition missing: !effectiveIsToday || isPrayerTimeReached');
    },
  );

  // F52b — T2: prayer_screen _loadCompletedPrayers skips gate on past day
  test(
    'T2: _loadCompletedPrayers guards isPrayerTimeReached with effectiveIsToday',
    () {
      final s = src('lib/features/prayer/prayer_screen.dart');
      expect(s, contains('effectiveIsToday && !isPrayerTimeReached'),
          reason: 'effectiveIsToday guard missing in _loadCompletedPrayers');
    },
  );

  // F52b — T3: prayer_screen ref.listen block skips gate on past day
  test(
    'T3: ref.listen update skips isPrayerTimeReached when not listenEffIsToday',
    () {
      final s = src('lib/features/prayer/prayer_screen.dart');
      expect(s, contains('listenEffIsToday'),
          reason: 'listenEffIsToday missing from ref.listen block');
      // Check both sides of the guard are present (avoids CRLF vs LF sensitivity)
      expect(s, contains('listenEffIsToday &&'),
          reason: 'listenEffIsToday guard missing in ref.listen');
      // The negated isPrayerTimeReached must also be present in the listen block
      final listenIdx = s.indexOf('listenEffIsToday');
      final window = s.substring(listenIdx, listenIdx + 600);
      expect(window, contains('!isPrayerTimeReached'),
          reason: '!isPrayerTimeReached not found near listenEffIsToday in ref.listen');
    },
  );

  // F52b — T4: _markPrayerAsCompleted skips canMarkPrayer when not on real today
  test(
    'T4: _markPrayerAsCompleted guards canMarkPrayer with markEffIsToday',
    () {
      final s = src('lib/features/prayer/prayer_screen.dart');
      expect(s, contains('markEffIsToday'),
          reason: 'markEffIsToday guard missing from _markPrayerAsCompleted');
      expect(s, contains('markEffIsToday &&'),
          reason: 'markEffIsToday && canMarkPrayer gate missing');
    },
  );

  // F52c — T5: syncNativePrayerStatuses checks recordPrayer return before clearing key
  test(
    'T5: syncNativePrayerStatuses clears native key only on successful recordPrayer',
    () {
      final s = src('lib/core/services/prayer_alarm_service.dart');
      expect(s, contains('final synced = await PrayerTrackingService'),
          reason: 'recordPrayer return value not captured as synced');
      expect(s, contains('if (synced) {'),
          reason: 'if (synced) guard before clearNativePrayerStatus missing');
      // The key must NOT be cleared unconditionally
      final unconditional = RegExp(
        r'recordPrayer\([^)]*\);\s*\n\s*await clearNativePrayerStatus',
        dotAll: true,
      );
      expect(unconditional.hasMatch(s), isFalse,
          reason: 'clearNativePrayerStatus is still called unconditionally');
    },
  );
}
