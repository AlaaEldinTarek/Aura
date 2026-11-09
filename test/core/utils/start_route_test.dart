import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/utils/start_route.dart';

void main() {
  group('resolveStartRoute', () {
    // (isSignedIn, isGuest, isFirstLaunch) -> route; same table as Splash before F50b.
    const cases = <(bool, bool, bool, String)>[
      (false, false, false, '/login'),
      (false, false, true, '/login'),
      (false, true, false, '/home'),
      (false, true, true, '/onboarding'),
      (true, false, false, '/home'),
      (true, false, true, '/onboarding'),
      (true, true, false, '/home'),
      (true, true, true, '/onboarding'),
    ];
    for (final (signedIn, guest, first, expected) in cases) {
      test('signedIn=$signedIn guest=$guest firstLaunch=$first -> $expected',
          () {
        expect(
          resolveStartRoute(
            isSignedIn: signedIn,
            isGuest: guest,
            isFirstLaunch: first,
          ),
          expected,
        );
      });
    }
  });

  group('resolvePostAuthRoute', () {
    test('first launch -> /onboarding', () {
      expect(resolvePostAuthRoute(isFirstLaunch: true), '/onboarding');
    });
    test('returning user -> /home', () {
      expect(resolvePostAuthRoute(isFirstLaunch: false), '/home');
    });
  });

  group('resolveSplashRoute', () {
    const loadingAuth = AsyncValue<Object?>.loading();
    const loadingBool = AsyncValue<bool>.loading();
    const signedOut = AsyncValue<Object?>.data(null);
    const signedIn = AsyncValue<Object?>.data(Object());
    AsyncValue<bool> b(bool v) => AsyncValue<bool>.data(v);
    final err = AsyncValue<bool>.error(Exception('x'), StackTrace.empty);

    test('auth loading -> null', () {
      expect(
        resolveSplashRoute(
            auth: loadingAuth, guest: b(false), firstLaunch: b(false)),
        isNull,
      );
    });
    test('guest loading -> null', () {
      expect(
        resolveSplashRoute(
            auth: signedOut, guest: loadingBool, firstLaunch: b(false)),
        isNull,
      );
    });
    test('firstLaunch loading -> null', () {
      expect(
        resolveSplashRoute(
            auth: signedOut, guest: b(true), firstLaunch: loadingBool),
        isNull,
      );
    });

    test('auth error -> /login', () {
      expect(
        resolveSplashRoute(
          auth: AsyncValue<Object?>.error(Exception('x'), StackTrace.empty),
          guest: b(true),
          firstLaunch: b(false),
        ),
        '/login',
      );
    });
    test('guest error -> treated as not guest', () {
      expect(
        resolveSplashRoute(auth: signedOut, guest: err, firstLaunch: b(false)),
        '/login',
      );
    });
    test('firstLaunch error -> treated as first launch', () {
      expect(
        resolveSplashRoute(auth: signedIn, guest: b(false), firstLaunch: err),
        '/onboarding',
      );
    });

    test('data: returning guest -> /home', () {
      expect(
        resolveSplashRoute(
            auth: signedOut, guest: b(true), firstLaunch: b(false)),
        '/home',
      );
    });
    test('data: signed in, first launch -> /onboarding', () {
      expect(
        resolveSplashRoute(
            auth: signedIn, guest: b(false), firstLaunch: b(true)),
        '/onboarding',
      );
    });
    test('data: signed in, returning -> /home', () {
      expect(
        resolveSplashRoute(
            auth: signedIn, guest: b(false), firstLaunch: b(false)),
        '/home',
      );
    });
    test('data: signed out, not guest -> /login', () {
      expect(
        resolveSplashRoute(
            auth: signedOut, guest: b(false), firstLaunch: b(false)),
        '/login',
      );
    });
  });
}
