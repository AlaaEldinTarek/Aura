import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/services/desktop_tray_service.dart';

/// The tray plugin reports ONE menu click twice, in the same synchronous run
/// (item `onClick`, then `onTrayMenuItemClick`). The guard must let the first
/// call through, block the second, and let the NEXT click (a later event-loop
/// turn) through again.
void main() {
  group('SameTurnGuard', () {
    test('a second call in the same turn is blocked', () {
      final guard = SameTurnGuard();
      var runs = 0;
      void action() {
        if (!guard.tryAcquire('test_notif')) return;
        runs++;
      }

      action();
      action();

      expect(runs, 1);
    });

    test('the next click, in a later turn, runs again', () async {
      final guard = SameTurnGuard();
      var runs = 0;
      void action() {
        if (!guard.tryAcquire('test_notif')) return;
        runs++;
      }

      action();
      action();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      action();
      action();

      expect(runs, 2);
    });

    test('different keys do not block each other', () {
      final guard = SameTurnGuard();
      expect(guard.tryAcquire('test_notif'), isTrue);
      expect(guard.tryAcquire('stop_adhan'), isTrue);
      expect(guard.tryAcquire('test_notif'), isFalse);
      expect(guard.tryAcquire('stop_adhan'), isFalse);
    });
  });
}
