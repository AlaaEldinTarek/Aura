# Fix: guest-sync dialog never shows (F60)

Status: APPROVED (user 2026-11-09, "approve phase F60, with the account check") · Level C · branch `fix/f60-guest-sync` · finding `reference/findings.md` F60 · no EGM review

## Problem
After a guest with local tasks signs in, `_syncUserData` sets `pending_guest_migration_uid` (`auth_provider.dart:133–139`).
The shell should then offer to sync: `_checkGuestMigration` (`main_wrapper_screen.dart:240, :542–577`) runs 1 s after
the shell starts and shows the dialog if `guestMigrationProvider` is pending. It never shows (device VERIFIED, S20,
nova 5T, 2026-11-09: flag logged, no dialog after sign-in or after a relaunch; the Profile sync card works). Two causes
in code (static):
1. **Cold start race.** The dialog check is the first reader of the provider, so `GuestMigrationNotifier` is created
   right then; its async `_load()` (`guest_migration_provider.dart:33–47`) has not finished, `isPending` is still false,
   and nothing checks again.
2. **Stale state after sign-in.** If the provider already exists from the guest session (created when the flag was not
   set yet; the provider is not autoDispose), it never re-reads prefs, so the new shell after sign-in sees "not pending".

The Profile card works because it `ref.watch`es the provider and redraws when `_load()` completes.

## Fix
- `GuestMigrationNotifier`:
  - Add `Future<void> refresh()`: re-reads the flag and the local task count (same rules as today's `_load()`: no flag →
    not pending; count 0 → clear the flag, not pending; otherwise pending with uid and count). It keeps
    `dialogShownThisSession` from the current state. The constructor calls `refresh()` instead of `_load()`.
  - Constructor takes an optional `Future<int> Function()? localTaskCount` (default
    `TaskService.instance.getLocalTaskCount`) and an optional `String? Function()? currentUid` (default
    `FirebaseAuth.instance.currentUser?.uid`), so tests do not need Firebase. The provider still builds it with no
    arguments.
  - **Account check (user decision):** `refresh()` reports pending only when a user is signed in and their uid equals
    `pending_guest_migration_uid`. Not signed in, or a different uid → not pending, and the flag and the local tasks
    are left unchanged (no clear, no upload). The count-0 rule (clear the flag) applies only when the uid matches.
  - `migrate()` also returns without uploading unless the signed-in uid equals `state.uid`.
- `_checkGuestMigration`: `await ref.read(guestMigrationProvider.notifier).refresh();` then `if (!mounted) return;`,
  then read the state and decide as today. The 1 s delay, the once-per-session rule, the dialog text, buttons and
  `migrate()` stay unchanged.
- Profile sync card (`profile_screen.dart:323–380`): it shows while `isPending`, so the account check in `refresh()`
  applies to it too. Every route into the shell (sign-in, sign-up, guest, cold start) builds a new shell, whose
  `_checkGuestMigration` refreshes the state, so the card never shows stale "pending" for another account. No code
  change in `profile_screen.dart` is expected; it is in the file boundary in case the card needs an explicit guard.

Why the account check: today a user who taps "Later", logs out and continues as a guest keeps the old uid in the flag,
and "Sync now" would upload the guest's tasks to the previous account.

## Tests (written first; new `test/core/providers/guest_migration_test.dart`)
Unit tests with `SharedPreferences.setMockInitialValues`, a fake `localTaskCount` and a fake `currentUid`; one
`setUp` per case:
- Matching uid: flag `u1`, signed in as `u1`, count 2: after `await refresh()`, state is pending, uid `u1`,
  `taskCount == 2`.
- Different uid: flag `u1`, signed in as `u2`, count 2: not pending; the flag is still `u1`; `migrate()` does not call
  the upload.
- Not signed in: flag `u1`, `currentUid` null: not pending; the flag is kept.
- Stale-after-sign-in: notifier created with no flag (not pending); then the flag is written to prefs; after
  `await refresh()`, state is pending. (Fails on today's code: no `refresh`, state stays not pending.)
- Count 0: after `refresh()`, not pending and the flag is removed from prefs (today's rule).
- `markDialogShown()` then `refresh()`: `dialogShownThisSession` stays true.
- No flag: not pending.
Test gap: the dialog itself (`_checkGuestMigration` in the shell) has no widget test; evidence is device-checklist
scenario S20 after the fix.

## File boundary
- Production: `lib/core/providers/guest_migration_provider.dart`, `lib/features/main/main_wrapper_screen.dart`
  (`_checkGuestMigration` only), `lib/features/profile/profile_screen.dart` (sync card; change only if needed).
- Test (new): `test/core/providers/guest_migration_test.dart`.
- Docs: `.project-docs/reference/findings.md` (F60), `.project-docs/reference/device-checklist.md` (S20),
  `.project-docs/STATE.md`, `.project-docs/log/<date>.md`, `lib/core/providers/README.md`,
  `lib/features/main/README.md`.
- Not touched: `auth_provider.dart`, `task_service.dart`, translations, prefs keys, Kotlin.

## Verification
- `flutter test` (all pass, new tests included), `flutter analyze` (0 new issues on changed lines), `dart format` on
  the new test file.
- Device (nova 5T, release APK; owner data kept by using a temporary Android user as on 2026-11-09):
  - **S20 after:** guest → create 2 tasks → sign in → dialog "sync 2 tasks" appears within ~1 s on Home → "Sync now" →
    success snackbar → each task once. Log: `Migrating 2 guest tasks → Firestore`.
  - **Later + relaunch:** repeat with "Later" → dialog does not show again in the same session → relaunch → dialog
    shows again; Profile card still shows until synced.
  - **Mismatch:** guest tasks → sign in with a **different** account than the one in the flag (e.g. flag from account A
    after "Later", log out, continue as guest, sign in with account B) → no dialog, no Profile card; local tasks kept.
- Record results in the device checklist and log. Do not mark PASS unless the check ran.

## Commits
1. Tests + `refresh()` and the injectable count in `GuestMigrationNotifier` (constructor uses `refresh()`; no caller
   change yet).
2. `_checkGuestMigration` awaits `refresh()` before deciding.
3. Docs.
