import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Start-up routing rules (Splash, sign-in, sign-up, "Continue as guest").
///
/// A returning user is one who finished onboarding on this device
/// (`first_launch` == false); they skip onboarding.

/// Route after the splash delay.
String resolveStartRoute({
  required bool isSignedIn,
  required bool isGuest,
  required bool isFirstLaunch,
}) {
  if (isGuest || isSignedIn) {
    return isFirstLaunch ? '/onboarding' : '/home';
  }
  return '/login';
}

/// Route after a successful sign-in / sign-up / "Continue as guest".
String resolvePostAuthRoute({required bool isFirstLaunch}) {
  return isFirstLaunch ? '/onboarding' : '/home';
}

/// Splash decision; null while any input is still loading.
///
/// `auth` holds the signed-in user (any non-null value means signed in).
/// An auth error routes to `/login`; a guest / first-launch error falls back
/// to `isGuest` false and `isFirstLaunch` true.
String? resolveSplashRoute({
  required AsyncValue<Object?> auth,
  required AsyncValue<bool> guest,
  required AsyncValue<bool> firstLaunch,
}) {
  if (auth.isLoading || guest.isLoading || firstLaunch.isLoading) return null;
  if (auth.hasError) return '/login';

  final isGuest = guest.hasError ? false : (guest.valueOrNull ?? false);
  final isFirstLaunch =
      firstLaunch.hasError ? true : (firstLaunch.valueOrNull ?? true);

  return resolveStartRoute(
    isSignedIn: auth.valueOrNull != null,
    isGuest: isGuest,
    isFirstLaunch: isFirstLaunch,
  );
}
