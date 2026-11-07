# Prayer tracking
Verified against code 2026-11-07 (reference/2026-11-07_DRIFT_REPORT.md).

## Key files
- `lib/core/providers/daily_prayer_status_provider.dart` — `dailyPrayerStatusProvider` (on-time/late/missed/excused)
- `lib/core/services/prayer_tracking_service.dart`, `lib/core/models/prayer_record`
- Screens: `/prayer_tracking` (`prayer_tracking_screen.dart`), `/prayer_report`; home + prayer screens share the provider
- `lib/core/widgets/prayer_status_dialog`, `prayer_card` (`PrayerCard._buildCompletedIndicator`)
- Native side: `PrayerAlarmReceiver`, `NativeNotificationReceiver`, `DailySummaryReceiver`; Dart bridge
  `prayer_alarm_service.dart` `syncNativePrayerStatuses`

## Status semantics
- The dialog's red "Missed" returns `PrayerStatus.excused`; `DailyPrayerSummary.isComplete` / `completedCount` and the
  calendar's `_isDayComplete` treat every non-`missed` status as done (F25, FX-1).
- `_buildCompletedIndicator` shows `excused` and `missed` as the red "Missed" badge. `PrayerScreen._loadCompletedPrayers()`
  puts every prayer with a record in `_explicitlyMarked` (incl. missed) so marks from Home show on Prayer cards.

## Null = untracked
- A prayer with no Firestore record is untracked (grey "Not Prayed"), never `PrayerStatus.missed`. In
  `prayer_tracking_screen.dart`, `_displayStatuses` returns `Map<String, PrayerStatus>` and the row looks up
  `displayed[prayerName]` (nullable); `_buildPrayerActionRow` accepts `PrayerStatus?`.
- `getMonthData` must NOT pre-fill unrecorded prayers as missed — only prayers with actual records.

## After-midnight rules
- Effective day = `dailyPrayerStatusProvider.notifier.computeEffectiveToday()` (between 00:00 and today's Fajr →
  yesterday). `load()` always computes it; the optional `fajrTime` only updates `_lastFajr`. `load()` skips Firestore when
  cached data is < 30 s old and non-empty, unless `forceRefresh`.
- Tracking screen: initial selected/focused day = `_effectiveToday` (set once in `initState`).
  `_togglePrayerStatus` records to the **tapped calendar date** (`markDate` / `unmarkDate`); no automatic remap. A date
  after the effective day is rejected, so the real today is rejected before Fajr. `canMarkPrayer` (20-minute rule)
  applies only when the tapped date is the real calendar today. Tapping yesterday as the effective day → snackbar
  "Recorded [Prayer] for yesterday".
- Home and prayer screen filter the effective day's statuses with today's prayer times, so yesterday's statuses are hidden
  between 00:00 and Fajr, and the prayer screen's `canMarkPrayer` blocks marking yesterday's Isha (F52b).
- `MainWrapperScreen.didChangeAppLifecycleState`: read Fajr **before** `ref.invalidate(prayerTimesProvider)`
  (invalidation clears state).
- Month data: no local month map and no `ref.listen`; the screen calls
  `dailyPrayerStatusProvider.notifier.loadMonth(_focusedDay, forceRefresh: true)` and renders provider state (F36d).

## Live sync
- Android: `startLiveSync()` Firestore listener + 3-minute re-subscribe tick; `stopLiveSync()` on pause.
- Desktop: 30-second sync timer in `MainWrapperScreen` (passes Fajr).

## isPrayerTimeReached guard
- `prayer_time_rules.dart` `isPrayerTimeReached(prayerName, prayerTimes)` — true only if `now >= prayer.time + 20 min`
  (same threshold as `canMarkPrayer`). Apply wherever a status is DISPLAYED for today.
- Applied in: home `build()` (via `ref.watch`), prayer screen (`_buildPrayerCards`, `_loadCompletedPrayers`,
  `ref.listen`), tracking screen `_displayStatuses` (real calendar today only; feeds stats cards, calendar markers and
  `_buildDayDetails`). Past days never filtered.

## Invalid record cleanup
- `PrayerTrackingService.cleanupFuturePrayerRecords()` deletes today's (real calendar day) records where
  `record.prayedAt < prayer.time + 20 min`. Runs in every `prayerTimesProvider` side-effects run, i.e. each new notifier
  (cold start, every resume) — see prayer.md § Calculation flow. Always use `prayedAt`, never current time alone.

## Native status sync (notification layer 3)
- 30 min after adhan, post-prayer buttons write `prayer_status_{name}_{date}` = `on_time` / `late` / `missed` to
  `aura_prayer_times` (pattern: contracts/prefs-keys.md); "Remind later" opens a picker. `NativeNotificationReceiver`
  "Mark as prayed" also writes `on_time`. `DailySummaryReceiver` summarizes at a configurable time (default 21:00) and
  prunes keys older than 7 days.
- `MainWrapperScreen._syncThenLoadPrayerStatus(fajrTime)` (resume, and cold start after 2 s): first
  `syncNativePrayerStatuses()` (Firestore write, then key overwritten with `"synced"`, skipped on read — also when the
  write failed, F52c), then always one `load(forceRefresh: true, fajrTime:)` in `finally` (returned `bool` ignored), then
  Android `startLiveSync()`.
- Navigation channel callbacks: `openPostPrayerPicker` / `openReminderPicker` / `updatePrayerStatus` (contracts/method-channels.md).
