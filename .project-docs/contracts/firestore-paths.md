# Contract — Firestore paths
Verified 2026-11-06 at 4aa1022 by static grep of `lib/` (Step 2). Firestore is Dart-only (no Kotlin access). No schema
changes without an approved spec. Guest user id is `'guest_user'` (`task_service.dart:32`) — never written to Firestore.

| Path | Dart location | Dynamic? | Confidence |
| --- | --- | --- | --- |
| `users/{uid}` | `firestore_service.dart:12`, `sync_service.dart:85,104` | uid | Verified |
| `users/{uid}/tasks/{autoId}` | `task_service.dart:103–642` (guest migration batch :100–104) | uid | Verified |
| `users/{uid}/prayer_records/{prayerName}_{YYYY-MM-DD}` | `prayer_tracking_service.dart:112–687`; doc id `_recordDocId` :596–600 | uid, name, date | Verified |
| `users/{uid}/achievements/…` | `achievement_service.dart:30,56,401` | uid | Verified |
| `users/{uid}/dhikr_sessions/…` | `dhikr_service.dart:25–154` | uid | Verified |
| `users/{uid}/wird/data` | `wird_service.dart:497,517–520` | uid | Verified |
| `users/{uid}/{operation.collection}` | `sync_service.dart:87,106` (offline queue; values `prayer_records`, `dhikr_sessions`, `tasks` per `offline_queue_service.dart:9`) | collection | Partial — no `QueuedOperation(` producer found (UNKNOWN whether queue is populated) |
| `_` (local id generation only, never written) | `task_service.dart:34` | — | Verified |

Daily content (Hadith/Ayah/Dua): no Firestore path found — UNKNOWN source (likely bundled assets; Step 2.4).
`prayer_records` name casing: `{prayerName}` is whatever caller passes ('Zuhr' vs 'Dhuhr' UNKNOWN per call site).
