# lib/features

## Overview
One folder per screen group (16 folders, each with its own README). Features own no data: they read Riverpod
providers and call services from [`../core/README.md`](../core/README.md). Routes are declared in `lib/main.dart`
(`_generateRoute`; on Windows `main()` first backs up an unreadable prefs file, F62, before any prefs read); the desktop shell builds the same screens in its nested navigator in `main/`. Cross-feature
imports exist only in `main/main_wrapper_screen.dart` (hosts the tabs and desktop routes), `prayer/prayer_screen.dart`
(reuses the calculation dialogs and enums from `settings/`) and `quran/quran_reader_screen.dart`
(`desktopSidebarVisibleProvider` from `main/`) — VERIFIED by grep of relative and package imports, 2026-11-07.

## Subdirectories & Boundaries
- splash: [./splash/README.md](./splash/README.md) — initial route `/`; routes to onboarding, home or login after a fixed delay.
- onboarding: [./onboarding/README.md](./onboarding/README.md) — first-run wizard (language, theme, app mode); also shown after every sign-in.
- auth: [./auth/README.md](./auth/README.md) — login and signup screens over `authStateNotifierProvider`.
- main: [./main/README.md](./main/README.md) — app shell: 5 tabs, bottom nav / desktop sidebar, lifecycle work, widget and native hand-off.
- home: [./home/README.md](./home/README.md) — Home tab: day summary, next prayer, tasks, first-run tutorial.
- prayer: [./prayer/README.md](./prayer/README.md) — Prayer tab, settings page, tracking calendar, 60-day report.
- tasks: [./tasks/README.md](./tasks/README.md) — task list/calendar, form, statistics.
- quran: [./quran/README.md](./quran/README.md) — Quran tab, SVG Mushaf reader, Wird, search, stats, khatma screens.
- profile: [./profile/README.md](./profile/README.md) — Profile tab: stats, account actions, app mode, logout.
- settings: [./settings/README.md](./settings/README.md) — Settings, iqama offsets, adhan reciters, calculation dialogs.
- achievements: [./achievements/README.md](./achievements/README.md) — read-only badge list.
- azkar: [./azkar/README.md](./azkar/README.md) — morning/evening azkar checklist.
- dhikl: [./dhikl/README.md](./dhikl/README.md) — tasbeeh counter, stats, custom zikr (folder name typo kept on purpose).
- daily_content: [./daily_content/README.md](./daily_content/README.md) — today's verse/hadith in full.
- islamic_events: [./islamic_events/README.md](./islamic_events/README.md) — upcoming Islamic events with countdowns.
- qibla: [./qibla/README.md](./qibla/README.md) — compass bearing to the Kaaba.

## Global Invariants
- Every UI string via `.tr()` (key in both `en.json` and `ar.json`); every number in Arabic UI via `NumberFormatter`;
  prayer names via `getPrayerDisplayName` (CLAUDE.md).
- Behavior-preserving refactor: no UI, routing or logic change without an approved spec.
