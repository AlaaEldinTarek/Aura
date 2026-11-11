# FX-1 — Fix Prayer Streak and Missed-Prayer Storage (F20a + F25)

*   **Author:** Alaa Eldin Tarek
*   **Status:** Draft
*   **Date:** 2026-11-11

---

## Overview

Two connected bugs make the prayer streak counter and prayer statistics wrong. First, the streak functions count every stored prayer record regardless of whether the prayer was actually performed — a day where all five prayers were marked "Missed" looks identical to a day where all five were prayed on time. Second, the in-app "Missed" button stores the wrong status value (`excused` instead of `missed`), which makes the statistics system treat those prayers as prayed. The two bugs compound each other: fixing the streak filter alone would not fix the statistics, and fixing the dialog alone would still leave the streak broken for the records already stored.

## The Problem

**F20a — Streak ignores status:**
`_streakFromRecords` and `_calculateBestStreak` in `prayer_tracking_service.dart` group records by prayer name per day and check whether five or more distinct names exist. They never look at the status field. A day with five `missed` or five `excused` records passes the completeness check and increments the streak.

**F25 — "Missed" stores wrong value:**
`showPrayerStatusDialog` returns `PrayerStatus.excused` when the user taps "Missed" / لم أصلّ. Notification and desktop paths store `PrayerStatus.missed` for the same user action. This means:
- `DailyPrayerSummary.completedCount` excludes only `missed`; `excused` records count as prayed.
- `getStatistics` has an explicit `case PrayerStatus.excused: break;` at line 347 that silently drops those records, so they are not counted as missed in completion rates.
- `prayer_report_screen.dart` tracks `excused` in a separate bucket and subtracts it from `totalMissed`, which also excludes it from the completion denominator.
- `prayer_tracking_screen.dart._isDayComplete` uses `st != PrayerStatus.missed`, so `excused` passes as a valid prayer in the calendar.
- `prayer_screen.dart` has a snackbar color ternary branching on `PrayerStatus.excused`; after the dialog fix, that branch never fires.
- `PrayerCard` correctly shows a red "Missed" badge for `excused`, but the numbers behind it are wrong.

**Decision (locked):** Existing `excused` records are kept as-is in Firestore. No migration. Past "Missed" taps stored as `excused` keep their stored status. All counting code is updated to treat both `excused` and `missed` as "not prayed" — so those historical records are correctly excluded from streaks and completion counts under the new logic.

## Goals

*   Streak (current and best) counts only days where at least five prayers have status `onTime` or `late`.
*   In-app "Missed" tap stores `PrayerStatus.missed`, matching the notification and desktop paths.
*   `DailyPrayerSummary.completedCount`, `isComplete`, and `_isDayComplete` treat both `excused` and `missed` as not-prayed.
*   `getStatistics` and `prayer_report_screen` count `excused` as missed in completion statistics.
*   `prayer_screen` snackbar shows the correct color when a prayer is marked missed.
*   Existing `excused` records in Firestore are preserved; they are re-read under the corrected logic.

## Non-Goals

*   Migrating stored `excused` records to `missed` in Firestore.
*   Changing what `PrayerCard` displays (badge rendering is already correct).
*   Changing the `excused` status or the `PrayerStatus` enum values themselves.
*   `achievement_service.dart:355` — that method has its own independent 7-day prayer-record scan and does not read from the streak counter; fixing it is deferred as a separate finding.
*   Fixing unrelated backlog items in F37 (prayer scout) or F20b/F20c.

## Open Questions

*   None — decision on existing records is locked (keep as-is).

---

## Critical User Journeys

### CUJ 1: Streak does not count a day where all prayers were missed

*   **Given**: User has marked all five prayers for a day as "Missed" via the in-app dialog.
*   **When**: User views the prayer streak counter.
*   **Then**: That day does not count toward the streak. If no other complete days exist, the streak is 0.

### CUJ 2: Streak counts a fully prayed day

*   **Given**: User has marked all five prayers as "On Time" or "Late" for a day.
*   **When**: User views the prayer streak counter.
*   **Then**: That day counts toward the streak as before.

### CUJ 3: "Missed" tap stores the right value

*   **Given**: User opens the prayer status dialog and taps "Missed" / لم أصلّ.
*   **When**: The record is saved via `dailyPrayerStatusProvider.notifier.markToday`.
*   **Then**: The stored status is `missed`, matching the notification and desktop paths.

### CUJ 4: Statistics treat past "Missed" taps correctly

*   **Given**: Historical records stored as `excused` (from past "Missed" taps before this fix).
*   **When**: User views completion rate or daily summary.
*   **Then**: Those records are counted as not-prayed, not as prayed.

---

## Technical Plan

There are eight call sites across five files. All changes are additive filters or single-value corrections — no new data structures, no Firestore writes.

```
PrayerStatus enum (prayer_record.dart)
  onTime ──┐
  late  ───┤  "prayed" — counts toward streak and completion
  missed ──┤  "not prayed" — excluded from streak, counted as missed in stats
  excused ─┘  "not prayed" — same treatment as missed (historical + new records)
```

**Day key format (`prayer_tracking_service.dart`)**

Both streak functions build `Map<String, Set<String>> prayersByDay` where the key is `"${record.date.year}-${record.date.month}-${record.date.day}"` using device-local date fields from `PrayerRecord.date`. This format is unchanged by the fix.

**`_streakFromRecords` (prayer_tracking_service.dart:480–482)**

Works with pre-loaded `PrayerRecord` objects passed in from `calculateCurrentStreak`. Add a status guard before `prayersByDay.putIfAbsent(...).add(record.prayerName)`: skip any record where `record.status` is not `onTime` or `late`. The `>= 5` threshold and all date-walking logic stay unchanged.

**`_calculateBestStreak` (prayer_tracking_service.dart:525–528)**

Deserializes from Firestore documents via `PrayerRecord.fromFirestore(doc)` inside the accumulation loop. Apply the same status guard on the deserialized record object before adding to `prayersByDay`. The consecutive-day counting logic stays unchanged.

**`showPrayerStatusDialog` (prayer_status_dialog.dart:57)**

Change `Navigator.pop(dialogContext, PrayerStatus.excused)` to `Navigator.pop(dialogContext, PrayerStatus.missed)`. All three callers (`home_screen.dart:1640`, `prayer_screen.dart:246`, `prayer_tracking_screen.dart:608`) pass the returned value directly to `dailyPrayerStatusProvider.notifier.markToday` — no caller changes needed.

**`DailyPrayerSummary.completedCount` and `isComplete` (prayer_record.dart:148, :152–154)**

Both getters currently use negative-exclusion (`!= missed`). Change both to positive-inclusion: count / check only `onTime` and `late`. Note: `achievement_service.dart:105` calls `DailyPrayerSummary.isComplete` for the `perfect_day` badge — it is automatically fixed by this change; no separate edit to `achievement_service.dart` is needed.

**`_isDayComplete` (prayer_tracking_screen.dart:92)**

Change `st != PrayerStatus.missed` to `st == PrayerStatus.onTime || st == PrayerStatus.late`. Used by the calendar's green "complete day" marker.

**`getStatistics` (prayer_tracking_service.dart:347)**

Change the explicit `case PrayerStatus.excused: break;` at line 347 to `case PrayerStatus.excused: missed++; break;` so `excused` records increment the missed counter instead of being dropped.

**`prayer_report_screen.dart:135–140`**

Remove the `else if (record.status == PrayerStatus.excused) { totalExcused++; }` branch (lines 135–137). Remove `- totalExcused` from the `totalMissed` formula at line 140. After the change, `excused` records fall through all branches and are counted as missed via `totalMissed = (kPrayerNames.length * 30) - completedOnTime - completedLate`, which treats them identically to `missed` records.

**`prayer_screen.dart:268–272`**

The snackbar color ternary branches on `PrayerStatus.excused`. After the dialog fix, the dialog returns `missed` instead of `excused`, so this branch never fires. Replace the `excused` branch with `missed`.

---

## Alternatives Considered

### Alternative A: Migrate existing `excused` records to `missed` in Firestore

Write a one-time migration that reads every prayer record stored as `excused` and rewrites it as `missed`.

*   **Pros**: Uniform data; no special-case handling needed in counting code.
*   **Cons**: Writes to production Firestore; risk of partial migration on network failure; irreversible without a backup; `excused` may carry different semantics for some users (e.g., illness, travel) that the app does not currently model but might in future.
*   **Reason for rejection**: Rejected by author — the user's data must not be rewritten; treat `excused` as not-prayed in counting code instead of modifying stored records.

### Alternative B: Rename `excused` to `missed` in the enum and dialog, drop `excused` entirely

Remove `PrayerStatus.excused` from the enum and use `missed` everywhere.

*   **Pros**: Eliminates the ambiguous status; simplifies future code.
*   **Cons**: Breaking change to Firestore deserialization — existing `'excused'` strings fall back to `onTime` via `fromString`; this would corrupt all historical missed prayers. Requires a migration to be safe, which was rejected in Alternative A.
*   **Reason for rejection**: Rejected by author — `excused` records must remain readable via `PrayerStatus.fromString('excused')`; the enum value cannot be removed without a migration.

### Alternative C: Add a `prayedStatuses` constant and reference it at every call site

Define `const prayedStatuses = {PrayerStatus.onTime, PrayerStatus.late}` and use it in all checks.

*   **Pros**: Single source of truth; easier to extend if a third "valid" status is added.
*   **Cons**: Introduces a shared constant that crosses model/service/widget boundaries; adds a dependency for a two-value set that is unlikely to change. The inline predicate duplication across the fixed call sites is a known trade-off.
*   **Reason for rejection**: Rejected by author — the fix touches eight call sites, each readable inline; a shared constant adds indirection without meaningful benefit at this scope.

---

## Non-Functional Requirements

**Firestore**: No reads or writes beyond normal app operation. No migration.

**Backward compatibility**: `excused` records stored before this fix continue to deserialize correctly via `PrayerStatus.fromString('excused')`. The new counting logic treats them as not-prayed, which is the intended behavior.

**Rollback**: All changes are in Dart; reverting the commit restores previous behavior.

---

## Risks and Behavioral Changes

**Historical completion rates will decrease.** Users who previously tapped "Missed" in-app accumulated `excused` records that the old statistics code counted as prayed. After the fix, those records count as missed. Users will see lower completion rates for past periods. This is correct — the old numbers were inflated — but it is a visible change. No user communication or migration is planned; the new numbers reflect actual prayer performance.

**Calendar "complete day" markers may change.** The green marker on the prayer tracking calendar is driven by `_isDayComplete`. Past days where the user marked prayers as "Missed" (stored as `excused`) may lose their green marker after the fix. This is correct behavior.

**`perfect_day` badge threshold becomes stricter.** The achievement at `achievement_service.dart:105` uses `DailyPrayerSummary.isComplete`, which after the fix excludes `excused`. A day previously qualifying as "perfect" may no longer qualify. This is correct behavior.

---

## Detailed Implementation Plan

### Target Files to Modify

#### 1. `lib/core/widgets/prayer_status_dialog.dart` (Modify)

*   **Type / Scope**: Shared widget — `showPrayerStatusDialog`
*   **Line**: `:57`
*   **Proposed change**: Change `Navigator.pop(dialogContext, PrayerStatus.excused)` to `Navigator.pop(dialogContext, PrayerStatus.missed)`.
*   **Why**: The "Missed" / لم أصلّ option represents a prayer the user did not perform. Storing `excused` was a naming mismatch with the notification and desktop paths that already store `missed` for the same action. All three callers pass the returned value directly to `dailyPrayerStatusProvider.notifier.markToday`; no caller changes are needed.

#### 2. `lib/features/prayer/prayer_screen.dart` (Modify)

*   **Type / Scope**: Feature screen — snackbar color ternary
*   **Lines**: `:268–272`
*   **Proposed change**: Replace the ternary branch that checks `== PrayerStatus.excused` with `== PrayerStatus.missed`.
*   **Why**: After the dialog fix, `showPrayerStatusDialog` no longer returns `excused`. The ternary must branch on `missed` to show the red snackbar color correctly.

#### 3. `lib/core/models/prayer_record.dart` (Modify)

*   **Type / Scope**: Model — `DailyPrayerSummary`
*   **Lines**: `:148`, `:152–154`
*   **Proposed changes**:
    - `completedCount`: change `s != PrayerStatus.missed` to `s == PrayerStatus.onTime || s == PrayerStatus.late`.
    - `isComplete`: change `every((s) => s != PrayerStatus.missed)` to `every((s) => s == PrayerStatus.onTime || s == PrayerStatus.late)`.
*   **Why**: Both getters currently treat `excused` as prayed. After the fix, only `onTime` and `late` count as completed. `achievement_service.dart:105` calls `isComplete` for the `perfect_day` badge and is fixed automatically by this change.
*   **Known callers of `isComplete`**: `achievement_service.dart:105` (`perfect_day` badge). No other callers in `lib/` use `DailyPrayerSummary.isComplete`.

#### 4. `lib/features/prayer/prayer_tracking_screen.dart` (Modify)

*   **Type / Scope**: Feature screen — `_isDayComplete`
*   **Line**: `:92`
*   **Proposed change**: Change `s.values.every((st) => st != PrayerStatus.missed)` to `s.values.every((st) => st == PrayerStatus.onTime || st == PrayerStatus.late)`.
*   **Why**: This is the same `!= missed` pattern as `DailyPrayerSummary.isComplete`. It drives the green "complete day" marker on the prayer tracking calendar. `excused` records currently pass this check; they must not.

#### 5. `lib/core/services/prayer_tracking_service.dart` (Modify)

*   **Type / Scope**: Service — `_streakFromRecords`, `_calculateBestStreak`, `getStatistics`

*   **`_streakFromRecords` (:480–482)**:
    Add a guard before `prayersByDay.putIfAbsent(...).add(record.prayerName)`: skip any record where `record.status != onTime && record.status != late`. `record` is a pre-loaded `PrayerRecord` object — no deserialization needed here.
    *   **Why**: The set currently admits any record regardless of status. With the guard, `prayers.length >= 5` only passes when five different prayers were actually performed.

*   **`_calculateBestStreak` (:525–528)**:
    Apply the same guard on the deserialized `PrayerRecord` object produced by `PrayerRecord.fromFirestore(doc)` inside the accumulation loop. The guard placement is on the resulting `.status` field after deserialization.
    *   **Why**: Same root cause; different data source — this function reads directly from Firestore documents rather than pre-loaded objects.

*   **`getStatistics` (:347)**:
    Change `case PrayerStatus.excused: break;` to `case PrayerStatus.excused: missed++; break;`.
    *   **Why**: The explicit `case excused: break;` at line 347 silently drops `excused` records, inflating completion rates. Routing them to `missed++` means they are counted as not-prayed in the statistics denominator.

*   **Test access**: Both `_streakFromRecords` and `_calculateBestStreak` are private. Test the streak filter via the public `calculateCurrentStreak({required String userId})` entry point using a Firestore fake or by promoting `_streakFromRecords` to `@visibleForTesting`. Test `getStatistics` behavior via its public signature with mocked Firestore records.

#### 6. `lib/features/prayer/prayer_report_screen.dart` (Modify)

*   **Type / Scope**: Feature screen — monthly statistics calculation
*   **Lines**: `:135–140`
*   **Proposed changes**:
    - Remove the `else if (record.status == PrayerStatus.excused) { totalExcused++; }` branch (lines 135–137).
    - Remove `- totalExcused` from the `totalMissed` formula at line 140. The formula becomes: `totalMissed = (kPrayerNames.length * 30) - completedOnTime - completedLate`.
*   **Why**: `excused` records currently go into a separate bucket and are excluded from both the "completed" and "missed" totals. After the fix, they fall through all branches and are counted in `totalMissed` via the subtraction formula — the same path as `missed` records. This correctly reflects that those prayers were not performed.

#### 7. `test/core/services/prayer_tracking_streak_test.dart` (Create)

*   **Type / Scope**: Unit test — streak filter and `getStatistics` status semantics
*   **Proposed test cases**:
    1. A day with five `missed` records does not count toward the streak.
    2. A day with five `excused` records does not count toward the streak (historical records).
    3. A day with five `onTime` records counts toward the streak.
    4. A day with a mix of `onTime` and `late` totalling five counts toward the streak.
    5. A day with four `onTime` + one `missed` does not count.
    6. Best streak: three consecutive fully-prayed days followed by a missed day returns 3.
    7. `getStatistics` with one `excused` record increments `missed` count and reduces completion rate.
*   **Why**: The streak filter is the change most likely to regress in a future refactor; pinning its boundary conditions makes the filter explicit and regression-detectable.

#### 8. `test/core/models/prayer_record_test.dart` (Create)

*   **Type / Scope**: Unit test — `DailyPrayerSummary.completedCount` and `isComplete`
*   **Proposed test cases**:
    1. `completedCount` with all five as `onTime` returns 5.
    2. `completedCount` with one `missed` returns 4.
    3. `completedCount` with one `excused` returns 4 (historical record treated as not-prayed).
    4. `isComplete` returns false when any prayer is `excused`.
    5. `isComplete` returns true when all five are `onTime` or `late`.
*   **Why**: `DailyPrayerSummary` is used by the prayer tracking screen and `achievement_service`; confirming the filter change produces the expected values for callers.

### Verification Plan

*   **Static analysis**: `flutter analyze` — no new issues above the 418-issue baseline (frozen reference from pre-work project state).
*   **Format**: `dart format --output=none --set-exit-if-changed .`
*   **Unit tests**: `flutter test` — all existing 249 Dart tests pass; new streak and model tests pass.
*   **Device check (nova 5T — project minimum-SDK test device, API 29)**:
    1. Mark one prayer as "Missed" via the in-app dialog.
    2. Confirm in logcat that the stored status is `missed`, not `excused`.
    3. Confirm the snackbar color is red (not green).
    4. Mark the remaining four prayers for today as "On Time."
    5. Confirm the streak does not increment — only 4 of 5 prayers qualify, which is below the 5-prayer threshold.
    6. Mark all five prayers "On Time" on a separate test day; confirm the streak increments.

---

*Drafted with EGM*
