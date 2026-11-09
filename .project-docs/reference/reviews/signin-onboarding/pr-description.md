# Sign-in & onboarding flow: guest mode, returning users, logout, splash loading

Spec: `docs/designs/fix-signin-onboarding.md` (approved 2026-11-09; EGM Stage 9 review, 22 findings applied in
f09ff33 / b819648). Findings fixed: F41a (HIGH), F46a, F47f, F50b. Merge as a whole.

## What changes
- **F41a:** a guest who finishes onboarding stays a guest. Onboarding returns `result: true`; Login clears guest mode
  only when that result is missing (system back still cancels guest).
- **F46a:** returning users (`first_launch` false = onboarding already finished on this device) go straight to Home
  after sign-in, sign-up or "Continue as guest"; onboarding no longer resets language / theme / app mode.
- **F47f:** logout goes to Login with the stack cleared when no user is signed in afterwards (covers Google sign-out
  failing on Windows). Local data is kept (F59, decide later).
- **F50b:** Splash routes only after auth, `is_guest` and `first_launch` have loaded, and navigates once.

## Commits
| # | Commit |
| --- | --- |
| 1 | 20c8b4c Add start-route helpers and use them in Splash |
| 2 | 620a394 Route Splash only after start flags have loaded (F50b) |
| 3 | 7e494f2 Keep guest mode after guest onboarding finishes (F41a) |
| 4 | 7f3889a Send returning users to Home after sign-in (F46a) |
| 5 | 3552c52 Navigate to Login after logout (F47f) |
| 6+ | docs: spec, review, STATE, findings, device checklist, contracts (`first_launch` row, `[AUTH]` tag), READMEs, logs |

No contract renames: prefs keys, routes, Firestore paths, IDs, channels and existing log tags are unchanged. One new
Dart-only log tag `[AUTH]`. No Kotlin, `pubspec.*`, `main.dart` or translation changes.

## Verification
- `flutter test`: 184 pass (+22 new: `test/core/utils/start_route_test.dart`, `test/core/providers/start_flags_test.dart`;
  the provider test failed on the pre-fix code).
- `flutter analyze`: 0 new issues vs 80c603d (issue lists compared in a worktree; 5 base-only errors come from the
  gitignored `google_oauth_config.dart` missing there).
- Release APK built and installed on nova 5T (API 29); Windows release exe run unpackaged.

## Device checks (2026-11-09, branch build 3552c52)
| Check | Device | Result |
| --- | --- | --- |
| S22 guest stays guest after onboarding | nova 5T, temporary Android user | PASS (relaunch → Home) |
| S20 guest → account migration | nova 5T, temporary Android user | Flag set: PASS (`📦 2 local task(s) pending migration`); sync dialog: FAIL (F60, pre-existing); Profile card synced, no duplicates |
| Fresh install | nova 5T, temporary Android user | PASS (onboarding once, relaunch → Home) |
| S36 logout + returning user | nova 5T, owner | PASS (Login, one Back exits, relaunch → Login, sign-in → Home, guest → Home) |
| S23 settings survive re-login | nova 5T, owner | PASS (Arabic / dark / prayer-only kept, no onboarding) |
| S36 Windows | Windows, unpackaged release exe | PASS (Login reached although Google sign-out throws `MissingPluginException`) |

S22, S20 and the fresh-install check ran in a temporary Android user so the owner's data was not cleared. Prayer
alarms stayed armed throughout (verified 08:51 and 09:43). Details: `.project-docs/reference/device-checklist.md`,
`.project-docs/log/2026-11-09.md`.

## Known issues, not caused by this fix
- **F60 (MEDIUM):** the guest-sync dialog never shows. `_checkGuestMigration` reads `guestMigrationProvider` before its
  async `_load()` finishes; the Profile sync card (which watches the provider) works.
- **F61 (LOW):** after switching language in Settings, the bottom nav stays one language behind until the app
  restarts. This branch changes no Settings, nav or shell code.
- **F62 (MEDIUM):** an unreadable (all-zero) SharedPreferences file leaves the Windows app on a white window with no
  recovery. Seen on the unpackaged Windows prefs file during S36; renamed to `.bak` to continue.
- F59 (MEDIUM, privacy, decide later): logout keeps local data.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
