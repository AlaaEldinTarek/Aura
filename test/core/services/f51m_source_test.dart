import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final activity = File(
    'android/app/src/main/kotlin/com/aura/hala/FocusModeActivity.kt',
  ).readAsStringSync();

  final service = File(
    'android/app/src/main/kotlin/com/aura/hala/FocusModeService.kt',
  ).readAsStringSync();

  final receiver = File(
    'android/app/src/main/kotlin/com/aura/hala/FocusModeReceiver.kt',
  ).readAsStringSync();

  // T1 — Activity.restoreSoundMode restores savedRingerMode, not RINGER_MODE_NORMAL
  test('T1 F51m: Activity.restoreSoundMode uses savedRingerMode', () {
    expect(activity, contains('audioManager.ringerMode = savedRingerMode'),
        reason: 'restoreSoundMode must restore savedRingerMode, not hardcode RINGER_MODE_NORMAL');
  });

  // T2 — Activity.restoreSoundMode restores savedInterruptionFilter, not FILTER_ALL
  test('T2 F51m: Activity.restoreSoundMode uses savedInterruptionFilter', () {
    expect(activity, contains('setInterruptionFilter(savedInterruptionFilter)'),
        reason: 'restoreSoundMode must restore savedInterruptionFilter, not hardcode FILTER_ALL');
    expect(activity, isNot(contains('setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)')),
        reason: 'Activity.restoreSoundMode must not hardcode INTERRUPTION_FILTER_ALL');
  });

  // T3 — Activity.enableSilentMode reads currentInterruptionFilter before setting PRIORITY
  test('T3 F51m: Activity.enableSilentMode saves currentInterruptionFilter', () {
    expect(activity, contains('savedInterruptionFilter = notificationManager.currentInterruptionFilter'),
        reason: 'enableSilentMode must capture the pre-focus DND filter');
  });

  // T4 — Service.onDestroy calls restoreSoundMode only when isTimerFinished
  test('T4 F51m: Service.onDestroy guards restoreSoundMode with isTimerFinished', () {
    expect(service, contains('if (isTimerFinished) restoreSoundMode()'),
        reason: 'onDestroy must not restore sound when restarting mid-session');
  });

  // T5 — Service.saveFocusState persists saved_ringer_mode and saved_dnd_filter
  test('T5 F51m: Service.saveFocusState persists audio state', () {
    expect(service, contains('"saved_ringer_mode"'),
        reason: 'saveFocusState must write saved_ringer_mode so restart path can load it');
    expect(service, contains('"saved_dnd_filter"'),
        reason: 'saveFocusState must write saved_dnd_filter so restart path can load it');
  });

  // T6 — Service.enableSilentMode checks prefs for saved_ringer_mode (restart path)
  test('T6 F51m: Service.enableSilentMode checks prefs for restart path', () {
    expect(service, contains('prefs.contains("saved_ringer_mode")'),
        reason: 'enableSilentMode must detect restart path via prefs to avoid re-reading already-restored audio state');
  });

  // T7 — FocusModeReceiver uses REQUEST_CODE_SLOTS = 10_000
  test('T7 F51m: FocusModeReceiver REQUEST_CODE_SLOTS is 10_000', () {
    expect(receiver, contains('REQUEST_CODE_SLOTS = 10_000'),
        reason: 'Focus alarm request codes must span 10 000 slots to reduce hash collisions');
  });

  // T8 — FocusModeReceiver.cancelSpecs covers 0 until REQUEST_CODE_SLOTS
  test('T8 F51m: FocusModeReceiver.cancelSpecs covers 0 until REQUEST_CODE_SLOTS', () {
    expect(receiver, contains('(0 until REQUEST_CODE_SLOTS)'),
        reason: 'cancelSpecs must cancel all 10 000 possible request codes for F70 logout cleanup');
  });
}
