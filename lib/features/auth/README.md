# Auth Feature

## Overview
The sign-in entry screens: `login_screen.dart` (route `/login`, shown by Splash when there is no user and no guest
flag) and `signup_screen.dart` (route `/signup`, pushed from Login). Both are thin UI over
`authStateNotifierProvider` ([providers](../../core/providers/README.md)); Firebase calls, Firestore user
creation and guest migration live in `AuthStateNotifier._syncUserData` / `AuthService`
([services](../../core/services/README.md)). Cross-folder view: `.project-docs/modules/auth-sync.md`.
Behavior-preserving rule: no UI or logic change without an approved spec.

## Interface
| File | Public symbols / entry points |
| --- | --- |
| `login_screen.dart` | `LoginScreen()` (no params). Private: `_LoginScreenState`, top-level `_isDesktop` (unused) |
| `signup_screen.dart` | `SignupScreen()` (no params). Private: `_SignupScreenState`, top-level `_isDesktopSignup` (unused) |

- Calls on `authStateNotifierProvider.notifier`: `signInWithEmail`, `signUpWithEmail(name:)`, `signInWithGoogle`
  (both screens, all platforms), `sendPasswordResetEmail`. Login also calls `guestModeProvider.notifier.setGuest`.
- Navigation: success → `pushReplacementNamed(_postAuthRoute())`; Login → `/signup` (push); Signup back / "Login" →
  pop; guest → `/home` (returning) or `pushNamed('/onboarding')` (awaited, see Invariants).

## Invariants
- **After any successful sign-in or sign-up** (email or Google): `_postAuthRoute` reads `first_launch` via
  `sharedPreferencesServiceProvider` at that moment → `resolvePostAuthRoute`: first launch on this device →
  `/onboarding`, returning user → `/home` (F46a).
- **Guest flow** (`_continueAsGuest`): `setGuest(true)`; returning guest → `pushReplacementNamed('/home')` (not
  awaited); otherwise await untyped `pushNamed('/onboarding')` (routes are `MaterialPageRoute<dynamic>`, so
  `pushNamed<bool>` would throw) and call `setGuest(false)` only if the result is not `true` (onboarding finishes with
  `result: true`; system back cancels guest) (F41a).
- **Validation** (both forms): email non-empty and contains `@` and `.`; password non-empty and at least
  `AppConstants.minPasswordLength` (also enforced on login); signup also requires a name and matching confirm field.
- **Errors**: every failure shows `e.toString()` in a 3 s floating snackbar (`_showErrorSnackBar`), so text comes from
  `AuthService` exceptions as-is. `_isLoading` disables inputs and buttons during a call.
- **Forgot password**: dialog pre-filled from the email field; sends via `sendPasswordResetEmail`; green snackbar.
- **Localization**: form labels, buttons and validators use `auth_*` / `guest_mode` / `home_welcome` keys; the
  forgot-password dialog body, hint and buttons are inline `isRTL ? '…' : '…'`.
- **Unused code**: `_showDesktopGoogleDialog` and `_step` (English-only "Google Sign-In is not available on Windows"
  reset-password workaround) have no callers; desktop Google sign-in goes through `AuthService.signInWithGoogle`.

## Side Effects
- Firebase Auth sign-in / sign-up / password-reset email, and (inside the notifier) Firestore user doc creation or
  update, Wird sync and the guest → account migration flag.
- SharedPreferences `is_guest` via `guestModeProvider.setGuest` (Login only).

## Verification
- Run: `flutter test` (no tests for this folder). Known issues: findings F41.
