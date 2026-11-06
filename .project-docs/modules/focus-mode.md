# Focus Mode
Relocated from CLAUDE.md on 2026-11-06; not yet re-verified (Step 2).

## Flow
- Task fields: `focusMode` (bool), `focusDurationMinutes` (int, default 25).
- Alarm fires → `FocusModeReceiver` → `FocusModeService` (overlay) → `FocusModeActivity` (`startLockTask()`).
- `AuraAccessibilityService` auto-clicks OK on the "Screen pinned" dialog silently.
- After the timer: DND restored, "Did you complete?" → Yes marks the task done via the `getFocusCompletedTaskId`
  MethodChannel method.
- `focus_a11y_ever_enabled` flag prevents re-asking for accessibility on Huawei EMUI.

## Native files
- `FocusModeService.kt` — START_STICKY, system overlay (TYPE_APPLICATION_OVERLAY), blocks notification shade, countdown
  timer, restores sound on end.
- `FocusModeActivity.kt` — `startLockTask()` for complete lockdown; no `stopLockTask()` at timer end; DND restored unconditionally.
- `AuraAccessibilityService.kt`, `FocusModeReceiver.kt`.
- Channel: `com.aura.hala/focus_mode` (scheduling, overlay/DND, service control).

## Prefs
- `${packageName}_preferences` is used ONLY by Focus Mode (native↔native handoff): `focus_completed_task_id`,
  `focus_task_was_completed`. `aura_focus_mode` file: `completed_task_id`, `completed_at`. See contracts/prefs-keys.md.
