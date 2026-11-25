# Fix F26 + F32c + F21 — Jumu'ah display gaps and wrong Quran revelation types

**Status:** Approved for code (phase P1)  
**Branch:** `fix/f26-f32c-f21` (to be created from main)  
**Findings:** F26 (MEDIUM), F32c (LOW), F21 (LOW)  
**Files touched:**
- `lib/core/widgets/prayer_card.dart`
- `lib/features/home/home_screen.dart`
- `lib/core/models/quran_models.dart`

---

## F26 — Prayer screen cards do not show Jumu'ah on Fridays

### Problem

`prayer_card.dart:121` renders the prayer name directly from the model:

```dart
isArabic ? prayer.nameAr : prayer.name
```

`prayer.name` is always `'Zuhr'`; `prayer.nameAr` is always `'الظهر'`. Neither path
calls `getPrayerDisplayName`, which is the CLAUDE.md-mandated function that returns
`"Jumu'ah"` / `"الجمعة"` on Fridays. The same raw access appears in the accessibility
label at `:96`.

`PrayerTimeCard` (`:316` area) has the same gap but has no callers outside its own file —
tagged P6, not fixed here.

### Fix

**`lib/core/widgets/prayer_card.dart`**

Add import (after the existing imports):
```dart
import '../utils/prayer_time_rules.dart';
```

Line 96 — accessibility label:
```dart
// Before
label: '${isArabic ? prayer.nameAr : prayer.name}, ${_formatPrayerTime(prayer, isArabic)}'

// After
label: '${getPrayerDisplayName(prayer.name, isArabic: isArabic)}, ${_formatPrayerTime(prayer, isArabic)}'
```

Line 121 — card title:
```dart
// Before
isArabic ? prayer.nameAr : prayer.name,

// After
getPrayerDisplayName(prayer.name, isArabic: isArabic),
```

---

## F32c — Home screen prayer progress labels skip Jumu'ah

### Problem

`home_screen.dart:1222–1228` renders the five prayer labels in the daily progress ring
with a hard-coded Arabic array and `kPrayerNames[i]`:

```dart
isArabic
    ? ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'][i]
    : kPrayerNames[i],
```

Both branches bypass `getPrayerDisplayName`, so Zuhr always shows as `الظهر` / `Zuhr`
even on Fridays. `prayer_time_rules.dart` is already imported in `home_screen.dart` (:37);
`trackablePrayers[i]` (a `String` prayer name) is in scope at that point.

### Fix

**`lib/features/home/home_screen.dart`**

Lines 1222–1229 — replace the branched literal with one call:
```dart
// Before
isArabic
    ? [
        'الفجر',
        'الظهر',
        'العصر',
        'المغرب',
        'العشاء'
      ][i]
    : kPrayerNames[i],

// After
getPrayerDisplayName(trackablePrayers[i], isArabic: isArabic),
```

---

## F21 — Four surahs have wrong revelation type (Makki instead of Madani)

### Problem

`quran_models.dart:187–189, 192` mark four surahs as `RevelationType.makki` when they
are Madani by scholarly consensus (the standard 28-Madani count):

| # | Surah | Current | Correct |
|---|-------|---------|---------|
| 3 | Āl-ʿImrān | makki | madani |
| 4 | An-Nisāʾ | makki | madani |
| 5 | Al-Māʾidah | makki | madani |
| 8 | Al-Anfāl | makki | madani |

The type is displayed in the Quran surah list (`quran_screen.dart:280`).
No logic branches on this value; changing it is data-only with no side effects.

### Fix

**`lib/core/models/quran_models.dart`**

```dart
// Before (lines 187–189, 192)
SurahMetaData(3, 'Āl-'Imrān', 'آل عِمران', 200, RevelationType.makki, 50, 76),
SurahMetaData(4, 'An-Nisā'', 'النِّسَاء', 176, RevelationType.makki, 77, 106),
SurahMetaData(5, 'Al-Mā'idah', 'المَائدة', 120, RevelationType.makki, 106, 127),
// line 192:
SurahMetaData(8, 'Al-Anfāl', 'الأنفَال', 75, RevelationType.makki, 177, 186),

// After
SurahMetaData(3, 'Āl-'Imrān', 'آل عِمران', 200, RevelationType.madani, 50, 76),
SurahMetaData(4, 'An-Nisā'', 'النِّسَاء', 176, RevelationType.madani, 77, 106),
SurahMetaData(5, 'Al-Mā'idah', 'المَائدة', 120, RevelationType.madani, 106, 127),
// line 192:
SurahMetaData(8, 'Al-Anfāl', 'الأنفَال', 75, RevelationType.madani, 177, 186),
```

After the fix the file has 28 Madani entries, matching the standard count.

---

## Contract check

| Contract | Verdict |
|----------|---------|
| SharedPreferences key names | Unchanged |
| Firestore paths | Unchanged |
| Notification IDs / channels | Not involved |
| Native method channels | Not involved |
| Model fields | `RevelationType` values corrected (data only; no logic branches on this field) |
| New keys introduced | None |

---

## Tests

Source-text tests (3 tests, file `test/core/widgets/f26_f32c_f21_source_test.dart`):

- **T1**: `prayer_card.dart` calls `getPrayerDisplayName(prayer.name, isArabic: isArabic)` and does not contain the raw `prayer.nameAr` pattern for the name text.
- **T2**: `home_screen.dart` uses `getPrayerDisplayName(trackablePrayers[i], isArabic: isArabic)` and does not contain the hard-coded `'الظهر'` string in the prayer-label context.
- **T3**: `quran_models.dart` has exactly 28 `RevelationType.madani` entries (surahs 3, 4, 5, 8 corrected).

---

## Device check

| Step | Description |
|------|-------------|
| S-F26 | On a Friday: open the Prayer tab. Zuhr card shows **"Jumu'ah"** (EN) or **"الجمعة"** (AR). On any other day it shows "Zuhr" / "الظهر". |
| S-F32c | On a Friday: Home screen prayer progress ring labels — the Zuhr dot shows **"الجمعة"** (AR) or **"Jumu'ah"** (EN). |
| S-F21 | Quran surah list: surahs 3 (Āl-ʿImrān), 4 (An-Nisāʾ), 5 (Al-Māʾidah) and 8 (Al-Anfāl) show **Madani**, not Makki. |

S-F26 and S-F32c require a Friday; they can be deferred to the next Friday if the merge happens on a different day.
