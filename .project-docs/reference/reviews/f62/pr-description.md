# F62: start on Windows even when the prefs file is unreadable

Spec: `docs/designs/fix-f62-unreadable-prefs.md` (approved 2026-11-09). Finding fixed: F62.

## What changes
- An unreadable `shared_preferences.json` (invalid JSON or invalid UTF-8; seen: 1867 zero bytes) made every prefs read
  throw, and the retry in `main.dart` escaped `main()` before `runApp`: white window, no recovery.
- New `backUpUnreadablePrefsFile(dir)` (`lib/core/services/prefs_file_recovery.dart`) renames such a file to
  `shared_preferences.json.unreadable-<yyyyMMdd-HHmmss>.bak` (never deletes, never overwrites, never throws). Missing,
  empty and any valid JSON files are left alone.
- `main.dart`, **Windows only**, right after line 59 and before the first prefs read (`registerIfEnabled`, line 94):
  calls it with `getApplicationSupportDirectory()`, which resolves through `PathProviderWindows.getApplicationSupportPath`,
  the same call the `shared_preferences_windows` plugin uses (same file, also under MSIX). Logs
  `⚠️ [PREFS] Unreadable prefs file backed up: <path>`.

## Commits
| # | Commit |
| --- | --- |
| 1 | 9d21e1a Add F62 unreadable prefs file spec |
| 2 | ac30244 Add backup of an unreadable prefs file (F62) |
| 3 | c2073e2 Back up an unreadable prefs file before start-up on Windows (F62) |
| 4 | ee909af docs: document F62 fix, S37 and Android regression results, add F63 |

No prefs key, Kotlin, `pubspec.*` or translation changes. New Dart-only log tag `[PREFS]`.

## Verification
- `flutter test`: 199 pass (+7 new in `test/core/services/prefs_file_recovery_test.dart`, including the
  1867-zero-byte case and a healthy file left byte-for-byte unchanged).
- `flutter analyze`: no issues on changed lines.

## Device checks (2026-11-09)
| Check | Result |
| --- | --- |
| S37 Windows, zeroed prefs file | PASS: one `[PREFS]` backup line, one `.unreadable-…bak`, normal start-up to Home |
| S37 Windows, relaunch on the healthy file | PASS: no `[PREFS]` line, no new backup |
| Android regression (release APK, data kept) | PASS: normal start-up, no `[PREFS]` line, settings and prayer alarms kept |

## Known issue, not caused by this fix
- **F63 (MEDIUM):** at 150% Windows display scaling the window (fixed 900 × 1400 logical) is taller than the screen and
  the top is cut off; same in the installed MSIX Aura.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
