# Fix F40a + F40b — Achievements screen: inflated count + inline strings

**Status:** Approved for code (phase P1)  
**Branch:** `fix/f40ab` (to be created from main)  
**Findings:** F40a (LOW), F40b (LOW)  
**Files touched:**
- `lib/features/achievements/achievements_screen.dart`
- `assets/translations/en.json`
- `assets/translations/ar.json`

---

## F40a — Problem

`earnedCount` (`:67–69`) counts all achievements in `_earnedAchievements`
whose category is visible. When Firestore holds an id not in
`AchievementDefinitions.all`, `Achievement.earnedFromFirestore` creates a
fallback badge with `category: AchievementCategory.special` (`:57`). That
badge is counted by `earnedCount` but NOT by `visibleTotal` (which only
counts ids in `AchievementDefinitions.all`), so the header can show
"6 of 5 unlocked".

## F40a — Fix

Add an `allIds` guard to `earnedCount` so only known achievements count:

**Before:**
```dart
final earnedCount = _earnedAchievements
    .where((a) => visibleCategories.contains(a.category))
    .length;
```

**After:**
```dart
final allIds = AchievementDefinitions.all.map((a) => a.id).toSet();
final earnedCount = _earnedAchievements
    .where((a) => visibleCategories.contains(a.category) && allIds.contains(a.id))
    .length;
```

---

## F40b — Problem

Five places in `build()` use inline EN/AR strings instead of `.tr()`:

| Line(s) | String |
|---------|--------|
| `:73` | AppBar title `isArabic ? 'الإنجازات' : 'Achievements'` |
| `:105` | Header `isArabic ? 'إنجازاتك' : 'Your Achievements'` |
| `:113–115` | Subtitle `'$n من $m مكتمل'` / `'$n of $m unlocked'` |
| `:147–154` | `categoryNames` map (6 entries, all inline) |

## F40b — Fix

**New translation keys** (added to both `en.json` and `ar.json`):

```json
// en.json additions
"achievements_screen_title": "Achievements",
"achievements_header": "Your Achievements",
"achievements_subtitle": "{} of {} unlocked",
"achievement_category_streaks": "Streaks",
"achievement_category_consistency": "Consistency",
"achievement_category_dhikr": "Zikr",
"achievement_category_tasks": "Tasks",
"achievement_category_quran": "Quran",
"achievement_category_special": "Special"
```

```json
// ar.json additions
"achievements_screen_title": "الإنجازات",
"achievements_header": "إنجازاتك",
"achievements_subtitle": "{} من {} مكتمل",
"achievement_category_streaks": "التتابعات",
"achievement_category_consistency": "الالتزام",
"achievement_category_dhikr": "الأذكار",
"achievement_category_tasks": "المهام",
"achievement_category_quran": "القرآن",
"achievement_category_special": "خاص"
```

**Code changes:**

```dart
// line 73 — AppBar title
title: Text('achievements_screen_title'.tr()),

// line 105 — header
Text('achievements_header'.tr(), ...),

// lines 113–115 — subtitle
Text('achievements_subtitle'.tr(args: [
  NumberFormatter.withArabicNumeralsByLanguage('$earnedCount', isArabic ? 'ar' : 'en'),
  NumberFormatter.withArabicNumeralsByLanguage('$visibleTotal', isArabic ? 'ar' : 'en'),
]), ...),

// lines 147–154 — categoryNames map
final categoryNames = {
  AchievementCategory.streaks:     'achievement_category_streaks'.tr(),
  AchievementCategory.consistency: 'achievement_category_consistency'.tr(),
  AchievementCategory.dhikr:       'achievement_category_dhikr'.tr(),
  AchievementCategory.tasks:       'achievement_category_tasks'.tr(),
  AchievementCategory.quran:       'achievement_category_quran'.tr(),
  AchievementCategory.special:     'achievement_category_special'.tr(),
};
```

The `isArabic` variable used at `:73` and `:105` is removed from those two
spots; `.tr()` reads the current locale automatically.

---

## Contract check

| Contract | Verdict |
|----------|---------|
| SharedPreferences key names | Unchanged |
| Firestore paths | Unchanged |
| Notification IDs / channels | Not involved |
| `Achievement.id` values | Unchanged |
| New translation keys | 9 added to both locales |

---

## Tests

Source-text test (2 tests, `test/features/achievements/f40ab_source_test.dart`):

- **T1**: `achievements_screen.dart` contains `allIds.contains(a.id)` (F40a guard)
- **T2**: `achievements_screen.dart` does NOT contain `'الإنجازات'` or `'Achievements'` as an inline string; contains `'achievements_screen_title'.tr()`

---

## Device check

| ID | Description |
|----|-------------|
| S-F40a-1 | On the Achievements screen, the "N of M" count matches the number of visible badges (never exceeds M). |
| S-F40b-1 | Switch app language to Arabic; Achievements screen title, header, subtitle, and category names all show in Arabic. |
