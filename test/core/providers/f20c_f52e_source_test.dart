import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Source-text tests for F20c + F52e fix.
/// T1: Android daily-effects no longer call scheduleDailyTaskDigest.
/// T2: NotificationService.initialize() contains the 4001 native-cancel cleanup.
void main() {
  group('F20c + F52e source', () {
    test('T1: prayer_times_provider Android path does not call scheduleDailyTaskDigest', () {
      final src = File('lib/core/providers/prayer_times_provider.dart').readAsStringSync();
      // The else-branch called NotificationService.instance.scheduleDailyTaskDigest.
      // The desktop path uses DesktopNotificationService.instance.scheduleDailyTaskDigest
      // (kept). Use a lookbehind to confirm only the desktop-prefixed form remains.
      final androidCall = RegExp(
          r'(?<!Desktop)NotificationService\.instance\.scheduleDailyTaskDigest');
      expect(
        androidCall.hasMatch(src),
        isFalse,
        reason: 'Android should no longer schedule the retired 4001 digest',
      );
    });

    test('T2: notification_service initialize() cancels native alarm 4001', () {
      final src = File('lib/core/services/notification_service.dart').readAsStringSync();
      expect(
        src.contains("'notificationId': 4001"),
        isTrue,
        reason: 'initialize() must cancel the stale 4001 alarm on upgrade',
      );
    });
  });
}
