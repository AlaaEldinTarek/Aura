# Fix F51j — Azkar launches twice per prayer

**Status:** Approved for code (phase P1)  
**Branch:** `fix/f51j` (to be created from main)  
**Finding:** F51j (MEDIUM)  
**Files touched:**
- `android/app/src/main/kotlin/com/aura/hala/AdhanFullScreenActivity.kt`
- `android/app/src/main/kotlin/com/aura/hala/PrayerAlarmReceiver.kt`

---

## Problem

Two independent code paths both launch `AzkarFullScreenActivity` for the same prayer:

**Path A — AdhanFullScreenActivity (iqama time)**  
When the iqama countdown reaches zero (or immediately when no iqama is set), the ticker posts an anonymous 3-second Runnable:
```kotlin
tickHandler.postDelayed({ launchAzkarAndFinish() }, 3000)   // AdhanFullScreenActivity.kt:96, 101
```
`launchAzkarAndFinish()` calls `startActivity(AzkarFullScreenActivity.getIntent(...))` and then `finish()`.

**Path B — AzkarAlarmReceiver (iqama + 10 min)**  
`PrayerAlarmReceiver` schedules an exact alarm for `iqamaTimeMs + 10 min` (or `currentTime + 15 min` if no iqama is set). When it fires, `AzkarAlarmReceiver.onReceive()` posts a full-screen-intent notification that launches `AzkarFullScreenActivity` again.

**Lambda leak**  
`onDestroy()` calls `tickHandler.removeCallbacks(tickRunnable)` but the two anonymous `{ launchAzkarAndFinish() }` lambdas are separate objects — not `tickRunnable`. If the user dismisses the adhan screen at or just after iqama, those lambdas are still pending in the handler queue and fire 3 seconds later from an already-destroyed activity. The alarm then fires 10 minutes later, causing a second launch.

**Device evidence (2026-11-08, nova 5T, Zuhr):**  
Adhan screen closed at 11:38 (before iqama 11:53). `AzkarAlarmReceiver` fired at 12:03 and `ActivityTaskManager` logged two `START AzkarFullScreenActivity` entries 130 ms apart, the second returning to the already-open screen.

**Product rule (user 2026-11-07):** exactly one azkar launch, at iqama.

---

## Fix

Two coordinated changes:

### A — Named Runnable + alarm cancel (`AdhanFullScreenActivity.kt`)

Replace both anonymous lambda posts with a named field Runnable so it can be cancelled in `onDestroy`. Also cancel the AzkarAlarmReceiver backup alarm inside `launchAzkarAndFinish()` before launching, so the alarm cannot fire independently if the screen handled the launch first.

```kotlin
// Add field near tickHandler declaration
private val azkarRunnable = Runnable { launchAzkarAndFinish() }

// Replace both occurrences of:
//   tickHandler.postDelayed({ launchAzkarAndFinish() }, 3000)
// with:
tickHandler.postDelayed(azkarRunnable, 3000)

// In onDestroy() — add after removeCallbacks(tickRunnable):
tickHandler.removeCallbacks(azkarRunnable)

// In launchAzkarAndFinish() — add before startActivity():
AzkarAlarmReceiver.cancel(applicationContext, prayerName)
Log.d(TAG, "❌ [ADHAN] Cancelled azkar backup alarm (screen handled launch)")
```

### B — Tighten backup window (`PrayerAlarmReceiver.kt`)

Change the alarm trigger from iqama+10 min to iqama+60 s. This keeps the alarm as a true backup (fires only if the screen never handled the launch, e.g. screen dismissed before iqama), while ensuring azkar appears near iqama time rather than 10 minutes late. The no-iqama fallback is similarly tightened.

```kotlin
// Before (PrayerAlarmReceiver.kt ~688–689):
val azkarTrigger = if (iqamaTimeMs > 0) iqamaTimeMs + 10 * 60 * 1000L
                   else currentTime + 15 * 60 * 1000L

// After:
val azkarTrigger = if (iqamaTimeMs > 0) iqamaTimeMs + 60 * 1000L
                   else currentTime + 60 * 1000L
```

**How the two paths interact after the fix:**

| Scenario | Path A (screen) | Path B (alarm at iqama+60s) | Result |
|---|---|---|---|
| Screen active at iqama | 3s lambda fires → cancels alarm → launches azkar | Cancelled before firing | 1 launch ✓ |
| Screen dismissed before iqama | `onDestroy` cancels `azkarRunnable` | Fires at iqama+60s | 1 launch ✓ |
| Screen dismissed after iqama (within 3s) | `onDestroy` cancels `azkarRunnable` (not yet fired) | Fires at iqama+60s | 1 launch ✓ |
| Screen dismissed after iqama (after 3s) | Lambda already ran, cancelled alarm | Cancelled before firing | 1 launch ✓ |

---

## Contract check

| Contract | Verdict |
|---|---|
| `AzkarAlarmReceiver` request codes 3001–3006 | Unchanged |
| Notification IDs 9001–9006 | Unchanged |
| Alarm ACTION_AZKAR_ALARM intent | Unchanged |
| `AzkarAlarmReceiver.cancel()` method | Already exists; called with same args |
| New prefs keys | None |

---

## Tests

Source-text tests (Kotlin JUnit, file `android/app/src/test/kotlin/com/aura/hala/AzkarLaunchTest.kt`):

- **T1**: `AdhanFullScreenActivity` declares a `val azkarRunnable: Runnable` field (not anonymous) — verifies the named Runnable is present so `removeCallbacks` can target it.
- **T2**: `onDestroy()` calls `tickHandler.removeCallbacks(azkarRunnable)` — verifies the lambda leak is closed.
- **T3**: `launchAzkarAndFinish()` calls `AzkarAlarmReceiver.cancel(...)` before `startActivity(...)` — verifies the alarm is cancelled on the screen-handled path.
- **T4**: `PrayerAlarmReceiver` azkar trigger is `iqamaTimeMs + 60_000L` when `iqamaTimeMs > 0` — verifies the 10-min delay is gone.
- **T5**: `PrayerAlarmReceiver` azkar trigger is `currentTime + 60_000L` when `iqamaTimeMs <= 0` — verifies the no-iqama fallback is tightened.

---

## Device check

| Step | Description |
|---|---|
| S71 | Real or test-adhan Zuhr. Stay on the adhan screen to iqama. Confirm exactly one AzkarFullScreenActivity opens (no second copy appears on back navigation or after returning to the app). |
| S72 | Real or test-adhan prayer. Dismiss the adhan screen (back button) before iqama. Confirm exactly one AzkarFullScreenActivity opens ~60 s after the dismiss (the backup alarm). |
