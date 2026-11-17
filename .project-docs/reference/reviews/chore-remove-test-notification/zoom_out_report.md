# Goldfish Review Report

**Target:** `docs/designs/chore-remove-test-notification.md` (lines 1-255)

## Reviewer Status

| Reviewer | Status |
| --- | --- |
| `egm-zoom-out` | completed |
| `egm-inventive-catalyst` | completed |

Verdict: no Blockers, no Majors, 6 Nits after deduplication. The spec can proceed once the owner approves.

## Fact check (both reviewers, VERIFIED against code)

- `desktop_tray_service.dart`: `_testNotifItem` 132-139, `_sepAfterTestNotif` 148, `buildMenu` entries 166-167, `case 'test_notif'` 209-211, import line 10, `_fireTestAdhanFromMenu` and comment 252-260 all match. `DesktopPrayerScheduler` is used only at line 259, so removing the import is correct.
- `_clickGuard` stays because `_stopAdhanFromMenu` uses it (line 244).
- `desktop_tray_menu_ids_test.dart`: cited lines 29, 45, 64-72, 73-81, 85-95, 97 match. `items![2]` is still Stop Adhan after the edit.
- After the change `fireTestAdhan` has no caller in `lib/`. The `test_notification*` translation keys and `NotificationService.showTestNotification` are separate features and are correctly left alone.
- Not checked by the inventive-catalyst: `desktop_prayer_scheduler.dart` claims (playing-flag lines 85-87, 110-112) and the A1 spec's line numbers.

## Prioritized Findings (Blockers -> Major -> Nits)

No Blockers. No Majors.

### Deferred `fireTestAdhan()` dead code and stale comment - Severity: Nit
* **Reviewer Lens:** `egm-zoom-out`, `egm-inventive-catalyst`
* **Affected Scope:** lines 35-38, 59-69, 125-129, 161-169, 229-230
* **Discrepancy Description**: `fireTestAdhan()` stays as unreachable code and its "use via tray menu" doc comment becomes false. This is an explicit owner decision deferred to `fix/adhan-stop`.
* **Rationale & Recommendation**: Sound deferral. Make the docs task explicit: the `fix/adhan-stop` entry in STATE.md must list both items (decide whether to remove the method, and fix the comment).

### Profile test-adhan tool not addressed as a stand-in - Severity: Nit
* **Reviewer Lens:** `egm-inventive-catalyst`
* **Affected Scope:** Verification Plan, E2E/Device (lines 248-251)
* **Discrepancy Description**: The spec accepts that manual adhan testing needs real prayer times, but does not say whether the Profile "test adhan" tool (`PrayerAlarmService.testAdhanNow`) can cover any A2 or `fix/adhan-stop` device checks.
* **Rationale & Recommendation**: Add one sentence saying whether it is a usable stand-in. It only partly substitutes, because it bypasses the desktop scheduler and tray and cannot reproduce the scheduler-timer playing-flag bug.

### Plan restates Technical Plan - Severity: Nit
* **Reviewer Lens:** `egm-zoom-out`
* **Affected Scope:** lines 133-139, 188-215
* **Discrepancy Description**: The Detailed Implementation Plan repeats the Technical Plan nearly line for line, with per-line numbers and literal expected arrays. That is more altitude than a one-item removal needs, and the numbers go stale. The spec already says to re-check them at the start of implementation (lines 181-183).
* **Rationale & Recommendation**: Keep one list. In the test section keep only the intent (drop the item and its separator from the expected lists).

### Trade-off repeated about five times - Severity: Nit
* **Reviewer Lens:** `egm-zoom-out`
* **Affected Scope:** lines 37-38, 70-73, 81-84, 149-159
* **Discrepancy Description**: "Manual adhan testing now needs real prayer times or `fix/adhan-stop`" appears in Goals, Q2, Q5, Alternative A and its rejection. Q2 and Q5 are closed but still repeat it.
* **Rationale & Recommendation**: State it once and link to it. Collapse closed questions to one line each.

### Status line carries process state - Severity: Nit
* **Reviewer Lens:** `egm-zoom-out`
* **Affected Scope:** lines 4, 181
* **Discrepancy Description**: "Stage 5 re-run is pending" will go stale.
* **Rationale & Recommendation**: Reduce to Draft or Approved and keep review history out of the header.

### Scope statement says "Windows only" - Severity: Nit
* **Reviewer Lens:** `egm-zoom-out`
* **Affected Scope:** line 11 vs `desktop_tray_service.dart:56-57`
* **Discrepancy Description**: The tray service's `isDesktop` guard also covers macOS and Linux, so the removal applies there too. The effect is harmless.
* **Rationale & Recommendation**: Say "desktop (the tray service's `isDesktop` guard)".

### Ambiguous or optional steps in the plan - Severity: Nit
* **Reviewer Lens:** `egm-zoom-out`, `egm-inventive-catalyst`
* **Affected Scope:** line 200 (step 7), lines 236-238
* **Discrepancy Description**: "Run `dart format` on the file and keep its output" is ambiguous. The Android release build is described as "not needed but cheap to run once", which blurs what counts as done.
* **Rationale & Recommendation**: Say "keep the formatted result and report whether it changed anything", consistent with the `--set-exit-if-changed` check. Either require the Android build or drop it.

## Reviewer notes

* **egm-zoom-out:** Nothing new is added, so there is nothing to reuse. Removing the item and reusing the existing ids and guard is the simplest approach. PASS.
* **egm-inventive-catalyst:** No false compromise detected. The one real trade-off (losing the manual adhan trigger on Windows to remove stray-click risk) was examined in Open Question 5 and Alternatives A and B and accepted with a reason. The change is deletion only, so no new pattern is proposed.
