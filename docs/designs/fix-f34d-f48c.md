# Fix spec: F34d + F48c — platform guards for two channel/stream calls

Status: Decisions made 2026-11-28 (no timeout; Arabic text approved) — awaiting `approve phase P1`

Branch: `fix/f34d-f48c` (from main 505a540). Tag: fix track P2 (platform guard). Source: `reference/findings.md` F34(d), F48(c).
Behavior on Android is unchanged. Windows gets a guard and a message instead of an unhandled error / endless spinner.

All checks below are static (source and package code, 2026-11-28). No Windows run was done: runtime impact is UNVERIFIED.

## Finding

### F34d — `setCurrentRoute` called on every platform, unguarded (VERIFIED in source)

- `main_wrapper_screen.dart:790-793`: `_updateCurrentRoute()` calls `_navigationChannel.invokeMethod('setCurrentRoute', …)` with no `try`/`catch`, not awaited.
- Callers run on every tab change (`:137`, `:1123`, `:1340`), also on desktop.
- The handler is registered only on Android (`:245`: `if (!kIsWeb && Platform.isAndroid)`), and the channel `com.aura.hala/navigation` exists only in `MainActivity.kt:294`. `windows/` has no match (searched).
- So on Windows each call returns a Future that fails with `MissingPluginException`. Nobody handles it → unhandled async error in the log on every tab change. UI impact: none seen from code (UNVERIFIED on device).
- CLAUDE.md rule broken: "Platform channels: always `try-catch`".

### F48c — endless spinner when no compass events arrive (VERIFIED in source and package)

- `qibla_screen.dart:93-129`: `_isLoading` becomes false only inside the compass listener; there is no `onError` and no fallback.
- `flutter_compass 0.8.1` (pub cache) declares only `android` and `ios` in its `pubspec.yaml`. Its `events` getter returns a non-null stream on every non-web platform, so the `?.` at `:93` never protects anything.
- On Windows the stream has no native side: listening fails with `MissingPluginException` as a stream error. With no `onError` that is an unhandled error, and `_isLoading` stays true → spinner forever.
- The screen is reachable on Windows: route `/qibla` exists in the desktop shell (`main_wrapper_screen.dart:1509`) and `prayer_screen.dart:462,855` push it. Whether the entry is visible on desktop: UNVERIFIED.
- An Android phone with no magnetometer: UNVERIFIED whether the plugin emits an error or nothing (Android plugin source not read).

## Fix (phase P1, one commit per finding)

### F34d

```dart
void _updateCurrentRoute() {
  if (kIsWeb || !Platform.isAndroid) return;   // same condition as the handler at :245
  final route = _currentIndex == 0 ? '/home' : '/tab/$_currentIndex';
  _setCurrentRoute(route);
}

Future<void> _setCurrentRoute(String route) async {
  try {
    await _navigationChannel.invokeMethod('setCurrentRoute', {'route': route});
  } catch (e) {
    debugPrint('🧭 setCurrentRoute failed: $e');
  }
}
```

Channel name, method name and argument are untouched; Android sends exactly the same call. No contract file changes.

### F48c

In `_initializeCompass` (`qibla_screen.dart`):

1. At the top of `_initializeCompass`, before the location request, if the platform has no compass plugin (`kIsWeb || !(Platform.isAndroid || Platform.isIOS)`), set `_errorMessage = 'qibla_compass_unavailable'.tr()`, `_isLoading = false`, and return. The existing error view (`_buildErrorState`) shows it.
2. Add `onError` to `listen`: set the same error message and `_isLoading = false` (guarded by `mounted`).
3. Both translation files get one new key, in the same position:
   - `en.json`: `"qibla_compass_unavailable": "Compass is not available on this device"`
   - `ar.json`: `"qibla_compass_unavailable": "البوصلة غير متوفرة على هذا الجهاز"` (Arabic wording is a draft for the owner to review)

The Retry button of the error view stays; on Windows it re-shows the same message (harmless). The compass listener body, the vibration code and `_buildInstructions` are not touched.

## Decisions (owner)

**Answered 2026-11-28:** (1) no timeout in this fix; (2) Arabic text approved as written.

1. Android phone with no compass sensor: add a timeout (e.g. 10 s without any event → same message), or leave as is? The risk of a timeout is a false error on a slow first event. Recommended: **no timeout in this fix**; measure first (the plugin behavior with no sensor is UNVERIFIED).
2. Arabic text of `qibla_compass_unavailable` — approve or change.

## Files changed

- `lib/features/main/main_wrapper_screen.dart` (F34d)
- `lib/features/qibla/qibla_screen.dart` (F48c)
- `assets/translations/en.json`, `assets/translations/ar.json` (new key)
- new `test/features/main/f34d_source_test.dart`, `test/features/qibla/f48c_source_test.dart`
- `.project-docs/STATE.md` after merge (docs, separate branch)

## Verification

- `flutter analyze`, `flutter test` (pass/fail only). New tests, same style as `f34e_source_test.dart`:
  - F34d: `_updateCurrentRoute` contains the Android guard before `invokeMethod`, and the call sits inside a `try`/`catch`.
  - F48c: the screen source has a platform check and an `onError`; both JSON files have the key and the same key set (the existing key-parity test still passes).
- Build both targets, as the desktop rule requires: `flutter build apk --release …` and the Windows build (`modules/desktop.md`). Not run until approved.
- Device (owner-observed): Windows — open Qibla from the prayer screen: the message shows instead of a spinner; switching tabs prints no `MissingPluginException`. Android — Qibla and tab switching behave as before (compass, vibration, widget-tab handoff).

## Risks

- Android: the F34d guard is true on Android, so the call is identical. The only difference is a swallowed exception, which today would be unhandled anyway.
- The F48c early return runs before the location request on Windows, so Windows no longer asks for a location on this screen. Today that location is used only to compute the bearing, which is useless without a compass (VERIFIED in `_initializeCompass`).
- iOS is disabled in this project; the iOS branch of the platform check is kept only to mirror the plugin's supported platforms.
