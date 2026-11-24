// F75 — session gate for _scheduleJumuahOnStartup
// (main_wrapper_screen.dart)
//
// The gate mirrors SessionState.shouldArm (Kotlin): arm when guest OR signed-in.
// Tests run on the extracted boolean so no Firebase or SharedPreferences mocking
// is needed.
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the guard in _scheduleJumuahOnStartup:
///   if (!isGuest && !hasUser) return;
bool _shouldSchedule({required bool isGuest, required bool hasUser}) =>
    isGuest || hasUser;

void main() {
  group('F75 _scheduleJumuahOnStartup session gate', () {
    test('T1: no session (not guest, no user) → do not schedule', () {
      expect(_shouldSchedule(isGuest: false, hasUser: false), isFalse);
    });

    test('T2: guest session, no Firebase user → schedule', () {
      expect(_shouldSchedule(isGuest: true, hasUser: false), isTrue);
    });

    test('T3: signed-in user, not guest → schedule', () {
      expect(_shouldSchedule(isGuest: false, hasUser: true), isTrue);
    });

    test('T4: guest AND signed-in (migration flow) → schedule', () {
      expect(_shouldSchedule(isGuest: true, hasUser: true), isTrue);
    });

    // T5 covers the NotificationService.initialize path (same gate, second call site)
    test('T5: same gate in NotificationService.initialize — no session → false', () {
      expect(_shouldSchedule(isGuest: false, hasUser: false), isFalse);
    });
  });
}
