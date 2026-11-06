# CLAUDE.md

## Context
- **Aura (هالة)**: Flutter + Firebase app combining an Islamic prayer system and task management. Package `com.aura.hala`.
- Version: `pubspec.yaml` (`version:` = Play Store build code; `msix_version` = Windows).
- Platforms: Android (primary; native Kotlin in `android/app/src/main/kotlin/com/aura/hala/`) + Windows desktop. iOS disabled.
- English/Arabic with full RTL; Firebase auth + Firestore sync; guest mode works offline.
- In progress: behavior-preserving senior-level refactor. Current status: `.project-docs/STATE.md`.
- Feature list, structure, routes, init flow, dependencies: `.project-docs/reference/architecture.md`.

## Commands
```bash
flutter run                                   # debug
flutter analyze                               # lint (read-only)
dart format --output=none --set-exit-if-changed .   # format check (read-only)
dart format .                                 # write mode: needs approval level of touched files
flutter test
flutter build apk --release --obfuscate --split-debug-info=build/debug-info        # release APK
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info  # Play Store bundle
adb logcat | grep -E "(PrayerAlarm|NotificationService|PrayerTimes|AdhanPlayer|SilentMode)"
adb logcat | grep "🕌"
```
Windows/MSIX build: `.project-docs/modules/desktop.md`.

## Rules
- **Approval levels**: A docs (`.project-docs/`, `docs/designs/`, READMEs, `CLAUDE.md`) · B tooling (`.claude/`, hooks,
  skills, `analysis_options.yaml`, test infra) needs "approve B" · C production (`lib/`, `android/`, `windows/`,
  `pubspec.*`, `test/` cases) needs an approved spec + "approve phase PN". One level never implies another.
- **Behavior-preserving**: no new features, UI changes, Firestore schema changes, prefs key renames, or
  notification/alarm ID/channel changes unless a spec approves it.
- **Native keys are contracts** (prefs names, MethodChannels, notification IDs/channels, intent extras, Firestore
  paths, log tags): change both Dart and Kotlin + `.project-docs/contracts/` in one commit. Do not modify notification IDs.
- **NEVER launch MainActivity from native code** (`PrayerForegroundService`, `PrayerAlarmReceiver`, …) when azan fires
  or prayer times are stale; use `NativePrayerCalculator.calculateAndSave()`. `AdhanFullScreenActivity` is NOT "the
  app" — it is native notification UI and must keep launching at azan time.
- **Kotlin reading Flutter prefs**: use `FlutterPrefs.kt` (file `FlutterSharedPreferences`, `flutter.` prefix). Never
  `${packageName}_preferences` (Focus Mode only). Details: `contracts/prefs-keys.md`.
- **Dhuhr/Zuhr**: prefs key always `dhuhr_time`; UI shows "Zuhr"; `kPrayerNames` canonical `'Zuhr'`. Every switch/map
  handles both (Dart `case 'dhuhr': case 'zuhr':`, Kotlin `"Dhuhr", "Zuhr" ->`). Display names only via
  `getPrayerDisplayName(name, isArabic:)` (`lib/core/utils/prayer_time_rules.dart`; returns Jumu'ah on Fridays).
- **Strings**: every UI string via `.tr()`; add each key to BOTH `assets/translations/en.json` and `ar.json`.
- **Arabic numerals**: every number in Arabic UI goes through `NumberFormatter.withArabicNumerals('$n')` or
  `withArabicNumeralsByLanguage()`; never interpolate raw integers into Arabic strings (`TimeFormatter` already does it).
- **Platform channels**: always `try-catch`; keep emoji log prefixes and logcat tags (`contracts/log-tags.md`).
- **Edit carefully**: `prayer_times_service.dart`, `prayer_times_provider.dart`, `PrayerAlarmReceiver.kt`, `DailySummaryReceiver.kt`.
- **Zero guessing**: "not found by search" ≠ unused; unknown → mark `UNKNOWN` and ask. Label findings
  `VERIFIED`/`UNVERIFIED`/`BLOCKED`/`UNKNOWN`; never report a build/test/device check as passed unless it ran.
- **Git**: `git status` + diff review before B/C work; never touch pre-existing user changes. Forbidden without explicit
  approval: `reset --hard`, `clean`, `checkout -- <file>`, `push --force`, branch deletion, history rewrite, amending
  pushed commits. Never push (user pushes/merges). Phases on `refactor/pN-<name>` + PR. Preserve `pubspec.lock`.
- **Commits**: one per logical change; imperative mood ("Fix Zuhr", not "Fixed Zuhr"); summary <72 chars, body explains
  what/why/which files.

## Context Loading
| Task | Required context (under `.project-docs/`) |
| --- | --- |
| Prayer times / tracking | modules/prayer + modules/prayer-tracking + contracts/prefs-keys |
| Notifications, adhan, alarms | modules/notifications-native + contracts/* |
| Tasks / Focus Mode | modules/tasks / modules/focus-mode |
| Quran / Wird | modules/quran-wird (+ modules/wird) |
| Widgets | modules/widgets + contracts/method-channels + contracts/intent-extras |
| Auth / sync / Firestore | modules/auth-sync + contracts/firestore-paths |
| UI / theme / RTL | modules/ui-kit |
| Windows desktop | modules/desktop (+ modules/desktop-scaling) |
| Refactor phase work | STATE + spec phase section + modules it names |
| Architecture | relevant ADRs + relevant section of docs/designs/aura-refactor.md |

- Every session: read `.project-docs/STATE.md` first, nothing else by default. `INDEX.md` only when this table doesn't answer.
- Never read logs unless asked about a date. Never reread a file already in context unless it changed.
- Files >300 lines: search first, read only relevant ranges. Broad exploration: Explore subagent, conclusions + paths only.
- Long EGM output goes to files; chat gets a short pointer. Concise responses; diffs/changed sections only.
