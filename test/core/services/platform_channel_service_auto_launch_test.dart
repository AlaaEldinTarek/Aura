// Spec: docs/designs/fix-boot-start-service.md, section 3a and phase P1b. The Dart
// side of the "App launch" tile: the Huawei (EMUI) check. The dialog is checked on a Huawei phone.
import 'package:aura_app/core/services/platform_channel_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('com.aura.hala/prayer_alarms');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;

  void mockChannel(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) {
      calls.add(call.method);
      return handler(call);
    });
  }

  setUp(() {
    calls = [];
    PlatformChannelService.debugIsAndroid = true;
  });

  tearDown(() {
    PlatformChannelService.debugIsAndroid = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('isEmuiDevice', () {
    test('true when the native side says this is a Huawei (EMUI) phone', () async {
      mockChannel((_) async => true);
      expect(await PlatformChannelService.isEmuiDevice(), isTrue);
      expect(calls, ['isEmuiDevice']);
    });

    test('false when the native side says it is not', () async {
      mockChannel((_) async => false);
      expect(await PlatformChannelService.isEmuiDevice(), isFalse);
    });

    test('false when the channel throws', () async {
      mockChannel((_) async => throw PlatformException(code: 'boom'));
      expect(await PlatformChannelService.isEmuiDevice(), isFalse);
    });

    test('false, with no channel call, when not on Android', () async {
      PlatformChannelService.debugIsAndroid = false;
      mockChannel((_) async => true);
      expect(await PlatformChannelService.isEmuiDevice(), isFalse);
      expect(calls, isEmpty);
    });
  });
}
