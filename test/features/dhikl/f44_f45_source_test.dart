// Source-text tests for F44a+F44b+F44c+F45a+F45b
// These verify the fix is in place without running the app.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('F44a – Continue button does not call _incrementCounter', () {
    test('T1: Continue onPressed clears _isCompleted, not calls _incrementCounter', () {
      final src = File('lib/features/dhikl/dhikr_screen.dart').readAsStringSync();
      // The Continue button block must NOT call _incrementCounter
      final continueBlock = RegExp(
        r"dhikr_continue.*?onPressed.*?\{.*?\}",
        dotAll: true,
      ).firstMatch(src)?.group(0) ?? '';
      expect(
        continueBlock.contains('_incrementCounter'),
        isFalse,
        reason: 'Continue onPressed must not call _incrementCounter',
      );
      expect(
        src.contains('_isCompleted = false'),
        isTrue,
        reason: 'Continue must clear _isCompleted',
      );
    });
  });

  group('F44b – Arabic numerals in counter display', () {
    test('T2: Counter values are routed through NumberFormatter', () {
      final src = File('lib/features/dhikl/dhikr_screen.dart').readAsStringSync();
      // countStr and targetStr locals must exist and use NumberFormatter
      expect(
        src.contains('final countStr = NumberFormatter'),
        isTrue,
        reason: 'Must declare countStr via NumberFormatter',
      );
      expect(
        src.contains('final targetStr = NumberFormatter'),
        isTrue,
        reason: 'Must declare targetStr via NumberFormatter',
      );
      // The counter display body must reference countStr and targetStr
      final displayIdx = src.indexOf('Widget _buildCounterDisplay');
      final displayBody = src.substring(displayIdx);
      expect(
        displayBody.contains('countStr'),
        isTrue,
        reason: 'Counter circle must display countStr',
      );
    });
  });

  group('F44c – No bare isArabic ternary strings in dhikr screens', () {
    test('T3: dhikr_screen.dart has no isArabic ? string ternaries', () {
      final src = File('lib/features/dhikl/dhikr_screen.dart').readAsStringSync();
      // Match UI strings (3+ chars); skip 'ar'/'en' locale assignments
      final ternaryStrings = RegExp(r"isArabic \? '[^']{3,}' : '[^']+'").allMatches(src);
      expect(
        ternaryStrings.isEmpty,
        isTrue,
        reason: 'All UI string ternaries must be replaced with .tr()',
      );
    });

    test('T3b: custom_zikr_form_screen.dart has no isArabic ? string ternaries', () {
      final src = File('lib/features/dhikl/custom_zikr_form_screen.dart').readAsStringSync();
      final ternaryStrings = RegExp(r"isArabic \? '[^']{3,}' : '[^']+'").allMatches(src);
      expect(ternaryStrings.isEmpty, isTrue);
    });

    test('T3c: dhikr_stats_screen.dart has no isArabic ? string ternaries', () {
      final src = File('lib/features/dhikl/dhikr_stats_screen.dart').readAsStringSync();
      final ternaryStrings = RegExp(r"isArabic \? '[^']{3,}' : '[^']+'").allMatches(src);
      expect(ternaryStrings.isEmpty, isTrue);
    });
  });

  group('F45a – islamicEventsProvider is a NotifierProvider', () {
    test('T4: Provider declaration uses NotifierProvider', () {
      final src = File('lib/core/providers/islamic_events_provider.dart').readAsStringSync();
      expect(
        src.contains('NotifierProvider'),
        isTrue,
        reason: 'Must use NotifierProvider for midnight refresh',
      );
      expect(
        src.contains('Timer'),
        isTrue,
        reason: 'Must schedule a midnight timer',
      );
    });
  });

  group('F45b – HijriDate.formatAr uses NumberFormatter', () {
    test('T5: formatAr passes day and year through NumberFormatter', () {
      final src = File('lib/core/utils/hijri_date.dart').readAsStringSync();
      expect(
        src.contains('NumberFormatter.withArabicNumerals'),
        isTrue,
        reason: 'formatAr must format numbers with NumberFormatter',
      );
    });
  });
}
