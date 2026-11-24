# Fix F52b + F52c — Prayer tracking: midnight display and sync data loss

**Status:** Approved for code (phase P1)  
**Branch:** `fix/f52bc` (to be created from main)  
**Findings:** F52b (MEDIUM), F52c (MEDIUM)  
**Files touched:**
- `lib/features/home/home_screen.dart`
- `lib/features/prayer/prayer_screen.dart`
- `lib/core/services/prayer_alarm_service.dart`

---

## F52b — Home and Prayer screens hide yesterday's statuses between midnight and Fajr

### Problem

Between midnight and Fajr:
- `dailyPrayerStatusProvider` correctly sets `effectiveToday` to yesterday and loads yesterday's prayer records.
- `home_screen.dart:306–309` and `prayer_screen.dart:221–227, :409–413` then filter those statuses with `isPrayerTimeReached(name, todayPrayerTimes)`.
- `todayPrayerTimes` are today's (future) prayer times. `isPrayerTimeReached("Isha", todayPrayerTimes)` returns false because today's Isha hasn't occurred yet — so all five of yesterday's statuses are hidden.
- `prayer_screen.dart:239–244` calls `canMarkPrayer` against today's prayer times, which also returns false for every prayer, so the user cannot mark yesterday's Isha (or any other) after midnight.

The `daily_prayer_status_provider.dart:markDate()` already handles this correctly — it comments "In the after-midnight window the effective day is yesterday — all of its prayers are already in the past, so they must stay markable" and skips the 20-min rule unless `day == realToday`. The screens need to match.

### Fix

Gate the `isPrayerTimeReached` and `canMarkPrayer` checks behind `effectiveIsToday`. When `effectiveToday != realToday` (the midnight-to-Fajr window), all of yesterday's prayers are already in the past, so they always pass.

`DailyPrayerStatus.effectiveToday` is already exposed on the provider state. No new state or helpers are needed.

### Changes (Dart)

#### `lib/features/home/home_screen.dart` — prayer progress block (~line 299–309)

```dart
// Before
final rawPrayerStatuses =
    ref.watch(dailyPrayerStatusProvider.select((s) => s.statuses));
final todayPrayerTimes =
    ref.watch(prayerTimesProvider.select((s) => s.prayerTimes));
final prayerStatuses = Map<String, PrayerStatus>.fromEntries(
  rawPrayerStatuses.entries
      .where((e) => isPrayerTimeReached(e.key, todayPrayerTimes)),
);

// After
final rawPrayerStatuses =
    ref.watch(dailyPrayerStatusProvider.select((s) => s.statuses));
final effectiveIsToday = ref.watch(dailyPrayerStatusProvider.select((s) {
  final eff = s.effectiveToday;
  final now = DateTime.now();
  return eff.year == now.year && eff.month == now.month && eff.day == now.day;
}));
final todayPrayerTimes =
    ref.watch(prayerTimesProvider.select((s) => s.prayerTimes));
final prayerStatuses = Map<String, PrayerStatus>.fromEntries(
  rawPrayerStatuses.entries.where(
    (e) => !effectiveIsToday || isPrayerTimeReached(e.key, todayPrayerTimes),
  ),
);
```

#### `lib/features/prayer/prayer_screen.dart` — `_loadCompletedPrayers()` (~line 208–231)

```dart
// Before (inside the for-loop)
if (!isPrayerTimeReached(entry.key, prayerTimes)) continue;

// After
final effectiveToday = ref.read(dailyPrayerStatusProvider).effectiveToday;
final realToday = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
// (declare effectiveIsToday once before the loop)
final effectiveIsToday = effectiveToday == realToday;
...
if (effectiveIsToday && !isPrayerTimeReached(entry.key, prayerTimes)) continue;
```

#### `lib/features/prayer/prayer_screen.dart` — `ref.listen` block (~line 403–415)

Same guard, using `next.effectiveToday`:

```dart
// Before (inside the for-loop)
if (!isPrayerTimeReached(entry.key, currentPrayerTimes)) continue;

// After
final effectiveIsToday = next.effectiveToday == DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
...
if (effectiveIsToday && !isPrayerTimeReached(entry.key, currentPrayerTimes)) continue;
```

#### `lib/features/prayer/prayer_screen.dart` — `_markPrayerAsCompleted()` (~line 234–244)

```dart
// Before
if (!canMarkPrayer(
    context: context,
    prayerName: prayerName,
    prayerTimes: _prayerTimes,
    isArabic: isArabic)) {
  return;
}

// After
final effectiveToday = ref.read(dailyPrayerStatusProvider).effectiveToday;
final realToday = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
if (effectiveToday == realToday &&
    !canMarkPrayer(
        context: context,
        prayerName: prayerName,
        prayerTimes: _prayerTimes,
        isArabic: isArabic)) {
  return;
}
```

---

## F52c — Native statuses cleared as synced even when Firestore write fails

### Problem

`PrayerAlarmService.syncNativePrayerStatuses()` calls `clearNativePrayerStatus(key)` unconditionally after `PrayerTrackingService.recordPrayer()`. `recordPrayer()` returns `bool` — `false` on any Firestore error — but the return value is ignored. If the write fails, the native record is deleted without being stored in Firestore. The user's prayer status is silently lost and cannot be retried.

### Fix

Check the return value of `recordPrayer`. Only clear the native key on success; leave it in place on failure so the next sync can retry it.

### Change (Dart)

**File:** `lib/core/services/prayer_alarm_service.dart` (~line 444–455)

```dart
// Before
await PrayerTrackingService.instance.recordPrayer(
  userId: userId,
  prayerName: prayerName,
  date: date,
  prayedAt: DateTime.now(),
  status: prayerStatus,
  method: PrayerMethod.alone,
  notes: 'Logged via notification reminder',
);

// Clear the native key after successful sync
await clearNativePrayerStatus(key);

// After
final synced = await PrayerTrackingService.instance.recordPrayer(
  userId: userId,
  prayerName: prayerName,
  date: date,
  prayedAt: DateTime.now(),
  status: prayerStatus,
  method: PrayerMethod.alone,
  notes: 'Logged via notification reminder',
);

if (synced) {
  await clearNativePrayerStatus(key);
} else {
  debugPrint('⚠️ [SYNC] recordPrayer failed for $key — keeping for retry');
}
```

---

## Contract check

| Contract | Verdict |
|----------|---------|
| SharedPreferences key names | Unchanged |
| Firestore paths | Unchanged |
| Notification IDs / channels | Unchanged |
| Method-channel names | Unchanged |
| `prayer_status_*` native keys | Retained on Firestore failure (behavior improvement) |
| New keys introduced | None |

---

## Tests

Source-text tests are not applicable (Dart widget/provider logic). Unit tests for `syncNativePrayerStatuses` require a mock `PrayerTrackingService`; that infrastructure does not exist. Test coverage is via device checks.

The 20-min rule is already unit-tested by `DailySummaryDateKeyTest` (F51d tests cover `dateKey`; `isPrayerTimeReached` itself is tested implicitly through integration). No new unit tests are added.

---

## Device checks

| Step | Description |
|------|-------------|
| S63 | Between midnight and Fajr: open the app — Home shows yesterday's prayer progress (non-zero); Prayer screen shows all 5 yesterday's statuses |
| S64 | Between midnight and Fajr: tap a prayer that was missed yesterday — status dialog appears (not blocked by 20-min rule) |
| S65 | (Simulated, rare): offline sync — with no internet, answer a post-prayer notification; on next app open with internet, the status appears in Prayer Tracking calendar |
