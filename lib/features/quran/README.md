# Quran Feature Blueprint

## System Overview
The Quran UI. It has the Quran tab (`quran_screen.dart`, 4 tabs: Surahs, Juz, Bookmarks, Wird), the SVG Mushaf reader
(`quran_reader_screen.dart`, 604 pages) and the Wird daily-reading tab (`wird_tab.dart`). It also has search, stats,
and the khatma celebration and dua screens. Data comes from `../../core/` and is not owned here: `QuranService`
(local `hafsData_v2-0.json`), `QuranSvgService` (CDN SVG pages and disk cache), and `quranBookmarksProvider` /
`quranReadingProgressProvider` (`QuranBookmarkService`, prefs). `wirdStateProvider` / `quranStatsProvider` come from
`WirdService` (prefs plus Firestore for logged-in users). Cross-folder views: `.project-docs/modules/quran-wird.md`,
`.project-docs/modules/wird.md`. Behavior-preserving rule: no UI or logic change without an approved spec.

## Local Interface & Invariants

### Interface
| File | Public symbols / entry points |
| --- | --- |
| `quran_screen.dart` | `QuranScreen()`: route `/quran`, also bottom-nav tab page. Private tabs `_SurahListTab`, `_JuzTab`, `_BookmarksTab`; `_LastReadCard` |
| `quran_reader_screen.dart` | `QuranReaderScreen({required suraNo, scrollToAyaNo, initialJuz, initialPage})`, always pushed via `MaterialPageRoute` (no named route). Private: `_MushafPage`, `_AyahSheet`, `_BookmarkReplaceSheet`, `_AyahMarkerColorizer`, bars and zoom controls |
| `wird_tab.dart` | `WirdTab({required lang})`, the 4th tab of `QuranScreen`. Private: `_WirdContentView`, `_BookmarkPagesSheet`, `_BookmarkListSheet`, `_RecordPagesContent` |
| `quran_search_screen.dart` | `QuranSearchScreen()`, opened only from the `QuranScreen` AppBar (`MaterialPageRoute`) |
| `quran_stats_screen.dart` | `QuranStatsScreen()`: route `/quran_stats` (Wird streak card) |
| `khatma_celebration_screen.dart` | `KhatmaCelebrationScreen({required khatmCount, required date})`, pushed by the reader (page mode) and Wird tab (juz mode) |
| `khatma_dua_screen.dart` | `KhatmaDuaScreen()`: route `/khatma_dua`, also pushed from the celebration screen. Private consts `_duaArabic`, `_duaEnglish` |

### Invariants
- **Opening the reader**: start page = `initialPage`, else `initialJuz` via the reader's hardcoded `_juzStartPages`
  (same table as `QuranService.getJuzList`), else `getSurahMeta(suraNo).startPage`, else 1. `scrollToAyaNo` is accepted
  but never used (findings F38). Juz and Wird callers pass `suraNo: 1` and rely on `initialJuz` / `initialPage`.
- **Reader pages**: `PageView` of 604 (index = page − 1). Pages 1–2 use a 235×235 viewBox, the rest 345×550. SVGs are
  preloaded ±3 pages. Tapping the content maps y → line → `Ayah` and opens `_AyahSheet`; tapping outside toggles the bars.
  Wakelock on for the reader's lifetime; no orientation handling.
- **Last read**: saved in `initState` and on every page change as (surah of page, ayah **1**, page). `_LastReadCard`
  reads it back and is hidden when there is no progress.
- **Bookmarks**: ayah id `'<sura>_<aya>'`, colors red / orange / green. Tapping any color on a bookmarked ayah removes it.
  If the color already has bookmarks, a dialog offers add new or replace (`_BookmarkReplaceSheet` → `replaceBookmark`).
  No count limit. The top-bar page bookmark is id `'page_<n>'` (ayah 1, default green). The Bookmarks tab deletes with
  a confirm dialog and an undo SnackBar.
- **Ayah marker colors**: SVG marker groups sorted by y get the color of the i-th ayah sorted by `ayaNo`. Only fill
  `#231f20` is replaced, and dark mode uses pre-inverted colors because the page is RGB-inverted.
- **Reader back**: `PopScope(canPop: false)`. At page 604 in Wird page mode, with today not completed, a khatma prompt
  appears ("yes" → `recordPageKhatma` + `markComplete` → celebration). Otherwise a "Close Reader?" confirm. The top-bar
  close button calls `Navigator.pop` directly and skips both (F38).
- **Desktop reader** (`!kIsWeb` and Windows/macOS/Linux): hides the shell sidebar via `desktopSidebarVisibleProvider`
  and restores it on every exit path. Drag ≥ 80 px horizontal to turn pages; keys: arrows, `+` / `-`, Esc. Vertical pan
  only, zoom 0.5–8. Mobile: pinch zoom 1.0–6.0; page swipe is locked while zoomed.
- **Wird modes** (`settings.wirdUnit`): page mode shows `pagesRead / dailyPageGoal` and the range
  `startPage..startPage+goal−1` (clamped to 604). Juz mode shows a 30-cell grid (tap = `toggleJuzCompleted`) and the
  days-left estimate. Goals: pages 1–604, juz 1–30.
- **Wird khatma**: juz mode only, in `ref.listen` (completed juz reaches 30, guarded by `_khatmaHandled`) →
  `resetJuzForKhatma` → celebration. Page-mode khatma only happens in the reader back prompt.
- **Bookmark auto-sync**: runs inside `build()` when `linkedBookmarkColor` is set. Pages of that color not in
  `countedBookmarkPages` are synced (page mode: `syncBookmarkPages`; juz mode: mark juz 1..maxJuz). `_syncInProgress`
  guards re-entry. "Choose one" in page mode resets the counted set to that one page, so the next build counts all
  other pages of that color too (F38).
- **"Reset All Progress"** (`wird_reset_today` key) calls `resetAllProgress` after a confirm. It wipes streak,
  totals, history, completed juz and khatma count and keeps settings. That is the intended behavior (the key name is
  misleading).
- **Manual recording**: count mode → `currentPage + N` (no clamp); range mode needs 1 ≤ from ≤ to ≤ 604.
- **Reminders**: `HH:mm` strings, max 10, new time defaults to 06:00; scheduling happens in `WirdService`.
- **Search**: 500 ms debounce, ≥ 2 trimmed chars, `QuranService.searchAyahs` is a plain substring match on
  `aya_text_emlaey` (no normalization, no limit).
- **Stats**: from `quranStatsProvider`. Bar chart = last 7 days (pages, or juz in juz mode). Average daily =
  `totalPagesRead / totalDaysCompleted` (labelled juz in juz mode; F38). Best streak = last 90 days. The khatm circle is
  `allCompletedJuz` out of 30.
- **Khatma screens**: the celebration screen shows count and date and offers dua / share (`captureAndShare`,
  `aura_khatm.png`) / done; it requests an app rating after 3 s. The dua screen shows a fixed Arabic dua and an English
  translation regardless of locale, plus the history from `khatmCount` / `khatmDates`.
- **Localization**: mostly `.tr()`. Inline `isArabic` strings in the reader close dialog and the Wird stats tooltip;
  `'Error: $e'` is raw. Numbers go through `NumberFormatter`, except `%d` substitutions in Wird and the reader replace
  sheet, and `DateFormat` dates (F39).
- **Tutorials**: Quran (tab, juz, bookmarks), reader and Wird each launch once. The Wird tutorial lives in
  `_WirdContentViewState`, not in `QuranScreen._onTabChanged`.

### Side Effects
- `quranBookmarksProvider.notifier`: `addBookmark` / `removeBookmark` / `replaceBookmark` → prefs `quran_bookmarks`.
- `quranReadingProgressProvider.notifier.saveProgress` → prefs `quran_reading_progress`.
- `wirdStateProvider.notifier`: goals, unit, reminders, `recordPagesRead`, `markComplete` / `undoComplete`,
  `toggleJuzCompleted`, `markJuzFromBookmarks`, `syncBookmarkPages`, `setLinkedBookmarkColor`, `resetJuzForKhatma`,
  `recordPageKhatma`, `resetAllProgress`. These write `wird_*` prefs, push to Firestore `users/{uid}/wird/data` and
  (re)schedule Wird reminders, all inside `WirdService`.
- Network: `QuranSvgService` downloads pages from the jsDelivr CDN into `<appDocs>/quran_pages`.
- Platform: `WakelockPlus.enable` / `disable` (no try-catch); share sheet; `RatingService.maybeRequest`.
- Prefs tutorial flags via `SharedPreferencesService`: `tutorial_quran_seen`, `tutorial_juz_seen`,
  `tutorial_bookmarks_seen`, `tutorial_reader_seen`, `tutorial_wird_seen`.
- Desktop: `desktopSidebarVisibleProvider` state. No MethodChannels, haptics or direct Firestore calls in this folder.

## Subdirectories & System Boundaries
- None (flat directory).

## Global Invariants
- Prefs keys `quran_bookmarks`, `quran_reading_progress`, `wird_*` and the tutorial flags are contracts
  ([prefs-keys](/.project-docs/contracts/prefs-keys.md)); Firestore path in
  [firestore-paths](/.project-docs/contracts/firestore-paths.md).
- Bookmark colors (`BookmarkColor.name`: red / orange / green) are shared with Wird's `linkedBookmarkColor`.

## Global Side Effects
- Wird state (local and Firestore) and Wird reminder notifications through `WirdService`; bookmark and progress prefs;
  the SVG page cache on disk.

## System Verification
- Run: `flutter test` (no tests cover these screens). Manual checks: `.project-docs/reference/device-checklist.md`.
- Known issues: findings F38 (verified) and F39 (scout backlog).
