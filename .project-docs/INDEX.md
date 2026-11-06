# Index — topic → file
Read STATE.md first. Use this only when CLAUDE.md's Context Loading table doesn't answer.

## Modules
- Prayer times, calc methods, next-prayer, iqama, Makkah offset → modules/prayer.md
- Prayer tracking, after-midnight rules, native status sync, cleanup → modules/prayer-tracking.md
- Notification layers, adhan, receivers, Jumu'ah, foreground service → modules/notifications-native.md
- Tasks: model, sections, sort/filter, reminders, recurrence, sync → modules/tasks.md
- Focus Mode: overlay, lock task, accessibility, DND → modules/focus-mode.md
- Quran reader, SVG pages, bookmarks, Quran data/font → modules/quran-wird.md
- Wird daily reading: model, streak, reminders, bookmark sync → modules/wird.md
- Dhikr/Tasbeeh, Azkar, daily Islamic content → modules/dhikr-azkar.md
- Achievements: definitions, mode filtering, screens, notifications → modules/achievements.md
- Auth, guest mode, Firestore ↔ prefs sync → modules/auth-sync.md
- Home screen widgets (prayer, tasks, daily content) → modules/widgets.md
- Settings screen, preferences provider, app mode → modules/settings-prefs.md
- Windows desktop: MSIX build, versioning → modules/desktop.md
- Windows adaptive scaling (`ts.scale()`) → modules/desktop-scaling.md
- Theme, localization/RTL, tutorial overlay, InfoTipIcon, screen patterns → modules/ui-kit.md

## Contracts (Dart ↔ Kotlin shared names)
- SharedPreferences files and keys → contracts/prefs-keys.md
- MethodChannels → contracts/method-channels.md
- Notification IDs and channels → contracts/notification-ids.md
- Intent extras and widget handoff flags → contracts/intent-extras.md
- Firestore collections/paths → contracts/firestore-paths.md
- Log tags, logcat filters, emoji prefixes → contracts/log-tags.md

## Reference
- Feature list, folders, providers, routes, init flow, dependencies, assets → reference/architecture.md
- Analyzer/test baseline numbers → reference/baseline.md
- Findings to investigate + doc conflicts → reference/findings.md
- Device characterization checklist → reference/device-checklist.md
- Old CLAUDE.md section → new file map → reference/claude-md-relocation.md

## Folder READMEs (EGM contracts)
- Done: `lib/core/providers/README.md`. Pending: core/services, core/{models,utils,widgets,theme,constants},
  features (2 batches), android kotlin. Drift report: once, after all batches.
- Rules (user-approved 2026-11-06): no line numbers (name functions/classes; line numbers only in findings.md);
  ≤ ~120 lines (one table row per file, key invariants only); folder README = what this folder's files expose + their
  rules, modules/*.md = cross-folder feature view — never duplicate, link instead.

## Other
- Decisions (ADRs) → decisions/ · Daily log → log/YYYY-MM-DD.md · Specs → ../docs/designs/
