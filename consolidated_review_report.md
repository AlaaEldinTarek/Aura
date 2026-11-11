# EGM Consolidated Review Report
# F68 — fix-silent-mode-notification.md

**Date:** 2026-11-11  
**Target:** `docs/designs/fix-silent-mode-notification.md`  
**Branch:** `fix/silent-mode-notification`  
**Reviewers:** 10 Goldfish across 5 stages (Zoom Out ×2, Comprehension, Design, Structural, Style ×2, Intermediate Zoom Out, Implementation Readiness, Codebase Accuracy)  
**Preset:** Consolidated report — all rubrics (uninterrupted)

---

## Executive Summary

The spec's core approach is **technically sound**: root cause is correct, fix approach is correct, Android API behavior claims in paths (a)–(d) are verified, double-post guard reasoning is correct, all code line numbers and method names verified accurate. Three genuine blockers were found, all fixable by spec edits only (no code changes needed before implementation). The most critical is a factual error that would silently break Arabic for all users. Twelve majors follow, several requiring explicit design decisions the spec currently defers.

**Counts:** 3 Blockers · 12 Majors · 18 Nits  
**Confirmed correct (no defects):** Root cause, fix approach, path (d) Android claims, double-post guard, all 6 source-file line numbers, all assigned PendingIntent codes, `R.drawable.ic_notification`, `FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT` combination

---

## Stage Coverage

| Stage | Reviewer(s) | Range | Status |
|---|---|---|---|
| 5 Initial Zoom Out | egm-zoom-out + egm-inventive-catalyst | Full (1–491) | Done |
| 6 Comprehension | egm-comprehension | Full (1–491) | Done |
| 7 Critic Review | egm-design + egm-structural + egm-style | FeatureRange (1–335) | Done |
| 8 Intermediate Zoom Out | egm-zoom-out | Full (1–491) | Done |
| 9 Implementation Readiness | egm-implementation-readiness + egm-codebase-details + egm-style | DetailedRange (336–491) | Done |

---

## 🔴 Blockers

### B1 — Path (f) table, prose, and implementation plan are mutually contradictory
**Confirmed by:** Stage 5a, 5b, 6, 7a, 7b (5 independent reviewers — most-flagged finding)  
**Locations:** Teardown table row (f) line 187; §Path (f) prose lines 210–212; Implementation Plan file list (which omits `SilentModeAutomation.kt`)

The teardown table's "Change needed" cell for row (f) says **"Add `cancel(8100)`"**. The §Path (f) prose two lines later says **"No separate cancel needed in `SilentModeAutomation` itself."** The Implementation Plan omits `SilentModeAutomation.kt` entirely, silently siding with the prose. Three sections give three answers.

Additionally (Stage 5a, confirmed by reading `ToggleSilentModeReceiver.kt`): the spec's reasoning in §Path (f) — that `SilentModeAutomation.restoreRingerMode` is called by `SilentOffReceiver` (and therefore path (c) covers it) — is **factually wrong**. `SilentOffReceiver.onReceive()` calls a package-level `restoreRingerMode(context: Context)` function defined at line 379 of `ToggleSilentModeReceiver.kt`, not `SilentModeScheduler.restoreRingerMode()`. `SilentModeScheduler` (the exported object in `SilentModeAutomation.kt`) has zero call sites in the Android source; it is dead code. The conclusion (no cancel needed) is accidentally correct because the dead function never executes — but the reasoning is wrong and creates a future hazard: if `SilentModeScheduler.cancelAll()` is ever called (e.g., from a Dart-side method channel), silent mode ends without cancelling notification 8100.

**Required fix — choose one option and make all three sections consistent:**
- **Option A (safe, no future hazard):** Add `cancel(8100)` to `SilentModeAutomation.kt:restoreRingerMode`, add it to the Implementation Plan file list. `NotificationManagerCompat.cancel` on a non-existent notification is a no-op; the extra call is harmless.
- **Option B (lean):** Correct the table row (f) "Change needed" cell to "No change needed — `SilentModeScheduler` has no active call sites (dead code); §Path (f) prose is correct." Update the §Path (f) rationale to cite the actual call-graph evidence (file path + line numbers of all callers of `SilentModeScheduler`). The table's "Static code read" verification label is misleading — replace with "Dead code — zero call sites confirmed."

---

### B2 — `cancelSilentModeNotification` helper: `TAG` is unresolvable at top-level; code only compiles as companion-object
**Confirmed by:** Stage 9a (found via code read), Stage 9c (found via style analysis)  
**Locations:** Implementation Plan §File 3, lines 381–391

The plan offers two placement options: "can be a top-level `internal fun` or a companion-object function in `ToggleSilentModeReceiver`." The pseudocode uses `TAG` bare (no qualifier). In the actual source, `TAG` is `private const val TAG = "ToggleSilentMode"` inside `ToggleSilentModeReceiver`'s companion object and `private const val TAG = "SilentOffReceiver"` inside `SilentOffReceiver`'s companion object. At package scope (top-level function), `TAG` is not in scope. The code does not compile in the top-level option.

**Required fix:** Remove "top-level `internal fun`" as an option. Specify: **companion-object function in `ToggleSilentModeReceiver`**. `SilentOffReceiver` then calls it as `ToggleSilentModeReceiver.cancelSilentModeNotification(context)`, which compiles and avoids duplication. Update the pseudocode signature to reflect this placement; the `Note:` sentence about sharing can be dropped once the decision is made.

---

### B3 — `FlutterPrefs` instruction silently breaks Arabic for all users
**Confirmed by:** Stage 9b (single reviewer — only one to read `PrayerAlarmReceiver.kt`)  
**Location:** Implementation Plan §File 1, line 347

The plan instructs: "Read `language` from `aura_prayer_times` via `FlutterPrefs` (consistent with the existing `isArabic` pattern in this file)."

The actual existing pattern at `PrayerAlarmReceiver.kt:772–773` is:
```kotlin
val timesPrefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
val language = timesPrefs.getString("language", "en") ?: "en"
```
This is a **direct `getSharedPreferences` call**, not `FlutterPrefs`. `FlutterPrefs` is a wrapper for the Flutter-managed `FlutterSharedPreferences` store, which applies a `flutter.` prefix to every key. Using `FlutterPrefs` to read `language` would look for the key `flutter.language` in `FlutterSharedPreferences` — not `language` in `aura_prayer_times` — silently return `"en"`, and permanently break Arabic display for all Arabic-language users.

**Required fix:** Replace "via `FlutterPrefs`" with "via `context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)`". The parenthetical "consistent with the existing `isArabic` pattern" is correct in spirit — it correctly points to that method as the model — but the words "via `FlutterPrefs`" directly contradict it.

---

## 🟡 Majors

### M1 — `setOngoing(false)` swipe-dismiss is an unspecified UX trap; no re-post mechanism
**Confirmed by:** Stage 5a, 5b, 7a, 9a (4 reviewers)  
**Locations:** Line 153 (`setOngoing(false)` spec), lines 185–186 (path e "no change needed"), verification plan lines 480–487

After notification 8100 is swiped away (without tapping either button): `is_silent_active` stays true, the ringer stays on vibrate, the auto-restore alarm is still armed, but the user has no visible control in the shade for the rest of the silent window (up to 20 minutes). The only exits are waiting for the timer or manually opening Android Settings. The spec acknowledges this ("swiping is a no-op") but provides no rationale for why `setOngoing(false)` was preferred over `setOngoing(true)`, which would prevent swipe and guarantee the control surface remains available. Stage 5b calls this "a milder variant of F68 itself" — controls visible but permanently removable by one accidental swipe.

**Required fix — pick one option, state it explicitly in the spec:**
- **Option A:** Change to `setOngoing(true)`. Add `setOnlyAlertOnce(true)` to suppress re-alerting. Update Non-Functional Requirements to note the notification cannot be dismissed until the user acts.
- **Option B:** Keep `setOngoing(false)` and add an explicit note: "If the user swipes away notification 8100 without tapping a button, silent mode continues until the scheduled restore fires. This is intentional — the auto-restore timer is the safety net." Add a swipe-dismiss step to the verification plan.

Whichever option is chosen, the verification plan must add: "Swipe away notification 8100 without tapping any button; confirm ringer stays on vibrate until the auto-restore timer fires, and no crash or ANR occurs."

---

### M2 — §Path (f) reasoning is factually wrong (covered under B1 above; listed separately for traceability)
See B1. The conclusion (no cancel needed) is accidentally correct; the reasoning (path (c) covers SilentModeAutomation via `SilentOffReceiver`) is false. `SilentModeScheduler` is dead code.

---

### M3 — "until the next boot or app start" in path (e) — "app start" is unimplemented; force-stop leaves ringer stuck
**Confirmed by:** Stage 5b only  
**Locations:** Lines 185–186 (teardown path e), Implementation Plan §File 4

Path (e) states the orphaned notification resolves "until the next boot or app start." The Implementation Plan adds cleanup only to `PrayerBootReceiver` — no `MainActivity.onCreate` or `PrayerForegroundService.onCreate` handler is added. If the user manually force-stops the app via Android Settings: (i) Android removes notification 8100 ✓, (ii) Android cancels the `SilentOffReceiver` alarm ✗ (never fires), (iii) `is_silent_active = true` and vibrate ringer persist across the force-stop. Recovery requires a reboot, not an app restart — because on next app start, nothing reads `is_silent_active`. The "or app start" claim in the spec is therefore wrong for force-stop scenarios.

**Required fix — pick one:**
- **Option A (documentation only):** Change "until the next boot or app start" to "until the next boot" to match the Implementation Plan. Force-stop is a known gap, acceptable given its rarity.
- **Option B (closes the gap):** Add an `is_silent_active` check to `MainActivity.onCreate` (or `PrayerForegroundService.onCreate`) mirroring the `PrayerBootReceiver` block (restore ringer, clear prefs). This requires adding an 8th file to the Implementation Plan. Note: the check runs on the main thread; ensure consistency with existing patterns in that file.

---

### M4 — PrayerBootReceiver addition is undeclared scope expansion; Goals section doesn't mention it
**Confirmed by:** Stage 8 (Major), Stage 5a (Nit)  
**Locations:** Goals section (line 44), Implementation Plan §4

The Goals section lists the notification-related objectives but makes no mention of boot-time ringer restoration. The PrayerBootReceiver change is introduced only in the Teardown coverage table (as one row among five) with no signal that it represents scope beyond F68. The underlying ringer-persist-across-reboot behavior predates commit `6514f26` — the commit that introduced F68. Stage 8 notes: "A future rollback or bisect of F68 will silently revert the boot fix as well."

**Required fix:** Add a bullet to the Goals section: "Restore `saved_ringer_mode` and clear `is_silent_active` in `PrayerBootReceiver` on boot (pre-existing gap; included here because it is inseparable from clearing `is_silent_active` safely — clearing the flag without first restoring the ringer would leave the phone on vibrate after reboot)."

---

### M5 — `NotificationCompat.Builder` 2-argument constructor never written out
**Confirmed by:** Stage 9a  
**Location:** Implementation Plan §File 1, line 352

The plan says "Build the notification with channel `silent_mode_control`" but never shows the builder construction line. The deprecated single-argument `NotificationCompat.Builder(ctx)` does not associate a channel and silently drops notifications on API 26+. Every existing builder instantiation in the codebase uses the two-argument form. This is an "edit carefully" file; the plan must be unambiguous.

**Required fix:** Add explicitly to the helper specification: `val builder = NotificationCompat.Builder(ctx, "silent_mode_control")`

---

### M6 — CUJ 5 "Then" block embeds pre-fix behavior; implementation note does not belong
**Confirmed by:** Stage 7c (Major), Stage 7b (Nit)  
**Locations:** Lines 112–125 (CUJ 5 Then block)

The Then block header promises "the exact state the user sees after the fix." The ringer-mode sub-item immediately shifts to describing the unfixed behavior: "Without action, the phone stays on vibrate after the reboot" followed by an inline "After the fix:" divider. A CUJ Then block must describe only the post-fix target state; rationale for why that state differs belongs in the Technical Plan. Line 114 ("PrayerBootReceiver does not need to cancel it") is an implementation constraint, not a user-observable outcome. Line 119 says "whatever it was before silent mode was activated" — `saved_ringer_mode` is the precise term already defined in this document.

**Required fix:** Rewrite the ringer-mode sub-item to state only the post-fix outcome: "**Ringer mode:** Restored to `saved_ringer_mode`. `PrayerBootReceiver` reads `saved_ringer_mode` from `aura_silent_mode` prefs and calls `audioManager.setRingerMode` before clearing the prefs." Drop "Without action...", "After the fix:", and line 114. Move any rationale about Android ringer persistence to §Path (d) where it already largely appears.

---

### M7 — "rc" abbreviation undefined (used twice without expansion)
**Confirmed by:** Stage 7c (Major F2), Stage 6 (Nit)  
**Locations:** Lines 125, 207

"`rc 3999`" appears in CUJ 5 and in §Path (d) prose without being defined anywhere in the document.

**Required fix:** Replace both occurrences of "rc 3999" with "request code 3999".

---

### M8 — "normal countdown mode" is an undefined technical state
**Confirmed by:** Stage 7c (Major F3)  
**Location:** Line 86 (CUJ 1 Then block)

"foreground service returns to normal countdown mode" references a named system state not defined anywhere in this document or the referenced modules.

**Required fix:** Replace with "foreground service exits adhan mode and resumes its standard prayer-countdown operation."

---

### M9 — Teardown "Verified" column has no legend; "Static reasoning" is not a verification
**Confirmed by:** Stage 7c (Major F4), Stage 9c (Major M-2)  
**Location:** Lines 180–187 (teardown coverage table)

The column contains three distinct values — "Static code read", "Static — gap confirmed", "Static reasoning" — with no key defining what each authorizes a reviewer to conclude. "Static reasoning" for path (e) means no code was read; conclusion follows from service lifecycle reasoning. The column header is "Verified" making "Static reasoning" a false entry. Stage 9c notes the distinction matters: code-read confirmation vs. design inference are meaningfully different confidence levels.

**Required fix:** Add a footnote or caption below the table defining the labels. Example: "Static code read = insertion point confirmed by reading source; Static — gap confirmed = absence confirmed by reading source; Static reasoning = design inference, code not read."

---

### M10 — Teardown table uses `cancel(8100)` directly; Implementation Plan introduces `cancelSilentModeNotification` helper — no cross-reference
**Confirmed by:** Stage 9c (Major M-1)  
**Locations:** Teardown table rows (a), (b), (c) (lines 182–184); Implementation Plan §File 3 (lines 372–379)

The teardown table tells implementers "Add `cancel(8100)`" for paths (a), (b), (c). The Implementation Plan for file 3 tells them "Add `cancelSilentModeNotification(context)` call." There is no cross-reference stating that one fulfills the other. An implementer reading only the table would add direct `NotificationManagerCompat.cancel(8100)` calls and not construct the helper.

**Required fix:** Add a note after the teardown table (before the §Path (d) block): "In the Implementation Plan, the `cancel(8100)` calls for paths (a), (b), (c) are implemented via the `cancelSilentModeNotification(context)` helper defined in §File 3."

---

### M11 — Mixed notation in PendingIntent construction: `8100 / 8101` and `FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT` use inconsistent convention in one fragment
**Confirmed by:** Stage 9c (Major M-3)  
**Location:** Line 351

"`PendingIntent.getBroadcast(ctx, 8100 / 8101, …, FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT)`" uses `/` as documentation shorthand for "choose one" and `or` as the Kotlin bitwise infix operator in the same fragment, with no signal that the conventions differ.

**Required fix:** Split into two bullet items:
- "Build `dismissIntent` with request code `8100`, flags `FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT`."
- "Build `extendIntent` with request code `8101`, flags `FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT`."

---

### M12 — `IMPORTANCE_DEFAULT` vs `IMPORTANCE_LOW` — rationale for the choice is absent
**Confirmed by:** Stage 7a (Nit Finding 4)  
**Locations:** Lines 148–149, 244–246

The spec uses `IMPORTANCE_DEFAULT` with manually-disabled sound and vibration for the new channel. The stated purpose ("appear silently in the shade, not alert the user again") is the documented purpose of `IMPORTANCE_LOW`. The spec provides no rationale for preferring `IMPORTANCE_DEFAULT` over `IMPORTANCE_LOW`. (The defensible reason: some OEM launchers collapse `IMPORTANCE_LOW` notifications into a "silent notifications" group, reducing visibility — but this is not stated.)

**Required fix:** Add a one-sentence rationale to the channel spec: "Using `IMPORTANCE_DEFAULT` rather than `IMPORTANCE_LOW` to avoid OEM launchers collapsing the notification into a hidden 'silent notifications' group that the user might not find."

---

## 🟢 Nits

| # | Location | Finding |
|---|---|---|
| N1 | Verification plan (lines 480–487) | CUJ 5 reboot path not in device check. Add: enable silent mode, reboot while `is_silent_active = true`, confirm ringer restored and `is_silent_active = false` via logcat `🔕 [SILENT]`. |
| N2 | Line 186 (path e) | "destruction while silent mode is active is an abnormal crash path" understates OEM reality. MIUI, EMUI, Samsung One UI with aggressive battery optimization kill foreground services under memory pressure. Restate as: "known limitation on OEM skins with aggressive process killing." |
| N3 | Lines 63, 113–115, 190, 421 | "Android removes all posted notifications before BOOT_COMPLETED fires" is not universal — Samsung and some vendor ROMs restore notifications at boot. The resulting UX is confusing (stale buttons reappear) but all teardown paths are idempotent so there is no data corruption. Add one sentence: "On vendor ROMs that restore notifications at boot (e.g., Samsung), notification 8100 may briefly reappear; tapping either button is a safe no-op since all teardown paths check state before acting." |
| N4 | Line 405 (PrayerBootReceiver pseudocode) | `saved_ringer_mode` default of `RINGER_MODE_NORMAL` is correct (safe fallback if partial crash leaves flag set without committing the value) but unjustified. Add an inline comment: "RINGER_MODE_NORMAL as safe fallback if saved_ringer_mode was never committed (partial crash between prefs writes)." |
| N5 | CUJ 1–4 / CUJ 5 | `saved_ringer_mode` appears for the first time in CUJ 5 with no prior establishment. Brief introduction in the notification spec table alongside `is_silent_active` and `silent_end_time` would close the gap. |
| N6 | Line 399 (PrayerBootReceiver insertion point) | "before the `Handler.postDelayed` alarm-rescheduling block, ~line 40" is ambiguous if `onReceive` has prior logging. Change to: "at the very top of `onReceive`, as the first executable statement." |
| N7 | Lines 428–442 (MainActivity channel) | The channel registration block must stay inside the `if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)` block — `notificationManager` is a local variable scoped to that block. The plan says only "after the `prayer_tracking` channel (~line 156)" without mentioning this structural constraint. Inserting after the closing brace produces "Unresolved reference: notificationManager." |
| N8 | Line 442 | Log message uses `…` placeholder. Specify the actual string: `Log.d("MainActivity", "✅ [CHANNEL] silent_mode_control channel created")`. |
| N9 | Lines 185–186 (teardown table row e) | Row (e) contains five sentences of rationale in the "Change needed" cell, inconsistent with the terse cells for rows (a)–(c). Extract to a "Path (e) — service destruction" expansion block matching the §Path (d) and §Path (f) pattern. |
| N10 | Line 185 (row d, Location column) | "PrayerBootReceiver — currently **no silent-mode reset**" is a status annotation, not a code location. Use "`PrayerBootReceiver.onReceive()`" and move the status annotation to the "Change needed" cell. |
| N11 | Lines 182–187 (teardown invariant) | The stated invariant "Every path that sets `is_silent_active = false` must also call `cancel(8100)`" is imprecise for path (b): `extendSilentMode` cancels notification 8100 without ever setting `is_silent_active = false`. Restate as: "Every path that removes the user's ability to adjust the vibration window must cancel notification 8100 (this includes paths that set `is_silent_active = false` AND paths where the user has finalized their choice — `extendSilentMode`)." |
| N12 | Lines 46–54 (Non-Goals) | `SilentModeAutomation.kt` appears in the teardown table but not in Non-Goals and not in the Implementation Plan. Add: "Modifying `SilentModeAutomation.kt` — the teardown coverage analysis in §Path (f) explains why no change is needed there." |
| N13 | Line 27 | Heading `## The Problem` deviates from the template's `## Problem Statement`. Rename. |
| N14 | Lines 109–126 (CUJ 5) + lines 185 + 189–208 | Boot behavior defined in full in three separate locations (CUJ 5, teardown table row (d), §Path (d) prose). Shorten CUJ 5 to user-visible outcome only; add cross-reference to §Path (d) for the technical mechanism. |
| N15 | Line 167 | "This is the correct behaviour." adds no information after two sentences that already demonstrate it. Drop. |
| N16 | Line 153 | "swiping is a no-op" is ambiguous. Clarify: "swiping the notification away does not restore the ringer; `is_silent_active` remains true until a button is tapped or the timer fires." |
| N17 | Lines 13, 151 | "vibrate-on-prayer" and "Vibrate Mode" (notification title) vs "silent mode" (feature name) used without a mapping. Add a one-sentence definition in §Overview: "The feature is referred to internally as 'silent mode' and displayed to the user as 'Vibrate Mode'." |
| N18 | Lines 197, 198 | "per CLAUDE.md platform-channel rules" is an internal reference a code reviewer cannot resolve. The parenthetical "(ringer changes can throw without DND permission on some API levels)" already states the concrete reason. Remove the CLAUDE.md reference. Also expand "DND" to "Do Not Disturb (DND)" on first use. |

---

## Verified Correct — No Changes Needed

The following design and code claims were independently verified by reviewers who read the source files:

| Claim | Verified by |
|---|---|
| Root cause: `addAction` invisible on `setCustomBigContentView` without `DecoratedCustomViewStyle` | Stage 7a (design) + Stage 9b (code read: `setCustomBigContentView` at line 590 of `PrayerForegroundService.kt`) |
| Dead block is lines 592–622 with request codes 8001/8002 | Stage 9b (code read) |
| `enableSilentModeForPrayer()` exists; `scheduleSilentModeRestore` at line 727 | Stage 9b (code read) |
| `dismissSilentMode` writes `is_silent_active = false` at exactly line 139 | Stage 9b (code read) |
| `extendSilentMode` writes `silent_end_time = 0` at exactly line 205 | Stage 9b (code read) |
| `SilentOffReceiver.onReceive` writes `is_silent_active = false` at exactly line 331 | Stage 9b (code read) |
| `SilentOffReceiver` is a top-level class (not inner class) | Stage 9b (code read) |
| `Handler.postDelayed` block at line 40 of `PrayerBootReceiver.kt` | Stage 9b (code read) |
| `createNotificationChannel()` at lines 110–162; `prayer_tracking` at line 156 | Stage 9b (code read) |
| ID 8100 is free; PI codes 8100/8101 are free | Stage 9b (code read of `notification-ids.md`) |
| `R.drawable.ic_notification` exists at all density buckets | Stage 9a (glob verification) |
| `FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT` combination is correct for Android 12+ | Stage 9a |
| Android persists `AudioManager.ringerMode` across reboots (`Settings.Global`) | Stage 7a (design) |
| Android clears notifications before `BOOT_COMPLETED` on AOSP | Stage 7a (design) + Stage 5b (with vendor-ROM caveat in N3) |
| `NotificationManagerCompat.notify(id, n)` replaces existing notification with same ID | Stage 7a (design) |
| Alternative A rejection (DecoratedCustomViewStyle) holds | Stage 7a (design) |
| Alternative B rejection (re-attach to adhan notification) holds | Stage 7a (design) |

---

## Traceability Matrix

| Finding | Source stages | Action required | Type |
|---|---|---|---|
| B1: Path (f) table/prose/impl-plan contradiction | S5a, S5b, S6, S7a, S7b | Correct table OR add cancel to SilentModeAutomation; make all 3 sections consistent | Spec edit |
| B2: TAG unresolvable at top-level; must be companion-object | S9a, S9c | Remove top-level option; specify companion-object in ToggleSilentModeReceiver | Spec edit |
| B3: FlutterPrefs instruction wrong; breaks Arabic | S9b | Replace "via FlutterPrefs" with direct getSharedPreferences call | Spec edit |
| M1: setOngoing(false) swipe-dismiss unspecified | S5a, S5b, S7a, S9a | Pick setOngoing(true) or document the gap; add verification step | Spec edit + design decision |
| M2: Path (f) reasoning factually wrong (see B1) | S5a, S5b | See B1 | — |
| M3: "or app start" unimplemented; force-stop gap | S5b | Either drop "or app start" OR add app-start handler | Spec edit ± impl scope |
| M4: PrayerBootReceiver undeclared in Goals | S8, S5a | Add boot-ringer goal to Goals section | Spec edit |
| M5: Builder 2-arg constructor not specified | S9a | Add `NotificationCompat.Builder(ctx, "silent_mode_control")` to spec | Spec edit |
| M6: CUJ 5 Then block structurally defective | S7c, S7b | Rewrite to post-fix outcomes only; remove pre-fix rationale | Spec edit |
| M7: "rc" undefined | S7c, S6 | Expand to "request code 3999" × 2 | Spec edit |
| M8: "normal countdown mode" undefined | S7c | Rewrite phrase | Spec edit |
| M9: Verified column no legend | S7c, S9c | Add footnote with label definitions | Spec edit |
| M10: Teardown table vs helper name mismatch | S9c | Add cross-reference note after teardown table | Spec edit |
| M11: Mixed notation in PendingIntent construction | S9c | Split into two bullet items | Spec edit |
| M12: IMPORTANCE_DEFAULT rationale missing | S7a | Add one-sentence rationale | Spec edit |
| N1–N18 | Various | See Nits table | Spec edits |

---

## Blockers Requiring Author Decision (not just editorial)

Three findings require a **design decision** before the spec can be corrected:

| # | Decision | Options |
|---|---|---|
| B1 | Does SilentModeAutomation need `cancel(8100)`? | Option A: add it (safe, defensive) · Option B: correct the reasoning, cite call-graph evidence |
| M1 | Should notification 8100 be swipe-resistant? | `setOngoing(true)` (control always visible) · `setOngoing(false)` with explicit gap acceptance |
| M3 | Does "or app start" need to be implemented? | Add app-start handler · OR drop "app start" from path (e) claim |
