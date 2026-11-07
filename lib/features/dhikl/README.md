# Dhikr (Tasbeeh) Feature

## Overview
The digital tasbeeh: a counter screen, a stats screen and a custom-zikr form. (The folder name `dhikl` is a
historical typo; imports depend on it, so it is not renamed.) Opened from the Prayer screen toolkit (`/dhikr`);
the desktop shell builds both routes in `main_wrapper_screen.dart`. Sessions go to Firestore through
`DhikrService` ([services](../../core/services/README.md)); custom presets stay in local prefs.
Behavior-preserving rule: no UI or logic change without an approved spec.

## Interface
| File | Public symbols / entry points |
| --- | --- |
| `dhikr_screen.dart` | `DhikrScreen()` (route `/dhikr`). Private: `_DhikrScreenState` (counter, preset/target sheets, custom preset CRUD) |
| `dhikr_stats_screen.dart` | `DhikrStatsScreen()` (route `/dhikr_stats`, from the counter app bar). Private: `_StatCard` |
| `custom_zikr_form_screen.dart` | `CustomZikrFormScreen({DhikrPreset? existingPreset})`; pops with the new/edited `DhikrPreset` or `null` |

- Uses `DhikrPresets.builtIn`, `DhikrPreset` (`fromJson` / `toJson`), `DhikrSession`, `DhikrStatistics`
  ([models](../../core/models/README.md)) and `DhikrService.recordSession`, `getStatistics`, `getRecentSessions`,
  `getSessionsForDateRange`.

## Invariants
- **Counter state is in memory only**: count, target and selected preset reset when the screen is closed. Start:
  `DhikrPresets.builtIn[0]`, target 33. Target sheet offers 33 / 99 / 100 / 333 / 1000; picking a preset sets
  `target = preset.defaultTarget`. Changing preset or target resets the count.
- **Completion** (`count >= target` in `_incrementCounter`): `_onComplete` records one session
  (`recordSession(userId, dhikrText: preset.displayName, count, target)`, not awaited), vibrates and shows a
  non-dismissible dialog. Both "Start New" and "Continue" end in `_resetCounter` (findings F44).
- **Tap while completed** resets instead of counting. Desktop: Space key = count (`Focus` + `onKeyEvent`).
- **Haptics**: `HapticFeedback` on every tap plus the `vibration` plugin (`hasVibrator` → `vibrate`).
- **Custom presets**: ids `custom_<epochMillis>`; edit keeps the id; delete of the selected preset falls back to
  `builtIn[0]`. Saved as a JSON list after every add/edit/delete. Form: name required, target an integer > 0.
- **Guests**: `DhikrService` skips `guest_user` — sessions are not saved and the stats screen is always empty.
- **Stats**: streak / today / total sessions from `getStatistics`; weekly chart = 7 per-day range queries (oldest
  first, labels `d/M`); recent sessions list. Numbers go through `_n` → `NumberFormatter`.
- **Localization**: all three screens use inline `isArabic ? '…' : '…'`; no `.tr()` keys. The counter, target
  and target-sheet numbers are raw integers (findings F44).

## Side Effects
- Firestore `users/{uid}/dhikr_sessions` — write on each completion, reads on the stats screen (signed-in only).
- SharedPreferences `custom_dhikr_presets` (JSON list) — read on open, written on every preset change.
- Device vibration / haptics.

## Verification
- Run: `flutter test` (no tests for this folder). Known issues: findings F44.
