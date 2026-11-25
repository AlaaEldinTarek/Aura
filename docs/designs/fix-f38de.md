# Fix F38d — Stats English weekday labels off by one

**Status:** Approved for code (phase P1)  
**Branch:** `fix/f38de` (to be created from main)  
**Findings:** F38d (LOW), F38e (LOW — already resolved, see below)  
**Files touched:**
- `lib/features/quran/quran_stats_screen.dart`

---

## F38d — Problem

`_BarChart._dayLabel()` at `quran_stats_screen.dart:396–397` indexes a
Monday-first English array with `weekday % 7`:

```dart
const enDays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
return enDays[day.weekday % 7];
```

`DateTime.weekday` is 1=Monday … 7=Sunday. `weekday % 7` gives:

| Day     | weekday | % 7 | label shown | correct |
|---------|---------|-----|-------------|---------|
| Monday  | 1       | 1   | Tu          | Mo ✗    |
| Tuesday | 2       | 2   | We          | Tu ✗    |
| …       | …       | …   | …           |         |
| Saturday| 6       | 6   | Su          | Sa ✗    |
| Sunday  | 7       | 0   | Mo          | Su ✗    |

Every English day label is wrong by one position. The Arabic array is
Sunday-first (`['أح','إث',...]`) and `weekday % 7` happens to give the
correct mapping (Sunday=7→0=أح), so Arabic is unaffected.

---

## F38d — Fix

Change only the English index from `day.weekday % 7` to `day.weekday - 1`:

**Before (`quran_stats_screen.dart:396–397`):**
```dart
const enDays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
return enDays[day.weekday % 7];
```

**After:**
```dart
const enDays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
return enDays[day.weekday - 1];
```

The Arabic branch (`arDays[day.weekday % 7]`) is unchanged.

---

## F38e — Already resolved

Finding F38e reported: `averageDaily = totalPagesRead / totalDaysCompleted`
even in juz mode, so the value was in pages but the label said "juz".

**Current state (VERIFIED):** `quranStatsProvider` in `wird_provider.dart`
calls `averagePerCompletedDay(unit: wirdState.settings.wirdUnit, ...)`.
That function (`wird_marker_logic.dart:214–226`) uses
`juzKhatmCount * 30 + checkedJuzCount` for juz mode and
`progressTotal` for page mode. The juz reset lifecycle
(`resetJuzForKhatma()` → `recordKhatma()` + `resetAllJuz()`) ensures
`allCompletedJuz` is cleared after each khatm, so the count is correct.

**Resolution:** fixed by mode-separation work (PR #29, commit `c67f29d`).
No code change needed for F38e in this PR.

---

## Contract check

| Contract | Verdict |
|----------|---------|
| SharedPreferences key names | Unchanged |
| Firestore paths | Unchanged |
| Notification IDs / channels | Not involved |
| Translation keys | Unchanged (labels not touched) |
| New keys introduced | None |

---

## Tests

Source-text test (1 test, file `test/features/quran/f38d_source_test.dart`):

- **T1**: `quran_stats_screen.dart` does NOT contain `enDays[day.weekday % 7]`,
  and DOES contain `enDays[day.weekday - 1]`.

---

## Device check

| ID | Description |
|----|-------------|
| S-F38d-1 | Open Quran stats screen in English. The 7-bar weekly chart shows the correct day abbreviation for today and the six previous days (e.g., if today is Tuesday, the rightmost bar is "Tu"). |
