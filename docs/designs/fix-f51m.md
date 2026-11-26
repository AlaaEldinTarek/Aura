# Fix spec: D4 — F51m Focus Mode native (DND restore, restart path, hash collision)

Status: Draft

---

## Findings

### Finding 1 — DND restore clobbers user's pre-Focus DND state (FocusModeActivity)

`FocusModeActivity.restoreSoundMode()` (`:320–330`):
```kotlin
notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)  // ← always ALL
audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL                               // ← always NORMAL
```
Both values are hardcoded.
- `savedRingerMode` is set in `enableSilentMode()` but never used in `restoreSoundMode()`.
- `wasDndEnabled` only records a boolean; it does not capture the user's pre-Focus DND filter.
- If the user had DND on (e.g. `INTERRUPTION_FILTER_PRIORITY`) or their phone on vibrate/silent, Focus Mode permanently discards that state when it exits.

### Finding 2 — Same restore bug in FocusModeService

`FocusModeService.restoreSoundMode()` (`:424–436`):
```kotlin
nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)  // ← always ALL
```
The service correctly restores `savedRingerMode` but still forces DND to `INTERRUPTION_FILTER_ALL` unconditionally.

### Finding 3 — Restart path re-reads already-restored audio state

`FocusModeService.onDestroy()` (`:217–234`): when the OS kills the service mid-session
(`!isTimerFinished`), `restoreSoundMode()` is called (line 220) **before** the restart
intent is sent. The new service instance calls `enableSilentMode()` on start, which
reads the current ringer mode — now NORMAL/ALL after the restore — and saves that as
the "pre-Focus" state to be restored when the session finally ends. Result: the user's
original ringer state is permanently lost after any service restart.

### Finding 4 — Hash collision in focus alarm request codes

`FocusModeReceiver.scheduleFocusAlarm()` (`:49`):
```kotlin
val requestCode = REQUEST_CODE_BASE + abs(taskId.hashCode() % 1000)
```
Only 1000 slots (5000–5999). Two distinct task IDs can produce the same `hashCode() % 1000`
value. When that happens, the second `scheduleFocusAlarm` call uses `FLAG_UPDATE_CURRENT`
on the first task's `PendingIntent`, overwriting the first task's intent data. The first
task's alarm fires at the right time but launches the wrong (second) task's focus session.

---

## Root causes

- **DND**: `restoreSoundMode()` hardcodes the restore targets instead of using the
  saved fields. `wasDndEnabled` (Boolean) cannot hold the previous filter value.
- **Restart path**: `onDestroy` restores sound before restarting, so the new instance
  reads restored (not original) audio state as "pre-Focus".
- **Hash collision**: `% 1000` truncates the hash to 1000 buckets; collision probability
  is 1/1000 per pair of simultaneously-scheduled tasks.

---

## Fix

### Phase M1 — `android/app/src/main/kotlin/com/aura/hala/FocusModeActivity.kt`

**Replace the boolean flag with the saved filter value:**
```kotlin
// Before:
private var wasDndEnabled: Boolean = false

// After:
private var savedInterruptionFilter: Int = NotificationManager.INTERRUPTION_FILTER_ALL
```

**In `enableSilentMode()`, save the current filter before changing it (replace the
`wasDndEnabled = true` line):**
```kotlin
// Before:
wasDndEnabled = true
try {
    notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
} catch ...

// After:
savedInterruptionFilter = notificationManager.currentInterruptionFilter
try {
    notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
} catch ...
```

**In `restoreSoundMode()`, restore to saved values:**
```kotlin
// Before:
try { notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL) } catch (_: Exception) {}
...
try { audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL } catch (_: Exception) {}

// After:
try { notificationManager.setInterruptionFilter(savedInterruptionFilter) } catch (_: Exception) {}
...
try { audioManager.ringerMode = savedRingerMode } catch (_: Exception) {
    try { audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL } catch (_: Exception) {}
}
```

---

### Phase M2 — `android/app/src/main/kotlin/com/aura/hala/FocusModeService.kt`

**Add `savedInterruptionFilter` field (after `wasDndEnabled`):**
```kotlin
private var savedInterruptionFilter: Int = NotificationManager.INTERRUPTION_FILTER_ALL
```

**In `enableSilentMode()`, check for restart path; if first start, read and save;
if restart, load from prefs:**
```kotlin
private fun enableSilentMode() {
    val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    if (prefs.contains("saved_ringer_mode")) {
        // Restart path: load original state saved before first focus start
        savedRingerMode = prefs.getInt("saved_ringer_mode", AudioManager.RINGER_MODE_NORMAL)
        savedInterruptionFilter = prefs.getInt("saved_dnd_filter", NotificationManager.INTERRUPTION_FILTER_ALL)
    } else {
        // First start: read and cache the user's current audio state
        savedRingerMode = audioManager.ringerMode
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.isNotificationPolicyAccessGranted) {
                savedInterruptionFilter = nm.currentInterruptionFilter
            }
        }
    }
    // Enforce focus mode audio regardless of whether this is a first start or restart
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.isNotificationPolicyAccessGranted) {
            try { nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY) } catch (_: Exception) { fallbackToRingerSilent(audioManager) }
        } else { fallbackToRingerSilent(audioManager) }
    } else { fallbackToRingerSilent(audioManager) }
}
```

**Add `saved_ringer_mode` and `saved_dnd_filter` to `saveFocusState()`:**
```kotlin
private fun saveFocusState() {
    getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
        .putString("task_id", taskId)
        .putString("task_title", taskTitle)
        .putString("task_desc", taskDesc)
        .putInt("duration_minutes", durationMinutes)
        .putString("language", language)
        .putLong("started_at", focusStartedAt)
        .putInt("saved_ringer_mode", savedRingerMode)       // ← new
        .putInt("saved_dnd_filter", savedInterruptionFilter) // ← new
        .apply()
}
```

**In `restoreSoundMode()`, restore to saved DND filter (not always ALL):**
```kotlin
// Before:
try { nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL) } catch (_: Exception) {}

// After:
try { nm.setInterruptionFilter(savedInterruptionFilter) } catch (_: Exception) {}
```

**In `onDestroy()`, only restore sound if the timer actually finished; skip restore
when the OS killed the service mid-session (it will restart and resume):**
```kotlin
// Before:
override fun onDestroy() {
    stopMonitoring()
    removeTouchBlocker()
    restoreSoundMode()       // ← unconditional
    ...
}

// After:
override fun onDestroy() {
    stopMonitoring()
    removeTouchBlocker()
    if (isTimerFinished) restoreSoundMode()  // only on clean exit
    ...
}
```
`saveFocusState()` is already called in `onStartCommand(ACTION_START)`, so
`saved_ringer_mode` / `saved_dnd_filter` are in prefs before any restart path
runs. `clearFocusState()` (called by `stopFocusMode()`) clears them on clean stop.

---

### Phase M3 — `android/app/src/main/kotlin/com/aura/hala/FocusModeReceiver.kt`

**Widen the hash slot space from 1000 to 10 000:**
```kotlin
// Before:
private const val REQUEST_CODE_BASE = 5000
...
val requestCode = REQUEST_CODE_BASE + abs(taskId.hashCode() % 1000)

// After:
private const val REQUEST_CODE_BASE = 5000
private const val REQUEST_CODE_SLOTS = 10_000
...
val requestCode = REQUEST_CODE_BASE + abs(taskId.hashCode() % REQUEST_CODE_SLOTS)
```

Apply the same change in `cancelFocusAlarm`:
```kotlin
val requestCode = REQUEST_CODE_BASE + abs(taskId.hashCode() % REQUEST_CODE_SLOTS)
```

**Update `cancelSpecs()` to cover 10 000 slots (5000–14999):**
```kotlin
internal fun cancelSpecs(): List<CancelSpec> =
    (0 until REQUEST_CODE_SLOTS).map { CancelSpec(FocusModeReceiver::class.java, ACTION_FOCUS_ALARM, REQUEST_CODE_BASE + it) }
```

**Update `contracts/notification-ids.md`**: focus alarm request codes row
`5000–5999` → `5000–14999`.

---

## Tests

| ID | File | What it checks |
|----|------|----------------|
| T1 | test/core/services/f51m_source_test.dart | Activity.restoreSoundMode restores `savedRingerMode`, not `RINGER_MODE_NORMAL` |
| T2 | (same) | Activity.restoreSoundMode restores `savedInterruptionFilter`, not `FILTER_ALL` hardcoded |
| T3 | (same) | Activity.enableSilentMode reads `currentInterruptionFilter` before setting PRIORITY |
| T4 | (same) | Service.onDestroy calls restoreSoundMode only when `isTimerFinished` |
| T5 | (same) | Service.saveFocusState persists `saved_ringer_mode` and `saved_dnd_filter` |
| T6 | (same) | Service.enableSilentMode checks prefs for `saved_ringer_mode` (restart path) |
| T7 | (same) | FocusModeReceiver uses `REQUEST_CODE_SLOTS = 10_000` |
| T8 | (same) | FocusModeReceiver.cancelSpecs covers `0 until REQUEST_CODE_SLOTS` |

---

## Device checks

| ID | How to run | Expected |
|----|-----------|---------|
| S-F51m-1 | Enable DND (Priority mode), start and finish a focus session | Phone stays in Priority DND after Focus Mode ends |
| S-F51m-2 | Set ringer to Vibrate, start and finish a focus session | Phone stays on Vibrate after Focus Mode ends |
| S-F51m-3 | Kill the app during an active focus session via Recents; re-open | Focus Mode resumes; after natural end, original ringer state restored |

---

## Contracts

`contracts/notification-ids.md`: focus alarm request code range `5000–5999`
→ `5000–14999`.  No new prefs keys exposed to Dart; `saved_ringer_mode` and
`saved_dnd_filter` are internal to `aura_focus_state` (native-only prefs).

---

## Phases

| Phase | File(s) | Scope |
|-------|---------|-------|
| M1 | `android/…/FocusModeActivity.kt` | Save + restore DND filter correctly; fix ringerMode restore |
| M2 | `android/…/FocusModeService.kt` | Same DND fix; restart path: persist audio state to prefs; guard restoreSoundMode in onDestroy |
| M3 | `android/…/FocusModeReceiver.kt` · `contracts/notification-ids.md` | Widen hash slots 1000 → 10 000; update cancelSpecs |
