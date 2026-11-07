# Settings & preferences
Verified against code 2026-11-07 (reference/2026-11-07_DRIFT_REPORT.md). Key names/files: contracts/prefs-keys.md.
Folder view: `lib/features/settings/README.md`.

## `/settings` — central settings screen (`lib/features/settings/settings_screen.dart`)
- Sections: Prayer (calc method + madhab, silent mode, iqama, adhan) · Tasks (reminders, minutes) · Appearance
  (language, theme) · Notifications (Jumu'ah, prayer tracking, daily summary time) · Background & Battery (Android
  only: exact alarm, battery optimization) · Desktop (Windows only: "Start with Windows").
- Conditional rows: silent-mode duration (silent mode on), remind-before minutes (task reminders on), daily summary time
  (tracking on).
- Method/madhab change calls `_recalculatePrayerTimes` → `loadPrayerTimes(now)`; side effects (alarms, native data) are
  skipped by the same-day guard (F52a).
- Reached from Profile → "All Settings". The prayer screen still opens the calculation dialog, iqama settings and adhan
  downloads too (F36c). Related: `/iqama_settings`, `/adhan_downloads`.

## Preferences provider (`lib/core/providers/preferences_provider.dart`)
- Theme, language, guest mode, first launch, vibration (+ simplified), dynamic color, silent mode, task notifications +
  reminder minutes, Jumu'ah reminder, app mode, prayer tracking, daily summary time, tab navigation, show tutorial.
- `SharedPreferencesService` is injected via `ProviderContainer(overrides: [sharedPreferencesServiceProvider…])` +
  `UncontrolledProviderScope` in `main.dart`; the provider is defined in `auth_provider.dart` (architecture.md § Init flow).
- Silent mode during prayer times: configurable duration, default 20 min (`silent_mode_duration`). The enable flag does
  not reach native (F49a).
- Tutorial flags: ui-kit.md § Tutorial system.

## App mode
- `AppMode.both` / `prayerOnly` / `tasksOnly`; selected at `/onboarding` (`PreferenceScreen`) and in Profile.
  `/mode_selection` (`ModeSelectionScreen`) has no caller (F46c).
- Labels differ: onboarding "Prayer Only" / "الصلاة فقط"; Profile tiles "Prayer & Quran" / "الصلاة والقرآن".
- Bottom nav Quran tab: `showQuran = appMode == AppMode.both || appMode == AppMode.prayerOnly` (hidden only in
  `tasksOnly`). The PageView always has all 5 screens at fixed indices regardless of mode.
- Achievement filtering by mode: achievements.md.
