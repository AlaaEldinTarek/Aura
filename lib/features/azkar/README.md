# Azkar Feature

## Overview
One screen, `azkar_screen.dart` (route `/azkar`, opened from the Prayer screen toolkit; the desktop shell builds it in
`main_wrapper_screen.dart`). It is a daily morning/evening checklist over the fixed `AzkarData` lists
([models](../../core/models/README.md)). State, streak and persistence live in `azkarProvider`
([providers](../../core/providers/README.md)); this screen only displays it and toggles items.
Behavior-preserving rule: no UI or logic change without an approved spec.

## Interface
| File | Public symbols / entry points |
| --- | --- |
| `azkar_screen.dart` | `AzkarScreen()` (no params). Private: `_AzkarScreenState` (2-tab `TabController`), `_AzkarTabView`, `_ProgressHeader`, `_ZikrCard` |

- Watches `azkarProvider` (`doneCount`, `isItemDone`, `isMorningComplete` / `isEveningComplete`, `streakCount`).
- Writes only `azkarProvider.notifier.toggleItem(id, category)` (one tap = toggle, with `HapticFeedback.light()`).

## Invariants
- **Tabs**: index 0 = `AzkarCategory.morning`, 1 = `evening`; always opens on Morning (no time-of-day selection).
- **Items** come from `AzkarData.forCategory(category)`; a tab is complete when every item id is done
  (`AzkarState.isMorningComplete` / `isEveningComplete`). Complete → amber gradient header with ✓.
- **Day reset** happens only when the provider loads (`AzkarState.fromJson` drops sets whose `dateKey` is not
  today); the screen does no date check itself.
- **Streak**: the header shows `streakCount` whenever it is > 0. The provider updates it only when a session
  completes (`_onSessionComplete`); it is never reset when a day is skipped.
- **Card text**: Arabic `textAr` (always RTL) plus English `textEn` (shown in both languages); `× repeatCount`
  badge when > 1. Repeats are not counted; one tap marks the whole item.
- **Layout**: desktop (`Platform.isWindows/macOS/Linux`, not web) = 2-column `Wrap`; mobile = single `SliverList`.
- **Numbers** go through `NumberFormatter`. **Strings** are all inline `isArabic ? '…' : '…'` (no `.tr()` keys).

## Side Effects
- Through `azkarProvider`: SharedPreferences `azkar_state` (JSON, every toggle) and `azkar_streak_date`.
  Local only — no Firestore sync, no notifications.

## Verification
- Run: `flutter test` (no tests for this folder). Known issues: findings F42.
