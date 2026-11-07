# Splash Feature

## Overview
One screen, `splash_screen.dart`: the app's initial route `/` and also the `default` case of `_generateRoute` in
`main.dart` (any unknown route name lands here and re-runs start-up routing). It plays the logo animation, waits a
fixed delay, then replaces itself with `/onboarding`, `/home` or `/login` based on auth, guest and first-launch state
from [providers](../../core/providers/README.md). Behavior-preserving rule: no UI or routing change without an
approved spec.

## Interface
| File | Public symbols / entry points |
| --- | --- |
| `splash_screen.dart` | `SplashScreen()` (no params). Private: `_SplashScreenState` (animation + timer), `_AuthNavigationHandler` (routing widget in the `Stack`), `_requestNotificationPermission` (no caller — findings F50a) |

- Watches `authStateProvider` ([providers](../../core/providers/README.md)), `firstLaunchProvider` and
  `guestModeProvider` (`preferences_provider.dart`). Reads `AppConstants.splashDuration` (2500 ms).
- Asset: `assets/animations/splash_logo.json` (Lottie; `assets/animations/` is declared in `pubspec.yaml`).

## Invariants
- **Routing table** (after the delay, once `authState` and `guestMode` are not loading), via `pushReplacementNamed`:
  | `is_guest` | Firebase user | first launch | Destination |
  | --- | --- | --- | --- |
  | true | any | true / false | `/onboarding` / `/home` |
  | false | signed in | true / false | `/onboarding` / `/home` |
  | false | none | any | `/login` |
  Guest wins over a signed-in user. A missing first-launch value counts as `true`, a missing guest value as `false`.
- **Timing**: navigation waits only for `splashDuration`, not for the animation. The Lottie controller is set to
  1.5× the composition length and plays once (`repeat: false`). The spinner hides when navigation starts.
- **Loading guard**: the guest and first-launch notifiers start as `data(false)` / `data(true)`, not `loading`, and
  `firstLaunchProvider` is not checked at all; correct routing relies on their prefs reads finishing within the delay
  (findings F50b).
- **Permission**: notification permission is NOT requested here (requested after onboarding, per the `initState`
  comment).
- **Localization**: tagline is `'app_tagline'.tr()`; the brand text `Aura | هالة` is fixed in both languages.
- **Desktop**: logo is 10% of screen width (25% on mobile); otherwise identical.

## Side Effects
- Navigation only (`pushReplacementNamed`). No prefs or Firestore writes, no channel calls.

## Verification
- Run: `flutter test` (no tests for this folder). Device: S22 (guest relaunch → this routing table). Known issues:
  findings F50.
