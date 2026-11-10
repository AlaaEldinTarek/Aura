# Stage 7 — Critic Review Report

**Target:** `docs/designs/fix-settings-bridge.md` (FeatureRange, lines 1–429)
**Standards:** `feature-spec-standard.md` (design, structural); persona rules (style)
**GoldfishContext:** `reviews/settings-bridge/precheck.md`, `contracts/prefs-keys.md`, `contracts/method-channels.md`,
`CLAUDE.md` · **Date:** 2026-11-09 · **Mode:** uninterrupted (no fixes applied between stages)

## Reviewer Status

| Reviewer | Status | Findings |
| --- | --- | --- |
| `egm-design` | completed | 0 Blocker, 5 Major, 7 Nit |
| `egm-structural` | completed | 0 Blocker, 3 Major, 5 Nit |
| `egm-style` | completed | 0 Blocker, 6 Major, 12 Nit |

Design critic verified against code: `aura_prefs` readers/writers, boot + `MY_PACKAGE_REPLACED` path
(`PrayerBootReceiver.kt:36/44/89`), `DailyRecalcReceiver.kt:73`, `releasePlayer()` exits, `PathUtils.getDataDirectory`
citation (`PathProviderPlugin.java`), `FlutterPrefs` API, F15 call sites, no `android:process` (read-timing holds).

## Prioritized Findings (deduplicated)

### CR-1 — Goal 9 misdescribes today: the in-app toggle already shows the native copy — Major
* **Reviewers:** `egm-design` (M1); related `egm-style` (M1)
* **Scope:** 119–126, 201–206; Overview 20–21.
* **Discrepancy:** The toggle comes from `AdhanPlayerService.instance.isEnabled` (`prayer_screen.dart:1128`), which
  `initialize()` overwrites with native `isAdhanEnabled` (`adhan_player_service.dart:38–42`). Today both the toggle
  and Android follow `aura_prefs`. For users whose copies differ, the update flips both the visible toggle and the
  adhan. The Overview also says "one approved behavior change" while Goal 9 states a second.
* **Recommendation:** Keep the decision; justify it by write order (`setEnabled` writes Flutter prefs first, `:94`,
  then the channel, `:97`; nothing writes `aura_prefs` without Flutter prefs, so Flutter prefs holds the latest
  choice). State that the visible toggle may change for affected users, and list both behavior changes in the
  Overview with their approval status.

### CR-2 — Reciter file-name / id rule is an untested cross-language contract — Major
* **Reviewers:** `egm-design` (M2) — same as Stage 5 ZO-M2 / IC-N1, Stage 6 CO-2
* **Scope:** 64–66, 109–115, 210–216.
* **Recommendation:** Dart test: every `availableAdhans` entry has `fileName == 'adhan_${id}.mp3'` and id
  `^[a-z0-9_]+$` (or derive `fileName` from `id`); add it to the Goal 2/8 proof.

### CR-3 — S42 "trigger the nightly recalc broadcast" cannot run as written — Major
* **Reviewer:** `egm-design` (M3)
* **Scope:** 84–85.
* **Discrepancy:** `DailyRecalcReceiver` is `android:exported="false"` (`AndroidManifest.xml:232–234`); `adb shell am
  broadcast` to it is refused on a non-rooted device. This is the only proof of the nightly half of F51i.
* **Recommendation:** Name a working trigger (e.g. set the device clock to ~00:04:50 so the 00:05 alarm fires), or
  state a root/debug requirement.

### CR-4 — Rollback of the adhan commit silently undoes users' adhan on/off changes — Major
* **Reviewers:** `egm-design` (M4); `egm-style` (N12)
* **Scope:** 420–422; §2 201–206.
* **Discrepancy:** After the fix nothing writes `aura_prefs.adhan_enabled`. Reverting the adhan commit restores the old
  `initialize()` (native overwrites Flutter) and old `AdhanPlayer.play` (reads `aura_prefs`), so changes made under
  the fixed build are lost (e.g. adhan turned back on → silent adhan). "no crash" is also unverified.
* **Recommendation:** Document this rollback cost, or require a one-way resync (Flutter → native) if that commit is
  reverted. Label "no crash" as a static expectation.

### CR-5 — Risks & Mitigations is a three-bullet H3; several stated risks are missing — Major
* **Reviewer:** `egm-structural` (M1)
* **Scope:** 313–318.
* **Missing:** device impact not yet observed (S25/S26); folder status; Goal 9 change with no direct proof; Goal 5
  `loadPrayerTimes` fallback; future `SharedPreferencesAsync` migration breaking `FlutterPrefs` readers (only a
  Non-Goal); **security**: the `[a-z0-9_]+` id rule is the guard against path traversal / arbitrary paths, stated
  only inside Alternative H.
* **Recommendation:** H2 "Risks & Mitigations" table (Risk / Failure mode / Mitigation / Proof) including a Security
  row.

### CR-6 — Alternatives: "Rejected by author" with no linked record; reasons restate the choice; two alternatives missing — Major
* **Reviewers:** `egm-structural` (M2), `egm-design` (M5), `egm-style` (N7)
* **Scope:** 154, 321–414.
* **Discrepancy:** The standard forbids attributing a rejection without a linked record. `precheck.md` "User
  decisions" covers the group, F49i, F9 and preview, but not Q2, Q3/Q4, Robolectric, or one-PR. Reasons for B, F, G, H
  (and A) restate the chosen option; the real reason sits in Cons. Missing: F49a via a native write into
  `aura_silent_mode` through the channel (the F9 route, precheck §5.5/§7); F15 fixed inline at the two call sites.
* **Recommendation:** Record the remaining decisions (e.g. extend precheck "User decisions") and link it; lead each
  reason with the deciding trade-off; add the two missing alternatives.

### CR-7 — Folder-name evidence contradicts itself — Major (structural, style) / Nit (design)
* **Reviewers:** all three — same as Stage 5 ZO-N2/IC-N2, Stage 6 CO-4
* **Scope:** 69–70 vs 113, 215–216.
* **Recommendation:** One status. (Elephant note: the engine source *was* read — `C:\Users\alaae\flutter\engine\src\
  flutter\shell\platform\android\io\flutter\util\PathUtils.java:25–29`; lines 69–70 are stale.)

### CR-8 — Overview scope claim is wider than Goal 8 — Major
* **Reviewer:** `egm-style` (M2)
* **Scope:** 19 vs 109–116, 149.
* **Recommendation:** "makes the four settings in this group come from one documented file and key; `language` stays
  duplicated until F67."

### CR-9 — Language read count (16 / 12 files) unsourced and differs from the contract ("R ×20") — Major (style) / Nit (design, structural)
* **Reviewers:** `egm-style` (M4), `egm-design` (N5), `egm-structural` (N8)
* **Scope:** 99–100, 149, 358, 367–371.
* **Discrepancy:** Structural notes one of the 16 reads `aura_prefs` (`ToggleSilentModeReceiver.kt:255`) and two in
  `TasksWidget.kt` read `aura_tasks_widget`, so "copies in `aura_prayer_times`" is not exact.
* **Recommendation:** Cite the search (or F67's file list) and reconcile `prefs-keys.md:44` in the same commit.

### CR-10 — "caught, logged" is false for `setCustomAdhan` — Major
* **Reviewer:** `egm-style` (M5)
* **Scope:** 316.
* **Discrepancy:** `adhan_player_service.dart:136` has no try-catch (precheck F49b row).
* **Recommendation:** Say caught only where wrapped; the Verification search is the real guard.

### CR-11 — Read-timing claim unsourced — Major (style)
* **Reviewer:** `egm-style` (M6) — design critic and Stage 5 catalyst verified it (no `android:process`).
* **Scope:** 174–175.
* **Recommendation:** Cite the manifest check (no `android:process`) and the plugin write path.

### CR-12 — Service self-restart path not gated (setting off, flag false) — Nit (design)
* **Reviewer:** `egm-design` (N1) — same as Stage 5 IC-M1 (Major there)
* **Scope:** 79–82, 266–274.
* **Recommendation:** Justify why `fg_user_stopped` is enough, or gate it too; add a swipe-away step to S42.

### CR-13 — Some "fails before the fix" JUnit tests only fail to compile — Nit
* **Reviewer:** `egm-design` (N2) — related Stage 5 ZO-N1
* **Scope:** 64–66, 83–84, 261.
* **Recommendation:** Label them structural tests, not regression proofs.

### CR-14 — `previewAdhan` under-specified — Nit
* **Reviewer:** `egm-design` (N4); `egm-style` (N5)
* **Scope:** 225–231, 251–255.
* **Gaps:** stop current preview first (as `play()` does, `AdhanPlayer.kt:190`); register volume receiver / media
  session (`:196–198`); keep or drop Dart-side vibration in `playAdhan` (`adhan_player_service.dart:68–71`); preview
  with adhan off silently does nothing (accepted UX); "(as today …)" needs a line reference; "(preview does nothing)"
  is redundant.

### CR-15 — Existing failure path hit more often: corrupt reciter file → built-in plays without volume-key stop — Nit
* **Reviewer:** `egm-design` (N6)
* **Scope:** 221–224. `playCustomAdhan` failure → `releasePlayer()` (`AdhanPlayer.kt:273/277`) unregisters the volume
  receiver and media session set up at `:196–198`; fallback plays without them.
* **Recommendation:** Known limitation or follow-up finding.

### CR-16 — Stale preview UI after a prayer adhan takes over (pre-existing) — Nit
* **Reviewer:** `egm-design` (N7)
* **Scope:** 285–286. `playingAdhanProvider` still shows stop; tapping it stops the prayer adhan.
* **Recommendation:** Record as known.

### CR-17 — Structure nits — Nit
* **Reviewer:** `egm-structural` (N4–N7)
* "Proof for the playback flag (§3)" sits between §5 and §6 (276–287) — move under §3 or into Goal 3.
* Goal n and §n numbers mean different topics (54–126 vs 194–311) — cross-reference or rename.
* Inconsistent `---` dividers (9, 319–320, 416, 428); double blank line at 319–320.
* Column "Dart writes (unchanged)" also lists removals (167, 171).

### CR-18 — Wording / calibration nits — Nit
* **Reviewer:** `egm-style` (N1–N6, N8–N11)
* "seven places where a user's setting …" — rows 5 and 7 are not user settings (25–26).
* "None of these paths is covered by a test" → cite the grep (44–45).
* "Nothing writes that key" → "no writer found in current code" (104–105, 305–306).
* Non-Goal allows strings "the preview change needs" vs §4 "no new string" (132 vs 255).
* "anyway" (240); "no Robolectric" stated three times (51–52, 148, 397–403); unquantified "slower … more setup" (401).
* Goal 5 contingency sentence too long; "no newer `zuhr_time` value" is not checkable — use "absent or unchanged"
  (93–97).
* "already-loaded `SharedPreferences`" → "loaded once per process" (425–426).
