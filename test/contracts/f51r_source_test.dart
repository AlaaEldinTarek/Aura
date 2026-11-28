import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Source-text test for F51r (docs/designs/fix-f51r.md).
/// On Android 12-12L, AlarmManager.setExact* can throw SecurityException when
/// "Alarms & reminders" is revoked. Each named scheduling function must wrap
/// its exact-alarm call in try/catch (e: SecurityException) and return before
/// the "scheduled" log line, so a revoked permission neither crashes the
/// process nor logs a false success.
void main() {
  const dir = 'android/app/src/main/kotlin/com/aura/hala';

  /// The text of the function that starts at the first match of [signature],
  /// up to the next member-level `fun` (or the end of the file).
  String functionBody(String file, String signature) {
    final s = File('$dir/$file').readAsStringSync();
    final start = s.indexOf(signature);
    expect(start, isNot(-1), reason: '$file: $signature not found');
    final rest = s.substring(start + signature.length);
    final next = RegExp(r'\n {4,8}(private |internal )?fun ').firstMatch(rest);
    return s.substring(
        start, next == null ? s.length : start + signature.length + next.start);
  }

  void expectGuarded(String file, String signature, {required String logMark}) {
    final b = functionBody(file, signature);
    final call = b.indexOf('alarmManager.setExactAndAllowWhileIdle(');
    final legacy = b.indexOf('alarmManager.setExact(');
    expect(call, isNot(-1), reason: '$signature: exact call missing');
    final tryIdx = b.lastIndexOf('try {', call);
    expect(tryIdx, isNot(-1), reason: '$signature: no try before the call');
    final catchIdx = b.indexOf('catch (e: SecurityException)', legacy);
    expect(catchIdx, isNot(-1),
        reason: '$signature: no catch (e: SecurityException) after the call');
    expect(catchIdx, greaterThan(legacy),
        reason: '$signature: catch must follow the legacy setExact branch');
    final retIdx = b.indexOf('return', catchIdx);
    final logIdx = b.indexOf(logMark, catchIdx);
    expect(logIdx, isNot(-1),
        reason: '$signature: log line "$logMark" missing');
    expect(retIdx, isNot(-1), reason: '$signature: catch must return');
    expect(retIdx, lessThan(logIdx),
        reason: '$signature: return must come before the "scheduled" log');
  }

  const par = 'PrayerAlarmReceiver.kt';

  test('T1: scheduleReminderAlarm guards setExact', () {
    expectGuarded(par, 'fun scheduleReminderAlarm(',
        logMark: 'REMINDER SCHEDULED');
  });

  test('T2: scheduleDelayedReminder guards setExact', () {
    expectGuarded(par, 'fun scheduleDelayedReminder(',
        logMark: 'DELAYED_REMINDER');
  });

  test('T3: schedulePrayerAlarm (the adhan alarm) guards setExact', () {
    expectGuarded(par, 'fun schedulePrayerAlarm(', logMark: 'ALARM SCHEDULED');
  });

  test('T4: schedulePostPrayerCheck guards setExact', () {
    expectGuarded(par, 'fun schedulePostPrayerCheck(', logMark: 'POST_CHECK');
  });

  test('T5: scheduleSilentModeRestore guards setExact', () {
    expectGuarded(par, 'fun scheduleSilentModeRestore(',
        logMark: 'Scheduled silent mode restore');
  });

  test('T6: NativeNotificationReceiver.schedule guards setExact', () {
    expectGuarded('NativeNotificationReceiver.kt', 'fun schedule(',
        logMark: 'Scheduled id=');
  });

  test('T7: TaskReminderReceiver.schedule guards setExact', () {
    expectGuarded('TaskReminderReceiver.kt', 'fun schedule(',
        logMark: 'Task reminder scheduled');
  });
}
