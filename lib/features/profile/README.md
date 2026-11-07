# Profile Feature

## Overview
One screen, `profile_screen.dart`: the Profile tab of the main shell. Signed-out users (including guests) see a
login prompt; signed-in users see a header, prayer and task stat cards, account actions, app-mode switch,
achievement badges, links to Settings / App Tour, version info, the guest-task sync card and Logout. It owns no data;
it reads and writes through auth, preference, task, achievement and prayer-tracking providers/services
([providers](../../core/providers/README.md), [services](../../core/services/README.md)). Cross-folder view:
`.project-docs/modules/auth-sync.md`. Behavior-preserving rule: no UI or logic change without an approved spec.

## Interface
| File | Public symbols / entry points |
| --- | --- |
| `profile_screen.dart` | `ProfileScreen()` (no params, `ConsumerWidget`). Private: `_ProfileStatCard`, `_AppModeTiles`, `_AchievementsBadgeGrid` (+ state), unused `_JumuahReminderTile`, `_showThemeDialog`, `_getThemeModeText`, `_showLanguageDialog` |

- Watches: `authStateProvider` (`authStateChanges`), `themeModeProvider`, `appModeProvider`, `taskStatisticsProvider`,
  `guestMigrationProvider`.
- Navigation out: `/login` (root navigator, `pushReplacementNamed`), `/settings`, `/achievements`.
- App Tour sets `tabNavigationProvider = 0` and `showTutorialProvider = true` (Home runs the tutorial).

## Invariants
- **Auth gate**: `user == null` → login prompt (guests too); loading → shimmer skeleton; error →
  `error_loading_profile`.
- **App mode**: prayer stats hidden in `tasksOnly`, task stats hidden in `prayerOnly` (and when `stats.total == 0`);
  badge grid filters categories the same way as the Achievements screen. `_AppModeTiles` writes
  `appModeProvider.setMode` on tap.
- **Prayer stats** (`_loadProfileStats`, last 30 days): `totalPrayers = completedOnTime + completedLate`;
  completion = `totalPrayers / 150` (30 days × 5, unrecorded = not prayed), shown as `--` when 0; streak from
  `PrayerTrackingService.calculateCurrentStreak`; badge count from `AchievementService.getEarnedCount`. Any error →
  all zeros. The `FutureBuilder` future is created in `build`, so it reloads on every rebuild (findings F47g).
- **Badges**: `_AchievementsBadgeGrid.initState` runs `checkAndAward` then `getEarnedAchievements` (once per
  mount); collapsed view shows a fixed number, "Show all" expands, tap → `/achievements`.
- **Account**: edit name → `user.updateDisplayName`; change password → `updatePassword` if length ≥ 6. Errors are
  shown raw (`'Error: $e'`). Both tiles show for every provider (Google too).
- **App Tour** resets all eight tutorial flags (`setTutorialCompleted(false)`, `setTutorial*Seen(false)`).
- **Version**: Windows shows `AppConstants.desktopVersion` (findings F28); other platforms `PackageInfo`
  `version+buildNumber`.
- **Guest sync card**: shown while `guestMigrationProvider.isPending`; button → `migrate()` then a success snackbar.
- **Logout**: confirm dialog → `authStateNotifierProvider.signOut()`; no navigation — the screen rebuilds into the
  login prompt inside the shell (findings F47f).
- **Numbers** mostly via `NumberFormatter`; exceptions in findings F47. Strings mostly inline EN/AR; `profile`,
  `login*`, `logout*`, `guest_sync_*`, `error_loading_profile` are `.tr()` keys.

## Side Effects
- Firebase Auth: `updateDisplayName`, `updatePassword`, `signOut`.
- Firestore: reads via `PrayerTrackingService` / `AchievementService` / task providers; **writes** achievements via
  `checkAndAward` each time the badge grid mounts; guest task upload via `migrate()`.
- SharedPreferences: tutorial flags (App Tour), `app_mode`, `pending_guest_migration_uid` (cleared by `migrate`).
- Share sheet: `captureAndShare` of a `ShareCard` image (prayer streak).

## Verification
- Run: `flutter test` (no tests for this folder). Device: S20 (guest → account migration), S21 (Arabic).
  Known issues: findings F47.
