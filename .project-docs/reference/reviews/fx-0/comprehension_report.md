# Stage 6 — Comprehension Test Report
Target: `docs/designs/fx-0-prayer-settings.md` (FeatureRange 1–339, DetailedRange 340–507) · Date: 2026-11-07
Reviewer: `egm-comprehension` (fresh context; document only, no reading list)

**What this proposes**
FX-0 fixes four related prayer-time bugs. Hanafi users get Shafi Asr because of a case mismatch. Five UI methods
(Qatar, Dubai, Turkey, Singapore, Moonsighting Committee) are mapped to the wrong method. Settings changes don't
refresh alarms, widgets, native data or cached days, because a once-per-day guard blocks them. Times for future dates
are today's times shifted by whole days. The fix maps every UI method and madhab exactly to the `adhan` package. It
calculates each date on its own. It replaces the daily guard with an input fingerprint (date + method + madhab +
iqama + seven days of calculated times), so any change triggers a full refresh. Alarms are replaced by re-scheduling
under the same request code, never cancelled. The author chose Option B: Dart precomputes 7 days (`cached_*`, 42
keys). Kotlin is also brought to ±1 min parity, which a golden CSV fixture tests, but it only calculates times itself
as a fallback after more than 6 days without opening the app. Moonsighting Committee in Kotlin is allowed an
approximation of at most 2 min. Tests are written first, then fixes, contract and doc updates, and before/after
device scenarios.

**How the existing system works, per this document**
Settings screens write `calculation_method`, `asr_madhab` and iqama prefs. `PrayerTimesNotifier.loadPrayerTimes`
maps them to an internal `CalculationMethod` enum and a madhab, then calls `PrayerTimesService.getPrayerTimes`, which
uses `PrayerTimes.today` plus a day shift. Side effects run at most once per day (`_lastSideEffectsDate`):
post-prayer checks, adhan alarms (future times only, never cancelled), widgets and desktop timers,
`updatePrayerTimes` to native prefs, and `cached_{date}_*` for today, +1 and +2. On Android, Kotlin
(`NativePrayerCalculator`) runs at 00:05, from WorkManager, on a foreground stale check and after Fajr/Isha. It reads
cached days or falls back to its own astronomy. That astronomy knows only 9 method names, ignores adjustments,
truncates minutes, uses a 1/7-night high-latitude rule and one UTC offset per day. It then reschedules alarms.

## Findings
| # | Sev | Scope | Finding |
| --- | --- | --- | --- |
| C1 | Major | CUJ 2 (L84–88) vs shared change 4 post-checks (L178–180) | Contradiction: CUJ 2 says no alarm fires at a method-X time; the plan keeps an old post-check that fires once at its old (method-X) time. |
| C2 | Major | Shared change 4 tests (L189–191) vs item 5 (L396–398) | Trigger tests "assert no old `cached_*` key survives" vs item 5 "not checked in a Dart test; MainActivity + S32". Which is the requirement? |
| C3 | Major | L15–16, 48–49, 203, 460 | "Documented approximation" for Moonsighting Committee is never defined, and there is no placeholder/table for the measured error the spec says it records. |
| C4 | Major | L3, 228, 341–342, 347–353, 360 | Level A/B/C and ADR 0001 undefined (no path). "approve B" collides with "Option B". "C for the rest" vs docs marked Level A. |
| C5 | Major | L171–174, L445 | "Five prayers" but request codes "1001–1006" (six). What is the sixth (Sunrise?) and is it affected or left stale? |
| C6 | Major | CUJ 3 (L90–93), L124, item 14 | How native learns iqama minutes is never stated; reader cannot confirm item 14's reload satisfies CUJ 3. |
| C7 | Nit | L138, 196, 206, 417, 459 | Say once that internal `makkah` = Umm al-Qura. |
| C8 | Nit | L122, 175–180, 265 | "Post-prayer check" undefined (what it shows, why +30 min, that it is a user-visible notification). |
| C9 | Nit | L337 | "→ P6" undefined (Pn = Problem n; no Problem 6). |
| C10 | Nit | L38 vs L266, 332 | F51p cited for two different things (single UTC offset; Jumu'ah using last `dhuhr_time`). |
| C11 | Nit | L471; L206, 298, 305, 312 | "Q1 decision", "decision 1/4/5" point into an unsupplied file. |
| C12 | Nit | L158–159, 290–293 | What starts the "next load" after the 15-min location cache on mobile? |
| C13 | Nit | L188 | Desktop "gets the same refresh" but no desktop file in the boundary — no change needed, or missing file? |
| C14 | Nit | L50, 156, 448–450 | "Prayer screen dialog" vs pushed `PrayerSettingsPage`; two `_saveCalculationSettings` not distinguished. |
| C15 | Nit | L490–491 | Item 21 "moved from `design_draft.md`" is stale; the doc already lives at the target path. |
| C16 | Nit | L484 | "EGM folder contract" undefined. |
| C17 | Nit | L164 | `cacheAccuratePrayerTimes` not introduced as a platform-channel call handled in `MainActivity`. |
