# lib/core

## Overview
Shared, feature-independent layers of the Flutter app. Data flows one way: `models` (data + schema) ← `services`
(I/O, platform channels, Firestore, prefs) ← `providers` (Riverpod state) ← `lib/features/` UI; `theme`, `utils`,
`widgets` and `constants` are used by every layer. No file in `lib/core/` imports `lib/features/` (VERIFIED by grep,
2026-11-07). Cross-folder feature flows: `.project-docs/modules/*.md`; Dart↔Kotlin names: `.project-docs/contracts/`.

## Subdirectories & Boundaries
- models: [./models/README.md](./models/README.md) — plain data classes, enums and const tables; serialized field
  names are a schema contract (Firestore + local JSON).
- services: [./services/README.md](./services/README.md) — singletons for business logic and platform I/O
  (notifications, native alarms, prayer times, tracking, tasks, wird, auth, Firestore, desktop tray/adhan).
- providers: [./providers/README.md](./providers/README.md) — Riverpod notifiers over the services;
  `prayer_times_provider.dart` is the scheduling hub (alarms, widgets, foreground service, desktop timers).
- utils: [./utils/README.md](./utils/README.md) — stateless helpers: `NumberFormatter` (Arabic numerals),
  `getPrayerDisplayName`, prayer timing rules, Hijri, haptics, share.
- widgets: [./widgets/README.md](./widgets/README.md) — shared UI building blocks (bottom nav, cards, dialogs,
  banners, tutorial).
- theme: [./theme/README.md](./theme/README.md) — Material 3 light / dark / AMOLED / dynamic themes and tokens.
- constants: `constants/app_constants.dart` (1 file, no README) — `AppConstants`: color and spacing tokens (an
  independent copy of the theme tokens, findings F29) and SharedPreferences key names (`key*`, e.g. `keyThemeMode`,
  `keyIsGuest`, tutorial / banner flags). Key values are contracts: prefs-keys contract.

## Global Invariants
- Services are reached both through providers and directly from widgets (`XService.instance`) — two access paths;
  keep `instance` stable during the refactor.
- Native names sent from `services/` (channels, prefs keys, notification IDs) change together with Kotlin and
  `.project-docs/contracts/` in one commit.
- Keys, prefs names and Firestore paths are built locale-independently (integer `toString` / `toIso8601String`);
  findings F51 "locale-dependent keys".
