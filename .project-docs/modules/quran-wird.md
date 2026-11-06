# Quran
Relocated from CLAUDE.md on 2026-11-06; not yet re-verified (Step 2). Wird (daily reading): wird.md.

## Key files
- `lib/features/quran/` — `QuranScreen` (4 tabs: Surahs, Juz, Bookmarks, Wird), `QuranReaderScreen` (604 SVG pages),
  `QuranSearchScreen`; route `/quran`
- Services: `quran_service`, `quran_bookmark_service`, `quran_svg_service` (CDN download + local cache)
- Providers: `quranDataProvider`, `surahListProvider`, `juzListProvider`, `quranBookmarksProvider`, `quranSearchProvider`
- Model: `lib/core/models/quran_models`

## Data & font
- `assets/data/hafsData_v2-0.json` — 12,472 ayahs, loaded **LAZILY** on first Quran tab open (NOT at startup — causes
  crash); cached in `QuranService._cachedAyahs`. Fields: `sura_no`, `aya_no`, `jozz`, `page`, `line_start`, `line_end`,
  `aya_text` (PUA-encoded, display), `aya_text_emlaey` (standard Arabic, search only).
- `assets/fonts/uthmanic_hafs_v20.ttf`, family `UthmanicHafs` — inline ayah text in surah list and search. Mushaf
  pages render as SVG, not font text.

## SVG reader
- Pages from `https://cdn.jsdelivr.net/gh/AlaaEldinTarek/aura-adhans/mushafs/hafs/svg` (`001.svg`–`604.svg`), NOT bundled;
  cached at `getApplicationDocumentsDirectory()/quran_pages/`. `QuranSvgService` deduplicates concurrent requests and
  preloads ±1 page. Dark mode inverts via `ColorFiltered` matrix.
- Tap detection: widget coords → SVG coords → line number (from `line_start`/`line_end`) → `Ayah`. Pages 1–2 square
  viewBox (235×235); pages 3–604 portrait (345×550).
- No ayah highlight: `_AyahHighlightPainter` and `_selectedAyah` were removed; tapping goes straight to `_AyahSheet`.
- Wakelock: `WakelockPlus.enable()` in `initState`, `disable()` in `dispose` (screen stays on; no button).
- Back button: `PopScope(canPop: false, onPopInvokedWithResult: ...)` wraps the `Scaffold` → `AlertDialog`
  ("Keep Reading" / "Close"). Progress is always auto-saved, so the message says "Your progress is saved."
- Uses `import 'dart:ui' as ui show TextDirection;` (see ui-kit.md § TextDirection conflict).

## Bookmarks
- Bookmarks tab: delete icon per item with confirmation dialog + undo Snackbar (NOT long-press delete).
- Reader bookmark color dialog: `_AyahSheet.onBookmark` is `void Function(BuildContext context, BookmarkColor color)` —
  `BuildContext` is passed so nested dialogs can show from inside the sheet. If a color already has bookmarks,
  `_handleAyahTap` shows an `AlertDialog` ("Add New" / "Choose One"). "Choose One" opens `_BookmarkReplaceSheet`
  (DraggableScrollableSheet); on selection `Navigator.of(context)..pop()..pop()` closes both sheets.
- Colors: red / orange / green (Wird can link one: wird.md).

## Other routes
- `/quran_stats`, `/khatma_dua` exist in `main.dart` (UNKNOWN details, Step 2).
