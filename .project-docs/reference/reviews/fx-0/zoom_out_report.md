# Stage 5 — Initial Zoom Out Report
Target: `docs/designs/fx-0-prayer-settings.md` (full file, lines 1–507) · Date: 2026-11-07
Reviewers: `egm-zoom-out`, `egm-inventive-catalyst` (fresh context; reading list of 10 files, no `fx-0-decisions.md`)
Verdict (both): context sufficient; no Blockers.

## egm-zoom-out
| # | Sev | Scope | Finding |
| --- | --- | --- | --- |
| Z1 | Major | Goal 2; shared change 5; Options B; Steps 1–3 items 2, 6, 13 | Full Kotlin parity (solar-math port, 14-method table, MC approximation, JVM infra, fixture) is the largest FX-0 cost but under B buys accuracy only on a rare fallback. Proposal: widen the Dart window (N=7 is arbitrary; 30 days ≈ 180 strings), fix only cheap + dangerous Kotlin items (5 method names, per-instant UTC offset, rounding), log the fallback. Or justify why the fallback needs parity. |
| Z2 | Major | Shared change 4; items 9, 10 | `loadPrayerTimes(date)` is called with tomorrow's date after Isha (`prayer_times_provider.dart:453`); spec never says which date anchors the 7-day window, the fingerprint and `nextOccurrences`. Proposal: anchor on `now`, independent of display date; say whether side effects use the display list or the computed window. |
| Z3 | Major | Shared change 6; items 2, 6 | Fixture city list omits Birmingham and New York (and New York DST dates), but the MC ceiling test reads those rows. Plan cannot run as written. |
| Z4 | Nit | Item 11; Target Scope | `scheduleDailyPrayerAlarms` already schedules every entry with a skip-if-past guard (`prayer_alarm_service.dart:151–169`); item 11 is a no-op. Remove it or state the real change. |
| Z5 | Nit | Item 9 | New `prayer_refresh.dart` vs existing `prayer_time_rules.dart` (pure helpers). Keep separate only if pure-Dart tests matter (`prayer_time_rules.dart` imports `flutter/material.dart`) — say so. |
| Z6 | Nit | Shared change 4 triggers; items 12, 14 | Notifier already has `setCalculationMethod` / `setAsrMadhab` (`:562–575`) that save + reload; spec has screens save and reload themselves. Reuse them (+ one for iqama) or say why screens bypass them (string formats differ). |
| Z7 | Nit | Fingerprint | Date + method + madhab are redundant with the calculated times; note why method/madhab are kept (native must receive new strings even if times are identical). |
| Z8 | Nit | Problems 4, 5; shared change 4 | Altitude drop: `DateTime.add` semantics, PendingIntent equality, +2000 arithmetic, file:line in high-level sections; move evidence to the implementation plan / findings log. |
| Z9 | Nit | Item 4 vs shared change 6 | Two Dart checks of the same thing (app == package; fixture recompute). Combine: app output == fixture rows. |

Checked and accepted: fingerprint vs separate entry point; replace-not-cancel; per-date `PrayerTimes`; no new IDs/channels/MethodChannels/key formats; 7 calculations per refresh is negligible.

## egm-inventive-catalyst
| # | Sev | Scope | Finding |
| --- | --- | --- | --- |
| I1 | Major | Options B; shared change 5; Goal 2; Alt C | False compromise: N=7 with full parity ties the main cost (a second astronomy engine kept in sync forever) to an almost-free setting. Raising N does not make data staler (same stored coords/method; settings changes already force a rewrite). Proposal: raise N (30–60 days, a few KB) and either keep parity as edge-case protection or downgrade Kotlin to a bounded approximation (fix per-instant offset, rounding, 5 names; keep fallback log + measured ceiling). Write down why N was chosen. Liabilities: bigger prefs XML rewritten on every open; longer rollback window for a Dart bug. |
| I2 | Major | Shared change 4; items 9, 10 | Same as Z2, plus: `_quickUpdateNextPrayer` calls `loadPrayerTimes(now)` every minute after Isha (`:149–157`); a tomorrow-anchored call would drop today's cache keys (native post-Isha recalc needs them, comment `:399–402`) and alternating dates flip the fingerprint → repeated rewrites. Proposal: side effects always anchor on wall-clock date; add test "load with tomorrow's date after Isha → no re-run, cache includes today". |
| I3 | Major | CUJ 2 vs shared change 4 | CUJ 2 promises no method-X alarm and post-checks on method Y, but the plan keeps an old post-check that fires once at the method-X time. Proposal (in scope): narrow CUJ 2 to adhan alarms and state the post-check exception. |
| I4 | Major | Current flow; stale alarms; item 10 order | Two writers arm request codes 1001–1006 (Dart side effects and Kotlin `reschedule`). Baseline order schedules alarms (`:320`) before `updatePrayerTimes` (`:381`) and the cache write (`:423`); a native recalc in that gap re-arms method-X times. Proposal: write data first (`updatePrayerTimes`, then cache), schedule alarms last (own try block). Single alarm writer → Future Improvement (touches MainActivity / channel contract). |
| I5 | Major | Fingerprint; failure row; item 10 | Guard is set synchronously before async effects, and each effect swallows errors; a failed cache write/alarm schedule still records the new fingerprint, so no retry until next open/input change. Proposal: in-flight flag + save fingerprint only after critical effects succeed; backoff; test "cache write throws → next load re-runs". |
| I6 | Nit | Fingerprint | Times-based fingerprint forces a 7-day calculation on every load (incl. per-minute post-Isha reloads). Alternative: inputs + build number. Current choice defensible (catches unlisted inputs) — state it. |
| I7 | Nit | Goal 5; shared change 1; item 13 | Method shared as a name; each side keeps its own table. Alternative: Dart publishes resolved parameters, Kotlin needs no table → Future Improvement (channel contract change). |
| I8 | Nit | CUJ 2; S30 | Shafi → Hanafi after Shafi Asr fired arms the later Hanafi Asr → Asr heard twice. State whether intended; add mirror case to S30. |
