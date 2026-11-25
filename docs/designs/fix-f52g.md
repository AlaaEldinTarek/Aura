# Fix spec — F52g: Wird sync data loss

**Finding:** F52g — `syncFromFirestore` unconditionally overwrites local data with the cloud
copy on every init. If a user reads Wird offline, the cloud push fails silently, and on the
next app start the stale cloud data overwrites the local changes (streak increment, day count,
etc. are lost). Additionally, `wird_progress_history` is never sent to or pulled from
Firestore (local-only), so weekly stats are empty on a new device or after clearing app data.

**Status:** Draft — P1 + P2 approved in principle (2026-11-25); "approve phase P1" required before coding starts

---

## Root cause

### A — Unconditional overwrite on init (the data-loss path)

`WirdNotifier._init()` calls `WirdService.syncFromFirestore()` on every mount.
`syncFromFirestore` reads the cloud document and writes every field it finds straight to
SharedPreferences with no timestamp comparison.

**Data-loss scenario (concrete):**
1. 8:00 AM — user reads 5 pages offline; `creditPages` increments local streak (4 → 5) and
   calls `_pushToCloud()` which fails silently (no network).
2. 10:00 AM — user comes online and opens the app.
3. `syncFromFirestore` reads the cloud document (`streakCount: 4`) and overwrites local prefs
   → streak drops from 5 back to 4. The subsequent `_pushToCloud()` then pushes 4 to the
   cloud, permanently losing the increment.

The 5-second Firestore timeout means this only happens when the cloud is reachable. If the
device stays offline, `syncFromFirestore` times out and the local data is unaffected.

**Key callers:**
- `lib/core/providers/wird_provider.dart:121` (every mount)
- `lib/core/providers/auth_provider.dart:91` (on login)

### B — History never synced

`wird_progress_history` (up to 90 daily entries; daily page/juz read + completion flag) is
never included in `syncToFirestore` or `syncFromFirestore`. Weekly stats bar charts and
`getBestStreak()` rely on it. On a second device or after clearing app data the history is
empty even though the account has cloud data.

---

## Fix design

### P1 — Timestamp-guarded sync (Issue A)

**Prefs key added:** `wird_local_updated_at_ms` (int, epoch ms; added to `contracts/prefs-keys.md`)

**Firestore field added:** `localUpdatedAt` (int, epoch ms) in `users/{uid}/wird/data`
(additive; old documents without the field default to 0 → cloud wins, same as today)

**Changes to `lib/core/services/wird_service.dart`:**

1. Add constant:
   ```dart
   static const _localUpdatedAtKey = 'wird_local_updated_at_ms';
   ```

2. Add pure helper (testable without Firebase/Prefs):
   ```dart
   /// Returns true when the cloud snapshot is at least as recent as the local
   /// data, meaning the cloud should win and the overwrite may proceed.
   ///
   /// Tie (equal ms) → cloud wins. In practice the two timestamps come from
   /// separate `DateTime.now()` calls so a true tie is rare; the rule is
   /// documented here rather than depending on that observation.
   @visibleForTesting
   static bool cloudIsNewer(int localUpdatedAtMs, int cloudUpdatedAtMs) =>
       cloudUpdatedAtMs >= localUpdatedAtMs;
   ```

3. Modify `_pushToCloud()` — record the local modification time before each push attempt:
   ```dart
   Future<void> _pushToCloud() async {
     final uid = FirebaseAuth.instance.currentUser?.uid;
     if (uid == null) return;
     // Record before the push so a failed push still marks local as dirty.
     final prefs = await _prefs;
     await prefs.setInt(
         _localUpdatedAtKey, DateTime.now().millisecondsSinceEpoch);
     await syncToFirestore(uid);
   }
   ```

4. Modify `syncToFirestore()` — include `localUpdatedAt` in the document:
   ```dart
   await doc.set({
     ...
     'localUpdatedAt': DateTime.now().millisecondsSinceEpoch,
     'updatedAt': FieldValue.serverTimestamp(),
   }, SetOptions(merge: true));
   ```

5. Extract overwrite logic into a `@visibleForTesting` helper so it is testable
   without a Firestore mock:
   ```dart
   /// Applies a cloud data map to local SharedPreferences.
   /// Only called when the cloud snapshot is at least as recent as local data.
   @visibleForTesting
   Future<void> applyCloudData(
       Map<String, dynamic> data, SharedPreferences prefs) async {
     if (data['settings'] != null) {
       await prefs.setString(_settingsKey,
           jsonEncode(Map<String, dynamic>.from(data['settings'] as Map)));
     }
     if (data['streakCount'] != null) {
       await prefs.setInt(_streakCountKey, data['streakCount'] as int);
     }
     if (data['streakDate'] != null) {
       await prefs.setString(_streakDateKey, data['streakDate'] as String);
     }
     if (data['totalDaysCompleted'] != null) {
       await prefs.setInt(_totalDaysKey, data['totalDaysCompleted'] as int);
     }
     if (data['completedJuz'] != null) {
       final juzList =
           (data['completedJuz'] as List<dynamic>).map((e) => e as int).toList();
       await prefs.setString(_completedJuzKey, jsonEncode(juzList));
     }
     if (data['khatmCount'] != null) {
       await prefs.setInt(_khatmCountKey, data['khatmCount'] as int);
     }
     if (data['khatmDates'] != null) {
       final dateList =
           (data['khatmDates'] as List<dynamic>).map((e) => e as String).toList();
       await prefs.setString(_khatmDatesKey, jsonEncode(dateList));
     }
   }
   ```

6. Modify `syncFromFirestore()` — guard the overwrite, then delegate to `applyCloudData`:
   ```dart
   final data = doc.data()!;
   final prefs = await _prefs;

   final cloudUpdatedAt = (data['localUpdatedAt'] as int?) ?? 0;
   final localUpdatedAt = prefs.getInt(_localUpdatedAtKey) ?? 0;
   if (!WirdService.cloudIsNewer(localUpdatedAt, cloudUpdatedAt)) {
     // Local is newer than cloud (offline writes pending); push local up and
     // skip the overwrite so we don't lose the user's offline progress.
     // Note: syncToFirestore's internal try-catch absorbs any push failure.
     // The guard will fire again on the next app start and retry.
     await syncToFirestore(userId);
     return;
   }

   // Cloud is at least as recent — overwrite local (existing behaviour).
   await applyCloudData(data, prefs);
   ```

**Tie-breaking rule:** `cloudUpdatedAtMs >= localUpdatedAtMs` → cloud wins. `_pushToCloud`
sets `_localUpdatedAtKey = T1` before calling `syncToFirestore`, which calls `DateTime.now()`
again (T2 ≥ T1). After a successful push the cloud therefore has `localUpdatedAt = T2 ≥ T1`,
so `cloudIsNewer(T1, T2)` = true → cloud overwrites local with the data just pushed, which is
harmless. This design avoids any false "local is dirty" detection after a successful push.

**Reset All Progress from another device:** `resetAllProgress()` calls `_pushToCloud()` which
sets `_localUpdatedAtKey = T_reset` and sends `localUpdatedAt: T_reset` to the cloud. On the
other device, `syncFromFirestore` reads `cloudUpdatedAt = T_reset` which is newer than its
`_localUpdatedAtKey`, so the cloud (zeroed) data overwrites local → reset propagates. ✓

**First app start after a login (new device, cloud already has data):** `_localUpdatedAtKey`
is absent in prefs → `localUpdatedAt = 0`. Cloud document has `localUpdatedAt > 0` (or 0 for
old documents without the field, in which case both are 0 → tie → cloud wins). Cloud always
wins for a fresh device. ✓

**Old cloud documents (no `localUpdatedAt` field):** default to 0. Local prefs also default
to 0 (key absent). `cloudIsNewer(0, 0)` → true → cloud wins → same behaviour as today. ✓

---

### P2 — History sync (Issue B)

Add `progressHistory` (array of WirdProgress JSON objects) to `users/{uid}/wird/data` and
sync it under the same P1 timestamp guard. No new files; changes are within
`wird_service.dart`.

**Firestore schema addition:** `progressHistory` array in `users/{uid}/wird/data`. Old
documents without the field are treated as `[]` on read (no migration needed).

**Push (`syncToFirestore`):**
```dart
final history = await _loadHistory(); // already pruned to 90 days
await doc.set({
  ...existing fields...,
  'progressHistory': history.map((e) => e.toJson()).toList(),
  'localUpdatedAt': DateTime.now().millisecondsSinceEpoch,
  'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
```

**Pull (`applyCloudData`)** — add alongside existing scalar writes:
```dart
if (data['progressHistory'] != null) {
  final histList = (data['progressHistory'] as List<dynamic>)
      .map((e) => WirdProgress.fromJson(
              Map<String, dynamic>.from(e as Map)))
      .toList();
  // _loadHistory prunes to 90 days on the next read; no extra pruning needed.
  await _saveHistory(histList);
}
```

**Conflict resolution:** last-write-wins (the same timestamp guard as P1). The device that
pushed most recently owns the history. If two devices read Wird on the same day, whichever
syncs last overwrites the other. This handles the main use cases:
- Clear app data + re-login → cloud history restored ✓
- Reset All Progress from another device → cloud `progressHistory: []` overwrites local ✓
- Two devices, same day → last write wins (some entries from the earlier device may be
  lost; union merge is a follow-up if the owner finds this matters in practice) ⚠️

**Size:** ≈9 KB (90 entries × ~100 bytes) added per document write. Firestore charges per
write operation (not per KB), so cost is unchanged from P1. Bandwidth is negligible.

---

## Files

| File | Change |
|------|--------|
| `lib/core/services/wird_service.dart` | Add `_localUpdatedAtKey`, `cloudIsNewer`, `applyCloudData`; modify `_pushToCloud`, `syncToFirestore`, `syncFromFirestore` |
| `.project-docs/contracts/prefs-keys.md` | Add `wird_local_updated_at_ms` |
| `.project-docs/contracts/firestore-paths.md` | Note `localUpdatedAt` and `progressHistory` fields in `users/{uid}/wird/data` |
| `test/core/services/f52g_source_test.dart` | New — source-text + unit tests (see below) |

---

## Tests

New file: `test/core/services/f52g_source_test.dart`

| ID | Description | Type |
|----|-------------|------|
| T1 | `wird_service.dart` declares `_localUpdatedAtKey = 'wird_local_updated_at_ms'` | source-text |
| T2 | `wird_service.dart` exports `cloudIsNewer` and `applyCloudData` | source-text |
| T3 | `syncFromFirestore` contains `!WirdService.cloudIsNewer` and calls `applyCloudData` | source-text |
| T4 | `syncToFirestore` includes `'localUpdatedAt'` in the doc set | source-text |
| T5 | `_pushToCloud` sets `_localUpdatedAtKey` after the uid check | source-text |
| T6 | `cloudIsNewer(100, 100)` → true (tie, cloud wins) | unit |
| T7 | `cloudIsNewer(100, 200)` → true (cloud newer) | unit |
| T8 | `cloudIsNewer(200, 100)` → false (local newer, skip overwrite) | unit |
| T9 | `applyCloudData` with `streakCount: 7` overwrites local `streakCount` in prefs | unit (SharedPreferences.setMockInitialValues) |
| T10 | `applyCloudData` with `streakCount: 0` (Reset All Progress scenario) writes 0 to prefs | unit |

| T11 | `syncToFirestore` includes `'progressHistory'` in the doc set | source-text |
| T12 | `applyCloudData` applies `progressHistory` from cloud data to local history | unit (SharedPreferences.setMockInitialValues) |

T9–T12 use `WirdService.forTesting()` and `SharedPreferences.setMockInitialValues`; they
exercise the overwrite path without Firestore. Combined with T3 (source-text check that
`applyCloudData` is called on the cloud-wins branch) this ensures a logic inversion in the
guard would surface as a T3 failure and that the overwrite itself works via T9–T12.

---

## Contracts updated

- `contracts/prefs-keys.md`: add `wird_local_updated_at_ms` (int, epoch ms; set by `_pushToCloud`, read by `syncFromFirestore`; signed-in users only)
- `contracts/firestore-paths.md`: add `localUpdatedAt` (int) and `progressHistory` (array) to `users/{uid}/wird/data` row

---

## Phases

| Phase | Description | Branch |
|-------|-------------|--------|
| P1 | `wird_service.dart` timestamp guard + `applyCloudData` + tests | `fix/f52g` |
| P2 | Add `progressHistory` to push/pull (same branch, same PR) | `fix/f52g` |

---

## Behavioral notes

- **Silent recovery-push failure:** when the guard fires (`!cloudIsNewer`) and calls
  `syncToFirestore(userId)`, that push's try-catch absorbs any failure without rethrowing.
  `syncFromFirestore`'s caller cannot distinguish "guard fired and push failed" from
  "normal sync completed." This is acceptable: on the next app start the guard will fire
  again and retry. No data is lost; the worst case is a delayed sync.

- **`_refreshStreak()` interaction:** `_refreshStreak` zeros the local streak when it is
  stale (streak date is not today or yesterday) but does NOT call `_pushToCloud()`, so
  `_localUpdatedAtKey` is not updated. After `_refreshStreak` runs, the next
  `syncFromFirestore` will still see the cloud's timestamp as newer (the last push was before
  the streak reset) and will overwrite local with the cloud's non-zero streak — net result is
  the same as today (streak refresh doesn't propagate until the next explicit write). This
  interaction is pre-existing and not changed by P1.

## Out of scope

- `_refreshStreak()` not pushing to cloud is a separate pre-existing gap.
- Offline queue integration (`sync_service.dart`): the queue's Wird support is UNKNOWN
  (finding F52g). Not addressed here.
- Two-device same-day reading: P2 uses last-write-wins (not union merge). If two devices
  read on the same day, the one that syncs later owns the history for that day. Union merge
  is a follow-up if the owner finds this matters in practice.
