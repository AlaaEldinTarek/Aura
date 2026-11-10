# Stage 8 — Intermediate Zoom Out Report

**Target:** `docs/designs/fix-settings-bridge.md` (full file, lines 1–605; unchanged since Stages 5–7)
**Standard:** `zoom-out-standard.md` · **Inputs:** `zoom_out_report.md`, `comprehension_report.md`, `critic_report.md`
+ GoldfishContext · **Date:** 2026-11-09

## Reviewer Status

| Reviewer | Status | Verdict |
| --- | --- | --- |
| `egm-zoom-out` | completed | Pass with changes — 0 Blocker, 4 Major, 4 Nit |

Core design still holds. Most Stage 6/7 recommendations are wording and proportionate; a few would add mechanism or
weight the fix does not need; two conflict with open Stage 5 findings.

## Prioritized Findings

### ZOM-1 — Gate the service's self-restart, not its startup (narrows IC-M1 / CR-12; settles ZO-N1) — Major
* **Scope:** 79–85, 257–274, 550–553, 559–560.
* **Evidence:** swipe-away / destroy restart goes through `scheduleRestartIfNeeded` (alarm), gated only by
  `shouldAutoRestart()` reading `fg_user_stopped` (`PrayerForegroundService.kt:759–790`) — not through
  `startService`, so a gate in or beside `startService` never covers it.
* **Recommendation:** `shouldAutoRestart()` also reads `background_notification_enabled` via `FlutterPrefs`, through one
  pure decision `isAutoStartAllowed(settingEnabled, userStopped)` (real logic, so file 34 stays meaningful). Add S42
  step "setting off → swipe away → no service". Do **not** gate `onCreate` (Android 12+ `startForeground` timing,
  notification flash); list `START_STICKY` recreation while values disagree as a known limit.

### ZOM-2 — Do not make the static checks permanent tests in this group (IC-M2) — Major
* **Scope:** 587–593.
* **Rationale:** source-text-scanning JUnit is a new, brittle pattern (allow-lists, comments, log strings) and checks
  routing only. Existing guards: CLAUDE.md FlutterPrefs rule, `prefs-keys.md` rule + history, the Dart key-function
  test, `aura_prefs` becoming readerless.
* **Recommendation:** keep the one-time greps in the PR. If a lasting guard is wanted, log a separate Level B tooling
  item (lint/hook). Skip the optional `FlutterSettingKeys` object (YAGNI).

### ZOM-3 — Drop the preview-refusal rule and the playback flag (ZO-M1 still open) — Major
* **Scope:** 225–238, 276–287, 318, 509–510, 525, 530, 567–568.
* **New evidence:** today's preview calls `playAdhan('Fajr')` (`adhan_downloads_screen.dart:673`), so `currentPrayer`
  is `"Fajr"` during a preview; building refusal on `currentPrayer` would still need a separate marker (new state).
* **Recommendation:** `previewAdhan` resolves by id and reuses the existing stop-then-play sequence (preview replaces
  whatever plays; a prayer adhan stops a preview). Removes `AdhanPlaybackState`, file 25, the playback-flag proof
  section and S26 a–d. Keep CO-3's S26 step (e) "select A, preview B, adhan fires → A plays" as Goal 3's proof.

### ZOM-4 — CR-6 conflicts with ZO-M3 on F15; settle F15 first — Major
* **Scope:** 86–97, 291–296, 321–414, 460–483.
* **Conflict:** CR-6 would add "F15 fixed inline" as a *rejected* alternative; ZO-M3 recommends it as the design.
  A fourth Zuhr rule remains: `buildNativeCache` (`lib/core/utils/prayer_refresh.dart:51–52`).
* **Recommendation:** adopt ZO-M3 (rejected alternative becomes "shared map builder"); route `buildNativeCache` through
  the shared key function or list it out of scope. From CR-6, adopt the cheap parts: extend precheck "User decisions"
  with Q2, Q3/Q4, Robolectric, one-PR and link it; add a short "F49a via native write into `aura_silent_mode`"
  alternative.

### ZON-1 — Answer CO-1 with one sentence — Nit
* **Scope:** 98–102, 191. The language copy is pushed at once on change (`preferences_provider.dart:124–145`); the
  only gap is no prayer times loaded (`:137`). Cite it in Goal 6, define "push gap" as that case, add the
  language-change arrow to the data-flow diagram. No new code.

### ZON-2 — CR-5 Risks table: move existing text, add only the security row — Nit
* **Scope:** 313–318. Promote the `[a-z0-9_]+` path-traversal guard (now only in Alternative H) to a risk row; point to
  the other places instead of duplicating. Same proportion rule: CR-4 → document the rollback cost only (no resync
  mechanism); CR-2/CO-2 → one pure Dart test on `availableAdhans`, not a model change.

### ZON-3 — Reciter rule is Android-only; the contract does not say so (missed earlier) — Nit
* **Scope:** 112–115, 140–141, 541–544. `desktop_adhan_service.dart:39` reads `adhans/<prayerName>.mp3` from the same
  folder and ignores `selected_adhan_id`. Mark the contract row "Android only; Windows uses
  `adhans/<prayerName>.mp3` (unchanged, Non-Goal)".

### ZON-4 — Third service on/off key not mentioned (missed earlier) — Nit
* **Scope:** 79–82, 274, 561–562. `foreground_service_enabled` (`background_service_manager.dart:26, 59, 77`) is a
  Dart-only running-state cache with no native reader. One clause so nobody wires a native reader to it.

## Recommendations judged proportionate as given
* Wording: CR-1, CR-7 / ZO-N2 / CO-4, CR-8, CR-10, CR-11, CR-13, CO-8, CO-9.
* Test plan: CR-3 (working nightly-recalc trigger), CO-3 S26 step (e).
* Glosses: CO-5 to CO-7, CO-10 — one line or a link each.
