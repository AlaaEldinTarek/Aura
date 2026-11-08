# FX-0 — decided inputs for the spec (prayer method / madhab / recalculation)
Input for `/egm:egm-draft` (user runs it). Decisions by the user, 2026-11-07. Findings: F36a, F36c, F52a, F53a. Modules: `.project-docs/modules/prayer.md`, `notifications-native.md`. ADR 0001.

## Scope (decided)
- F36a: Hanafi Asr is applied (stored `'Hanafi'` / `'Shafi'` read as-is; no prefs key rename) and every UI method
  maps to its exact `adhan` method.
- F36c + F52a: any method / madhab / iqama change recalculates AND refreshes alarms, post-prayer checks, widgets,
  native data (`updatePrayerTimes`) and the `cached_*` days — from both entry points (Settings, Prayer screen dialog).
- F53a: times for any date are calculated for that date (no whole-day shift of today's times).

## Decisions
1. **Native times must never differ from Dart times.**
   - Singapore and Turkey: exact on both sides, parameters from the `adhan` package source (table below).
   - MoonsightingCommittee: exact in Dart; documented native approximation (option b). The spec records the
     limitation and a follow-up item: Dart precomputes several days of times for native, so the native calculator
     becomes a rare fallback. (Today Dart already caches today + 2 days as `cached_{date}_*` and
     `NativePrayerCalculator.cachedOrComputed` prefers them.)
2. **Qatar and Dubai: exact within FX-0** (current mappings Qatar → makkah, Dubai → kuwait give wrong times).
3. **Source of truth: the `adhan` package (2.0.0+1).** Tests: Dart output == package output for every method ×
   madhab; Kotlin parity vs package within ±1 min for several cities (incl. Cairo and one high-latitude city) and
   dates (summer, winter, DST change).
4. **No in-app notice.** The Asr correction is mentioned in the Play Store release notes only.
5. **Makkah +3 min Dhuhr stays** as a documented app adjustment, applied identically in Dart and Kotlin. Test rule
   (both sides): package output + documented app adjustments == app output.
6. **F53a joins FX-0.**
   - **A-1 (2026-11-08): F49c (HIGH) and F49j (MEDIUM) join FX-0.** Device evidence: the calculation dialog is cut
     off at "Singapore" on the nova 5T, so Hanafi cannot be selected; the stateless dialog does not show a tap.
     Scroll the middle section and hold the selection locally; callbacks and `show()` unchanged (spec § Changes 8).
7. **The spec must compare two options and pick one with reasons:**
   - A) Full Kotlin parity with the package for all methods.
   - B) Dart precomputes N days (e.g. 7), each calculated for its own date (fixes F53a at the root), and stores
     them for native; the Kotlin calculator becomes a fallback that still needs package parity.
   Either way the spec lists and resolves each existing native divergence: method adjustments, Tehran Maghrib
   angle, high-latitude rule, minute truncation vs rounding, single UTC offset per day (details below).

## Package parameters (from `adhan-2.0.0+1/lib/src/calculation_method.dart`, `getParameters()`)
| UI value → package method | Fajr | Isha | Method adjustments (min) |
| --- | --- | --- | --- |
| Singapore → `singapore` | 20.0° | 18.0° | dhuhr +1 |
| Turkey → `turkey` | 18.0° | 17.0° | sunrise −7, dhuhr +5, asr +4, maghrib +7 |
| Qatar → `qatar` | 18.0° | interval 90 min | none |
| Dubai → `dubai` | 18.2° | 18.2° | sunrise −3, dhuhr +3, asr +3, maghrib +3 |
| MoonsightingCommittee → `moon_sighting_committee` | 18.0° | 18.0° + seasonal adjustment | dhuhr +5, maghrib +3 |
| (existing) MWL / Egyptian / Karachi / NorthAmerica | per package | per package | dhuhr +1 |
| (existing) Tehran | 17.7° | 14.0° | Maghrib at 4.5° below horizon |
Package defaults: `highLatitudeRule = middle_of_the_night`; all times rounded to the nearest minute (`roundedMinute`).

## Facts the spec must handle (VERIFIED in code 2026-11-07)
- Native `NativePrayerCalculator.methodAngles` knows only the 9 internal names; it ignores method adjustments
  (e.g. dhuhr +1 on MWL), Tehran's Maghrib angle (uses sunset), uses a "1/7 of the night" high-latitude rule
  instead of the package's middle-of-the-night, truncates minutes and uses one UTC offset per day (F51p). Each of
  these breaks decision 1 for existing methods too, not only the new ones.
- Dart `PrayerTimesService.getPrayerTimes(date:)` always calculates TODAY (`PrayerTimes.today`) and shifts by
  `Duration(days: n)` → the cached days 1–2 are today's times + 24/48 h (F53a). The package offers
  `PrayerTimes(coordinates, DateComponents, params)` for any date.
- `_getAsrMadhab` compares `'Hanafi'` with enum name `hanafi`; native receives `madhab.name` (currently always
  `'shafi'`); Kotlin expects lowercase `"hanafi"`. Contract strings: `.project-docs/contracts/prefs-keys.md` +
  method-channels.

## Documented app adjustments (on top of the package)
- Umm al-Qura (`makkah`): Dhuhr +3 min (`params.adjustments.dhuhr = 3` in Dart; `dhuhrAdj` in Kotlin) — decision 5.

## Open for the user
- None as of 2026-11-07.

## Non-goals
- Umm al-Qura Ramadan Isha +30 min (package note) — not applied today; out of scope.
- UI changes beyond what mapping corrections require; prefs key renames; notification ID / channel changes.
