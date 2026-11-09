# Fix: unreadable prefs file leaves a white window on Windows (F62)

Status: APPROVED (user 2026-11-09, "approve phase F62" with two spec additions + byte-for-byte test) · Level C · branch `fix/f62-corrupt-prefs` · finding `reference/findings.md` F62 · no EGM review

## Problem
On Windows, `shared_preferences_windows` (2.4.1) stores prefs in `<ApplicationSupport>\shared_preferences.json`
(`%APPDATA%\com.aura\aura_app\` for the unpackaged exe; the MSIX build gets a virtualized copy of the same path).
Its `_readFromFile` (`shared_preferences_windows.dart:349–370`): an empty file or valid JSON that is not an object →
empty prefs (handled); **invalid JSON → `FormatException`**; invalid UTF-8 → exception from `readAsStringSync`.

Start-up then fails. Prefs readers in `main()`, in order (code VERIFIED):
1. `main.dart:94` `WindowsStartupService.registerIfEnabled()` (not awaited) → `isEnabled()` →
   `SharedPreferences.getInstance()` (`windows_startup_service.dart:19`) — **the first prefs read**.
2. `:119` `EasyLocalization.ensureInitialized()` (reads the saved locale from prefs).
3. `:129` `SharedPreferencesService.getInstance()` → `SharedPreferences.getInstance()`; the `catch` at `:132–136`
   retries the same call, which throws again outside any `try`, so `main()` stops before `runApp` and the window stays
   white. (Nothing before line 94 reads prefs: `WidgetsFlutterBinding.ensureInitialized()` and `windowManager` setup.) Device VERIFIED 2026-11-09 (S36 Windows): the file was 1867 zero
bytes; renaming it let the app start. Android stores prefs in XML through the platform (not affected by this path).

## Fix
- New `lib/core/services/prefs_file_recovery.dart` with one function:
  `Future<String?> backUpUnreadablePrefsFile(Directory dir, {DateTime? now})`.
  - Looks at `dir/shared_preferences.json`. Missing → `null`. Reads it as UTF-8; empty → `null` (the plugin handles it).
    `jsonDecode` succeeds (any JSON) → `null` (the plugin handles non-objects).
  - Read fails or `jsonDecode` throws → rename the file to
    `shared_preferences.json.unreadable-<yyyyMMdd-HHmmss>.bak` (local time, `now` for tests; add `-1`, `-2`… if that name
    exists) and return the backup path. Never deletes; never throws (errors are caught and logged, returns `null`).
- `main.dart`, **Windows only** (`!kIsWeb && Platform.isWindows`): inserted right after line 59
  (`final isStartup = …`) and before the desktop window block at line 61, so it runs **before every prefs read**
  (line 94 `registerIfEnabled`, line 119 EasyLocalization, lines 129/135 `SharedPreferencesService`):
  `await backUpUnreadablePrefsFile(await getApplicationSupportDirectory())` in a `try`; if it returns a path, log
  `⚠️ [PREFS] Unreadable prefs file backed up: <path>`. It is awaited, so nothing else starts before it finishes.
- **Same folder as the plugin:** `shared_preferences_windows` calls `PathProviderWindows().getApplicationSupportPath()`
  (`shared_preferences_windows.dart:339–340`). `path_provider`'s `getApplicationSupportDirectory()`
  (`path_provider.dart:77–78`) calls `PathProviderPlatform.instance.getApplicationSupportPath()`, and on Windows that
  instance is `PathProviderWindows` (`path_provider_windows_real.dart:75–76`, method `:119–120`, RoamingAppData +
  company/product subfolder). Same class and method, so the same file, also under MSIX (the virtualization applies to
  both calls in the same process). `path_provider` is already a direct dependency; `path_provider_windows` is not, so
  importing it directly would need a `pubspec` change, which is avoided. The app then starts like a fresh install (the old values were
  unreadable anyway). A healthy file is not touched, so normal start-up behavior is unchanged.
- No other start-up change (the retry in the `catch` at `:132–136` stays; with the file moved aside it succeeds).
  Android, macOS, Linux and web are unchanged (guarded).

## Tests (written first; new `test/core/services/prefs_file_recovery_test.dart`, temp directory per test)
- Healthy file with data (a JSON object with several `flutter.*` keys: string, bool, int, list) → returns `null`;
  file bytes are **byte-for-byte identical** before and after, the modified time is unchanged, and no other file
  appears in the folder.
- File of 1867 zero bytes (the device case) → returns a path ending `.unreadable-20261109-095000.bak` (fixed `now`),
  original file gone, backup has the same bytes.
- Invalid UTF-8 bytes → backed up.
- Empty file → `null`, unchanged. Valid JSON that is not an object (`[]`) → `null`, unchanged. No file → `null`.
- Backup name already exists → new name with `-1`; the existing backup is not overwritten.
Commit 1 adds the function and the tests; it has no caller yet (no behavior change). The tests are new (no "before"
version of the function), so the bug evidence is the device log `logcat/S36-windows-blank-2026-11-09.txt`.

## File boundary
- Production: new `lib/core/services/prefs_file_recovery.dart`; `lib/main.dart` (one guarded call after line 59,
  plus imports).
- Test (new): `test/core/services/prefs_file_recovery_test.dart`.
- Docs: `.project-docs/reference/findings.md` (F62), `.project-docs/reference/device-checklist.md` (new S37),
  `.project-docs/contracts/log-tags.md` (`[PREFS]`, Dart only), `.project-docs/modules/desktop.md`, `.project-docs/STATE.md`,
  `.project-docs/log/<date>.md`, `lib/core/services/README.md`, `lib/features/README.md` (documents `main.dart`;
  there is no `lib/README.md`). `[PREFS]` is a new tag (no current use in `lib/`).
- Not touched: `shared_preferences_service.dart`, Kotlin, `pubspec.*` (`path_provider` is already a dependency),
  prefs keys, translations.

## Verification
- `flutter test` (all pass), `flutter analyze` (0 new issues on changed lines), `dart format` on new files.
- Builds: release APK (guard: no Android change) and Windows release.
- Windows device check, new **S37** (unpackaged release exe):
  1. Copy the saved zeroed file back: `shared_preferences.json.zeroed-2026-06-30.bak` →
     `%APPDATA%\com.aura\aura_app\shared_preferences.json`.
  2. Launch → the app starts (no white window); log shows `⚠️ [PREFS] Unreadable prefs file backed up: …`; a
     `.unreadable-….bak` file exists; prefs start fresh.
  3. Close and launch again (healthy file now) → starts normally, no new backup file.
- Android: install the release APK in place → app starts with settings kept (regression only).
- Record results in the device checklist and log. Do not mark PASS unless the check ran.

## Commits
1. Add `backUpUnreadablePrefsFile` + tests (no caller).
2. Call it on Windows before start-up reads prefs.
3. Docs.
