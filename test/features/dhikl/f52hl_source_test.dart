// Source-text tests for F52h and F52l fixes.
// These tests verify the fix without running Flutter widgets.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('F52h — WirdMarkerService fires checkAndAward', () {
    late String src;
    setUpAll(() {
      src = File('lib/core/services/wird_marker_service.dart').readAsStringSync();
    });

    test('imports achievement_service.dart', () {
      expect(src, contains("import 'achievement_service.dart' show AchievementService"));
    });

    test('calls checkAndAward in moveMarker', () {
      // The move() method body must contain the award call
      final moveIdx = src.indexOf('Future<MoveOutcome> moveMarker(');
      expect(moveIdx, isNot(-1));
      final moveBody = src.substring(moveIdx, moveIdx + 1200);
      expect(moveBody, contains('_awardAchievements('));
    });

    test('calls checkAndAward in completeKhatma', () {
      final khatmaIdx = src.indexOf('Future<KhatmaOutcome> completeKhatma(');
      expect(khatmaIdx, isNot(-1));
      final khatmaBody = src.substring(khatmaIdx, khatmaIdx + 900);
      expect(khatmaBody, contains('_awardAchievements('));
    });

    test('the default award function is the real AchievementService call', () {
      // _awardAchievements is injectable for tests; production uses this default.
      expect(
        src,
        contains('AchievementService.instance.checkAndAward(userId: userId)'),
      );
    });
  });

  group('F52l — DhikrScreen uses app haptic wrapper', () {
    late String src;
    setUpAll(() {
      src = File('lib/features/dhikl/dhikr_screen.dart').readAsStringSync();
    });

    test('does not import flutter/services.dart unqualified (HapticFeedback removed)', () {
      // A show-qualified import for keyboard events is allowed; unqualified is not.
      expect(src, isNot(contains("import 'package:flutter/services.dart';")));
    });

    test('does not import vibration package', () {
      expect(src, isNot(contains("import 'package:vibration/vibration.dart'")));
    });

    test('imports haptic_feedback.dart as app_haptic', () {
      expect(src, contains("import '../../core/utils/haptic_feedback.dart' as app_haptic"));
    });

    test('does not call Vibration.vibrate', () {
      expect(src, isNot(contains('Vibration.vibrate')));
    });
  });
}
