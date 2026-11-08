# Fix: split the Prayer Calculation dialog (F57)

Status: APPROVED (user 2026-11-08, "approve phase F57") · Level C · branch `fix/ui-1.1.0` (F58 + F57, one PR) ·
release 1.1.0 · no EGM review · supersedes F49k

## Problem
One dialog (`PrayerCalculationSettingsDialog`) holds 12 methods and the Asr madhab. Both tiles on the prayer settings
page open it (`prayer_screen.dart:1486, :1517`), and the Settings tab has a single combined tile
(`settings_screen.dart:95–118`) whose subtitle shows raw values (`MuslimWorldLeague · Shafi`). Every tap saves at
once.

## Fix
- Two dialogs in `lib/features/settings/` replace `prayer_calculation_settings_dialog.dart`:
  - `CalculationMethodDialog`: the 12 `AdhanCalculationMethod` options only.
  - `AsrMadhabDialog`: Shafi and Hanafi only.
  Both keep today's look (header, radios, localized names and descriptions, scroll when needed).
- Behavior: a tap moves the radio only. "Done" closes and returns the chosen value. The close (X) button or back
  closes and returns nothing. API: `static Future<String?> show(context, current)`.
- Done without a change saves nothing and does not recalculate. Callers save only when Done returns a value different from the current one. They save with the same keys and values
  as today, then recalculate through the same FX-0 path:
  - Prayer settings page: `_saveCalculationSettings()` (drop its `Navigator.pop`, since the dialog closes itself).
  - Settings tab: `setString` + `_recalculatePrayerTimes()`, as today.
- Settings tab: two tiles, "Calculation Method" and "Asr Madhab". The prayer settings page keeps its two tiles.
- Subtitles everywhere: the localized current choice (`getLocalizedName(isArabic)`, e.g. "Muslim World League" /
  "رابطة العالم الإسلامي", "Shafi …" / "شافعي …").
- Every UI string touched goes through `.tr()`, in both `en.json` and `ar.json`: dialog titles, Settings tile titles and "Done". Method/madhab names stay as they are (localization group later).
- No contract change: keys `calculation_method` / `asr_madhab` and the stored values (`MuslimWorldLeague`, `Shafi`, …)
  are unchanged.

## Tests (widget; replace `test/features/settings/prayer_calculation_settings_dialog_test.dart`)
For each dialog:
- The current value's radio is selected, and the other section is absent (no madhab in the method dialog, no
  methods in the madhab dialog).
- A tap moves the radio and nothing is returned yet.
- Done returns the chosen value once and closes the dialog.
- Close (X) returns null and closes.
- The method dialog scrolls on a small screen (keeps the F49c guarantee).

## File boundary
- `lib/features/settings/`: two new dialog files; delete `prayer_calculation_settings_dialog.dart`; `settings_screen.dart`.
- `lib/features/prayer/prayer_screen.dart` (the tiles and `_saveCalculationSettings` of `PrayerSettingsPage`).
- `assets/translations/en.json`, `ar.json`; the tests above.
- Docs: `lib/features/settings/README.md`, `lib/features/prayer/README.md`, `.project-docs/` (findings F57, F49k, STATE, log).

## Verification
`flutter analyze` (no new issues), `flutter test`, a debug build on every commit. Device check after both fixes merge:
change the method and the madhab from both places; check that alarms follow (`dumpsys alarm`), and that close/back
changes nothing.

## Commits (on `fix/ui-1.1.0`, after F58 commits 1–2)
3. Add the two dialogs + translations + tests (callers not yet switched).
4. Switch the prayer settings page and the Settings tab, and delete the old dialog and its test.

## After both fixes merge
Merge `main` into `release/1.1.0` (resolve STATE/log conflicts in favor of main's wording plus the release facts), rebuild 1.1.0+60 (AAB + APK), verify the certificate, install in place, then the
user tests on the phone.
