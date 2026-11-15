import 'package:aura_app/core/services/prayer_alarm_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.aura.hala/prayer_alarms');
  late List<MethodCall> calls;

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void mock(Future<dynamic> Function(MethodCall) handler) {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  test('testAdhanNow sends only testAdhanNow with the prayer name', () async {
    mock((_) async => true);
    await PrayerAlarmService.instance.testAdhanNow('Zuhr');
    expect(calls.map((c) => c.method), ['testAdhanNow']);
    expect(calls.single.arguments, {'prayerName': 'Zuhr'});
  });

  test('testAdhanNow swallows a PlatformException', () async {
    mock((_) async => throw PlatformException(code: 'X'));
    await PrayerAlarmService.instance.testAdhanNow('Zuhr');
    expect(calls, hasLength(1));
  });

  test('canScheduleExactAlarms is false on error and true when granted',
      () async {
    mock((_) async => throw PlatformException(code: 'X'));
    expect(await PrayerAlarmService.instance.canScheduleExactAlarms(), isFalse);
    mock((_) async => true);
    expect(await PrayerAlarmService.instance.canScheduleExactAlarms(), isTrue);
  });
}
