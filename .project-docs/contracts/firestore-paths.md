# Contract — Firestore paths
Seeded from old CLAUDE.md on 2026-11-06; Confidence: Unknown until Step 2. No schema changes without an approved spec.

| Collection / path | Contents | Notes |
| --- | --- | --- |
| `users` | User profile, synced prefs (language/theme) | Login direction: device → Firestore (auth-sync.md) |
| `tasks` | Tasks | Pulled on login; guest data migrated on signup |
| `prayer_records` | Prayer tracking records (`prayedAt`, status) | Cleanup of impossible records: prayer-tracking.md |
| Daily content (Hadith/Ayah/Dua) | Read-only content | Path UNKNOWN |
| Wird sync | Wird state for logged-in users | Path UNKNOWN |
| Achievements, dhikr stats | — | Whether synced: UNKNOWN |
