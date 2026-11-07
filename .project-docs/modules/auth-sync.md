# Auth & sync
Verified against code 2026-11-07 (reference/2026-11-07_DRIFT_REPORT.md). Collections: contracts/firestore-paths.md.

## Key files
- `lib/core/providers/auth_provider.dart` — `authStateNotifierProvider` (sign-in/up/out, `_syncUserData`),
  `sharedPreferencesServiceProvider`; `guest_migration_provider.dart`
- `lib/core/services/auth_service` (+ `google_oauth_config.dart`), `firestore_service`, `offline_queue_service`,
  `sync_service`, `connectivity` provider
- Screens: `lib/features/auth/` (`/login`, `/signup`); next step after auth is `/onboarding`

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
