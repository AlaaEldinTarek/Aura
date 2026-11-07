# Qibla Feature

## Overview
One screen, `qibla_screen.dart` (route `/qibla`, opened from a Prayer screen button and the toolkit; the desktop shell
builds it in `main_wrapper_screen.dart`). It gets a location from `LocationService.getBestLocation`
([services](../../core/services/README.md)), computes the great-circle bearing and distance to the Kaaba locally,
and rotates a compass dial from `flutter_compass` heading events. Behavior-preserving rule: no UI or logic change
without an approved spec.

## Interface
| File | Public symbols / entry points |
| --- | --- |
| `qibla_screen.dart` | `QiblaScreen()` (no params). `CompassPainter({heading, qiblaDirection, isDark})` (public `CustomPainter`, used only here). Private: `_QiblaScreenState` |

- Reads `LocationService.instance.getBestLocation()` once per `_initializeCompass` (on open and on Retry).
- Subscribes to `FlutterCompass.events`; cancelled in `dispose`. Wrapped in `ConnectivityWrapper` (offline banner).

## Invariants
- **Kaaba** = `21.4225, 39.8262` (`_kaabaLatitude` / `_kaabaLongitude`). Bearing: `atan2(sin Δλ, cos φ1·tan φ2 −
  sin φ1·cos Δλ)`, normalized to 0–360 (relative to true north). Distance: haversine, R = 6371 km, rounded to km.
- **Location source** is whatever `getBestLocation` returns (manual location first; on desktop the saved location,
  else a Mecca default); no GPS call of its own.
- **Heading**: no magnetic-declination correction (findings F48f); low-pass filter `smoothed += diff × 0.3` with 0/360 wrap handling; the dial rotates by
  `-heading/360` turns (`AnimatedRotation`, 200 ms) and `CompassPainter` always gets `heading: 0`.
- **Loading ends only on the first compass event** (`_isLoading = false` inside the listener). No events (no sensor,
  null stream) → spinner forever (findings F48).
- **Instruction text**: `headingDiff = |qibla − heading|` with no wraparound; < 5° "facing Qibla" (green), < 20°
  "close" (orange), else always "Turn to the right" (findings F48).
- **Localization**: inline EN/AR strings; only `retry` is a `.tr()` key. Cardinal labels N/E/S/W are fixed English.

## Side Effects
- Location lookup through `LocationService`; magnetometer stream through `flutter_compass`. No writes.

## Verification
- Run: `flutter test` (no tests for this folder). Known issues: findings F48.
