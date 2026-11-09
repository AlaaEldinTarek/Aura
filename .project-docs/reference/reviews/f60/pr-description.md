# F60: show the guest-sync offer after sign-in (with account check)

Spec: `docs/designs/fix-f60-guest-sync-dialog.md` (approved 2026-11-09, with the account check). Finding fixed: F60.

## What changes
- The "sync N guest tasks" dialog never showed: the shell read `guestMigrationProvider` before its async load finished
  (cold start), or from a provider created before the sign-in that never re-read the flag.
- `GuestMigrationNotifier.refresh()` re-reads `pending_guest_migration_uid` and the local task count; the shell's
  `_checkGuestMigration` awaits it before deciding. Delay, once-per-session rule, dialog text and buttons unchanged.
- **Account check (user decision):** the offer (dialog and Profile card) is shown only when the signed-in uid equals the
  flag uid. Not signed in or a different account → no offer; the flag and local tasks stay as they are. `migrate()`
  uploads only for the matching account.

## Commits
| # | Commit |
| --- | --- |
| 1 | b0dd34c Add F60 guest-sync dialog spec |
| 2 | 6931c81 Add refresh and account check to guest migration state (F60) |
| 3 | c5c2c70 Refresh guest migration state before the sync dialog (F60) |
| 4 | a6bd997 docs: document F60 fix and device results |

No prefs key, route, Firestore path, translation or Kotlin changes. `profile_screen.dart` unchanged (the card uses
`isPending`, which now includes the account check).

## Verification
- `flutter test`: 192 pass (+8 new in `test/core/providers/guest_migration_test.dart`; they did not compile against the
  old notifier). Cases: matching uid, different uid (no offer, flag kept, no upload), not signed in, flag written after
  creation, count 0, shown-flag kept across refresh, no flag, migrate once.
- `flutter analyze`: no issues on changed lines.

## Device check (2026-11-09, nova 5T, release build c5c2c70)
| Check | Result |
| --- | --- |
| S20: guest → 2 tasks → sign in → dialog → Sync now | PASS (dialog shown; `Migrating 2 guest tasks → Firestore` 10:52:47; each task once) |
| "Later" → relaunch → dialog again | Not run (user skipped) |
| Different account → no offer | Not run on device (no second account); covered by unit tests |

🤖 Generated with [Claude Code](https://claude.com/claude-code)
