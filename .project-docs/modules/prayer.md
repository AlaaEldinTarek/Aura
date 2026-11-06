# Prayer — times & calculation
Relocated from CLAUDE.md on 2026-11-06; not yet re-verified against code (Step 2). Tracking: prayer-tracking.md.

## Key files
- `lib/core/services/prayer_times_service.dart` — day transitions, next/current prayer logic (edit carefully)
- `lib/core/providers/prayer_times_provider.dart` — `prayerTimesProvider`: prayer times, next/current prayer, alarms,
  widgets; auto-refreshes every minute (edit carefully)
- `lib/core/services/location_service.dart`, `geocoding_service`, `lib/core/utils/prayer_time_rules.dart`, `hijri_date`
- `lib/core/models/prayer_time`, `prayer_settings`
- Native recalculation without the app: `NativePrayerCalculator.kt` (notifications-native.md)

## Features
- 9 calculation methods: MWL, ISNA, Egyptian, Makkah, Karachi, Tehran, Kuwait, FixedAngle, Proportional; Asr madhab
- Location-based times via the Adhan library (`adhan` 2.0.0+1); Hijri date display; Qibla compass (`/qibla`)

## Calculation flow
1. `LocationService.getBestLocation()` — GPS or manual location, **cached 15 min** (`_locationCacheTTL`)
2. `PrayerTimesService.getPrayerTimes()` — 6 prayer times via Adhan library + selected method + Asr madhab
3. `PrayerTimesNotifier.loadPrayerTimes()` — **side effects run once per day** (guarded by `_lastSideEffectsDate`,
   set synchronously before the async block)
4. Side effects: `schedulePostPrayerCheck()`, `scheduleDailyTaskDigest()`, `scheduleDailyPrayerAlarms()`,
   `savePrayerTimes()`, `updatePrayerTimes()`. `updatePrayerTimes()` also passes `latitude`, `longitude`,
   `calculationMethod`, `asrMadhab` so `NativePrayerCalculator` can recalculate without the app open.
   The same block runs `PrayerTrackingService.cleanupFuturePrayerRecords()` (prayer-tracking.md).

## Next-prayer logic (critical)
- `getNextPrayer()` checks `prayer.time.isAfter(now)` for each prayer in order — returns tomorrow's Fajr only if ALL
  of today's prayers have passed.

## Makkah / Umm al-Qura Dhuhr offset
- The `adhan` library's `umm_al_qura` method has zero Dhuhr adjustment by default. `PrayerTimesService.getPrayerTimes()`
  applies `params.adjustments.dhuhr = 3` when `calculationMethod == CalculationMethod.makkah` to match the official
  Umm al-Qura calendar (+3 min). Do not remove this offset.

## Iqama
- Flutter's `prayerTimesProvider` side effects write per-prayer iqama keys (`fajr_iqama_time`, `dhuhr_iqama_time`,
  `asr_iqama_time`, `maghrib_iqama_time`, `isha_iqama_time`) to `aura_prayer_times` alongside the `*_time` keys.
  Zuhr key is `dhuhr_iqama_time` (not `zuhr_iqama_time`).
- `PrayerAlarmReceiver` reads them to activate Adhan Mode in the foreground notification ("Iqama in Xm Ys"), and writes
  `adhan_iqama_time` (absolute ms timestamp; 0 if iqama not configured) when an alarm fires.
  `AdhanFullScreenActivity` reads it for the post-adhan countdown.
- Iqama settings screen: `/iqama_settings`.

## Jumu'ah naming
- `getPrayerDisplayName()` returns "Jumu'ah"/"الجمعة" for Zuhr on Fridays (rule in CLAUDE.md). Reminder: notifications-native.md.
