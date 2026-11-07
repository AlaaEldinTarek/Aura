# Focus Mode
Verified against code 2026-11-07 (reference/2026-11-07_DRIFT_REPORT.md). Native issues: findings F51f, F51m, F51q.

## Flow
- Task fields: `focusMode` (bool), `focusDurationMinutes` (int, default 25).
- Alarm fires → `FocusModeReceiver` starts `FocusModeService` (overlay) and `FocusModeActivity` separately
  (`startActivity`; no full-screen intent despite its KDoc). The activity calls `startLockTask()`.
- At timer end `onCountdownComplete()` calls `stopLockTask()` and restores sound; "Did you complete?" → Yes stores the
  task id; Flutter reads it via `getFocusCompletedTaskId` and marks the task done.
- No early exit exists: `onKeyDown` only swallows BACK/HOME/APP_SWITCH/RECENT_APPS. The task form text promising
  "press volume up 3 times" is wrong (F52f).
- Accessibility auto-click is gone: `AuraAccessibilityService` is not in the manifest; `isAccessibilityServiceEnabled`
  always returns false, `requestAccessibilityPermission` is a no-op. `focus_a11y_ever_enabled` removed (bc765f6).

## Native files
- `FocusModeService.kt` — START_STICKY, overlay (TYPE_APPLICATION_OVERLAY, full-screen, not focusable), countdown,
  relaunch monitor (F51f), restores its saved ringer mode on destroy.
- `FocusModeActivity.kt` — `startLockTask()` / `stopLockTask()` (`onCountdownComplete`, `finishFocusMode`); DND restore
  forces filter ALL + `RINGER_MODE_NORMAL` (F51m).
- `FocusModeReceiver.kt` — alarm entry; its `ACTION_FOCUS_COMPLETE` branch is dead (F51q).
- Channel `com.aura.hala/focus_mode` (in `MainActivity`): `scheduleFocusAlarm`, `cancelFocusAlarm`, `canDrawOverlays`,
  `requestOverlayPermission`, `getFocusCompletedTaskId`, `isAccessibilityServiceEnabled`,
  `requestAccessibilityPermission`, `hasDndAccess`, `requestDndAccess`.

## Prefs
- `${packageName}_preferences` is used ONLY by Focus Mode (native handoff): `focus_completed_task_id`,
  `focus_task_was_completed` (read and cleared by `getFocusCompletedTaskId`).
- `aura_focus_state`: start timestamp (write-only, F51q). `aura_focus_mode` (`completed_task_id`, `completed_at`) is
  written only by the dead branch. See contracts/prefs-keys.md.
