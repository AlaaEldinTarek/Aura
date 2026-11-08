# Fix: sign-in & onboarding flow (F41a, F46a, F47f, F50b)

Status: DRAFT (not approved; Stage 9 review fixes applied) · Level C · branch `fix/signin-onboarding`
· findings `reference/findings.md` F41 (a), F46 (a), F47 (f), F50 (b)

Decision already made (user): **returning users go straight to Home (skip onboarding).**

## Problem
1. **F41a (HIGH, device-verified S22).** `_continueAsGuest` (`login_screen.dart:209–231`) awaits
   `pushNamed('/onboarding')` and calls `setGuest(false)` when that future completes. `PreferenceScreen._finish`
   leaves with `pushReplacementNamed('/home')` (`preference_screen.dart:245`), which completes the same future, so
   `is_guest` goes back to false right after a guest finishes onboarding. Result: (1) next cold start shows Login;
   (2) a later sign-in sees `wasGuest == false` (`auth_provider.dart:63, :130–139`), so
   `pending_guest_migration_uid` is never set and the guest-task sync prompt never shows.
2. **F46a (MEDIUM).** Every sign-in goes to `/onboarding` (`login_screen.dart:51, :71`, `signup_screen.dart:56, :76`).
   Onboarding starts from hard-coded defaults (`preference_screen.dart:27–29`) and saves them on Skip/Continue, so a
   re-login resets language / theme / mode.
3. **F47f.** Logout (`profile_screen.dart:1035–1037`) only calls `signOut()`. Nothing navigates; the shell stays open
   as a signed-out, non-guest user. Next cold start goes to `/login`.
4. **F50b (LOW).** `FirstLaunchNotifier` / `GuestModeNotifier` start as `data(true)` / `data(false)`
   (`preferences_provider.dart:196–199, :225–228`), so Splash's `isLoading` guard (`splash_screen.dart:211`) never
   holds during the first prefs read, and `firstLaunchProvider` is not checked at all. Routing is correct only because
   the 2.5 s delay usually outlasts the read.

## Definitions
- **Returning user (on this device)** = `first_launch == false` (`AppConstants.keyFirstLaunch`, `app_constants.dart:59`;
  onboarding finished once on this device). The flag is device-level, like language/theme (same policy as 5873793).
  A fresh install signing into an existing account still sees onboarding once; its values then match the stored defaults, so nothing is reset.
  VERIFIED (static, 2026-11-08): sign-in pulls no language / theme / mode from Firestore. `_syncUserData`
  (`auth_provider.dart:58–147`) only pushes device theme/language up (returning) or creates the doc (new) and pulls
  wird data (`WirdService.syncFromFirestore`, not an onboarding field). `getUserData` and
  `restorePreferences` have no callers; the only writers of `language` / `theme_mode` / `app_mode` are Settings,
  Profile and onboarding. So onboarding's defaults cannot overwrite pulled values; no preload needed.

## Fix
One pure helper file, `lib/core/utils/start_route.dart` (new):
```dart
/// Route after the splash delay.
String resolveStartRoute({required bool isSignedIn, required bool isGuest, required bool isFirstLaunch});
// isGuest || isSignedIn → isFirstLaunch ? '/onboarding' : '/home'; otherwise '/login'

/// Route after a successful sign-in / sign-up / "Continue as guest".
String resolvePostAuthRoute({required bool isFirstLaunch}); // isFirstLaunch ? '/onboarding' : '/home'

/// Splash decision; null while any input is still loading (F50b).
String? resolveSplashRoute({
  required AsyncValue<User?> auth,
  required AsyncValue<bool> guest,
  required AsyncValue<bool> firstLaunch,
});
// any input loading → null; auth error → '/login';
// guest / firstLaunch error → today's fallback (isGuest false, isFirstLaunch true);
// otherwise → resolveStartRoute(...)
```
`resolveStartRoute` keeps the same table as today.

- **F41a.** `PreferenceScreen._finish` leaves with `pushReplacementNamed('/home', result: true)`. Do not type
  `pushNamed` (`pushNamed<bool>` throws: `_generateRoute` returns untyped `MaterialPageRoute`s under `Route<dynamic>?`,
  `main.dart:415–436`). Final body of `_continueAsGuest`, in order:
  1. `await setGuest(true)`.
  2. Read `first_launch`: `await ref.read(sharedPreferencesServiceProvider).isFirstLaunch()`
     (`isFirstLaunch()` is an instance method; the provider is in `auth_provider.dart`, already imported).
  3. Returning user (`resolvePostAuthRoute(...) == '/home'`) → `Navigator.of(context).pushReplacementNamed('/home')`,
     not awaited.
  4. Otherwise `final result = await Navigator.of(context).pushNamed('/onboarding');` then
     `if (result != true && mounted) setGuest(false)` (system back from onboarding still cancels guest, as today).

  Commit 3 adds `result: true` and step 4's `result != true` check; commit 4 adds steps 2–3.
- **F46a.** The email and Google success handlers on Login and Signup call `resolvePostAuthRoute(isFirstLaunch: …)`
  instead of always going to `/onboarding`. `isFirstLaunch` is read at that moment with
  `await ref.read(sharedPreferencesServiceProvider).isFirstLaunch()` (not the provider value). Onboarding steps and
  defaults are unchanged; its only edit is F41a's `result: true`.
- **F47f — logout behavior.**
  1. Confirm dialog (unchanged) → `await ref.read(authServiceProvider).signOut()` inside `try`.
  2. `AuthService.signOut` runs `Future.wait([firebase, google])` and rethrows if either fails
     (`auth_service.dart:244–252`), so an error does not mean the user is still signed in. After the attempt
     (success or error): `if (!context.mounted) return;` then
     - `ref.read(authServiceProvider).currentUser == null` →
       `Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/login', (_) => false)`
       (clears the shell; system back from Login exits the app);
     - still signed in → stay on Profile; no new UI string.
  3. On error, log `debugPrint('❌ [AUTH] signOut failed: $e')` in both cases.
  4. Prefs: `is_guest` stays false; `first_launch` stays false (so signing in again or choosing guest → Home).
     Language, theme, mode, prayer settings, native alarms and local data are **not** touched. Prayer features must keep
     working signed out (S36 checks next prayer + alarm).
  5. No platform branch is added; the behavior is verified on both Android and Windows (the Google half may fail on
     Windows; UNVERIFIED).
- **F50b — splash routing with a real loading state.**
  1. Both notifiers start as `AsyncValue.loading()`; `_init` sets `data(...)` (or `error`). `home_screen.dart:294`
     reads `.value ?? false`, so it is unaffected.
  2. `_AuthNavigationHandler` waits until the delay has passed **and** `resolveSplashRoute(...)` returns non-null, then
     navigates to that route.
  3. Navigate once: the handler becomes a `ConsumerStatefulWidget` with a `_navigated` flag, set synchronously in
     `build` before `addPostFrameCallback`, so later rebuilds cannot schedule a second `pushReplacementNamed`
     (findings F50 backlog).
  4. While waiting, the logo and text stay on screen; the spinner hides once the delay has passed, as today
     (`_isNavigating`). No new UI.

Contracts: no existing key, route, Firestore path, ID, channel or log tag is renamed or removed. Doc-only additions:
the missing `first_launch` row in `contracts/prefs-keys.md` (key already exists in code), and one new Dart-only tag
`[AUTH]` in `contracts/log-tags.md`. No migration: an `is_guest` already reset by F41a stays false (user taps "Continue
as guest" once more).

## Tests (written first)
- `test/core/utils/start_route_test.dart`:
  - `resolveStartRoute`: full truth table (8 cases).
  - `resolvePostAuthRoute`: 2 cases.
  - `resolveSplashRoute`: loading × 3 (each input loading → null), error × 3 (auth → `/login`; guest / firstLaunch →
    fallback), data table.

  Commit 1 ships the final helpers. `resolvePostAuthRoute` and `resolveSplashRoute` have no callers until commits 4
  and 2, so there is no behavior change and no test is skipped.
- `test/core/providers/start_flags_test.dart`:
  - `setUpAll`: `SharedPreferences.setMockInitialValues({'is_guest': true, 'first_launch': false})`, then
    `await SharedPreferencesService.getInstance()`. One value set per file (the instance is cached statically).
  - Each test: new `ProviderContainer`; read the notifier and assert `isLoading` synchronously; then
    `await Future<void>.delayed(Duration.zero)` and assert `data` with the stored value.
  - Fails on today's code (initial state is `data`).
- Test gaps: the Login → onboarding → Home guest path (Firebase, `Permission`, `RatingService`), Splash's
  navigate-once, and F47f navigation have no widget test. Evidence: device-checklist scenarios S22 (F41a) and S36
  (navigate-once, logout) before/after on device.

Commit order (each builds, `flutter test` passes):
1. Add `start_route.dart` (all three helpers) + tests (no behavior change); Splash uses `resolveStartRoute`.
2. F50b: loading initial states + splash uses `resolveSplashRoute` + navigate once.
3. F41a: onboarding `result: true`; Login cancels guest only if `result != true` (`_continueAsGuest` step 4).
4. F46a: sign-in / sign-up use `resolvePostAuthRoute`; `_continueAsGuest` steps 2–3 (returning guest → Home).
5. F47f: logout navigation + error handling.
6. Docs (below).

## File boundary
- Production:
  - New: `lib/core/utils/start_route.dart`.
  - Modify: `lib/core/providers/preferences_provider.dart`, `lib/features/splash/splash_screen.dart`,
    `lib/features/auth/login_screen.dart`, `lib/features/auth/signup_screen.dart`,
    `lib/features/onboarding/preference_screen.dart`, `lib/features/profile/profile_screen.dart`.
- Tests (new): `test/core/utils/start_route_test.dart`, `test/core/providers/start_flags_test.dart`.
- Docs (modify):
  - `.project-docs/STATE.md`
  - `.project-docs/reference/findings.md` (F41a, F46a, F47f, F50b)
  - `.project-docs/log/<date of the work>.md`
  - `.project-docs/reference/device-checklist.md` (S22 / S23 expected text, new S36)
  - `.project-docs/contracts/prefs-keys.md` (`first_launch` row)
  - `.project-docs/contracts/log-tags.md` (`[AUTH]`)
  - `.project-docs/modules/auth-sync.md`
  - `lib/core/utils/README.md`, `lib/core/providers/README.md`, `lib/features/splash/README.md`,
    `lib/features/auth/README.md`, `lib/features/onboarding/README.md`, `lib/features/profile/README.md`
- Not touched: Kotlin, `auth_provider.dart` / `auth_service.dart`, `main.dart` routes, translations, `pubspec.*`.
  Contracts get only the two doc additions above.

## Verification
- On main @ 80c603d: `flutter analyze` (no new issues vs 418), `flutter test` (162 + new pass), `dart format` check
  on touched files.
- Device (release APK, nova 5T API 29, phone in English unless stated). Scenarios are in
  `reference/device-checklist.md`:
  - **Device-checklist scenario S22 before** on the 1.1.0+60 build: guest → finish onboarding → kill → relaunch →
    Login = FAIL. **S22 after:** Home appears.
  - **S20 after** (needs S22 PASS): as guest create 2 tasks → sign in → sync prompt appears → tasks in
    `users/{uid}/tasks`, no duplicates.
  - **S23 after** (expected text changes): signed in, set Arabic / dark / prayer-only → logout → sign in → lands on
    **Home** (no onboarding), Arabic / dark / prayer-only kept.
  - **S36 new (logout):** Profile → Logout → confirm → Login screen, back exits app; next prayer + alarm still work
    signed out; relaunch → Login (splash navigates once); sign in → Home; logout → "Continue as guest" → Home.
  - Fresh-install path (regression): clear app data → Login → sign in → onboarding shown once → Home.
  - **Windows (required):** logout → Login (also if Google sign-out fails); sign in → Home.
- Record results in the log and device-checklist. Do not mark PASS unless the check ran.

## Out of scope
- F41b: raw exception text in snackbars. F41c: inline EN/AR strings in the forgot-password dialog.
- F46b: inline EN/AR strings in the wizard. F46c: dead code (`ModeSelectionScreen`).
- Onboarding back-button handling (F46 backlog).
- F59: clearing local data on logout (decide later).
- Login staying in the stack under Home after guest onboarding (separate navigation cleanup).
- F47a: edited display name may not refresh. F47b: raw numbers in Arabic UI. F47c: raw error text. F47d: inline
  EN/AR strings. F47e: dead code.
- F50a: unused permission helper in Splash.
