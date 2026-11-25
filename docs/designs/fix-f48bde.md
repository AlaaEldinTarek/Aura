# Fix F48b + F48d + F48e — Qibla screen: error title language, Arabic digit, inline strings

**Branch:** `fix/f48bde` | **Status:** Spec — awaiting approve phase P1

---

## Findings

### F48b — Error title chosen by theme, not language (LOW)
`_buildErrorState` line 415:
```dart
isDark ? 'خطأ في تحميل القبلة' : 'Error loading Qibla'
```
Uses `isDark` instead of `isArabic`, so a dark-theme English user sees Arabic and a light-theme Arabic user sees English.

**Fix:** `'qibla_error_title'.tr()` — `.tr()` picks the locale.

### F48d — Raw digit in Arabic UI (LOW)
`_buildLocationInfo` lines 233–235:
```dart
final distanceText = isArabic
    ? '${distance.toStringAsFixed(0)} كم'
    : '${distance.toStringAsFixed(0)} km';
```
Raw integer in Arabic string violates CLAUDE.md rule.

**Fix:**
```dart
final distanceFormatted = NumberFormatter.withArabicNumeralsByLanguage(
    distance.toStringAsFixed(0), isArabic ? 'ar' : 'en');
final distanceText = '$distanceFormatted ${'qibla_distance_unit'.tr()}';
```

### F48e — Inline EN/AR strings + raw `e.toString()` error (LOW)
Six inline `isArabic ? … : …` ternaries and one raw `e.toString()` error assignment.

| Location | Old | Key |
|---|---|---|
| AppBar title (line 175) | `isArabic ? 'القبلة' : 'Qibla'` | `qibla_title` |
| Distance card label (line 257) | `isArabic ? 'المسافة إلى مكة' : 'Distance to Makkah'` | `qibla_distance_title` |
| Instruction — facing (line 361) | `isArabic ? 'أنت تتجه نحو القبلة' : 'You are facing Qibla'` | `qibla_instruction_facing` |
| Instruction — close (line 364) | `isArabic ? 'أنت قريب من القبلة' : 'Close to Qibla'` | `qibla_instruction_close` |
| Instruction — turn (line 367) | `isArabic ? 'دور نحو اليمين' : 'Turn to the right'` | `qibla_instruction_turn` |
| Hold flat hint (line 392) | `isArabic ? 'حمل جهازك بشكل مسطح' : 'Hold your device flat'` | `qibla_hold_flat` |

Raw error: `_errorMessage = e.toString()` (line 104) → strip `"Exception: "` prefix (same pattern as `login_screen.dart:311–313` and `profile_screen.dart`).

---

## Translation keys (8 new)

| Key | en | ar |
|---|---|---|
| `qibla_title` | Qibla | القبلة |
| `qibla_distance_title` | Distance to Makkah | المسافة إلى مكة |
| `qibla_distance_unit` | km | كم |
| `qibla_instruction_facing` | You are facing Qibla | أنت تتجه نحو القبلة |
| `qibla_instruction_close` | Close to Qibla | أنت قريب من القبلة |
| `qibla_instruction_turn` | Turn to the right | دور نحو اليمين |
| `qibla_hold_flat` | Hold your device flat | حمل جهازك بشكل مسطح |
| `qibla_error_title` | Error loading Qibla | خطأ في تحميل القبلة |

---

## Files changed

| File | Change |
|---|---|
| `lib/features/qibla/qibla_screen.dart` | F48b + F48d + F48e fixes; add `number_formatter.dart` import |
| `assets/translations/en.json` | 8 new keys |
| `assets/translations/ar.json` | 8 new keys |
| `test/features/qibla/f48bde_source_test.dart` | New — 3 tests |

---

## Tests

**T1** — `NumberFormatter.withArabicNumeralsByLanguage('1200', 'ar')` → `'١٢٠٠'`  
**T2** — `NumberFormatter.withArabicNumeralsByLanguage('1200', 'en')` → `'1200'`  
**T3** — Exception prefix stripped: `'Exception: location denied'` → `'location denied'`

---

## Device checks

**S-F48b-1** — Set English + dark theme → open Qibla → error card shows "Error loading Qibla" (English).  
**S-F48d-1** — Set Arabic locale → open Qibla → distance shows Arabic-Indic digits (e.g. ١٢٣٤ كم).  
**S-F48e-1** — Set Arabic locale → all labels (AppBar, distance title, instruction, hold-flat) show Arabic.
