# Core Utils Blueprint

## System Overview
Small stateless helpers (7 files, flat): number/date/time formatting, Hijri dates, prayer timing rules, haptics and
image sharing. Mostly pure static functions; the exceptions are haptics (prefs + platform), `canMarkPrayer` (shows a
SnackBar) and `captureAndShare` (files + share sheet). CLAUDE.md rules that live here: Arabic numerals go through
`NumberFormatter`, and prayer display names go through `getPrayerDisplayName`.

## Local Interface & Invariants

### Interface
| File | Public API |
| --- | --- |
| `number_formatter.dart` | `NumberFormatter.withArabicNumerals(text)`, `withArabicNumeralsByLanguage(text, languageCode)` |
| `date_formatter.dart` | `DateFormatter`: `formatDate`, `formatDateWithMonth`, `getDayName`, `formatTimeRange`, `formatTime`, `formatTime24`, `isToday`, `isTomorrow`, `getRelativeDateString` |
| `time_formatter.dart` | `TimeFormatter`: `formatDuration`, `formatRemaining`, `formatTime12h`, `formatTime24h`, `parseTime` |
| `hijri_date.dart` | `HijriDate`: `toHijri(date)`, `getMonthNameAr` / `getMonthNameEn`, `formatAr` / `formatEn` |
| `prayer_time_rules.dart` | top-level `getPrayerDate`, `isPrayerTimeReached`, `canMarkPrayer`, `getPrayerDisplayName` |
| `prayer_refresh.dart` | pure helpers for the prayer-times refresh (no Flutter imports): `sideEffectsFingerprint`, `cacheDays` (calendar days), `buildNativeCache` (`cached_{yyyy-MM-dd}_{name}`), `nextOccurrences`, `postChecksToSchedule`, `isLatest`; tests in `test/core/utils/prayer_refresh_test.dart` |
| `haptic_feedback.dart` | app `HapticFeedback` (shadows Flutter's): `light`, `medium`, `heavy`, `selection`, `notify`, `success`, `error`, `warning`, `buttonPress`, `toggle`, `cardTap`, `isVibrationEnabled`, `isSimplifiedMode` |
| `share_util.dart` | top-level `captureAndShare(key, filename)` |
| `start_route.dart` | pure start-up routing rules (spec fix-signin-onboarding): `resolveStartRoute`, `resolvePostAuthRoute`, `resolveSplashRoute` (null while auth / guest / first-launch is loading); tests in `test/core/utils/start_route_test.dart` |
| `app_language.dart` | `applyAppLanguage(code, setLocale:, setLanguage:, isMounted:)`: EasyLocalization locale first (awaited), mounted check, then `languageProvider` (F61; used by Settings and onboarding); tests in `test/core/utils/app_language_test.dart`, `test/features/settings/language_switch_test.dart` |
| `window_size.dart` | desktop window rules (F63): `adaptiveWindowSize(workArea)`, `fitMinimumSize`, `desktopTextScale(w, h)` (pure, tested in `test/core/utils/window_size_test.dart`), `currentWorkArea()` (window_manager `calcWindowPosition`, monitor under the cursor) |

### Invariants
- **Arabic numerals**: `withArabicNumerals` maps ASCII `0–9` to Arabic-Indic `٠–٩`; `withArabicNumeralsByLanguage`
  converts only when `languageCode == 'ar'`. Already localized: `DateFormatter.formatTime` / `formatTime24` and
  `TimeFormatter.formatDuration` / `formatRemaining`. Return **raw digits** (callers must wrap): `formatDate`,
  `formatDateWithMonth`, `formatTimeRange`, `formatTime12h`, `formatTime24h`, `HijriDate.formatAr` / `formatEn`.
- **Time formats**: `DateFormatter.formatTime` is 12 h, zero-padded, `ص` / `م` in Arabic. `TimeFormatter.formatTime12h`
  is 12 h, unpadded, English AM/PM only. Both are in use, so keep each caller on its current formatter.
- **Hijri**: `toHijri` is an arithmetic approximation (not Umm al-Qura); it returns `{'year': String, 'month': int, 'day': String}`.
- **Prayer day** (`getPrayerDate`): before today's Fajr → yesterday's date; otherwise today (midnight-normalized).
- **20-minute rule**: `isPrayerTimeReached` / `canMarkPrayer` allow marking only from adhan + 20 min. An unknown prayer
  name or empty list returns `true`. `canMarkPrayer` shows an orange SnackBar when it blocks.
- **Display names**: `getPrayerDisplayName` maps `Zuhr` and `Dhuhr`; on a Friday (by today's date, `DateTime.now()`)
  either becomes Jumu'ah / الجمعة. Otherwise English returns the name unchanged.
- **Haptics gating** (prefs `vibration_enabled` default **false**, `vibration_simplified` default **true**):
  `light` / `selection` / `success` / `buttonPress` / `toggle` / `cardTap` need enabled and not simplified; `medium` /
  `warning` need enabled only; `heavy` / `error` / `notify` always fire (by design: "error feedback is critical").
- **Start routes**: guest or signed in → `/onboarding` on first launch (`first_launch` true) else `/home`; otherwise
  `/login`. After sign-in / sign-up / guest: first launch → `/onboarding`, returning user → `/home`. Splash: auth
  error → `/login`; guest / first-launch error → not guest / first launch.
- **Sharing**: renders the widget at 3× to PNG in the temp dir. Mobile opens the share sheet; Windows copies the file to
  Documents and opens Explorer; macOS uses `open`.

### Side Effects
- SharedPreferences reads: `vibration_enabled`, `vibration_simplified`.
- MethodChannel `flutter/vibration` (`vibrate`, from `notify()`): no Android handler found — findings F23.
- Flutter `HapticFeedback` impacts; `ScaffoldMessenger` SnackBar (`canMarkPrayer`).
- `captureAndShare`: temp/Documents file writes, `share_plus` share sheet, `Process.run('explorer' | 'open')`.

## Subdirectories & System Boundaries
- None (flat directory).

## Global Invariants
- The 20-minute rule here also drives `DailyPrayerStatusNotifier.markDate` (providers) and
  `cleanupFuturePrayerRecords` (services; findings F19). Change all three together.

## Global Side Effects
- None beyond the above.

## System Verification
- Run: `flutter test` (`test/core/utils/formatters_test.dart`, `prayer_models_test.dart`).
