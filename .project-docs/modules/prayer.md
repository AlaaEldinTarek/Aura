# Prayer — times & calculation
Verified against code 2026-11-07 (reference/2026-11-07_DRIFT_REPORT.md). Tracking: prayer-tracking.md.

## Key files
- `lib/core/services/prayer_times_service.dart` — times via `adhan`, next/current prayer logic (edit carefully)
- `lib/core/providers/prayer_times_provider.dart` — `prayerTimesProvider` (`PrayerTimesNotifier`): times, next/current
  prayer, side effects (alarms, widgets, native data); minute tick (edit carefully)
- `lib/core/services/location_service.dart`, `geocoding_service`, `lib/core/utils/prayer_time_rules.dart`, `hijri_date`
- `lib/core/models/prayer_time`, `prayer_settings`; UI pickers `lib/features/settings/adhan_calculation_method.dart`,
  `asr_madhab_selection.dart`
- Native recalculation without the app: `NativePrayerCalculator.kt` (notifications-native.md)

## Methods & madhab
- UI (Settings and prayer screen) offers 12 `AdhanCalculationMethod` values, stored as strings (`'MuslimWorldLeague'`,
  `'UmmAlQura'`, …). `PrayerTimesNotifier._getCalculationMethod` maps them onto the internal 9-value enum
  (`prayer_settings.dart`): UmmAlQura / Qatar → makkah, NorthAmerica → isna, Dubai → kuwait; MoonsightingCommittee,
  Singapore, Turkey fall back to MWL (findings F36a). FixedAngle / Proportional are not selectable; in Dart they equal
  Egyptian / MWL (native Proportional uses other angles, F52p).
- Asr madhab stored as `'Hanafi'` / `'Shafi'`; `_getAsrMadhab` compares with lowercase enum names → always Shafi (F36a,
  root F49f). Do not rely on Hanafi working until FX-0.
- Location-based times via the `adhan` package; Hijri date display; Qibla compass (`/qibla`).

## Calculation flow
1. `PrayerTimesNotifier._getCachedLocation()` — wraps `LocationService.getBestLocation()` (GPS or manual), **cached
   15 min** in the notifier (`_locationCacheTTL`).
2. `PrayerTimesService.getPrayerTimes()` — 6 times (incl. Sunrise) + iqama minutes (`loadIqamaMinutes`).
3. `PrayerTimesNotifier.loadPrayerTimes(date)` sets state, then runs side effects guarded by `_lastSideEffectsDate`
   (key built from `date`, set synchronously). The guard lives on the notifier instance: `ref.invalidate(prayerTimesProvider)`
   on every app resume (and in the desktop location dialog) creates a new notifier, so side effects run on every cold
   start and resume, but a second same-day load in the same notifier skips them (F52a: Settings recalc).
4. Side effects, in order: post-prayer check alarms (Android) → daily task digest (desktop/mobile variants) → daily
   prayer alarms → desktop `DesktopAdhanService.initialize` + `DesktopPrayerScheduler.schedulePrayerTimers` →
   `savePrayerTimes` → `PrayerTrackingService.cleanupFuturePrayerRecords()` → `updatePrayerTimes` (also sends
   `latitude`, `longitude`, `calculationMethod`, `asrMadhab` for `NativePrayerCalculator`) → Android
   `cacheAccuratePrayerTimes` (today + 2 days, `cached_{date}_*`).

## Next-prayer logic (critical)
- `getNextPrayer()` sorts by time and returns the first after `now` (Sunrise can be returned). If all passed, it returns a
  "tomorrow's Fajr" built from today's Fajr time, not tomorrow's calculation. Background: memory "next-prayer
  architecture" (derive, never cache).
- Minute tick `_startNextPrayerUpdateTimer` → `_quickUpdateNextPrayer` (no GPS, no side effects); when the next prayer is
  dated tomorrow it calls `loadPrayerTimes(now)` — after Isha this repeats every minute (F52d). Desktop: a tick gap
  > 3 min (sleep) reschedules `DesktopPrayerScheduler`.
- `PrayerTimesNotifier.updateNextPrayer()` has no caller (F52o).

## Makkah / Umm al-Qura Dhuhr offset
- The `adhan` library's `umm_al_qura` method has zero Dhuhr adjustment by default. `PrayerTimesService.getPrayerTimes()`
  applies `params.adjustments.dhuhr = 3` when `calculationMethod == CalculationMethod.makkah` to match the official
  Umm al-Qura calendar (+3 min). Do not remove this offset.

## Iqama
- Side effects write per-prayer iqama keys (`fajr_iqama_time`, `dhuhr_iqama_time`, `asr_iqama_time`,
  `maghrib_iqama_time`, `isha_iqama_time`) to `aura_prayer_times` alongside the `*_time` keys. Zuhr key is
  `dhuhr_iqama_time` (not `zuhr_iqama_time`).
- `/iqama_settings` saves `iqama_minutes` and does not reload; native iqama keys update at the next side-effects run.
- `PrayerAlarmReceiver` reads them to activate Adhan Mode in the foreground notification ("Iqama in Xm Ys") and writes
  `adhan_iqama_time` (absolute ms; 0 if not configured); `AdhanFullScreenActivity` reads it for its countdown.

## Jumu'ah naming
- `getPrayerDisplayName()` returns "Jumu'ah"/"الجمعة" for Zuhr on Fridays (rule in CLAUDE.md). Reminder: notifications-native.md.
