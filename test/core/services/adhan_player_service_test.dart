import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aura_app/core/services/adhan_player_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    SharedPreferences.setMockInitialValues({'adhan_enabled': true});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.aura.hala/adhan'),
      (call) async {
        calls.add(call);
        if (call.method == 'previewAdhan') return true;
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.aura.hala/adhan'),
      null,
    );
  });

  test('previewAdhan sends the id to the channel', () async {
    final service = AdhanPlayerService.instance;
    final result = await service.previewAdhan('alafasy');

    expect(result, isTrue);
    final preview = calls.where((c) => c.method == 'previewAdhan').toList();
    expect(preview, hasLength(1));
    expect(preview.first.arguments, {'id': 'alafasy'});
  });

  test('previewAdhan returns false on PlatformException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.aura.hala/adhan'),
      (call) async {
        throw PlatformException(code: 'ERROR');
      },
    );

    final result = await AdhanPlayerService.instance.previewAdhan('x');
    expect(result, isFalse);
  });

  test('setEnabled writes prefs and sends no channel call', () async {
    calls.clear();
    await AdhanPlayerService.instance.setEnabled(false);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('adhan_enabled'), isFalse);
    expect(calls.where((c) => c.method == 'setAdhanEnabled'), isEmpty);
  });
}
