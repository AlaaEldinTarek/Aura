# Fix F44a+F44b+F44c + F45a+F45b — Dhikr & Islamic Events fixes

**Status:** Draft — awaiting "approve phase P1"
**Branch:** `fix/f44-f45` (from main)
**Files touched:** `lib/features/dhikl/dhikr_screen.dart`, `lib/features/dhikl/custom_zikr_form_screen.dart`, `lib/features/dhikl/dhikr_stats_screen.dart`, `lib/core/providers/islamic_events_provider.dart`, `lib/core/utils/hijri_date.dart`, `assets/translations/en.json`, `assets/translations/ar.json`

---

## Findings

### F44a — "Continue" resets the dhikr counter (`dhikr_screen.dart:215–218`)
The completion dialog "Continue" button calls `_incrementCounter()`. Inside that method, `if (_isCompleted) { _resetCounter(); return; }` (`:106–109`) fires immediately because `_isCompleted` is still `true` when the dialog closes. Result: Continue behaves identically to "Start New" — the counter resets to 0.

**Intended behaviour:** Continue clears the completed state so the user can keep tapping beyond the target (counts 34, 35, 36 …).

### F44b — Raw integers in Arabic UI (`dhikr_screen.dart`)
Three display sites use raw `'$integer'` interpolation without `NumberFormatter`:
- Counter circle: `'$_currentCount'` (`:716`) and `'/ $_currentTarget'` (`:727`)
- Accessibility label: `'$_currentCount / $_currentTarget'` (`:687`)
- Target selector list items: `'$target'` (`:482`) where target ∈ {33, 99, 100, 333, 1000}

### F44c — Inline EN/AR strings in all three dhikr screens
All three screens (`dhikr_screen.dart`, `custom_zikr_form_screen.dart`, `dhikr_stats_screen.dart`) use `isArabic ? '…' : '…'` ternaries instead of `.tr()`. Full list in the Translation keys section below.

### F45a — Islamic event countdowns go stale across midnight (`islamic_events_provider.dart`)
`islamicEventsProvider` is a plain `Provider` that calls `IslamicEventsService.getUpcomingEvents()` once per process (`:5–6`). `daysUntil` and the "Today!" label do not advance until the app restarts, so an event at midnight stays showing "in 1 day" until relaunch.

### F45b — Hijri date shown with Western digits in Arabic UI (`hijri_date.dart:106–108`)
`HijriDate.formatAr` interpolates `hijri['day']` and `hijri['year']` as raw integers:
```dart
return '${hijri['day']} ${getMonthNameAr(hijri['month'])} ${hijri['year']}';
```
No `NumberFormatter.withArabicNumerals()` call, so Arabic users see e.g. "1 رمضان 1446" with Western digits.

---

## Fixes

### P1 — F44a: Fix "Continue" button

**File:** `lib/features/dhikl/dhikr_screen.dart`

Replace the Continue button's `onPressed` to clear `_isCompleted` without resetting `_currentCount`:

```dart
// Before (line 215–218):
onPressed: () {
  Navigator.pop(context);
  _incrementCounter();
},

// After:
onPressed: () {
  Navigator.pop(context);
  setState(() => _isCompleted = false);
  _updateProgressAnimation();
},
```

No other changes. `_isCompleted = false` lets subsequent `_incrementCounter()` taps count normally from the current position.

### P2 — F44b: Arabic numerals in counter display

**File:** `lib/features/dhikl/dhikr_screen.dart`

In `_buildCounterDisplay` (`:676`), read `isArabic` from `Localizations.localeOf(context).languageCode == 'ar'` (already computed at call site). Format with `NumberFormatter.withArabicNumeralsByLanguage(value, isArabic ? 'ar' : 'en')`:

| Site | Before | After |
|------|--------|-------|
| Counter circle count (`:716`) | `'$_currentCount'` | `NumberFormatter.withArabicNumeralsByLanguage('$_currentCount', lang)` |
| Counter circle target (`:727`) | `'/ $_currentTarget'` | `'/ ${NumberFormatter.withArabicNumeralsByLanguage('$_currentTarget', lang)}'` |
| Accessibility label (`:687`) | `'$_currentCount / $_currentTarget'` | format both values with `lang` |
| Target list items (`:482`) | `'$target'` | `NumberFormatter.withArabicNumeralsByLanguage('$target', lang)` |

Pass `lang` (a local `final lang = isArabic ? 'ar' : 'en'`) through `_buildCounterDisplay`'s signature (already takes `isArabic`). `NumberFormatter` import is already present in `dhikr_stats_screen.dart`; add it to `dhikr_screen.dart`.

### P3 — F44c: Inline strings → `.tr()`

Replace every `isArabic ? '…' : '…'` ternary with the `.tr()` key below. `import 'package:easy_localization/easy_localization.dart';` is already in `islamic_events_screen.dart`; add it to all three dhikr screens.

#### `dhikr_screen.dart`

| Ternary (AR / EN) | Key |
|---|---|
| `'المسبحة'` / `'Tasbeeh'` (AppBar title) | `dhikr_title` |
| `'الإحصائيات'` / `'Statistics'` (tooltip) | `dhikr_statistics_tooltip` |
| `'الإعدادات'` / `'Settings'` (tooltip) | `dhikr_settings_tooltip` |
| `'الحمد لله'` / `'Alhamdulillah'` (dialog heading) | `dhikr_complete_heading` |
| `'أكملت الذكر'` / `'Zikr Completed!'` | `dhikr_complete_body` |
| `'بدء جديد'` / `'Start New'` | `dhikr_start_new` |
| `'متابعة'` / `'Continue'` | `dhikr_continue` |
| `'اختر الذكر'` / `'Select Zikr'` | `dhikr_select_zikr` |
| `'أذكار مخصصة'` / `'Custom Zikr'` | `dhikr_custom_section` |
| `'إضافة ذكر مخصص'` / `'Add Custom Zikr'` | `dhikr_add_custom` |
| `'حذف الذكر'` / `'Delete Zikr'` (dialog title) | `dhikr_delete_title` |
| `'إلغاء'` / `'Cancel'` → reuse existing `cancel` key | — |
| `'حذف'` / `'Delete'` (dialog button) | `dhikr_delete_confirm` |
| `'اختر العدد المستهدف'` / `'Select Target'` | `dhikr_select_target` |
| `'الهدف: '` / `'Target: '` | `dhikr_target_label` |
| `'إعادة'` / `'Reset'` | `dhikr_reset` |
| `'عدّ'` / `'Count'` | `dhikr_count` |
| `'عداد التسبيح'` / `'Tasbeeh counter'` (a11y) | `dhikr_counter_label` |

#### `custom_zikr_form_screen.dart`

| Ternary | Key |
|---|---|
| `'تعديل الذكر'` / `'Edit Zikr'` | `dhikr_edit_title` |
| `'إضافة ذكر مخصص'` / `'Add Custom Zikr'` | `dhikr_add_custom` (same key) |
| `'حفظ'` / `'Save'` (AppBar action) → reuse existing `save` key | — |
| `'الاسم'` / `'Name *'` | `dhikr_field_name` |
| `'مثال: صلاة على النبي'` / `'e.g., Salawat'` | `dhikr_field_name_hint` |
| `'مطلوب'` / `'Required'` | `dhikr_field_required` |
| `'النص العربي'` / `'Arabic Text'` | `dhikr_field_arabic` |
| `'النطق'` / `'Transliteration'` | `dhikr_field_transliteration` |
| `'اختياري'` / (hint for transliteration & translation) | `dhikr_field_optional` |
| `'الترجمة'` / `'Translation'` | `dhikr_field_translation` |
| `'العدد المستهدف'` / `'Target Count'` | `dhikr_field_target` |
| `'أدخل رقماً صحيحاً'` / `'Enter a valid number'` | `dhikr_field_target_invalid` |
| `'اختيار سريع:'` / `'Quick pick:'` | `dhikr_quick_pick` |
| `'حفظ التعديلات'` / `'Save Changes'` | `dhikr_save_changes` |
| `'إضافة الذكر'` / `'Add Zikr'` | `dhikr_add_zikr` |
| `'معاينة'` / `'Preview'` | `dhikr_preview` |
| `'هدف'` / `'target'` (preview suffix) | `dhikr_target_suffix` |

#### `dhikr_stats_screen.dart`

| Ternary | Key |
|---|---|
| `'إحصائيات الأذكار'` / `'Zikr Statistics'` | `dhikr_stats_title` |
| `'التتابع'` / `'Streak'` | `dhikr_stats_streak` |
| `'اليوم'` / `'Today'` | `dhikr_stats_today` |
| `'الجلسات'` / `'Sessions'` | `dhikr_stats_sessions` |
| `'النشاط الأسبوعي'` / `'Weekly Activity'` | `dhikr_stats_weekly` |
| `'عدد التسبيحات في آخر 7 أيام'` / `'Zikr count over last 7 days'` | `dhikr_stats_weekly_sub` |
| `'الجلسات الأخيرة'` / `'Recent Sessions'` | `dhikr_stats_recent` |
| `'لا توجد جلسات بعد'` / `'No sessions yet'` | `dhikr_stats_empty` |

### P4 — F45a: Midnight refresh for Islamic events

**File:** `lib/core/providers/islamic_events_provider.dart`

Convert from a plain `Provider` to a `NotifierProvider`. The `Notifier` loads the list on `build()` and schedules a one-shot timer to fire at the next midnight; the timer callback refreshes `state` and reschedules itself.

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/islamic_event.dart';
import '../services/islamic_events_service.dart';

class IslamicEventsNotifier extends Notifier<List<IslamicEventWithDate>> {
  Timer? _midnightTimer;

  @override
  List<IslamicEventWithDate> build() {
    ref.onDispose(() => _midnightTimer?.cancel());
    _scheduleMidnight();
    return IslamicEventsService.getUpcomingEvents();
  }

  void _scheduleMidnight() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay = nextMidnight.difference(now);
    _midnightTimer?.cancel();
    _midnightTimer = Timer(delay, () {
      state = IslamicEventsService.getUpcomingEvents();
      _scheduleMidnight();
    });
  }
}

final islamicEventsProvider =
    NotifierProvider<IslamicEventsNotifier, List<IslamicEventWithDate>>(
      IslamicEventsNotifier.new,
    );
```

No changes needed in `islamic_events_screen.dart` — `ref.watch(islamicEventsProvider)` already works with `NotifierProvider`.

The same fix resolves the stale "Today!" / `daysUntil == 0` badge on the Home event card (`home_screen.dart`) since it also watches `islamicEventsProvider`.

### P5 — F45b: Arabic numerals in Hijri date

**File:** `lib/core/utils/hijri_date.dart`

Add import and format day/year through `NumberFormatter.withArabicNumerals`:

```dart
import 'number_formatter.dart';   // add at top

static String formatAr(Map<String, dynamic> hijri) {
  final day = NumberFormatter.withArabicNumerals('${hijri['day']}');
  final year = NumberFormatter.withArabicNumerals('${hijri['year']}');
  return '$day ${getMonthNameAr(hijri['month'])} $year';
}
```

`formatEn` is unchanged (Western digits are correct in English).

---

## Translation keys to add

Add each key to **both** `assets/translations/en.json` and `assets/translations/ar.json`.

```jsonc
// en.json additions
"dhikr_title": "Tasbeeh",
"dhikr_statistics_tooltip": "Statistics",
"dhikr_settings_tooltip": "Settings",
"dhikr_complete_heading": "Alhamdulillah",
"dhikr_complete_body": "Zikr Completed!",
"dhikr_start_new": "Start New",
"dhikr_continue": "Continue",
"dhikr_select_zikr": "Select Zikr",
"dhikr_custom_section": "Custom Zikr",
"dhikr_add_custom": "Add Custom Zikr",
"dhikr_delete_title": "Delete Zikr",
"dhikr_delete_confirm": "Delete",
"dhikr_select_target": "Select Target",
"dhikr_target_label": "Target: ",
"dhikr_reset": "Reset",
"dhikr_count": "Count",
"dhikr_counter_label": "Tasbeeh counter",
"dhikr_edit_title": "Edit Zikr",
"dhikr_field_name": "Name *",
"dhikr_field_name_hint": "e.g., Salawat",
"dhikr_field_required": "Required",
"dhikr_field_arabic": "Arabic Text",
"dhikr_field_transliteration": "Transliteration",
"dhikr_field_optional": "Optional",
"dhikr_field_translation": "Translation",
"dhikr_field_target": "Target Count",
"dhikr_field_target_invalid": "Enter a valid number",
"dhikr_quick_pick": "Quick pick:",
"dhikr_save_changes": "Save Changes",
"dhikr_add_zikr": "Add Zikr",
"dhikr_preview": "Preview",
"dhikr_target_suffix": "target",
"dhikr_stats_title": "Zikr Statistics",
"dhikr_stats_streak": "Streak",
"dhikr_stats_today": "Today",
"dhikr_stats_sessions": "Sessions",
"dhikr_stats_weekly": "Weekly Activity",
"dhikr_stats_weekly_sub": "Zikr count over last 7 days",
"dhikr_stats_recent": "Recent Sessions",
"dhikr_stats_empty": "No sessions yet"
```

```jsonc
// ar.json additions
"dhikr_title": "المسبحة",
"dhikr_statistics_tooltip": "الإحصائيات",
"dhikr_settings_tooltip": "الإعدادات",
"dhikr_complete_heading": "الحمد لله",
"dhikr_complete_body": "أكملت الذكر",
"dhikr_start_new": "بدء جديد",
"dhikr_continue": "متابعة",
"dhikr_select_zikr": "اختر الذكر",
"dhikr_custom_section": "أذكار مخصصة",
"dhikr_add_custom": "إضافة ذكر مخصص",
"dhikr_delete_title": "حذف الذكر",
"dhikr_delete_confirm": "حذف",
"dhikr_select_target": "اختر العدد المستهدف",
"dhikr_target_label": "الهدف: ",
"dhikr_reset": "إعادة",
"dhikr_count": "عدّ",
"dhikr_counter_label": "عداد التسبيح",
"dhikr_edit_title": "تعديل الذكر",
"dhikr_field_name": "الاسم",
"dhikr_field_name_hint": "مثال: صلاة على النبي",
"dhikr_field_required": "مطلوب",
"dhikr_field_arabic": "النص العربي",
"dhikr_field_transliteration": "النطق",
"dhikr_field_optional": "اختياري",
"dhikr_field_translation": "الترجمة",
"dhikr_field_target": "العدد المستهدف",
"dhikr_field_target_invalid": "أدخل رقماً صحيحاً",
"dhikr_quick_pick": "اختيار سريع:",
"dhikr_save_changes": "حفظ التعديلات",
"dhikr_add_zikr": "إضافة الذكر",
"dhikr_preview": "معاينة",
"dhikr_target_suffix": "هدف",
"dhikr_stats_title": "إحصائيات الأذكار",
"dhikr_stats_streak": "التتابع",
"dhikr_stats_today": "اليوم",
"dhikr_stats_sessions": "الجلسات",
"dhikr_stats_weekly": "النشاط الأسبوعي",
"dhikr_stats_weekly_sub": "عدد التسبيحات في آخر 7 أيام",
"dhikr_stats_recent": "الجلسات الأخيرة",
"dhikr_stats_empty": "لا توجد جلسات بعد"
```

---

## Source tests (T1–T5)

File: `test/features/dhikl/f44_f45_source_test.dart`

| # | What is verified | How |
|---|---|---|
| T1 | F44a: `_isCompleted` cleared without resetting `_currentCount` | Check that Continue button's `onPressed` does not call `_resetCounter` or `_incrementCounter` when `_isCompleted == true` — grep for `_incrementCounter` inside the Continue `onPressed` block |
| T2 | F44b: counter display uses `NumberFormatter` | Grep for `'$_currentCount'` bare interpolation in `_buildCounterDisplay` — expect 0 matches |
| T3 | F44c: no bare `isArabic ?` ternary strings remain in dhikr screens | Grep for `isArabic ?` in all three dhikr files — expect 0 matches |
| T4 | F45a: provider is `NotifierProvider`, not plain `Provider` | Grep `islamicEventsProvider` declaration for `NotifierProvider` |
| T5 | F45b: `formatAr` uses `NumberFormatter.withArabicNumerals` | Grep `hijri_date.dart` for `NumberFormatter` |

---

## Checklist

- [ ] P1 Continue fix (`dhikr_screen.dart:215–218`)
- [ ] P2 Arabic numerals in counter (`dhikr_screen.dart`)
- [ ] P3 Inline strings → `.tr()` in all three dhikr screens + translation keys
- [ ] P4 `IslamicEventsNotifier` with midnight timer
- [ ] P5 `HijriDate.formatAr` Arabic numerals
- [ ] T1–T5 source tests pass
- [ ] `flutter test` passes
- [ ] `flutter analyze` — 0 new issues

## Contracts touched

None. No prefs keys, Firestore paths, notification IDs, MethodChannels, or intent extras are changed.
