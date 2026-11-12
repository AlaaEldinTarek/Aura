# Quran
Verified against code 2026-11-07 (reference/2026-11-07_DRIFT_REPORT.md). Wird (daily reading): wird.md. Folder view:
`lib/features/quran/README.md`.

## Key files
- `lib/features/quran/` — `QuranScreen` (4 tabs: Surahs, Juz, Bookmarks, Wird), `QuranReaderScreen` (604 SVG pages),
  `QuranSearchScreen`; route `/quran`
- Services: `quran_service`, `quran_bookmark_service`, `quran_svg_service` (CDN download + disk cache + 30-entry
  in-memory FIFO cache)
- Providers: `quranDataProvider`, `surahListProvider`, `juzListProvider`, `quranBookmarksProvider`, `quranSearchProvider`
- Model: `lib/core/models/quran_models`

## Data & font
- `assets/data/hafsData_v2-0.json` — 6,236 ayahs, loaded **LAZILY** on first Quran tab open (NOT at startup — causes
  crash); cached in `QuranService._cachedAyahs`. Fields: `id`, `sura_no`, `sura_name_ar`, `sura_name_en`, `aya_no`,
  `jozz`, `page`, `line_start`, `line_end`, `aya_text` (PUA-encoded, display), `aya_text_emlaey` (standard Arabic,
  search only).
- `assets/fonts/uthmanic_hafs_v20.ttf`, family `UthmanicHafs` — inline ayah text in surah list, search and Bookmarks
  tab. Mushaf pages render as SVG, not font text.

## SVG reader
- Pages from `https://cdn.jsdelivr.net/gh/AlaaEldinTarek/aura-adhans/mushafs/hafs/svg` (`001.svg`–`604.svg`), NOT bundled;
  cached at `getApplicationDocumentsDirectory()/quran_pages/`. `QuranSvgService` deduplicates concurrent requests; the
  reader preloads ±3 pages (`initState`, `_onPageChanged`). Dark mode inverts via `ColorFiltered` matrix.
- Tap detection: widget coords → SVG coords → line number (from `line_start`/`line_end`) → `Ayah`. Pages 1–2 square
  viewBox (235×235); pages 3–604 portrait (345×550).
- No ayah highlight: `_AyahHighlightPainter` and `_selectedAyah` were removed; tapping goes straight to `_AyahSheet`.
- Wakelock: `WakelockPlus.enable()` in `initState`, `disable()` in `dispose` (screen stays on; no button).
- Back: `PopScope(canPop: false, onPopInvokedWithResult: ...)` wraps the `Scaffold`. On page 604 with page-mode wird not
  completed → khatma dialog (yes → `recordPageKhatma()`, `markComplete()`, `pushReplacement` to
  `KhatmaCelebrationScreen`); otherwise "Close Reader?" `AlertDialog` ("Keep Reading" / "Close", "Your progress is
  saved."). The top-bar close button calls `Navigator.maybePop()`, so it runs the same handler as back and Esc.
- Uses `import 'dart:ui' as ui show TextDirection;` (see ui-kit.md § TextDirection conflict).

## Bookmarks
- Bookmarks tab: delete icon per item with confirmation dialog + undo Snackbar (NOT long-press delete).
- Reader bookmark color: `_AyahSheet.onBookmark` is `void Function(BuildContext context, BookmarkColor color)` — the sheet
  context is passed so nested dialogs can show from inside the sheet. The callback (built in `_handleAyahTap`) shows an
  `AlertDialog` when the color already has bookmarks ("Add New" / "Choose One", keys `wird_bookmark_mode_new` /
  `wird_bookmark_mode_update`). "Choose One" opens `_BookmarkReplaceSheet` (DraggableScrollableSheet); on selection
  `nav.pop(); nav.pop();` (screen navigator) closes both.
- Colors: red / orange / green (Wird can link one: wird.md).

## Other routes
- `/quran_stats` → `QuranStatsScreen` (`quran_stats_screen.dart`): wird stats from `quranStatsProvider` (totals, khatm
  count, 7-day chart, current/best streak over 90 days, daily average, khatm circle); opened from the Wird tab; also in
  the desktop nested navigator.
- `/khatma_dua` → `KhatmaDuaScreen`: fixed khatm du'a + `khatmCount` / `khatmDates`; reached only via `MaterialPageRoute`
  from `KhatmaCelebrationScreen` (named route unused, F52o).
