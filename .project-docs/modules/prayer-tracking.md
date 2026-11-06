# Prayer tracking
Relocated from CLAUDE.md on 2026-11-06; not yet re-verified against code (Step 2).

## Key files
- `lib/core/providers/daily_prayer_status_provider.dart` — `dailyPrayerStatusProvider` (on-time/late/missed/excused)
- `lib/core/services/prayer_tracking_service.dart`, `lib/core/models/prayer_record`
- Screens: `/prayer_tracking` (`prayer_tracking_screen.dart`), `/prayer_report`; home + prayer screens share the provider
- `lib/core/widgets/prayer_status_dialog`, `prayer_card` (`PrayerCard._buildCompletedIndicator`)

## Home ↔ prayer screen sync
- Both screens share `dailyPrayerStatusProvider`. In `PrayerScreen._loadCompletedPrayers()`, `_explicitlyMarked` must
  include ALL prayers with records, including `PrayerStatus.missed` — otherwise Prayer Times cards don't show "Missed"
  when marked from home. `_buildCompletedIndicator` treats `excused` and `missed` as the red "Missed" badge.

## Null = untracked
- In `prayer_tracking_screen.dart`, a prayer with no Firestore record is `null` (grey "Not Prayed"), NOT
  `PrayerStatus.missed`. Never default `summary?.prayers[name] ?? PrayerStatus.missed`. Map is `Map<String, PrayerStatus?>`;
  `_buildPrayerActionRow` accepts `PrayerStatus?`.
- `getMonthData` must NOT pre-fill unrecorded prayers as missed — only prayers with actual records.
- `DailyPrayerSummary.isComplete` requires `prayers.length >= kPrayerNames.length` (all 5) AND none missed.

## After-midnight rules
- `_togglePrayerStatus`: between 00:00 and today's Fajr, `effectiveDate` = yesterday. The prayer records to
  `effectiveDate`, `_monthlyData[effectiveDate]` updates (not today's), snackbar says "Recorded [Prayer] for yesterday",
  and the 20-minute rule is skipped in this window. Users see those marks by selecting yesterday in the calendar.
- `dailyPrayerStatusProvider.load()` takes optional `fajrTime`; when given it computes the effective date (midnight→Fajr
  → yesterday) before querying Firestore. All callers with `prayerTimesProvider` access must pass it.
- In `MainWrapperScreen.didChangeAppLifecycleState`, read Fajr time **before** `ref.invalidate(prayerTimesProvider)`
  (invalidation clears state). The 30-second sync timer in `MainWrapperScreen` also passes Fajr time.
- `_PrayerTrackingScreenState._effectiveToday` is computed once in `initState` (same logic as `_selectedDay`). The
  `ref.listen` on `dailyPrayerStatusProvider` writes to `_monthlyData[_effectiveToday]` — never recompute the date inside
  the listener (race: `prayerTimesProvider` may not be loaded → yesterday's data in today's slot). Guard: if
  `next.statuses.isEmpty` and `_monthlyData[_effectiveToday]` has data, skip the write.

## isPrayerTimeReached guard
- `prayer_time_rules.dart` exports `isPrayerTimeReached(prayerName, prayerTimes)` — true only if
  `now >= prayer.time + 20 min` (same threshold as `canMarkPrayer`). Apply wherever a status is DISPLAYED for today.
- Applied in: home screen (`build()` via `ref.watch`), prayer times screen (`_buildPrayerCards` render time +
  `_loadCompletedPrayers` + `ref.listen`), prayer tracking screen (`_buildDayDetails` for `isToday`). Past days never filtered.

## Invalid record cleanup
- `PrayerTrackingService.cleanupFuturePrayerRecords()` deletes today's Firestore records where
  `record.prayedAt < prayer.time + 20 min` (impossible for a real user action; `canMarkPrayer` blocks early marking).
  Runs once per day from `prayerTimesProvider` side effects (`_lastSideEffectsDate`). Always use `prayedAt`, never
  current time alone, so the check stays correct if cleanup runs after the prayer window.

## Native status sync (notification layer 3)
- 30 min after adhan, post-prayer actions Done/Late/Missed/Later write `prayer_status_{name}_{date}` to
  `aura_prayer_times` (pattern: contracts/prefs-keys.md). `DailySummaryReceiver` summarizes at a configurable time
  (default 21:00).
- On app resume `_syncNativePrayerStatuses()` syncs to Firestore, clears native keys, then reloads
  `dailyPrayerStatusProvider` so notification-pressed statuses show immediately.
- **Order**: sync runs AFTER `dailyPrayerStatusProvider.load()` (CLAUDE.md said "line 117"); `syncNativePrayerStatuses()`
  returns `bool` and triggers a second `load()` only if something was synced.
- Navigation channel callbacks: `openPostPrayerPicker` / `openReminderPicker` / `updatePrayerStatus` (contracts/method-channels.md).
