# Fix: translated text stays one language behind after a language switch (F61)

Status: APPROVED (user 2026-11-09, "approve phase F61" with two spec additions); implemented 46ee725, e0026de · Level C · branch `fix/f61-nav-language` · finding `reference/findings.md` F61 · no EGM review

## Problem
Device VERIFIED (user, nova 5T, 2026-11-09): Settings → Arabic → the bottom nav stays English (also after tapping a
tab); switching back to English then shows the nav in Arabic; a relaunch shows the right language.

Cause (code VERIFIED, easy_localization 3.0.8):
- `MaterialApp.locale` comes from `languageProvider` (`main.dart:416`). EasyLocalization's own locale changes only
  through `context.setLocale`; its `startLocale` (`main.dart:273`) is used once, when the widget is created.
- `_EasyLocalizationDelegate.load(locale)` installs the controller's **current** translations under the new locale,
  and `shouldReload` is always `false` (`easy_localization_app.dart:325–343`).
- Settings' language dialog (`settings_screen.dart:390–407`) calls `languageProvider.setLanguage(v)` **first** →
  `MaterialApp.locale` changes → `load(v)` runs with the **old** translations, so every `.tr()` returns the old
  language. Then `ctx.setLocale(v)` (after `Navigator.pop(ctx)`, on the dialog context) loads the new translations into
  the controller (`easy_localization_controller.dart:193–196`), but the locale has already changed, so `load` is not
  called again. The next switch installs these translations: one change behind. A relaunch rebuilds from `startLocale`.
- Text built from `Localizations.localeOf` / `isArabic` switches correctly, which is why only some text (e.g. the nav,
  which uses `.tr()`) lagged.

## Every place that changes the language (code VERIFIED, `grep` of `languageProvider.notifier`, `setLanguage(`,
`setLocale(`, `keyLanguage` in `lib/`)
| Place | Today | Plan |
| --- | --- | --- |
| `settings_screen.dart:390–407` Settings dialog (2 radio handlers) | provider first, then `ctx.setLocale` after `Navigator.pop(ctx)` | use `applyAppLanguage` |
| `preference_screen.dart:233` onboarding `_finish` | provider only, never `setLocale` (same bug path: Arabic chosen in onboarding → `.tr()` text English until relaunch; not device-checked) | use `applyAppLanguage` |
| `profile_screen.dart:971–1008` `_showLanguageDialog` | provider then `context.setLocale` | not touched: no callers (dead code, F47e) |
| `shared_preferences_service.dart:239–243` `clearUserData`, `:269–281` `restorePreferences` | write the `language` key directly | not needed: no callers in `lib/` |
| Firestore / Kotlin | sign-in never pulls `language` (verified for fix-signin-onboarding); Kotlin only reads it | not needed |

## Fix
- New `lib/core/utils/app_language.dart`:
  `Future<void> applyAppLanguage(String code, {required Future<void> Function(Locale) setLocale,
  required Future<void> Function(String) setLanguage, required bool Function() isMounted})`:
  1. `await setLocale(Locale(code))` (controller loads the new translations; awaited to completion);
  2. `if (!isMounted()) return;` (context check between the two steps);
  3. `await setLanguage(code)` (provider → `MaterialApp.locale` → `load` installs the new translations).
- Settings dialog, both radio handlers: `await applyAppLanguage(v, setLocale: context.setLocale, setLanguage:
  ref.read(languageProvider.notifier).setLanguage, isMounted: () => context.mounted)` using the **screen** `context`
  (stays mounted; not the dialog `ctx`), then `if (ctx.mounted) Navigator.pop(ctx)`. The old `ctx.setLocale` after the
  pop is removed.
- Onboarding `_finish`: replace the `setLanguage(_language)` call with `await applyAppLanguage(_language, setLocale:
  context.setLocale, setLanguage: …, isMounted: () => mounted)`; the existing `if (mounted)` and the rest of `_finish`
  (theme, mode, first launch, permission, `/home` with `result: true`) are unchanged.
- Unchanged: prefs key `language`, `LanguageNotifier.setLanguage` (still refreshes widgets / notification), UI, text,
  `main.dart`.

## Tests (written first)
- `test/core/utils/app_language_test.dart` (unit): with fakes that record calls, `applyAppLanguage('ar', …)` calls
  `setLocale(Locale('ar'))` before `setLanguage('ar')`, and `setLanguage` starts only after `setLocale` completes (the
  fake `setLocale` completes on a `Completer` the test controls). `isMounted` false after `setLocale` →
  `setLanguage` is not called. Two calls in a row (`ar` then `en`) → calls in order `setLocale(ar), setLanguage(ar),
  setLocale(en), setLanguage(en)`.
- `test/features/settings/language_switch_test.dart` (widget): a minimal `EasyLocalization` + `MaterialApp` whose
  `locale` follows a `ValueNotifier<String>` (same wiring as `main.dart`), with the real `assets/translations`, and a
  `Text('home'.tr())`. Old order (notifier first, then `setLocale`) → after `pumpAndSettle` the text is still English
  (reproduces F61). New order via `applyAppLanguage` → Arabic, then back to English → English (switching twice). Needs `SharedPreferences.setMockInitialValues` and
  `EasyLocalization.ensureInitialized()`. If the assets cannot load in the test environment, record the widget test as
  BLOCKED and keep the unit test plus the device check as evidence.

## File boundary
- Production: new `lib/core/utils/app_language.dart`; `lib/features/settings/settings_screen.dart` (`_showLanguageDialog`
  only); `lib/features/onboarding/preference_screen.dart` (`_finish`, the language line only).
- Tests (new): the two files above.
- Docs: `.project-docs/reference/findings.md` (F61), `.project-docs/reference/device-checklist.md` (new S38),
  `.project-docs/STATE.md`, `.project-docs/log/<date>.md`, `lib/core/utils/README.md`, `lib/features/settings/README.md`,
  `lib/features/onboarding/README.md`.
- Not touched: `main.dart`, `preferences_provider.dart`, `bottom_nav_bar.dart`, `profile_screen.dart`, translations,
  prefs keys, Kotlin.

## Verification
- `flutter test` (all pass), `flutter analyze` (0 new issues on changed lines), `dart format` on new files.
- Device, new **S38** (nova 5T release APK, and Windows unpackaged release because desktop uses the same dialog):
  Settings → Arabic → bottom nav (mobile) / sidebar (desktop) labels Arabic at once, no relaunch → Settings → English
  → labels English at once → switch twice in a row (Arabic, English) → labels follow each switch. Restore the user's
  language afterwards. Onboarding path (fresh data: temporary Android user or unpackaged Windows exe with a fresh prefs
  file): choose Arabic in onboarding → Home nav / sidebar Arabic without relaunch (if run).
- Record results in the device checklist and log. Do not mark PASS unless the check ran.

## Commits
1. `applyAppLanguage` + unit test + widget test (the widget test's "new order" case uses the helper; no caller yet).
2. Settings dialog and onboarding `_finish` use `applyAppLanguage`.
3. Docs.
