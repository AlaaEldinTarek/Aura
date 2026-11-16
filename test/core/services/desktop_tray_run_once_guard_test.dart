import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/services/desktop_tray_service.dart';

/// The tray plugin calls the Quit handler twice per click (item `onClick`
/// and `onTrayMenuItemClick`). The guard must let the action run only once.
/// Spec: docs/designs/tray-quit-fix.md (Decision, step 1).
void main() {
  group('RunOnceGuard', () {
    test('first call is let through', () {
      final guard = RunOnceGuard();
      expect(guard.tryAcquire(), isTrue);
    });

    test('a second call does not run the action again', () {
      final guard = RunOnceGuard();
      var runs = 0;
      void guardedAction() {
        if (!guard.tryAcquire()) return;
        runs++;
      }

      guardedAction();
      guardedAction();
      guardedAction();

      expect(runs, 1);
    });

    test('guards are independent of each other', () {
      final a = RunOnceGuard();
      final b = RunOnceGuard();
      expect(a.tryAcquire(), isTrue);
      expect(b.tryAcquire(), isTrue);
      expect(a.tryAcquire(), isFalse);
    });
  });
}
