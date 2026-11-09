# F61: language switch reaches all translated text at once

Spec: `docs/designs/fix-f61-nav-language.md` (approved 2026-11-09). Finding fixed: F61.

## What changes
- `MaterialApp.locale` follows `languageProvider`; easy_localization's delegate installs the controller's current
  translations when that locale changes and never reloads. Settings changed the provider before `setLocale`, so every
  `.tr()` text (e.g. the bottom nav / sidebar) stayed one language behind until a restart.
- New `applyAppLanguage()` (`lib/core/utils/app_language.dart`): awaits `setLocale` first, checks the context is still
  mounted, then updates the provider.
- Used by every runtime language writer: the Settings language dialog (screen context, not the closing dialog's) and
  onboarding `_finish` (same bug path). Profile's language dialog has no callers (F47e) and is unchanged;
  `clearUserData` / `restorePreferences` have no callers.

## Commits
| # | Commit |
| --- | --- |
| 1 | 28c42f4 Add F61 language switch spec |
| 2 | 46ee725 Add applyAppLanguage for correct language switch order (F61) |
| 3 | e0026de Switch language with locale first in Settings and onboarding (F61) |
| 4 | docs commit (findings, S38, STATE, READMEs, log, this description) |

No prefs key, UI, text, `main.dart`, Kotlin or `pubspec.*` changes.

## Verification
- `flutter test`: 205 pass (+6 new: unit test for order / waiting / unmounted / two switches; widget test with the real
  EasyLocalization wiring that reproduces F61 with today's order and passes with `applyAppLanguage`, both ways, twice).
- `flutter analyze`: 418 issues, 0 new vs base.

## Device check S38 (2026-11-09)
| Device | Result |
| --- | --- |
| Phone (nova 5T, release) | PASS: 8 switches logged, bottom nav followed each at once |
| Windows (unpackaged release) | PASS: sidebar followed each switch at once |
| Onboarding: choose Arabic during onboarding | Not run |

**Not verified on device:** the onboarding language path. Onboarding `_finish` calls the same `applyAppLanguage`
helper, whose order (locale first, mounted check, then provider) is covered by the unit and widget tests; the onboarding
call site itself has no test of its own and was not checked on a device.

## Known issue, not caused by this fix
- **F63 (MEDIUM):** at 150% Windows display scaling the window is taller than the screen and the top is cut off.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
