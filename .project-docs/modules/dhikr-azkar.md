# Dhikr, Azkar & daily content
Relocated from CLAUDE.md on 2026-11-06; not yet re-verified (Step 2).

## Dhikr / Tasbeeh
- Folder `lib/features/dhikl/` (typo of "dhikr"; rename planned for P6). Routes `/dhikr`, `/dhikr_stats`.
- 6 presets: SubhanAllah, Alhamdulillah, Allahu Akbar, La ilaha illallah, Astaghfirullah, Custom.
- Haptic feedback per tap (enable/simplified modes); session tracking + statistics persistence.
- `lib/core/models/dhikr`, `lib/core/services/dhikr_service`, `lib/core/utils/haptic_feedback`.

## Azkar
- `lib/features/azkar/`, route `/azkar` — not described in old CLAUDE.md. UNKNOWN, Step 2.

## Daily Islamic content
- Hadith, Ayah, Dua from Firestore; `lib/features/daily_content/`, route `/daily_content`,
  `daily_content_service`, `lib/core/models/daily_content`. Home widget: widgets.md (`DailyContentWidget`).

## Islamic events
- `lib/features/islamic_events/`, route `/islamic_events`. Desktop layout notes: desktop-scaling.md.
