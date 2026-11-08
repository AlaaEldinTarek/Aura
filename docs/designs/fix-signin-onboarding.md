# Fix: sign-in & onboarding flow (F41a, F46a, F47f, F50b)

Status: DRAFT (not approved) · Level C · branch `fix/signin-onboarding` · findings `reference/findings.md` F41 (a),
F46 (a), F47 (f), F50 (b)

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
- **Returning user (on this device)** = `is_first_launch == false` (onboarding finished once on this device).
  The flag is device-level, like language/theme (same policy as 5873793). A fresh install signing into an existing
  account still sees onboarding once; its values then match the stored defaults, so nothing is reset.
  VERIFIED (static, 2026-11-08): sign-in pulls no language / theme / mode from Firestore. `_syncUserData`
  (`auth_provider.dart:58–147`) only pushes device theme/language up (returning) or creates the doc (new) and pulls
  wird data (`WirdService.syncFromFirestore`, not an onboarding field). `getUserData` and
  `restorePreferences` have no callers; the only writers of `language` / `theme_mode` / `app_mode` are Settings,
  Profile and onboarding. So onboarding's defaults cannot overwrite pulled values; no preload needed.

## Fix
One pure helper, `lib/core/utils/start_route.dart` (new):
```dart
/// Route after the splash delay.
String resolveStartRoute({required bool isSignedIn, required bool isGuest, required bool isFirstLaunch});
// isGuest || isSignedIn -> isFirstLaunch ? '/onboarding' : '/home'; otherwise '/login'  (same table as today)

/// Route after a successful sign-in / sign-up / "Continue as guest".
String resolvePostAuthRoute({required bool isFirstLaunch}); // isFirstLaunch ? '/onboarding' : '/home'
```

- **F41a.** `PreferenceScreen._finish` leaves with `pushReplacementNamed('/home', result: true)`. Login awaits
  `pushNamed<bool>('/onboarding')` and calls `setGuest(false)` only when the result is not `true` (system back from
  onboarding still cancels guest, as today). If the guest is a returning user (`resolvePostAuthRoute` → `/home`), Login
  goes straight to Home with `pushReplacementNamed('/home')` and does not await.
- **F46a.** Email, Google (login + signup) success use `resolvePostAuthRoute(isFirstLaunch: …)` instead of always
  `/onboarding`. `isFirstLaunch` is read with `await SharedPreferencesService.isFirstLaunch()` at that moment (not the
  provider value). Onboarding itself is unchanged (no preloading of saved values; not needed once returning users skip it).
- **F47f — logout behavior (defined here).**
  1. Confirm dialog (unchanged) → `signOut()`.
  2. On success: `Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/login', (_) => false)`
     (clears the shell; system back from Login exits the app).
  3. Prefs: `is_guest` stays false; `is_first_launch` stays false (so signing in again or choosing guest → Home).
     Language, theme, mode, prayer settings, native alarms and local data are **not** touched; prayer features keep
     working without an account.
  4. On `signOut()` error: stay on Profile, log `❌ [AUTH] signOut failed: $e` (no new UI string).
  5. Same behavior on Android and Windows (shared code; no platform branch).
- **F50b — splash routing with a real loading state.**
  1. Both notifiers start as `AsyncValue.loading()`; `_init` sets `data(...)` (or `error`). `home_screen.dart:294`
     reads `.value ?? false`, so it is unaffected.
  2. `_AuthNavigationHandler` waits until the delay has passed **and** `authState`, `guestModeProvider` and
     `firstLaunchProvider` are all non-loading; then calls `resolveStartRoute`. Error = today's fallback
     (`isGuest` false, `isFirstLaunch` true).
  3. Navigate once: the handler becomes a `ConsumerStatefulWidget` with a `_navigated` flag, so later rebuilds cannot
     schedule a second `pushReplacementNamed` (findings F50 backlog). The splash animation stays on screen while
     loading (no new UI).

No contract changes: prefs keys (`is_guest`, `is_first_launch`, `pending_guest_migration_uid`), route names,
Firestore paths, IDs, channels and log tags are unchanged. No migration: an `is_guest` already reset by F41a stays
false (user taps "Continue as guest" once more).

## Tests (written first)
- `test/core/utils/start_route_test.dart`: full truth table for `resolveStartRoute` (8 cases) and
  `resolvePostAuthRoute` (2 cases). Commit 1 adds the helper with today's behavior; the post-auth "returning →
  /home" case is marked `@Skip('F46a')` until commit 4.
- `test/core/providers/start_flags_test.dart` (`SharedPreferences.setMockInitialValues`): both notifiers report
  `isLoading` before the first read, then `data` with the stored value (`is_guest: true`, `is_first_launch: false`).
  Fails on today's code (initial state is `data`). If `SharedPreferencesService.instance` cannot be built in a test,
  override `sharedPreferencesServiceProvider` in a `ProviderContainer`.
- Test gap (stated, not hidden): the Login → onboarding → Home guest path depends on Firebase, `Permission` and
  `RatingService`; no widget test. F41a evidence = S22 before/after on device.

Commit order (each builds, `flutter test` passes):
1. Add `start_route.dart` + tests (no behavior change); Splash uses `resolveStartRoute`.
2. F50b: loading initial states + splash waits for all three + navigate once.
3. F41a: onboarding `result: true`; Login cancels guest only when result ≠ true.
4. F46a: sign-in / sign-up / guest use `resolvePostAuthRoute`; remove `@Skip`.
5. F47f: logout navigation + error handling.
6. Docs (below).

## File boundary
- Production: `lib/core/utils/start_route.dart` (new), `lib/core/providers/preferences_provider.dart`,
  `lib/features/splash/splash_screen.dart`, `lib/features/auth/login_screen.dart`,
  `lib/features/auth/signup_screen.dart`, `lib/features/onboarding/preference_screen.dart`,
  `lib/features/profile/profile_screen.dart`.
- Tests: the two new test files above.
- Docs: `.project-docs/` (STATE, findings F41a/F46a/F47f/F50b, log, device-checklist S22/S23 expected text + new
  S36), folder READMEs of `lib/core/utils`, `lib/core/providers`, `features/splash`, `features/auth`,
  `features/onboarding`, `features/profile`, `modules/auth-sync`.
- Not touched: Kotlin, `auth_provider.dart` / `auth_service.dart`, `main.dart` routes, translations, `pubspec.*`,
  contracts.

## Verification
- `flutter analyze` (no new issues vs 418), `flutter test` (162 + new pass), `dart format` check on touched files.
- Device (release APK, nova 5T API 29, phone in English unless stated):
  - **S22 before** on the current 1.1.0+60 build: guest → finish onboarding → kill → relaunch → Login = FAIL
    (re-confirms on the current base). **S22 after:** Home appears.
  - **S20 after** (needs S22 PASS): as guest create 2 tasks → sign in → sync prompt appears → tasks in
    `users/{uid}/tasks`, no duplicates.
  - **S23 after** (expected text changes): signed in, set Arabic / dark / prayer-only → logout → sign in → lands on
    **Home** (no onboarding), Arabic / dark / prayer-only kept.
  - **S36 new (logout):** Profile → Logout → confirm → Login screen, back exits app; relaunch → Login; sign in →
    Home; logout → "Continue as guest" → Home.
  - Fresh-install path (regression): clear app data → Login → sign in → onboarding shown once → Home.
  - Windows (optional smoke, shared code): logout → Login; sign in → Home.
- Record results in the log and device-checklist. Do not mark PASS unless the check ran.

## Out of scope
F41b/F41c (raw error text, inline strings), F46b/F46c, onboarding back-button handling (F46 backlog), clearing local
data on logout (F59, decide later), Login staying in the stack under Home after guest onboarding, F47a–e, F50a.
