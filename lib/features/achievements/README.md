# Achievements Feature

## Overview
One read-only screen, `achievements_screen.dart`, that lists every badge in `AchievementDefinitions.all`, grouped
by `AchievementCategory`, earned or locked. Opened from Profile via the `/achievements` route (`lib/main.dart`; the
desktop shell builds it in `main_wrapper_screen.dart`). Awarding happens elsewhere
(`AchievementService.checkAndAward`, see [services](../../core/services/README.md)); this screen only reads.
Behavior-preserving rule: no UI or logic change without an approved spec.

## Interface
| File | Public symbols / entry points |
| --- | --- |
| `achievements_screen.dart` | `AchievementsScreen()` (no params). Private: `_AchievementsScreenState`, `_AchievementBadge` |

- Reads: `AchievementService.instance.getEarnedAchievements(userId: getCurrentUserId())`, `AchievementDefinitions.all`.
- Watches: `appModeProvider`.

## Invariants
- **Guests see nothing earned**: `getEarnedAchievements` returns `[]` for `'guest_user'` (achievements are cloud-only).
- **App mode filter**: `tasksOnly` → only `AchievementCategory.tasks`; `prayerOnly` → every category except `tasks`;
  otherwise all. The header counts (`earnedCount` / `visibleTotal`) use the same filter.
- **Grouping**: one collapsible section per `AchievementCategory.values` entry (order of the enum); empty or hidden
  categories render nothing. Collapse state (`_collapsedCategories`) is in memory only; all start expanded.
- **Earned** = the badge id is in the earned list's ids. Unknown Firestore ids become an "Unknown" `special` badge in
  `Achievement.earnedFromFirestore` (counted in `earnedCount`, never shown as a badge).
- **Numbers**: every count goes through `NumberFormatter` (`withArabicNumerals` / `withArabicNumeralsByLanguage`).
- **Localization**: all strings are inline `isArabic ? '…' : '…'` (title, header, category names); no `.tr()` keys.
- **Layout**: badge width = (screen width − padding) / 3, from `MediaQuery` size, not the parent width.
- **Errors**: a failed load just stops the spinner; the screen then shows 0 earned. Pull-to-refresh reloads.

## Side Effects
- One Firestore read of `users/{uid}/achievements` per load (through `AchievementService`); no writes, no prefs.

## Verification
- Run: `flutter test` (no tests for this folder). Known issues: findings F40.
