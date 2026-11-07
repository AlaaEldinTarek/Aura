# Islamic Events Feature

## Overview
One screen, `islamic_events_screen.dart` (route `/islamic_events`, opened from the Home event card; the desktop shell
builds it in `main_wrapper_screen.dart`). It lists every event in `IslamicEventsService.events` with its next
Gregorian date, Hijri date and a countdown. Data comes from `islamicEventsProvider`
([providers](../../core/providers/README.md)) → `IslamicEventsService.getUpcomingEvents`
([services](../../core/services/README.md)). Behavior-preserving rule: no UI or logic change without an approved spec.

## Interface
| File | Public symbols / entry points |
| --- | --- |
| `islamic_events_screen.dart` | `IslamicEventsScreen()` (no params, `ConsumerWidget`). Private: `_EventCard` |

- Watches `islamicEventsProvider` (`List<IslamicEventWithDate>`: `event`, `date`, `daysUntil`).
- Uses `HijriDate.toHijri` / `formatAr` / `formatEn` ([utils](../../core/utils/README.md)).

## Invariants
- **Order and dates come from the service**: for each event it scans today … today + 400 days for the first day whose
  computed Hijri month/day matches, then sorts by `daysUntil`. Dates are arithmetic (`HijriDate`), not moon-sighted.
- **Computed once**: `islamicEventsProvider` is a plain `Provider` (no autoDispose, no date dependency), so the list
  and `daysUntil` are fixed for the app process. Home's event card reads the same provider.
- **Countdown badge**: 0 → "Today!" (green), 1 → "Tomorrow", ≤ 7 → amber with highlighted border/shadow, ≤ 30 →
  primary, else grey. The day count goes through `NumberFormatter.withArabicNumeralsByLanguage`.
- **Language**: name and description use `nameAr`/`descriptionAr` or `nameEn`/`descriptionEn`; title and empty
  state use `events_title` / `events_no_events`; countdown words are inline `isArabic ? '…' : '…'`.
- **Unused**: the local `isDesktop` (and its `Platform` / `kIsWeb` imports) is computed but never read.

## Side Effects
- None (pure computation; no I/O, notifications or prefs).

## Verification
- Run: `flutter test` (no tests for this folder). Known issues: findings F45.
