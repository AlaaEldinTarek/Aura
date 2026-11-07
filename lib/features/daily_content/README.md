# Daily Content Feature

## Overview
One stateless screen, `daily_content_screen.dart` (route `/daily_content`, opened from the Home daily verse/hadith
card; the desktop shell builds it in `main_wrapper_screen.dart`). It shows today's item from
`DailyContentService.getToday()` ([services](../../core/services/README.md)) in full: Arabic text, translation and
source. Behavior-preserving rule: no UI or logic change without an approved spec.

## Interface
| File | Public symbols / entry points |
| --- | --- |
| `daily_content_screen.dart` | `DailyContentScreen()` (no params, `StatelessWidget`) |

- Reads `DailyContentService.instance.getToday()` → `DailyContent` (`type`, `arabic`, `translation`, `source`).

## Invariants
- **Same item as Home**: both call `getToday()`, which picks `_content[dayOfYear % length]` from a hard-coded list,
  so the choice changes at local midnight. The screen reads it once per build (no timer, no provider).
- **Type styling**: `DailyContentType.ayah` → teal accent, "📖 Verse of the Day"; `hadith` → gold accent,
  "📜 Hadith of the Day". Title strings are inline `isArabic ? '…' : '…'` (no `.tr()`).
- **Text**: `arabic` is always right-aligned and not text-scaled (`TextScaler.noScaling`, fixed `ts.scale(22)`).
  `translation` and `source` exist only in English and are shown in both languages (right-aligned in Arabic UI).

## Side Effects
- None (no I/O, no state). Only entry animations (`flutter_animate`).

## Verification
- Run: `flutter test` (no tests for this folder). Known issues: findings F43.
