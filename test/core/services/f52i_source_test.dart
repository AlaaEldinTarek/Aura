import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final dartSvc = File(
    'lib/core/services/notification_service.dart',
  ).readAsStringSync();

  final arabicCount = File(
    'android/app/src/main/kotlin/com/aura/hala/ArabicCount.kt',
  ).readAsStringSync();

  final nativeCard = File(
    'android/app/src/main/kotlin/com/aura/hala/NativeReminderCard.kt',
  ).readAsStringSync();

  // T4 — scheduleWirdReminders has isJuzMode parameter
  test('T4 F52i: scheduleWirdReminders has isJuzMode param', () {
    expect(dartSvc, contains('bool isJuzMode = false'),
        reason: 'scheduleWirdReminders must accept isJuzMode');
  });

  // T5 — Dart passes wird_juz kind when isJuzMode is true
  test('T5 F52i: Dart passes wird_juz kind when isJuzMode', () {
    expect(dartSvc, contains("isJuzMode ? 'wird_juz' : 'wird'"),
        reason: 'native kind must be wird_juz in juz mode');
  });

  // T6 — Dart uses NumberFormatter.withArabicNumerals for dailyPageGoal in body
  test('T6 F52i: Dart body uses NumberFormatter.withArabicNumerals for page/juz goal', () {
    expect(dartSvc, contains('NumberFormatter.withArabicNumerals("\$dailyPageGoal")'),
        reason: 'Arabic body must format dailyPageGoal through NumberFormatter');
  });

  // T7 — ArabicCount.juzParts declared
  test('T7 F52i: ArabicCount.juzParts function declared', () {
    expect(arabicCount, contains('fun juzParts(count: Int)'),
        reason: 'ArabicCount must have juzParts for Arabic plural forms');
  });

  // T8 — NativeReminderCard.KIND_WIRD_JUZ constant declared
  test('T8 F52i: NativeReminderCard.KIND_WIRD_JUZ constant declared', () {
    expect(nativeCard, contains('KIND_WIRD_JUZ = "wird_juz"'),
        reason: 'NativeReminderCard must declare KIND_WIRD_JUZ constant');
  });

  // T9 — NativeReminderCard.bodyFor handles KIND_WIRD_JUZ
  test('T9 F52i: NativeReminderCard.bodyFor handles KIND_WIRD_JUZ', () {
    expect(nativeCard, contains('KIND_WIRD_JUZ ->'),
        reason: 'bodyFor must have a KIND_WIRD_JUZ branch');
    expect(nativeCard, contains('ArabicCount.juzParts(a)'),
        reason: 'KIND_WIRD_JUZ branch must use ArabicCount.juzParts');
  });
}
