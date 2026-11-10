# Prayer — times & calculation
Verified against code 2026-11-07 (reference/2026-11-07_DRIFT_REPORT.md); FX-0 changes (2026-11-08, branch
`fix/fx-0-prayer-settings`, spec docs/designs/fx-0-prayer-settings.md) included. Tracking: prayer-tracking.md.

## Key files
- `lib/core/services/prayer_times_service.dart` — times via `adhan`, next/current prayer logic (edit carefully)
- `lib/core/providers/prayer_times_provider.dart` — `prayerTimesProvider` (`PrayerTimesNotifier`): times, next/current
  prayer, side effects (alarms, widgets, native data); minute tick (edit carefully)
- `lib/core/utils/prayer_refresh.dart` — pure refresh helpers (fingerprint, 7 cache days, native cache keys, next
  occurrences, post-checks to schedule, generation gate); unit-tested
- `lib/core/services/location_service.dart`, `geocoding_service`, `lib/core/utils/prayer_time_rules.dart` (`nativePrayerKey`:
  canonical Dart→native key mapping, maps zuhr→dhuhr; F15 fix), `hijri_date`
- `lib/core/models/prayer_time`, `prayer_settings`; UI pickers `lib/features/settings/adhan_calculation_method.dart`,
  `asr_madhab_selection.dart`
- Native recalculation without the app: `NativePrayerCalculator.kt` (notifications-native.md)

## Methods & madhab
- UI (Settings and prayer screen) offers 12 `AdhanCalculationMethod` values, stored as strings (`'MuslimWorldLeague'`,
  `'UmmAlQura'`, …). `calculationMethodFromPref` (`prayer_settings.dart`, used by `PrayerTimesNotifier._getCalculationMethod`)
  maps each onto its own value of the internal 14-value `CalculationMethod` enum: UmmAlQura → makkah, NorthAmerica →
  isna, Qatar → qatar, Dubai → dubai, Turkey → turkey, Singapore → singapore, MoonsightingCommittee →
  moonsightingCommittee, the rest by name; an exact enum name is accepted; null / unknown → MWL. Each internal value maps
  to its own `adhan` method (`_mapToAdhanCalculationMethod`). FixedAngle / Proportional are not selectable; in Dart and
  Kotlin they equal Egyptian / MWL. The enum names are the `prayer_calc_method` contract strings (contracts/prefs-keys.md).
- Asr madhab stored as `'Hanafi'` / `'Shafi'`; `asrMadhabFromPref` matches case-insensitively (null / unknown → Shafi),
  so Hanafi Asr applies and native receives `'hanafi'` (FX-0, F36a; duplicate enums F49f remain).
- Location-based times via the `adhan` package; Hijri date display; Qibla compass (`/qibla`).

## Calculation flow
1. `PrayerTimesNotifier._getCachedLocation()` — wraps `LocationService.getBestLocation()` (GPS or manual), **cached
   15 min** in the notifier (`_locationCacheTTL`).
2. `PrayerTimesService.getPrayerTimes()` — 6 times (incl. Sunrise) + iqama minutes (`loadIqamaMinutes`), calculated
   for the requested date itself (`adhan.PrayerTimes(coordinates, DateComponents.from(date), params)`; no whole-day
   shift of today's times, F53a fixed by FX-0).
3. `PrayerTimesNotifier.loadPrayerTimes(date)` sets state, then computes 7 calendar days from the wall-clock date
   (`cacheDays`, `lib/core/utils/prayer_refresh.dart`; day 0 reuses the loaded times) and an input fingerprint
   (`sideEffectsFingerprint`: wall-clock date, method, madhab, iqama minutes, every time of the 7 days). If it equals
   `_lastFingerprint`, nothing runs; otherwise it is stored and the run takes a generation number (static `_generation`,
   shared by all notifier instances), all synchronously. Before each platform write the run checks `isLatest` and stops
   if a newer run started. A new notifier (app resume, desktop location dialog) starts with an empty fingerprint, so
   every open rewrites everything. Method / madhab / iqama saves call `loadPrayerTimes(DateTime.now())` (Settings,
   prayer settings page, `/iqama_settings`).
4. Prayer-derived side effects, in order, each in its own try/catch: `savePrayerTimes` (widgets) and desktop
   `DesktopAdhanService.initialize` + `DesktopPrayerScheduler.schedulePrayerTimers` → `updatePrayerTimes` (also sends
   `latitude`, `longitude`, `calculationMethod`, `asrMadhab` for `NativePrayerCalculator`) → Android
   `cacheAccuratePrayerTimes` with `buildNativeCache` (today … +6, 42 `cached_{date}_*` keys) → adhan alarms at each
   prayer's next occurrence (`nextOccurrences`: today if ahead, else tomorrow) → post-prayer checks whose time + 30 min
   is still ahead (`postChecksToSchedule`; never cancelled). Then, once per wall-clock day (`_lastDailyEffectsDate`,
   not gated by the generation): daily task digest (desktop/mobile variants) → `PrayerTrackingService.cleanupFuturePrayerRecords()`.

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
  Umm al-Qura calendar (+3 min). Do not remove this offset. Kotlin applies the same +3 (`NativePrayerCalculator.methodParams`).

## Iqama
- Side effects write per-prayer iqama keys (`fajr_iqama_time`, `dhuhr_iqama_time`, `asr_iqama_time`,
  `maghrib_iqama_time`, `isha_iqama_time`) to `aura_prayer_times` alongside the `*_time` keys. Zuhr key is
  `dhuhr_iqama_time` (not `zuhr_iqama_time`).
- `/iqama_settings` saves `iqama_minutes` and calls `loadPrayerTimes(DateTime.now())`; iqama is in the fingerprint, so
  the native iqama keys update right away. Alarms armed for tomorrow still read today's iqama instant (F54a, out of FX-0).
- `PrayerAlarmReceiver` reads them to activate Adhan Mode in the foreground notification ("Iqama in Xm Ys") and writes
  `adhan_iqama_time` (absolute ms; 0 if not configured); `AdhanFullScreenActivity` reads it for its countdown.

## Jumu'ah naming
- `getPrayerDisplayName()` returns "Jumu'ah"/"الجمعة" for Zuhr on Fridays (rule in CLAUDE.md). Reminder: notifications-native.md.
