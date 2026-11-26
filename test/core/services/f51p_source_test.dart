import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final azkarReceiver = File(
    'android/app/src/main/kotlin/com/aura/hala/AzkarAlarmReceiver.kt',
  ).readAsStringSync();

  final focusService = File(
    'android/app/src/main/kotlin/com/aura/hala/FocusModeService.kt',
  ).readAsStringSync();

  // T10 — AzkarAlarmReceiver uses ic_notification, not ic_launcher
  test('T10 F51p: AzkarAlarmReceiver uses ic_notification small icon', () {
    expect(azkarReceiver, contains('R.drawable.ic_notification'),
        reason: 'AzkarAlarmReceiver must use the monochrome notification icon');
    expect(azkarReceiver, isNot(contains('R.mipmap.ic_launcher')),
        reason: 'AzkarAlarmReceiver must not use launcher mipmap as notification icon');
  });

  // T11 — FocusModeService uses ic_notification, not ic_launcher
  test('T11 F51p: FocusModeService uses ic_notification small icon', () {
    expect(focusService, contains('R.drawable.ic_notification'),
        reason: 'FocusModeService must use the monochrome notification icon');
    expect(focusService, isNot(contains('R.mipmap.ic_launcher')),
        reason: 'FocusModeService must not use launcher mipmap as notification icon');
  });
}
