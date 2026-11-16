import 'package:aura_app/core/services/desktop_notification_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every `LocalNotification` registers itself as a plugin listener when it is
/// created, and a toast button press is sent to every listener with a matching
/// identifier. Adhan toasts reuse one identifier per prayer, so showing a new
/// one must release the previous one; otherwise one press runs the callbacks
/// of every adhan toast ever shown for that prayer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('local_notifier');
  final calls = <MethodCall>[];

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    SharedPreferences.setMockInitialValues({'language': 'en'});
    await localNotifier.setup(appName: 'aura_test');
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  int notifyCount() => calls.where((c) => c.method == 'notify').length;
  int closeCount() => calls.where((c) => c.method == 'close').length;

  test('a repeated adhan toast keeps one listener, not one per toast',
      () async {
    final service = DesktopNotificationService.instance;
    final before = localNotifier.listeners.length;
    calls.clear();

    await service.showAdhanNotification('Fajr', 'الفجر');
    await service.showAdhanNotification('Fajr', 'الفجر');
    await service.showAdhanNotification('Fajr', 'الفجر');

    expect(notifyCount(), 3, reason: 'all three toasts were shown');
    expect(closeCount(), 2, reason: 'the first two were released');
    expect(localNotifier.listeners.length, before + 1);
  });

  test('toasts of different prayers do not release each other', () async {
    final service = DesktopNotificationService.instance;
    final before = localNotifier.listeners.length;
    calls.clear();

    await service.showAdhanNotification('Asr', 'العصر');
    await service.showAdhanNotification('Maghrib', 'المغرب');

    expect(notifyCount(), 2);
    expect(closeCount(), 0);
    expect(localNotifier.listeners.length, before + 2);
  });
}
