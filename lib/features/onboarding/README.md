# Onboarding Feature

## Overview
The first-run setup wizard. `preference_screen.dart` is the live flow (route `/onboarding`): Splash opens it on first
launch, and Login/Signup open it after a sign-in only on the first launch on this device; returning users go to
`/home` ([auth](../auth/README.md)). It collects language,
theme and app mode, shows a mode-specific feature carousel, saves through the preference providers
([providers](../../core/providers/README.md)) and replaces itself with `/home`. `mode_selection_screen.dart` is an
older standalone mode picker that nothing navigates to. Behavior-preserving rule: no UI or logic change without an
approved spec.

## Interface
| File | Public symbols / entry points |
| --- | --- |
| `preference_screen.dart` | `PreferenceScreen()` (route `/onboarding`). Private: `_PreferenceScreenState`, step widgets `_LanguageStep`, `_ThemeStep`, `_ModeStep`, `_CarouselStep`, `_AllSetStep` (+ `_Slide`, `_Feature`, `_LangCard`, `_ThemeOpt`, `_ModeOpt`, `_SlideView`, `_SummaryItem`) |
| `mode_selection_screen.dart` | `ModeSelectionScreen()` (route `/mode_selection` in `main.dart`; no caller found). Private: `_ModeOption` |

- Writes (in `_finish`, in this order): `languageProvider.setLanguage`, `themeModeProvider.setThemeMode`,
  `appModeProvider.setMode`, `firstLaunchProvider.setFirstLaunch(false)`, `RatingService.recordInstallDateIfNeeded`.

## Invariants
- **Steps** (`_totalSteps = 5`): 0 language → 1 theme → 2 mode → 3 carousel (3 slides per `AppMode`) → 4 summary.
  `_next` / `_back` move one slide or step; `_navigating` blocks taps during the 350–410 ms page animation.
  Swiping is disabled (`NeverScrollableScrollPhysics`); there is no `PopScope`, so system back leaves the route.
- **Defaults are fixed, not read from current settings**: `_language = 'en'`, `_theme = 'system'`,
  `_mode = AppMode.both`. "Skip" (step 0 only) calls `_finish` with whatever is selected. Safe since F46a: only users
  without a finished onboarding on this device (`first_launch` true) reach this screen, and their saved values are
  still the defaults.
- **Wizard language**: onboarding text follows the selected `_language` (`_isAr`), not the app locale; strings are
  inline EN/AR pairs (no `.tr()`). The app locale changes only when `_finish` saves.
- **Finish**: after saving, requests `Permission.notification` on Android/iOS only, then
  `pushReplacementNamed('/home', result: true)`. Any exception is swallowed (`catch (_) {}`) and the user stays on
  the screen. `result: true` completes Login's awaited guest push so Login keeps guest mode (F41a).
- **`ModeSelectionScreen`** (unused): tapping a card writes `appModeProvider.setMode` immediately; "Get Started" →
  `/home`.

## Side Effects
- SharedPreferences through the providers: language, theme mode, `app_mode`, first-launch flag, rating install date.
  `setLanguage` also refreshes prayer widgets / notification language.
- Runtime notification permission prompt (Android 13+ / iOS) at finish.

## Verification
- Run: `flutter test` (no tests for this folder). Known issues: findings F46.
