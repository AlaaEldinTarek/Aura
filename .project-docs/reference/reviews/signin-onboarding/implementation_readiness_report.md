# Stage 9 — Implementation readiness report: fix-signin-onboarding (round 1)

Target: `docs/designs/fix-signin-onboarding.md`, lines 35–end (`## Fix` → `## Out of scope`) · Mode: Implementation
plan only · 2026-11-08
Reviewers (fresh context, read-only): implementation-readiness — **completed** (NOT READY: 1🔴 4🟡 5🟢);
codebase-details — **completed** (FAIL: 2🔴 5🟡 7🟢); style — **completed** (0🔴 5🟡 13🟢).
GoldfishContext: the 6 existing production files, `contracts/prefs-keys.md`, `reference/findings.md` (F41/F46/F47/F50).
`start_route.dart` was given as a new file.

**Verdict: NOT READY.** Round is not clean (2 unsettled Blockers). Elephant spot-checks below are marked VERIFIED.

## 🔴 Blockers
| ID | Lines | Finding | Raised by | Elephant check |
| --- | --- | --- | --- | --- |
| B1 | 26, 57, 72, 81 | Prefs key is `first_launch` (`AppConstants.keyFirstLaunch`, `app_constants.dart:59`), not `is_first_launch`. Test seeding would use the wrong key; also the key is missing from `contracts/prefs-keys.md`. Also wrong in STATE.md:16. | codebase-details | VERIFIED (grep) |
| B2 | 46–47, 90 | `pushNamed<bool>('/onboarding')` throws: `_generateRoute` (`main.dart:415–436`) returns untyped `MaterialPageRoute` (= `<dynamic>`), and Navigator casts to `Route<bool?>`. Guest flow would break; no test catches it; `main.dart` is out of bounds. Fix: untyped `pushNamed`, then `result != true`. | impl-readiness, codebase-details | VERIFIED (route code); cast behavior from Flutter source, not run |

## 🟡 Majors
| ID | Lines | Finding | Raised by |
| --- | --- | --- | --- |
| M1 | 51 | `SharedPreferencesService.isFirstLaunch()` is an instance method; use `ref.read(sharedPreferencesServiceProvider).isFirstLaunch()` (provider in `auth_provider.dart:18–21`, already imported by Login/Signup). | all three (Nit/Major) |
| M2 | 43, 78–79, 88, 91 | Commit-1 helper body unclear ("today's behavior" vs line-43 logic); `@Skip` is file-level in package:test, per-test is `skip:`. Simplest: commit 1 ships final `resolvePostAuthRoute` (no callers yet → no behavior change), no skip. | all three |
| M3 | 46–51, 90–91 | `_continueAsGuest` final body scattered across F41a/F46a and commits 3/4; guest `isFirstLaunch` source not stated; must keep `setGuest(true)` first. Give ordered body, assign to one commit. | impl-readiness, codebase-details (N5), style |
| M4 | 60–61, 119 | `AuthService.signOut` = `Future.wait([firebase, googleSignIn])` and rethrows (`auth_service.dart:244–252` VERIFIED). If Google sign-out fails (possibly always on Windows — UNVERIFIED) Firebase is already signed out, Profile shows the login prompt and nothing navigates = F47f again. Navigate by outcome (e.g. auth user null after attempt). | codebase-details |
| M5 | 101–103 | File boundary docs list is not exact paths (STATE/findings/log/device-checklist short names, `features/*` without `lib/` + `README.md`, `modules/auth-sync` → `.project-docs/modules/auth-sync.md`). | impl-readiness, codebase-details, style |
| M6 | 76–85 | Test gaps not declared for F50b handler (wait-for-all, error fallback, navigate-once) and F47f navigation; option: pure decision function for the handler; point F47f gap to S36. | impl-readiness, codebase-details (N6) |
| M7 | 79–83 | `start_flags_test` setup left conditional. Prescribe: `setMockInitialValues` → `await SharedPreferencesService.getInstance()` in `setUpAll`; await `_init` (microtask); static `_prefs` cached per process (one value set per file). Private ctor makes the override fallback impractical. | codebase-details, impl-readiness (N2) |
| M8 | 52 | "Onboarding itself is unchanged" contradicts the `result: true` edit (lines 46, 90, 98). Narrow the claim. | style |
| M9 | 60, 72 | `[AUTH]` is a new tag (0 hits in `lib/`, not in `contracts/log-tags.md`) vs "log tags are unchanged". Say "one new additive tag" or reuse an existing one; name the call (`debugPrint`). | style, impl-readiness (N5), codebase-details (N4) |
| M10 | 85, 110–117 | Scenario IDs "S20/S22/S23/S36" read like Samsung models; define "device-checklist scenario" at first use. | style |

## 🟢 Nits
- Line 55: guard `if (!context.mounted) return;` after `await signOut()` (else new `use_build_context_synchronously` issue breaks the "no new issues" gate); `rootNavigator: true` is right (desktop nested Navigator, `main_wrapper_screen.dart:1428`). (impl, codebase)
- Lines 65–69: state auth-error → `/login`; set `_navigated` synchronously in `build` before `addPostFrameCallback`. (all three)
- Lines 69–70: spinner disappears after the delay (`splash_screen.dart:163–172`); only logo + text stay while waiting. (codebase)
- Line 72 / 104: add the missing `first_launch` row to `prefs-keys.md` in the docs step. (codebase)
- Line 40: move "(same table as today)" out of the code block. Line 50: reword "Email, Google (login + signup) success use". Line 52: drop the repeat of line 33. Line 53: drop "(defined here)". Line 84: drop "(stated, not hidden)". Line 111: drop the duplicate "current base". (style)
- Line 58: "prayer features keep working without an account" — unsupported; cite or reword as requirement. Line 61 vs 119: "same on Windows" vs optional Windows check. (style)
- Line 108: name the baseline commit for 418 / 162. Lines 123–124: short phrase per excluded ID or none. Lines 47/90: one notation (`≠`/`not`, `→`/`->`). (style)

## Checked and correct (reviewers)
`home_screen.dart:294` uses `.value ?? false` (loading initial state safe); only Splash/Home/Login/Onboarding use the two
providers; `pushReplacementNamed('/home', result: true)` completes onboarding's future with `true`; 8-case truth table
matches `splash_screen.dart:217–224`; `start_flags_test` premise holds; Profile never shows Logout to guests; `signOut()`
rethrows; no route/UI-string changes; `LanguageNotifier` already starts in `loading()` (precedent).
