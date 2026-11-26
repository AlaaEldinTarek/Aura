import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final adhan = File(
    'android/app/src/main/kotlin/com/aura/hala/AdhanFullScreenActivity.kt',
  ).readAsStringSync();

  final azkar = File(
    'android/app/src/main/kotlin/com/aura/hala/AzkarFullScreenActivity.kt',
  ).readAsStringSync();

  // T1 — AdhanFullScreenActivity wraps countdown digits in withArabicNumerals
  test('T1 F51n: AdhanFullScreenActivity uses withArabicNumerals for countdown', () {
    expect(adhan, contains('ThemedNotification.withArabicNumerals(formatted)'),
        reason: 'iqama countdown must convert ASCII digits to Arabic-Indic when Arabic');
  });

  // T2 — AzkarFullScreenActivity counter uses withArabicNumerals for item.count and item.target
  test('T2 F51n: AzkarFullScreenActivity counter uses withArabicNumerals', () {
    expect(azkar, contains('withArabicNumerals(item.count.toString())'),
        reason: 'azkar count must use Arabic-Indic digits in Arabic mode');
    expect(azkar, contains('withArabicNumerals(item.target.toString())'),
        reason: 'azkar target must use Arabic-Indic digits in Arabic mode');
  });

  // T3 — AzkarFullScreenActivity progress uses withArabicNumerals for total and done
  test('T3 F51n: AzkarFullScreenActivity progress uses withArabicNumerals', () {
    expect(azkar, contains('withArabicNumerals(total.toString())'),
        reason: 'progress total must use Arabic-Indic digits in Arabic mode');
    expect(azkar, contains('withArabicNumerals(done.toString())'),
        reason: 'progress done must use Arabic-Indic digits in Arabic mode');
  });
}
