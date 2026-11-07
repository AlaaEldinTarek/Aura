# Dhikr, Azkar & daily content
Verified against code 2026-11-07 (reference/2026-11-07_DRIFT_REPORT.md). Folder views: `lib/features/dhikl/`,
`azkar/`, `daily_content/`, `islamic_events/` READMEs.

## Dhikr / Tasbeeh
- Folder `lib/features/dhikl/` (typo of "dhikr"; rename planned for P6). Routes `/dhikr`, `/dhikr_stats`.
- 5 built-in presets (`DhikrPresets.builtIn`: SubhanAllah, Alhamdulillah, Allahu Akbar, La ilaha illallah,
  Astaghfirullah) + any number of user presets (`custom_dhikr_presets`, `CustomZikrFormScreen`).
- Tap feedback: Flutter `HapticFeedback` + unconditional `Vibration.vibrate(50)`; ignores the vibration settings and
  does not use `lib/core/utils/haptic_feedback` (F52l).
- Sessions/stats: Firestore only (`users/{uid}/dhikr_sessions`); guests save nothing.
- `lib/core/models/dhikr`, `lib/core/services/dhikr_service`.

## Azkar
- `lib/features/azkar/`, route `/azkar`; `core/models/azkar.dart`, `core/providers/azkar_provider.dart`.
- Morning / Evening tabs, 12 + 12 items hard-coded in `AzkarData`; tap toggles done (`repeatCount` shown as "×N", no
  counter). Local only: `azkar_state` (done ids per day, `streakCount`, `totalSessions`) + `azkar_streak_date`. No
  Firestore, notifications or achievements. Issues: F42.
- Native post-prayer azkar (lock-screen) is separate: `AzkarFullScreenActivity` (notifications-native.md).

## Daily Islamic content
- `lib/features/daily_content/`, route `/daily_content`; `daily_content_service` = hard-coded `const` list of 20 items
  (10 ayah + 10 hadith; `enum DailyContentType { ayah, hadith }`, no dua), rotated by day of year via `getToday()`.
  No Firestore. Home builds an inline card from `getToday()`.
- Native Android widget `DailyContentWidget` keeps its own list (widgets.md; mismatch F51o).

## Islamic events
- `lib/features/islamic_events/`, route `/islamic_events`. Desktop layout notes: desktop-scaling.md.
