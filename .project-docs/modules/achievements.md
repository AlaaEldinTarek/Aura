# Achievements
Verified against code 2026-11-07 (reference/2026-11-07_DRIFT_REPORT.md). (Added beyond the bootstrap module list:
achievements span tasks, prayer, Quran and had no single home.)

## Key files
- `lib/features/achievements/` (`AchievementsScreen`, route `/achievements`), `lib/core/services/achievement_service`,
  `lib/core/models/achievement` (`AchievementDefinitions.all`, `AchievementCategory`)
- Profile grid: `_AchievementsBadgeGrid` in `lib/features/profile/`

## Award & unlock flow
- `checkAndAward(userId)` is called from `prayer_tracking_service`, `task_service` and the profile grid (not from wird
  code, F52h). Guests (`guest_user`) never earn achievements. Awards stored at `users/{uid}/achievements/{id}`.
- `AchievementService._award()` emits to the `newAchievements` stream → `MainWrapperScreen` listener:
  phone — `_showAchievementToast()` when the app is `resumed`, otherwise `NotificationService.instance
  .showAchievementNotification()`; desktop — toast + `DesktopNotificationService.showAchievementNotification` (no-op).
- Notification channel `achievement_unlocked`, ID `7100 + (id.hashCode.abs() % 1000)` (range: contracts/notification-ids.md, F4).

## Mode filtering
- `AchievementsScreen` and `_AchievementsBadgeGrid` both filter by `appModeProvider`: `tasksOnly` → only
  `AchievementCategory.tasks`; `prayerOnly` → all except `tasks`; `both` → all.
- `AchievementsScreen` computes `visibleCategories` as a `Set` and reuses it for earned count, per-category filter and
  totals; the profile grid filters per achievement.

## Achievements screen
- Each category section has a tappable header (name + earned/total + rotating chevron). Collapsed state in
  `Set<AchievementCategory> _collapsedCategories` on `_AchievementsScreenState`; grid animates with `AnimatedSize`.

## Profile grid
- `_AchievementsBadgeGrid` takes an `appMode` parameter and filters `AchievementDefinitions.all` by mode.
- Shows 2 rows collapsed: `LayoutBuilder` computes `perRow`, then `all.take(perRow * 2)`. "Show all / Show less"
  toggle with `AnimatedSize`. Footer bar always navigates to `/achievements`.

## Wird achievements
- wird.md § Achievements (7).
