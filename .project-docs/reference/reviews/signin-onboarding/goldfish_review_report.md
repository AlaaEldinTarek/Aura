# Goldfish Annotated Review Report

**Target:** `docs/designs/fix-signin-onboarding.md` (lines 35–end; B1 also touches line 26 and STATE.md:16)
Source findings: `implementation_readiness_report.md` (round 1). Summary: 22 PROPOSE FIX · 0 CONTEST · 0 ESCALATE · 0 DECLINE.

## Prioritized Findings & AI Suggestions

### [B1] [`codebase-details`] - Severity: Blocker
*   **Affected Scope:** lines 26, 57, 72, 81 (Definitions, F47f, contracts, Tests)
*   **Discrepancy Description:** prefs key is `first_launch` (`AppConstants.keyFirstLaunch`), not `is_first_launch`.
*   **Rationale:** tests would seed the wrong key; implementer may create a new key.
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Justification:*** VERIFIED `app_constants.dart:59`; my error in the draft.
*   ***Proposed Edit:*** replace every `is_first_launch` with `first_launch` (spec + STATE.md:16); docs step adds the
    missing `first_launch` row to `contracts/prefs-keys.md` (doc gap, not a rename).

### [B2] [`implementation-readiness`, `codebase-details`] - Severity: Blocker
*   **Affected Scope:** lines 46–49, 90 (F41a)
*   **Discrepancy Description:** `pushNamed<bool>` throws with untyped `MaterialPageRoute` from `_generateRoute`.
*   **Rationale:** guest flow would break; no automated test; `main.dart` out of bounds.
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Justification:*** VERIFIED `main.dart:415–436` returns `MaterialPageRoute` with no type argument under `Route<dynamic>?`.
*   ***Proposed Edit:*** `final result = await Navigator.of(context).pushNamed('/onboarding');` (untyped), then
    `if (result != true && mounted) setGuest(false)`; add "do not type `pushNamed` (routes are `<dynamic>`)".

### [M1] [all] - Severity: Major
*   **Affected Scope:** line 51 · `SharedPreferencesService.isFirstLaunch()` is an instance method.
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** `await ref.read(sharedPreferencesServiceProvider).isFirstLaunch()` (provider in
    `auth_provider.dart`, already imported by Login and Signup).

### [M2] [all] - Severity: Major
*   **Affected Scope:** lines 43, 78–79, 88, 91 · commit-1 helper body unclear; `@Skip` is file-level.
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** commit 1 ships the final `resolvePostAuthRoute` (no callers until commit 4 → no behavior
    change); no skip at all.

### [M3] [impl, codebase, style] - Severity: Major
*   **Affected Scope:** lines 46–51, 90–91 · guest flow body scattered; `isFirstLaunch` source; `setGuest(true)` order.
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** add ordered final body of `_continueAsGuest` (1 `setGuest(true)`; 2 read `first_launch` via
    the service; 3 returning → `pushReplacementNamed('/home')`, no await; 4 else untyped `pushNamed`, cancel guest only if
    `result != true`). Commit 3 = onboarding `result: true` + step 4 check; commit 4 = steps 2–3 + sign-in/sign-up.

### [M4] [`codebase-details`] - Severity: Major
*   **Affected Scope:** lines 60–61, 119 · `AuthService.signOut` is `Future.wait([firebase, google])` + rethrow; Google
    half failing (possibly on Windows, UNVERIFIED) leaves the user signed out with no navigation.
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Justification:*** VERIFIED `auth_service.dart:244–252`. `auth_service.dart` stays out of bounds.
*   ***Proposed Edit:*** after the attempt (success or error), navigate to Login if
    `ref.read(authServiceProvider).currentUser == null`; stay on Profile + log only if still signed in. Windows logout
    check becomes **required**; line 61 reworded as "no platform branch is added; verified on both".

### [M5] [impl, codebase, style] - Severity: Major
*   **Affected Scope:** lines 101–103 · docs boundary not exact paths.
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** list full paths (STATE.md, reference/findings.md, log/2026-11-0X.md (date of the work),
    reference/device-checklist.md, contracts/prefs-keys.md, contracts/log-tags.md, modules/auth-sync.md, and
    `lib/.../README.md` for the 6 folders); mark production files New / Modify.

### [M6] [impl, codebase] - Severity: Major
*   **Affected Scope:** lines 76–85 · F50b handler and F47f untested, gaps undeclared.
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** add pure `String? resolveSplashRoute({required AsyncValue<User?> auth, required AsyncValue<bool>
    guest, required AsyncValue<bool> firstLaunch})` in `start_route.dart` (null while any is loading; errors → today's
    fallback) and unit-test it (loading ×3, error ×3, data table). Declare gaps: navigate-once and F47f navigation → S36.

### [M7] [codebase, impl] - Severity: Major
*   **Affected Scope:** lines 79–83 · test setup conditional.
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** prescribe `setMockInitialValues({'is_guest': true, 'first_launch': false})` then
    `await SharedPreferencesService.getInstance()` in `setUpAll`; `ProviderContainer`; assert `isLoading` synchronously
    after first read, then `await Future<void>.delayed(Duration.zero)` and assert `data`. One value set per file
    (static cache). Drop the override fallback.

### [M8] [`style`] - Severity: Major
*   **Affected Scope:** line 52 · "Onboarding itself is unchanged" contradicts the `result: true` edit.
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** "Onboarding steps and defaults are unchanged; its only edit is F41a's `result: true`."

### [M9] [style, impl, codebase] - Severity: Major
*   **Affected Scope:** lines 60, 72 · `[AUTH]` is a new tag vs "log tags unchanged".
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** `debugPrint('❌ [AUTH] signOut failed: $e')`; line 72 → "no existing tag renamed or removed; one
    new Dart-only tag `[AUTH]`, added to `contracts/log-tags.md`".

### [M10] [`style`] - Severity: Major
*   **Affected Scope:** lines 85, 110–117 · S20/S22/S23/S36 read like phone models.
*   ***AI Suggestion:*** PROPOSE FIX
*   ***Proposed Edit:*** first use in range: "device-checklist scenario S22 (`reference/device-checklist.md`)".

### [N1–N11] [mixed] - Severity: Nit (all PROPOSE FIX; cheap and they remove analyzer / ambiguity risk)
*   N1 line 55: `if (!context.mounted) return;` after the await (analyzer gate).
*   N2 lines 65–69: auth error → `/login`; `_navigated` set synchronously in `build` before `addPostFrameCallback`.
*   N3 lines 69–70: spinner hides after the delay; logo + text stay while waiting (no new UI).
*   N4 line 40: move "(same table as today)" out of the code block.
*   N5 line 50: reword ("The email and Google success handlers on Login and Signup call …").
*   N6 lines 52, 53, 84, 111: drop the line-33 repeat, "(defined here)", "(stated, not hidden)", duplicate "current base".
*   N7 line 58: reword as requirement ("prayer features must keep working signed out; S36 checks next prayer + alarm").
*   N8 line 108: baselines "on main @ 80c603d".
*   N9 lines 123–124: short phrase per excluded ID.
*   N10 lines 47/90: one notation (`!= true`, `→`).
*   N11 line 104: "contracts not touched" → contracts get doc-only additions (`first_launch` row, `[AUTH]` tag).
