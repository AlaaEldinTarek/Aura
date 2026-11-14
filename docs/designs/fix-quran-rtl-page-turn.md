# Fix — Quran Reader Turns Pages Right-to-Left in English

*   **Author:** Alaa Eldin Tarek
*   **Status:** Draft (design note written after the change, which is already committed as `ed62d72`)
*   **Date:** 2026-11-14
*   **Branch:** `fix/quran-rtl-page-turn` (off `main` at `827fa5e`)
*   **Area:** `lib/features/quran/` (reader screen and bottom bar). No change to Kotlin, Firestore or prefs.

Labels used below: VERIFIED (checked in code or by a run), UNKNOWN (not checked), GUESS (reasoning, not run).

## Problem

In English the Quran reader turns pages left-to-right: the next page comes in from the right. The Quran is read right-to-left, and Arabic already turns pages that way. The product owner wants English to turn pages like Arabic.

The cause is that `PageView` takes its direction from the app's text direction. English is LTR, Arabic is RTL. (VERIFIED: Flutter's `getAxisDirectionFromAxisReverseAndDirectionality`, `basic.dart:4439`, flips the axis when `reverse` is true, so LTR with `reverse: true` scrolls like RTL without it.)

## The change (as implemented in `ed62d72`)

*   `quran_page_direction.dart` (new):
    *   `readerReversesPages(TextDirection)` is true for LTR (English), false for RTL (Arabic).
    *   `keyPageStep(key, reversed:)` maps desktop arrow keys to +1 (next) or -1 (previous). Not reversed (Arabic, unchanged): right arrow = next. Reversed (English): left arrow = next.
    *   `dragPageStep(dx, reversed:)` maps a desktop mouse drag the same way. Not reversed (Arabic, unchanged): drag left = next. Reversed (English): drag right = next.
*   `quran_reader_screen.dart`: `PageView.builder(reverse: ...)` uses `readerReversesPages(Directionality.of(context))`. The desktop drag and key handlers use `dragPageStep` and `keyPageStep`. The bottom bar gets `reverseNav`.
*   `quran_reader_bottom_bar.dart`: new parameter `reverseNav` (default false). When true, Next is on the left with the back arrow and Previous is on the right with the forward arrow. This matches what Arabic's right-to-left layout already shows. The default keeps every existing caller and test unchanged.

How the direction is decided: from `Directionality.of(context)`, so it follows the app language. (VERIFIED in code.)

## What it affects, and what it does not

| Affected (VERIFIED in code unless noted) | Not affected |
|---|---|
| Swipe direction of the reader, on mobile and desktop | The "n / 604" page-number text |
| Bottom-bar Previous / Next arrows (position and icon) | Arabic behavior, including Arabic desktop keys and drag |
| Desktop arrow keys in English | The other `PageView`s (main tabs, onboarding) |
| Desktop mouse drag in English | Zoom, pinch and the one-finger pan when zoomed in (GUESS: untouched code, not run) |
| Every route into the reader: Surahs list, Juz, Bookmarks, Search, Wird tab (one screen, `QuranReaderScreen`) | Prayer, tasks, sync, prefs, native code |

Not on this branch: the Wird marker ribbon (it is on `feat/wird-marker`). It is placed with `right: 8`, which does not depend on text direction (GUESS, not run).

## Tests

*   Written first: the red run failed on the missing helper file and the missing `reverseNav` parameter. (VERIFIED, shown in the session.)
*   11 tests added in `test/features/quran/quran_page_direction_test.dart` (VERIFIED):
    *   `readerReversesPages` for LTR and RTL.
    *   `keyPageStep`: Arabic keeps right = next; English left = next; other keys do nothing.
    *   `dragPageStep`: Arabic keeps drag-left = next; English drag-right = next; zero movement does nothing.
    *   Bottom bar: English reversed (Next on the left), English default (Previous on the left), Arabic unchanged (Previous on the right), English reversed matches the Arabic layout.
*   Not covered by tests: `PageView(reverse: true)` itself, because it sits inside the large reader screen. Only a device check shows it. (VERIFIED: no test exists.)

| Point | Tests | Analyzer issues |
|---|---|---|
| Baseline on `main` | 273 | 419 |
| This branch at `ed62d72` | 284 | 419 |

Measured when the commit was made (VERIFIED then). Not re-run for this note.

## Device checklist (none run yet: UNKNOWN)

*   **Swipe direction (English):** swiping left-to-right goes to the next page, and the next page comes in from the left.
*   **Bottom-bar arrows (English):** the left arrow (←) is Next and the right arrow (→) is Previous.
*   **Limits:** on page 1, Previous is greyed and swiping that way does nothing. On page 604, Next is greyed and swiping that way does nothing.
*   **Zoomed in:** one-finger drags still pan the page and do not turn it.
*   **Arabic unchanged:** swipe, bottom bar, and nothing else moved.
*   **Entry points:** open the reader from the Surahs list, from Search and from the Wird tab. The direction is the same from each.
*   **Windows:** in English, left arrow = next page and dragging right = next page. Arabic keys and drag are as before.

## Known Issues (existing, outside the scope of this change)

*   **Arabic desktop keys and drag do not match its page direction.** In Arabic the pages slide in from the left for "next", but the right arrow and a left drag mean "next". English now follows its page direction, so on desktop English and Arabic differ in which key goes forward. This was already the case before `ed62d72`. A fix would change Arabic desktop behavior and needs its own decision.

## Decision needed

This note was written after the change was committed. The change touches `lib/` UI behavior, which CLAUDE.md requires a spec for. The product owner gives the go-ahead for this note and for merging; it is not recorded here.
