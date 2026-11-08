# Auth & sync
Verified against code 2026-11-07 (reference/2026-11-07_DRIFT_REPORT.md). Collections: contracts/firestore-paths.md.

## Key files
- `lib/core/providers/auth_provider.dart` — `authStateNotifierProvider` (sign-in/up/out, `_syncUserData`),
  `sharedPreferencesServiceProvider`; `guest_migration_provider.dart`
- `lib/core/services/auth_service` (+ `google_oauth_config.dart`), `firestore_service`, `offline_queue_service`,
  `sync_service`, `connectivity` provider
- Screens: `lib/features/auth/` (`/login`, `/signup`); next step after auth is `resolvePostAuthRoute`
  (`lib/core/utils/start_route.dart`): `/onboarding` on the first launch on this device, else `/home` (`first_launch`)

## Start-up routing & logout (spec fix-signin-onboarding, 2026-11-09)
- Splash: `resolveSplashRoute` waits for auth, `is_guest` and `first_launch` to load (both flag notifiers start as
  `loading`), then routes once: guest or signed in → `/onboarding` if first launch else `/home`; otherwise `/login`.
- Guest: "Continue as guest" sets `is_guest`, then returning guest → `/home`; first launch → onboarding, which returns
  `result: true` on finish so Login keeps guest mode (back from onboarding cancels guest).
- Logout (Profile): `AuthService.signOut` (Firebase + Google; throws if either fails, logged `❌ [AUTH]`); if no user is
  signed in afterwards → `/login` with the stack cleared. Prefs, settings and local data are kept (F59).

## Auth
- Email/Password, guest mode. Google: `google_sign_in` on mobile; desktop uses a loopback PKCE flow
  (`_signInWithGoogleDesktop`; no timeout / no `state`, F20 backlog).
- Offline queue: `OfflineQueueService.enqueue` has no caller; only init + pending count are used (F16).

## State sync pattern
- On login: device → Firestore for language/theme (device-level prefs win; pulling them down made re-logins silently
  reset the user's language). On change: SharedPreferences → Firestore.
- Login pulls only wird (`_syncUserData`). Tasks are a live stream keyed by `currentUserIdProvider`; prayer statuses
  come from the Firestore listener (Android) or desktop timer (prayer-tracking.md § Live sync).
- Guest → account: theme / language / wird are pushed only when the Firestore user doc does not exist yet; signing into
  an existing account pulls cloud wird over local. Guest tasks migrate only after a prompt
  (`pending_guest_migration_uid` → `guestMigrationProvider.migrate()`).

## Related
- Android app data backup is disabled (stale auth token caused random logout) — commit d3bfd01 (from git log).
- Task cross-device sync on resume: tasks.md.
