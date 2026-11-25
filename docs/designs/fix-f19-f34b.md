# Fix F19 + F34b — 20-minute rule applied inconsistently

**Status:** Approved for code (phase P1)  
**Branch:** `fix/f19-f34b` (to be created from main)  
**Findings:** F19 (MEDIUM), F34b (MEDIUM)  
**Files touched:**
- `lib/core/services/prayer_tracking_service.dart`
- `lib/features/main/main_wrapper_screen.dart`

---

## Problem

The 20-minute rule is defined once in `canMarkPrayer` / `isPrayerTimeReached`
(`lib/core/utils/prayer_time_rules.dart`): a prayer can be marked only after
`adhan + 20 min`. Two callsites are inconsistent with it:

### Bug 1 — F19: cleanup threshold is too aggressive

`cleanupFuturePrayerRecords` (`prayer_tracking_service.dart:731`) deletes
today's records where `record.prayedAt.isBefore(prayer.time.add(Duration(minutes: 20)))`.

That condition includes records created **at adhan time**, which is exactly
when the notification paths fire:
- Android "Prayed ✓" button: `prayedAt: DateTime.now()` in
  `NotificationService._handleMarkPrayed` (`notification_service.dart:563`)
- Desktop "Prayed ✓" toast: `prayedAt: now` in
  `DesktopNotificationService._handlePrayerStatusAction`
  (`desktop_notification_service.dart:192`)

Both are legitimate marks made at adhan time. The next app start runs the
cleanup and silently deletes them.

The only records that are **truly impossible** are ones with
`prayedAt < prayer.time` (before the prayer even started). The 20-minute
in-app guard blocks early marking, but notification paths are intentionally
exempt from it — they fire at adhan time.

### Bug 2 — F34b: untracked-prayer sheet appears too early

`_checkUntrackedPrayers` (`main_wrapper_screen.dart:626–630`) classifies
a prayer as "past" using only `p.time.isBefore(now)` — the adhan has fired.
It does not check whether 20 min have passed. Within those 20 min:

1. The sheet pops up showing the prayer as untracked.
2. The user taps a status button.
3. `_recordPrayerStatusFromNotification` calls `markToday` directly —
   bypassing `canMarkPrayer` entirely.

The user can mark a prayer within 20 min of adhan from the untracked sheet
even though the same action from the Home or Prayer tabs is blocked.

---

## Fix

### `prayer_tracking_service.dart` — lower threshold to `< prayer.time`

```dart
// Before (line 731)
final windowEnd = prayer.time.add(const Duration(minutes: 20));
// prayedAt before the window = physically impossible legitimate record
if (record.prayedAt.isBefore(windowEnd)) {

// After
// prayedAt before the prayer itself = truly impossible (notification paths
// fire at adhan time; canMarkPrayer blocks in-app marking for 20 min).
if (record.prayedAt.isBefore(prayer.time)) {
```

Update the doc-comment on the function:

```dart
/// Delete prayer records for today where the record was created before
/// the prayer's Adhan — i.e. impossible to have been created by any
/// legitimate user action.  Notification paths fire at adhan time and may
/// write [prayedAt] equal to [prayer.time]; those are valid and must not
/// be removed.  The 20-minute in-app guard ([canMarkPrayer]) is enforced
/// by the UI, not by this cleanup.
```

### `main_wrapper_screen.dart` — add import, use `isPrayerTimeReached`

Add import (after the existing `prayer_tracking_service.dart` import):

```dart
import '../../core/utils/prayer_time_rules.dart';
```

Change the filter in `_checkUntrackedPrayers` (line 626–630):

```dart
// Before
final pastPrayers = prayerTimes
    .where((p) => p.name != 'Sunrise' && p.time.isBefore(now))
    .toList();

// After
// Only include prayers whose 20-min marking window has opened so the
// sheet never races with canMarkPrayer on the Home / Prayer tabs.
final pastPrayers = prayerTimes
    .where((p) => p.name != 'Sunrise' && isPrayerTimeReached(p.name, prayerTimes))
    .toList();
```

The local `now` variable is no longer needed after this change if it has
no other uses in the function; check and remove if so.

---

## Contract check

| Contract | Verdict |
|----------|---------|
| SharedPreferences key names | Unchanged |
| Firestore paths | Unchanged |
| Notification IDs / channels | Not involved |
| Prayer record fields (`prayedAt`, `status`) | Unchanged — only the cleanup threshold and the sheet filter change |
| New keys introduced | None |

---

## Tests

Source-text tests (2 tests, file `test/core/services/f19_f34b_source_test.dart`):

- **T1**: `prayer_tracking_service.dart` uses `record.prayedAt.isBefore(prayer.time)`
  as the cleanup condition — not `isBefore(prayer.time.add(Duration(minutes: 20)))`.
- **T2**: `main_wrapper_screen.dart` uses `isPrayerTimeReached(p.name, prayerTimes)`
  (not `p.time.isBefore(now)`) to filter the past-prayers list in
  `_checkUntrackedPrayers`.

---

## Device checks

| ID | Description |
|----|-------------|
| S-F19-1 | At adhan time, tap "Prayed ✓" on the Android notification or the Windows toast. Force-stop the app and reopen it within 20 min of that adhan. The prayer should still be recorded (green mark on Home); the cleanup must not delete it. Requires a live prayer window. |
| S-F34b-1 | Within 20 min of an adhan, switch to the app (or resume it). The untracked-prayer sheet should **not** appear for that prayer yet. After 20 min have elapsed, force-stop and reopen; the sheet should now list the prayer as untracked. Requires a live prayer window. |
