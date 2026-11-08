# adhan port (`com.aura.hala.adhan`)

## Overview
Line-by-line Kotlin port of the Dart package **adhan 2.0.0+1** (pub.dev, `lib/src/`), used by
`NativePrayerCalculator.calculate` when no Flutter-cached day exists (FX-0,
[spec](/docs/designs/fx-0-prayer-settings.md) item 13). The Dart package is the source of truth; the port must equal it
(plus the app's documented Umm al-Qura Dhuhr +3 min, applied in `NativePrayerCalculator.methodParams`, not here).

**Do not edit except to re-port** from a new package version: change the Dart side first, then port the same lines,
then regenerate the fixture (`dart run tool/generate_prayer_parity_fixture.dart`) and run
`NativePrayerCalculatorParityTest`.

## Files (mirror of `adhan-2.0.0+1/lib/src/`)
| Dart file | Kotlin file |
| --- | --- |
| `prayer_times.dart` (without `today` / `utc` / `utcOffset` factories and `currentPrayer` … `timeForPrayer`) | `PrayerTimes.kt` |
| `calculation_method.dart` | `CalculationMethod.kt` |
| `calculation_parameters.dart` | `CalculationParameters.kt` |
| `prayer_adjustments.dart` | `PrayerAdjustments.kt` |
| `madhab.dart` | `Madhab.kt` |
| `high_latitude_rule.dart` | `HighLatitudeRule.kt` |
| `coordinates.dart` | `Coordinates.kt` |
| `data/date_components.dart` | `data/DateComponents.kt` |
| `data/time_components.dart` | `data/TimeComponents.kt` |
| `data/calendar_util.dart` | `data/CalendarUtil.kt` |
| `extensions/datetime.dart` | `extensions/DateTime.kt` |
| `internal/astronomical.dart` | `internal/Astronomical.kt` |
| `internal/calendrical_helper.dart` | `internal/CalendricalHelper.kt` |
| `internal/double_util.dart` | `internal/DoubleUtil.kt` |
| `internal/math.dart` | `internal/Math.kt` |
| `internal/shadow_length.dart` | `internal/ShadowLength.kt` |
| `internal/solar_coordinates.dart` | `internal/SolarCoordinates.kt` |
| `internal/solar_time.dart` | `internal/SolarTime.kt` |

Not ported: `adhan.dart`, `adhan_base.dart`, `prayer.dart`, `qibla.dart`, `sunnah_times.dart`, `internal/qibla_util.dart`.

## Invariants
- Every declaration is `internal`; no `android.*` calls (runs in JVM unit tests).
- Dart semantics kept: `round()` is half away from zero (`dartRound`, `DoubleUtil.kt`); `TimeComponents.fromDouble`
  floors; `copyWith` rolls out-of-range fields over like Dart's `DateTime` constructor; times are computed in UTC and
  converted with the caller's zone per instant (Dart's `toLocal()`); `adhanDayOfYear` equals Dart's `dayOfYear` on a
  host with a UTC offset in [0, 24 h), the host rule of the fixture generator.
- `java.time` on API 24 via core library desugaring (enabled in `android/app/build.gradle.kts`).

## Licence
adhan is MIT licensed, "Copyright (c) 2020 Riajul Islam"; `LICENSE` in this folder is a verbatim copy. Each file
carries the port header naming its source file.

## Verification
`android/app/src/test/kotlin/com/aura/hala/NativePrayerCalculatorParityTest.kt`: every row of
`test/fixtures/prayer_parity.csv` (13 cities × 10 dates × 14 methods × 2 madhabs) within ±1 min (2026-11-08: all
21,840 times equal to the millisecond), plus the DST transition dates of the fixture.
