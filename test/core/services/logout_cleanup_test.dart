import 'package:aura_app/core/services/logout_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';

/// F70 P3 — logoutCleanup: called after a successful sign-out (D3).
/// Never throws; each step is independent so one failure does not block the rest.
void main() {
  test('T1: all four steps are called in order', () async {
    final calls = <String>[];
    await logoutCleanup(
      cancelNativeAlarms: () async => calls.add('native'),
      cancelPluginNotifications: () async => calls.add('plugin'),
      clearThrottle: () async => calls.add('throttle'),
      clearGuestFlag: () async => calls.add('guest'),
    );
    expect(calls, ['native', 'plugin', 'throttle', 'guest']);
  });

  test('T2: a failing native step does not block subsequent steps', () async {
    final calls = <String>[];
    await logoutCleanup(
      cancelNativeAlarms: () async => throw StateError('native failed'),
      cancelPluginNotifications: () async => calls.add('plugin'),
      clearThrottle: () async => calls.add('throttle'),
      clearGuestFlag: () async => calls.add('guest'),
    );
    expect(calls, ['plugin', 'throttle', 'guest']);
  });

  test('T3: a failing plugin step does not block subsequent steps', () async {
    final calls = <String>[];
    await logoutCleanup(
      cancelNativeAlarms: () async => calls.add('native'),
      cancelPluginNotifications: () async => throw StateError('plugin failed'),
      clearThrottle: () async => calls.add('throttle'),
      clearGuestFlag: () async => calls.add('guest'),
    );
    expect(calls, ['native', 'throttle', 'guest']);
  });

  test('T4: all steps fail — logoutCleanup does not throw', () async {
    await expectLater(
      logoutCleanup(
        cancelNativeAlarms: () async => throw StateError('1'),
        cancelPluginNotifications: () async => throw StateError('2'),
        clearThrottle: () async => throw StateError('3'),
        clearGuestFlag: () async => throw StateError('4'),
      ),
      completes,
    );
  });

  test('T5: clearGuestFlag (D1-C residual hole) is always called even when prior steps fail',
      () async {
    var guestCleared = false;
    await logoutCleanup(
      cancelNativeAlarms: () async => throw StateError('failed'),
      cancelPluginNotifications: () async => throw StateError('failed'),
      clearThrottle: () async => throw StateError('failed'),
      clearGuestFlag: () async => guestCleared = true,
    );
    expect(guestCleared, isTrue);
  });
}
