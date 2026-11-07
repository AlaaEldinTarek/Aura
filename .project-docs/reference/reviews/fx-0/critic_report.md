# Stage 7 — Critic Review Report
Target: `docs/designs/fx-0-prayer-settings.md` (FeatureRange 1–339) · Date: 2026-11-07
Reviewers: `egm-design` + `egm-structural` (feature-spec-standard), `egm-style` (persona checks only) · fresh context, reading list of 10 files

## egm-design (0 Blocker · 9 Major · 9 Nit)
| # | Sev | Scope | Finding |
| --- | --- | --- | --- |
| D1 | Major | Shared change 4 | Fingerprint needs the 7 days' times, so it is known only after `await`; overlapping loads (init + Settings save, per-minute post-Isha reload + save) each start side effects; an older method-X run can finish last and win (breaks CUJ 2). Failed effects still record the fingerprint, and the "same inputs → no run" test blocks a retry. Needs an ordering rule (generation counter / serialised runs), fingerprint recorded only on success, overlap test. |
| D2 | Major | Shared change 4; Option B | Cache loop builds dates with `DateTime.now().add(Duration(days: i))` (`provider:405–406`): at 23:30 on a DST eve, +24 h skips a calendar day → DST day gets no `cached_*` keys, later keys shift. Require calendar-day arithmetic `DateTime(y, m, d + i)`; fixed-clock test for 7 distinct consecutive keys. |
| D3 | Major | CUJ 3; next-occurrence alarms | `*_iqama_time` are absolute instants written only by Dart (`MainActivity.kt:297–299`), read at fire time (`PrayerAlarmReceiver.kt:544–561`); native never writes them; `cached_*` has no iqama. A tomorrow-armed alarm reads today's past iqama → countdown "arrived" at once, azkar trigger in the past (also every closed day under B). Cache iqama per date / native derives from minutes, or narrow CUJ 3 + S31 and log a finding. |
| D4 | Major | Stale alarms | Case "old time already fired, new time ahead" (Shafi → Hanafi after Shafi Asr) re-arms today's Asr; only the undocumented 6 h duplicate guard (`PrayerAlarmReceiver.kt:486–495`) stops a second adhan; post-check can ask twice. Document the dependency, decide the second post-check, add mirror of S30. |
| D5 | Major | Fingerprint triggers; Goal 7 | `cleanupFuturePrayerRecords` (`provider:351–363`) now runs on every input change; when Asr moves later (Hanafi first open, Shafi → Hanafi), a legitimate record can fall before the new Adhan+20 window and be deleted. Check the predicate; exempt or accept as a risk. |
| D6 | Major | Shared change 6 | JVM test cannot reach `private` math; `android.util.Log` / `DateFormat` / `Context` fail "not mocked" without `unitTests.isReturnDefaultValues` or Robolectric. "approve B names exactly this dependency" may be incomplete. State the Android-free `internal` function and every `build.gradle.kts` change. |
| D7 | Major | Alternatives | Missing alternative: a JVM Adhan implementation (batoulapps adhan-java / Kotlin) — exact MC and parity for free, cost: `implementation` dependency (APK change, licence/supply-chain review). |
| D8 | Major | Whole document | No Risks & Mitigations section; failure rows (L252–254) have no mitigations; D1, D2, D4, D5 not mentioned anywhere. |
| D9 | Major | MC ceiling | Ceiling cities all 40.7°–52.5° N; MC users above 55° N (Scotland, Scandinavia) untested though Goal 2 says "every prayer". Add one city > 55° N or scope the claim. |
| D10 | Nit | Divergence table, high latitude | Package applies middle-of-night as a bound every day; Kotlin only when the angle is unreachable, plus a hard clamp (`:144–145`). Say whether the clamp stays. |
| D11 | Nit | Divergence table, minutes | Verify rounding mode per method in adhan 2.0.0+1 (other ports round Singapore up). |
| D12 | Nit | Golden fixture | "A Dart test writes the fixture" = test run modifies a tracked file; use a generator + staleness test. |
| D13 | Nit | Options B / A | Off by one evening: on day +6 after Isha native asks for +7 (uncached) → Kotlin times reach the D+7 Fajr alarm. |
| D14 | Nit | NFR performance | Post-Isha `_quickUpdateNextPrayer` calls `loadPrayerTimes` every minute (`provider:150–157`) → 7-day calc each minute; correct the statement. |
| D15 | Nit | Shared change 3 | "days 1–6" assumes B; say "each cached day". |
| D16 | Nit | Adhan alarms | "Five prayers … 1001–1006": write 1001, 1003–1006 (1002 = Sunrise, never scheduled). |
| D17 | Nit | Alternatives | "Rejected by author (decision N)" without links to `fx-0-decisions.md` entries; Alt C trade-off thin. |
| D18 | Nit | Rollout | "Install the previous build" impossible on Android without uninstall (wipes prefs); rollback = old code with higher versionCode; old Kotlin maps the 5 new strings to MWL until first open. |
| D19 | Nit (unverified) | Problem 3 | `prayer_screen.dart:752` calls `loadPrayerTimes(now)` — confirm it is not the settings save path. |

## egm-structural (0 Blocker · 5 Major · 7 Nit)
| # | Sev | Scope | Finding |
| --- | --- | --- | --- |
| S1 | Major | Whole document | No Risks & Mitigations H2 (standard requires it); failure rows lack detection/retry/logging. |
| S2 | Major | Alternatives A–E | Rejections credited to the author without links; C/D/E cite "decision N" without linking the decisions file; B has no source. |
| S3 | Major | Options vs Alternatives | "Alternative B" (separate entry point) collides with chosen "Option B"; re-label. |
| S4 | Major | Shared changes vs Option A | "Shared (both options)" items assume 7 days; A = "shared only … today+2"; table says A costs "none" and B "2 → 6" — contradiction. |
| S5 | Major | Shared change 4, L186–191 | Markdown lazy continuation: "Same notification IDs…" and the trigger-test spec render inside the pre-prayer-reminder bullet. Add a blank line. |
| S6 | Nit | Shared change 4 | ~40-line list item with bold pseudo-headings; make H4 sub-sections. |
| S7 | Nit | Options / Alt A | Option A described twice despite "moves to Alternatives". |
| S8 | Nit | Future Improvements | "→ P6" dangling (Pn = Problem n). |
| S9 | Nit | Header; Problem 5 | F51p missing from header findings and Problem 5 title. |
| S10 | Nit | Problem 5 vs table | Solar position, Qatar Isha, MC not named in Problem 5 though Goal 2 says each Problem 5 divergence is listed. |
| S11 | Nit | Paths | No Markdown links; same files under different roots; ADR 0001 and package paths unresolvable. |
| S12 | Nit | L266 | ~190-char line breaks the ~120 wrap. |

## egm-style (0 Blocker · 7 Major · 14 Nit)
| # | Sev | Scope | Finding |
| --- | --- | --- | --- |
| T1 | Major | CUJ 2 vs post-checks | Same contradiction as C1/I3; narrow CUJ 2 to adhan alarms. |
| T2 | Major | Shared change 4, pre-prayer reminders | **Claim wrong:** `PrayerAlarmReceiver.scheduleReminderAlarm` (`:112–180`) sets a separate exact alarm 45 min before a prayer (request code + 1000), via `scheduleReminderAlarm` channel (`MainActivity.kt:406–418`), called from `main_wrapper_screen.dart:859` with a stored prayer time. Can go stale on a settings change. |
| T3 | Major | Shared changes vs Option A | Same as S4. |
| T4 | Major | NFR rollout | Kotlin math changes as soon as the update installs; only the method/madhab inputs stay old until first open. |
| T5 | Major | Options table; Alt A cons | "common for users who rely on the adhan without opening the app" — no data; used as decision evidence. Cite or drop. |
| T6 | Major | Overview | Present tense ("Kotlin matches … measured by tests") for a goal; tests do not exist yet. |
| T7 | Major | Goal 7 | "1 h across DST … or the app was not opened" contradicts Problem 4's correction; 1 h only on the Kotlin path. |
| T8 | Nit | CUJ 4 | Under B, D+1…D+3 come from the cache → exact; ±1 min / 2 min applies only to the fallback. |
| T9 | Nit | Goal 6; Options | Goal 6 still "the user chooses"; B rationale repeated 3×. |
| T10 | Nit | Options | Option A described twice (= S7). |
| T11 | Nit | Problem 4 | "about 1–2 min per day … 7-day cache off by more" unmeasured; drop hypothetical. |
| T12 | Nit | Goal 2 | "several cities" vague; point to the fixture list. |
| T13 | Nit | L172 | 1001–1006 vs five prayers (= D16). |
| T14 | Nit | Stale alarms | "No cancel call is needed" duplicated by the Rule bullet. |
| T15 | Nit | Evidence tags | Six different forms; define one tag set once. |
| T16 | Nit | L188 | Desktop refresh claim has no evidence/test (cite provider `:329`). |
| T17 | Nit | L158–159 | "location cache gets a new fix" — rewrite. |
| T18 | Nit | Shared change 1 | Dubai rename parenthetical; say why in scope despite the Non-Goal. |
| T19 | Nit | Problem 5 | Informal wording ("where the DST error lives", "Besides knowing only 9 names"). |
| T20 | Nit | L207; L292 | "written first, before any fix" redundant; Alt B rejection does not say who. |
| T21 | Nit | Header; L266 | F51p missing from header; L266 overlong and embeds an out-of-scope note. |
