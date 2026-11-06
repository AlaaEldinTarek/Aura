# Settings & preferences
Relocated from CLAUDE.md on 2026-11-06; not yet re-verified (Step 2). Key names/files: contracts/prefs-keys.md.

## `/settings` — central settings screen (`lib/features/settings/settings_screen.dart`)
- 5 sections: Prayer (calc method + madhab, silent mode, iqama, adhan) · Tasks (reminders, minutes) · Appearance
  (language, theme) · Notifications (Jumu'ah, prayer tracking, daily summary time) · Background & Battery (exact alarm,
  battery optimization).
- Reached from Profile → "All Settings". Replaces settings formerly scattered across the prayer screen, the tasks tune
  icon, and profile. Related: `/iqama_settings`, `/adhan_downloads`.

## Preferences provider (`lib/core/providers/preferences_provider.dart`)
- Theme, language, guest mode, vibration, silent mode, task notifications.
- `SharedPreferencesService` is injected into Riverpod via a ProviderScope override (architecture.md § Init flow).
- Silent mode during prayer times: configurable duration, default 20 min (`silent_mode_duration`).
- Tutorial-seen flags live in `SharedPreferencesService` (`isTutorialXSeen()` / `setTutorialXSeen()`): ui-kit.md.

## App mode
- `AppMode.both` / `prayerOnly` / `tasksOnly`; selected at `/mode_selection` (onboarding) and in Profile.
- `AppMode.prayerOnly` is labelled "Prayer & Quran" (EN) / "الصلاة والقرآن" (AR) everywhere — onboarding mode selection
  and Profile app-mode tiles. Keep them in sync if labels change.
- Bottom nav Quran tab: `showQuran = appMode == AppMode.both || appMode == AppMode.prayerOnly` (hidden only in
  `tasksOnly`). The PageView always has all 5 screens at fixed indices regardless of mode.
- Achievement filtering by mode: achievements.md.
