# Achievements
Relocated from CLAUDE.md on 2026-11-06; not yet re-verified (Step 2). (Added beyond the bootstrap module list:
achievements span tasks, prayer, Quran and had no single home.)

## Key files
- `lib/features/achievements/` (`AchievementsScreen`, route `/achievements`), `lib/core/services/achievement_service`,
  `lib/core/models/achievement` (`AchievementDefinitions.all`, `AchievementCategory`)
- Profile grid: `_AchievementsBadgeGrid` in `lib/features/profile/`

## Unlock flow
- `AchievementService._award()` emits to the `newAchievements` stream → `MainWrapperScreen` listener calls
  `_showAchievementToast()` (in-app overlay) and `NotificationService.instance.showAchievementNotification()` (system).
- Notification channel `achievement_unlocked`, hash-based IDs per achievement ID (range: contracts/notification-ids.md).

## Mode filtering
- `AchievementsScreen` and `_AchievementsBadgeGrid` both filter by `appModeProvider`: `tasksOnly` → only
  `AchievementCategory.tasks`; `prayerOnly` → all except `tasks`; `both` → all.
- Always compute `visibleCategories` as a `Set` and reuse it for earned count, per-category filter, and totals.

## Achievements screen
- Each category section has a tappable header (name + earned/total + rotating chevron). Collapsed state in
  `Set<AchievementCategory> _collapsedCategories` on `_AchievementsScreenState`; grid animates with `AnimatedSize`.

## Profile grid
- `_AchievementsBadgeGrid` takes an `appMode` parameter and filters `AchievementDefinitions.all` by mode.
- Shows 2 rows collapsed: `LayoutBuilder` computes `perRow`, then `all.take(perRow * 2)`. "Show all / Show less"
  toggle with `AnimatedSize`. Footer bar always navigates to `/achievements`.

## Wird achievements
- wird.md § Achievements.
