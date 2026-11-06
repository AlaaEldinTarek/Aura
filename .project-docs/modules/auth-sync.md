# Auth & sync
Relocated from CLAUDE.md on 2026-11-06; not yet re-verified (Step 2). Collections: contracts/firestore-paths.md.

## Key files
- `lib/core/providers/auth_provider.dart` — `authStateNotifierProvider`: auth state, sign-in/up/out, Firestore user sync
- `lib/core/services/auth_service`, `firestore_service`, `offline_queue_service`, `sync_service`, `connectivity` provider
- Screens: `lib/features/auth/` (`/login`, `/signup`)

## Auth
- Email/Password, Google (`google_sign_in`), guest mode, offline queue.

## State sync pattern
- Firestore ↔ SharedPreferences bidirectional sync for logged-in users.
- On login: device → Firestore for language/theme (device-level prefs win; pulling them down made re-logins silently
  reset the user's language). On change: SharedPreferences → Firestore.
- Data (tasks, prayer records, wird) still pulls from Firestore on login.
- Guest mode: SharedPreferences-only; migrated to Firestore on signup.

## Related
- Android app data backup is disabled (stale auth token caused random logout) — commit d3bfd01 (from git log, not old CLAUDE.md).
- Task cross-device sync on resume: tasks.md.
