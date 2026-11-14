// Spec: docs/designs/fix-boot-start-service.md, section 3 and phase P1. The Dart
// side of the "App launch" tile: the two channel methods and the fallback when the
// native side fails. Whether the EMUI screen opens is checked on a Huawei phone.
import 'package:aura_app/core/services/platform_channel_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('com.aura.hala/prayer_alarms');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;
  late int appSettingsOpened;

  void mockChannel(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) {
      calls.add(call.method);
      return handler(call);
    });
  }

  setUp(() {
    calls = [];
    appSettingsOpened = 0;
    PlatformChannelService.debugIsAndroid = true;
    PlatformChannelService.debugOpenAppSettings = () async {
      appSettingsOpened++;
      return true;
    };
  });

  tearDown(() {
    PlatformChannelService.debugIsAndroid = null;
    PlatformChannelService.debugOpenAppSettings = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('canOpenAutoLaunchSettings', () {
    test('true when the native side says an EMUI screen exists', () async {
      mockChannel((_) async => true);
      expect(await PlatformChannelService.canOpenAutoLaunchSettings(), isTrue);
      expect(calls, ['canOpenAutoLaunchSettings']);
    });

    test('false when the native side says none exists', () async {
      mockChannel((_) async => false);
      expect(await PlatformChannelService.canOpenAutoLaunchSettings(), isFalse);
    });

    test('false when the channel throws', () async {
      mockChannel((_) async => throw PlatformException(code: 'boom'));
      expect(await PlatformChannelService.canOpenAutoLaunchSettings(), isFalse);
    });

    test('false, with no channel call, when not on Android', () async {
      PlatformChannelService.debugIsAndroid = false;
      mockChannel((_) async => true);
      expect(await PlatformChannelService.canOpenAutoLaunchSettings(), isFalse);
      expect(calls, isEmpty);
    });
  });

  group('openAutoLaunchSettings', () {
    test('asks the native side and does not touch app settings on success',
        () async {
      mockChannel((_) async => true);
      await PlatformChannelService.openAutoLaunchSettings();
      expect(calls, ['openAutoLaunchSettings']);
      expect(appSettingsOpened, 0);
    });

    test('falls back to the app settings screen when the channel throws',
        () async {
      mockChannel((_) async => throw PlatformException(code: 'boom'));
      await PlatformChannelService.openAutoLaunchSettings();
      expect(calls, ['openAutoLaunchSettings']);
      expect(appSettingsOpened, 1);
    });

    test('falls back to the app settings screen when nothing opened natively',
        () async {
      mockChannel((_) async => false);
      await PlatformChannelService.openAutoLaunchSettings();
      expect(calls, ['openAutoLaunchSettings']);
      expect(appSettingsOpened, 1);
    });

    test('does nothing when not on Android', () async {
      PlatformChannelService.debugIsAndroid = false;
      mockChannel((_) async => true);
      await PlatformChannelService.openAutoLaunchSettings();
      expect(calls, isEmpty);
      expect(appSettingsOpened, 0);
    });
  });
}
