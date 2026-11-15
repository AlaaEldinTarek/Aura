// Spec: docs/designs/fix-boot-start-service.md, section 3a and phase P1b. The
// "Open app details" button of the App launch dialog goes through the existing
// Dart app-settings open, with no native call.
import 'package:aura_app/core/services/platform_channel_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('com.aura.hala/prayer_alarms');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> channelCalls;
  late int appSettingsOpened;

  setUp(() {
    channelCalls = [];
    appSettingsOpened = 0;
    PlatformChannelService.debugIsAndroid = true;
    PlatformChannelService.debugOpenAppSettings = () async {
      appSettingsOpened++;
      return true;
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      channelCalls.add(call.method);
      return true;
    });
  });

  tearDown(() {
    PlatformChannelService.debugIsAndroid = null;
    PlatformChannelService.debugOpenAppSettings = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('opens the app settings once and makes no channel call', () async {
    await PlatformChannelService.openAppDetails();
    expect(appSettingsOpened, 1);
    expect(channelCalls, isEmpty);
  });

  test('does nothing when not on Android', () async {
    PlatformChannelService.debugIsAndroid = false;
    await PlatformChannelService.openAppDetails();
    expect(appSettingsOpened, 0);
    expect(channelCalls, isEmpty);
  });
}
