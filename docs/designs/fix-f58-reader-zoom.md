# Fix: Quran reader zoom buttons in the bottom bar (F58)

Status: APPROVED (user 2026-11-08, "approve phase F58") · Level C · branch `fix/ui-1.1.0` (F58 + F57, one PR) ·
release 1.1.0 · no EGM review

## Problem
On mobile, the A+/A− box is a floating overlay at a fixed `Positioned(right: 16, bottom: 80)`
(`quran_reader_screen.dart:555–563`, widget `_MobileZoomControls` `:1573`). On the nova 5T (360 dp, normal font),
page 122 shows it covering the start of the last two lines (ayah 89–90). Device VERIFIED (user screenshot).

## Fix
- Move A− and A+ into the reader's bottom bar, around the page counter: `←  A−  122 / 604  A+  →`.
  The row mirrors in Arabic (RTL), exactly as the arrows already do.
- Remove the floating overlay and the `_MobileZoomControls` widget.
- Same zoom steps as today: A+ → `_mushafCtrl.zoom(1.25)`, A− → `_mushafCtrl.zoom(0.8)`. The limits stay where they
  are, in `_MushafPage` (clamp to `minScale` / `_computedMaxScale`). Pinch-to-zoom is unchanged.
- Mobile only: the bar shows A−/A+ only when zoom callbacks are passed. Desktop passes none (it keeps
  `_DesktopControls`), so the desktop bottom bar is unchanged.
- The buttons show with the bar (`_showUI`), as the overlay did. Labels stay the glyphs "A−" / "A+"; no new strings.
- For a widget test: move `_BottomBar` to a new public widget `QuranReaderBottomBar`
  (`lib/features/quran/quran_reader_bottom_bar.dart`), with optional `onZoomIn` / `onZoomOut`. Its layout is otherwise
  unchanged: same padding, colors, arrows and Arabic numerals via `NumberFormatter`.

## Tests (widget, `test/features/quran/quran_reader_bottom_bar_test.dart`)
- With zoom callbacks: A− and A+ are shown, and each tap fires its own callback once.
- Without zoom callbacks (desktop): no A−/A+ is shown, and the arrows plus counter are unchanged.
- Counter text `122 / 604`. Prev disabled on page 1 and next disabled on page 604 (callbacks null).
- At 360 dp width, in both LTR and RTL: no overflow, and all five controls are visible.

## File boundary
- `lib/features/quran/quran_reader_screen.dart`, new `lib/features/quran/quran_reader_bottom_bar.dart`, new test file.
- Docs: `lib/features/quran/README.md`, `.project-docs/` (findings F58, STATE, log).
- No contract, prefs, or translation changes.

## Verification
`flutter analyze` (no new issues), `flutter test`, a debug build on every commit. Device check after both fixes merge:
page 122 on the nova 5T, where A−/A+ must sit in the bar and cover no text, and zoom in/out must still be limited as
today.

## Commits (on `fix/ui-1.1.0`, before F57 commits 3–4)
1. Extract `QuranReaderBottomBar` unchanged + tests for the current behavior.
2. Add A−/A+ to the bar, remove the overlay, and add the zoom tests.
