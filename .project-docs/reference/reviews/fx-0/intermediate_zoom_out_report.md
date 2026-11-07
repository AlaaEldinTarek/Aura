# Stage 8 — Intermediate Zoom Out Report
Target: `docs/designs/fx-0-prayer-settings.md` (full file, unchanged since Stages 5–7) · Date: 2026-11-07
Reviewer: `egm-zoom-out` (fresh context; read Stage 5–7 reports + reading list)
Verdict: context sufficient; no Blocker. Stage 7 deepened the Kotlin parity path before the Stage 5 question (does
the fallback need parity?) was settled; several proposed fixes rest on dead code or would pull out-of-bounds files in.

| # | Sev | Scope | Finding |
| --- | --- | --- | --- |
| R1 | Major | Overview, Goal 2, shared changes 5–6, Options, Alt C, item 13 | Settle Kotlin scope first. Options, simplest first: (a) raise N, fix only 5 names + per-instant offset + rounding + fallback log; (b) JVM Adhan library (D7) — removes the solar port, MC approximation and ceiling/stop process, costs a release dependency; (c) current hand port. Under (a) D9/D10/D11/D13 mostly vanish and D6 shrinks to "pure `calculate` has no `android.*` imports, junit suffices". Meet D9 by scoping the claim, not adding cities. |
| R2 | Major | Shared change 4; item 10 | D1 + I5 over-engineered: every open/resume already creates a new notifier with an empty fingerprint, so failures self-heal. Keep one latest-wins generation int checked before each platform write + I4 reordering; record "failed write lasts until next open/resume" as accepted risk; drop backoff and success-only fingerprinting. |
| R3 | Major | CUJ 3; item 14 | D3's per-date iqama cache breaks Non-Goals (new keys) and the boundary (`MainActivity.kt`, `PrayerAlarmReceiver.kt`). Gap already exists today (native `reschedule` arms tomorrow without iqama). Narrow CUJ 3 + S31 to the same day's next adhan, log a finding, state that next-occurrence scheduling now also reaches this gap. |
| R4 | Major | Pre-prayer reminders | T2 overstated: only Dart call to `scheduleReminderAlarm` is the user's "remind me later" snooze (`main_wrapper_screen.dart:859`, code 7000 + delay); `PrayerAlarmService.scheduleReminderAlarm` (`:99`) has no caller; native `reschedule` arms only adhan alarms. Fix the sentence (no automatic reminder; snooze is user-started, short-lived, out of scope); do not widen the boundary. |
| R5 | Major | Shared change 4; items 9–10 | Z2/I2 rest on dead code: `loadPrayerTimes(nextPrayer!.time)` (`:453`) is inside `updateNextPrayer()`, which has no caller; all live callers pass `DateTime.now()`. Add one anchor sentence (wall-clock today, independent of `date`); list `updateNextPrayer` as dead code; drop I2's extra test. |
| R6 | Major (new) | Shared change 4 | Fingerprint also gates non-prayer effects: daily task digest (reads up to 500 Firestore tasks, `:281–316`) and `cleanupFuturePrayerRecords` (deletes Firestore records, `:351–363`). Put only prayer-derived effects behind the fingerprint (alarms, post-checks, widgets, desktop timers, `updatePrayerTimes`, `cached_*`); digest + cleanup keep the once-per-day date guard. Removes D5. |
| R7 | Nit | Fingerprint + larger N | At N = 30–60 the times-based fingerprint means 30–60 calcs per minute after Isha; if N rises, use inputs + build number or compute only on date/input change; update L316–317. |
| R8 | Nit | Shared change 1; triggers | Z6 points the wrong way: `setCalculationMethod` / `setAsrMadhab` have no caller and write enum names (breaks "stored values do not change"). Keep screens calling `loadPrayerTimes(DateTime.now())`; list both as dead code. |
| R9 | Nit | Risks section (D8/S1) | Gather existing failure rows + D1, D2, D4, D5, each with a one-line accepted risk or the cheap fix chosen; no new mechanisms. |
| R10 | Nit | Stale alarms; S30 (D4/I8) | Document reliance on the 6 h duplicate guard (`PrayerAlarmReceiver.kt:486–495`); add S30 mirror; no new suppression mechanism. |
| R11 | Nit | Future Improvements | Dead-code list incomplete: add `updateNextPrayer`, `setCalculationMethod`, `setAsrMadhab`, `PrayerAlarmService.scheduleReminderAlarm`, `NotificationService.scheduleDailyPrayers`. Do not delete in FX-0. |
| R12 | Nit | Items 2, 4 (D12, Z9) | Generator + staleness check already planned; merge the two Dart checks ("app output == fixture rows"). |

Earlier findings endorsed as low-cost and scope-neutral: I4 (data first, alarms last), D2 (calendar-day arithmetic),
Z4 (item 11 no-op), Z8 (move evidence out of high-level sections), S5/S6 (markdown structure), C1/I3/T1 (narrow
CUJ 2 to adhan alarms), I7 (resolved parameters as Future Improvement only).
