# Fix: F38b — Quran Ayah Targeting

**Finding:** F38b — `scrollToAyaNo` accepted but never used (fix track, MEDIUM)
**Branch:** `fix/f38b-quran-ayah-target`

---

## Problem

`QuranReaderScreen` accepts `scrollToAyaNo` from three callers — search results,
bookmarks, and the last-read card — but never reads the value. Two bugs combine:

### Bug A — `_saveProgress` always records `ayaNo: 1` (line 174–181)

```dart
void _saveProgress(int page) {
  final meta = _surahForPage(page);
  if (meta != null) {
    ref.read(quranReadingProgressProvider.notifier).saveProgress(
          meta.suraNo, 1, page,   // ← hardcoded
        );
  }
}
```

### Bug B — `scrollToAyaNo` is stored but never read

`widget.scrollToAyaNo` is declared at line 33 of `QuranReaderScreen` and accepted as
a named constructor param at line 40, but no code in `_QuranReaderScreenState` ever
reads it. Bug A and B are the same root cause: the first save in `initState` (line 101)
passes no ayah, so it defaults to 1. Note: page navigation to the correct page is
handled separately by the `initialPage` parameter (all three callers pass both);
`scrollToAyaNo` is for recording which ayah within that page was targeted.

### Callers (all pass correct data)

| Caller | File | `scrollToAyaNo` source |
|---|---|---|
| Last-read card | `lib/features/quran/quran_screen.dart:238` | `progress.ayaNo` (was always 1 due to this bug — round-trips correctly after fix) |
| Bookmarks tab | `lib/features/quran/quran_screen.dart:485` | `bm.ayaNo` |
| Search results | `lib/features/quran/quran_search_screen.dart:134` | `ayah.ayaNo` |

**User impact:** reading history always records the first ayah of a page. Resuming
from last-read or a bookmark opens the correct page but with an incorrect ayah position
in the saved progress.

---

## Fix — P1

**Single file changed:** `lib/features/quran/quran_reader_screen.dart`

### Change 1 — add `{int? ayaNo}` to `_saveProgress` (line 174)

```dart
// BEFORE
void _saveProgress(int page) {
  final meta = _surahForPage(page);
  if (meta != null) {
    ref.read(quranReadingProgressProvider.notifier).saveProgress(
          meta.suraNo, 1, page,
        );
  }
}
```

```dart
// AFTER
void _saveProgress(int page, {int? ayaNo}) {
  final meta = _surahForPage(page);
  if (meta != null) {
    ref.read(quranReadingProgressProvider.notifier).saveProgress(
          meta.suraNo, ayaNo ?? 1, page,
        );
  }
}
```

Page-turn calls (`_onPageChanged`, line 186) pass no `ayaNo` and continue to
default to 1. After a page turn we do not know which ayah the user is at, so
recording the page-start position is the correct approximation; this is unchanged.

### Change 2 — pass `scrollToAyaNo` in `initState` (line 101)

```dart
// BEFORE
_saveProgress(_currentPage);
```

```dart
// AFTER
_saveProgress(_currentPage, ayaNo: widget.scrollToAyaNo);
```

`widget.scrollToAyaNo` is `null` when the screen is opened without an ayah target
(e.g. from the main Quran tab), which falls through to `ayaNo ?? 1` — the same
behaviour as before for that path.

---

## Tests

| ID | Description |
|---|---|
| T1 | Source text: `_saveProgress` signature in `quran_reader_screen.dart` contains `{int? ayaNo}` |
| T2 | Source text: `initState` block in `quran_reader_screen.dart` calls `_saveProgress` with `ayaNo: widget.scrollToAyaNo` |

File: `test/features/quran/f38b_source_test.dart`

---

## Scope / contracts

| Category | Changed? |
|---|---|
| Prefs keys | No |
| Notification IDs / channels | No |
| Firestore paths | No |
| MethodChannels | No |
| Kotlin | No |
| UI / layout | No |
| New feature | No |

Strictly behavior-preserving: makes `scrollToAyaNo` do what its name states for the
initial `saveProgress` call. No new UI, no schema changes.

---

## Out of scope — visual ayah highlight (future P2)

A per-page visual highlight of the target ayah would require:

1. Adding `int? targetAyaNo` + surah context to `_MushafPage` constructor.
2. Finding the sorted ayah index matching `(suraNo, targetAyaNo)` in `build()`.
3. Extending `_AyahMarkerColorizer.colorize` with a highlight-index argument (a
   new `BookmarkColor` case or a separate `Set<int>` parameter).

This is a UI change and must wait for a dedicated spec and `approve phase PN`.

---

## Device checks

| ID | Scenario | Expected |
|---|---|---|
| S-F38b-1 | Open Quran search → tap any ayah result → close reader → re-open last-read | Last-read card opens the same page; `progress.ayaNo` matches the tapped ayah, not 1 |
| S-F38b-2 | Bookmark an ayah that is not the first on its page → open from bookmarks tab | Bookmark opens the correct page (unchanged); `progress.ayaNo` saved as the bookmarked ayah, not 1 |
