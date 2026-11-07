# Stage 9 — Implementation Readiness Report
Target: `docs/designs/fx-0-prayer-settings.md` (DetailedRange 340–507) · Date: 2026-11-07
Reviewers: `egm-implementation-readiness` + `egm-codebase-details` (implementation-readiness-standard), `egm-style`
Verdict: **NOT READY** (2 distinct Blockers).

## egm-implementation-readiness (2 Blocker · 9 Major · 5 Nit)
| # | Sev | Scope | Finding |
| --- | --- | --- | --- |
| IR1 | Blocker | Item 4 | Core P1/P2 test cannot be written: `getPrayerTimes` takes enums; string mapping is private in the notifier (`:516–559`, needs `_prefs`, constructor starts location/Firebase). Hanafi via enum already correct today → no failure; new enum values → compile error. Name a public mapper (e.g. `methodFromPref(String)`, `madhabFromPref(String)`), its file, notifier delegates, test calls it. |
| IR2 | Blocker | Item 13 | Moonsighting Committee approximation undefined (which seasonal/shafaq/adjustment parts, where documented). |
| IR3 | Major | Item 13 | Method table values not given; `fixedAngle` / `proportional` (Dart = Egyptian / MWL, Kotlin 19.5/17.5, 15/15) undecided and untested; package-specific rules (rounding, Turkey Maghrib, Singapore Dhuhr) must be named. Give the 14-row table or name the package file as the verbatim source; add both to the fixture. |
| IR4 | Major | Items 6, 13 | `calculate` signature untyped, no return type; returning private `PrayerResult` from an internal fun does not compile; item 6 "Calendar" vs item 13 y/m/d + zone; `Log` calls throw on JVM with junit only. State `calculate` makes no Android calls. |
| IR5 | Major | Items 2, 6 | City lists conflict (Birmingham, New York never generated); Birmingham UK vs AL; coordinates + IANA zones; test year missing. One city table + year + methods per city. |
| IR6 | Major | Phasing | Step 2 does not compile (new enum values, `prayer_refresh.dart`, `internal calculate` not yet present). Contract commit 7 + 13 + 16 breaks the exhaustive switch (needs item 8) and bundles the whole solar port. Define stubs or co-landing; add items 8, 10; split Kotlin port from the name commit. |
| IR7 | Major | Items 9, 10 | Fingerprint anchor (`date` vs `now`), moment of assignment, retry behaviour, typed signature and format unspecified. |
| IR8 | Major | Item 5 | Seven trigger tests not definable as pure-helper tests ("new notifier", "injecting params"); give inputs → expected result per test or name the seam. |
| IR9 | Major | Item 11 | Edit undefined / no-op; state the change or drop the file. |
| IR10 | Major | Item 13 | Existing Fajr/Isha safety clamp and 1/7 fallback (`:124–145`): remove or replace? Keeping it can break ±1 min at Oslo. |
| IR11 | Major | Item 7 | EN/AR display strings for the five new values not given. |
| IR12 | Nit | Item 4 | Fixture check: raw package or app `getPrayerTimes`? Only the latter tests the app. |
| IR13 | Nit | Item 2 | Generator cannot import `prayer_times_service.dart` (Flutter, shared_preferences); mapping duplicated in the tool — say so. |
| IR14 | Nit | Items 12, 14 | `_loadPrayerTimes()` reload claim unverifiable from supplied files; item 14 await before pop/confirmation? |
| IR15 | Nit | Item 21 | Spec already exists; "Create … moved from `design_draft.md`" is stale. |
| IR16 | Nit | Item 16 | prefs-keys.md `cached_*` row Dart-location column changes with `buildNativeCache`. |

## egm-codebase-details (1 Blocker · 8 Major · 6 Nit)
Verified correct: listed line ranges in `prayer_times_service.dart`, `prayer_times_provider.dart`, `prayer_screen.dart`,
`iqama_settings_screen.dart`, `settings_screen.dart`, `MainActivity.kt`, `PrayerAlarmReceiver.kt`,
`adhan_calculation_method.dart:35`, `main_wrapper_screen.dart:121`; adhan enum values exist; no `android/app/src/test`;
64 Dart tests; Dart SDK ≥ 3.0 (records OK); `IqamaSettingsScreen` is a `ConsumerStatefulWidget`.

| # | Sev | Scope | Finding |
| --- | --- | --- | --- |
| CD1 | Blocker | Item 4 | Same as IR1. |
| CD2 | Major | Item 12; Technical Plan triggers; CUJ 2 | `PrayerSettingsPage._saveCalculationSettings`' `Navigator.pop` (`:1554`) closes the `PrayerCalculationSettingsDialog` (`showDialog`, `prayer_calculation_settings_dialog.dart:188`), not the page. With item 12 the reload runs only when the user later leaves the page; alarms stay on method X meanwhile. Accept + document, or change `_saveCalculationSettings` (page is a plain `StatefulWidget`, no `ref`). |
| CD3 | Major | Item 10 | Window/fingerprint anchor (`date` vs `now`) unspecified (= IR7). |
| CD4 | Major | Items 1, 13 | JVM setup incomplete: `android.util.Log` / `DateFormat` throw without `testOptions` (one-line limit). Require pure `calculate` without `android.*`, or allow `testOptions`. |
| CD5 | Major | Step 2 | Tests-first step cannot compile (= IR6). |
| CD6 | Major | Items 2, 6 | Fixture underspecified: Birmingham/New York, MC rows per city, Oslo MC rows, test year (= IR5). |
| CD7 | Major | Items 2, 4 | Generator needs its own mapping + adjustment; fixture check target unspecified (= IR12/IR13). |
| CD8 | Major | Items 6, 9, 13 | Kotlin test API described three ways; parameter and return types missing (= IR4). |
| CD9 | Major | Item 21; Target Scope | Spec exists (untracked); no `design_draft.md`; "(new)" and "moved from" are wrong. |
| CD10 | Nit | Item 11 | No-op (= IR9). |
| CD11 | Nit | Item 7 | `:42–80` wrong (`displayName` 42–63, `displayNameAr` 65–86); EN/AR strings missing. |
| CD12 | Nit | Item 8 | Method declared at `:253` (`:254` is the switch). |
| CD13 | Nit | Item 13 | Kotlin `proportional` / `fixedAngle` must take MWL / Egyptian parameters to match Dart. |
| CD14 | Nit | Items 9, 10 | Untyped fingerprint params; compare-and-set must run synchronously before the async block (today `:256–257`); per-minute post-Isha 7-day calc not in NFR. |
| CD15 | Nit | Item 5; item 14 | Adjustment / app-open trigger tests have no injection API; iqama screen needs a new import. |

## egm-style (0 Blocker · 6 Major · 11 Nit)
| # | Sev | Scope | Finding |
| --- | --- | --- | --- |
| SS1 | Major | L341–342 | "C for the rest" vs Step 4 / table = Level A; say B / C / A per step and the gate for item 16. |
| SS2 | Major | Items 4, 6 | "fails today" stated as fact for tests that do not exist; "expected to fail". |
| SS3 | Major | Item 5 vs shared change 4 | Which test covers "no old key survives"; "guaranteed by" overstates static evidence. |
| SS4 | Major | Items 7, 8, 10, 13 | Contract commit must be items 7, 8, 10 (mapping), 13, 16 or it does not compile. |
| SS5 | Major | Item 6; L217; item 13 | Time-zone mechanism described three ways; use the `zone` argument. |
| SS6 | Major | Item 13 | "Documented approximation" points to nothing. |
| SS7 | Nit | Items 8, 10 | "edit carefully" — name the hazard or drop. |
| SS8 | Nit | Item 13 | Unknown-name warning is new ("as today" covers only MWL). |
| SS9 | Nit | Item 13 | `calculateAndSave` behaviour changes; say "signature and cache-first order". |
| SS10 | Nit | Items 9, 10, 8 | `:403–423` vs `:403–426`; `:254` vs `:253`. |
| SS11 | Nit | Item 9 | Mixed typed/untyped helper signatures. |
| SS12 | Nit | Item 2 | CSV header code span broken across lines. |
| SS13 | Nit | Items 15, 21 | "settings_screen no change" and "Release notes" notes misplaced. |
| SS14 | Nit | Item 12 | Arrow shorthand; `_loadPrayerTimes()` claim uncited. |
| SS15 | Nit | Item 14 | What the catch does. |
| SS16 | Nit | Verification | "64" tests / "425" issues need source and date. |
| SS17 | Nit | Item 16 | "9 existing" = 9 current enum names, not contract strings. |
