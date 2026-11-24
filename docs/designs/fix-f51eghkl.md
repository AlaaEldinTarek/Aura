# Fix F51e + F51g + F51h + F51k + F51l — Native adhan and alarm reliability

**Status:** Approved for code (phase P1)  
**Branch:** `fix/f51eghkl` (to be created from main)  
**Findings:** F51e (MEDIUM), F51g (MEDIUM), F51h (MEDIUM), F51k (MEDIUM), F51l (MEDIUM)  
**Files touched:**
- `android/app/src/main/kotlin/com/aura/hala/PrayerAlarmReceiver.kt` — F51e (ringer save guard), F51g (post-check cancel), F51h (+24 h fix)
- `android/app/src/main/kotlin/com/aura/hala/ToggleSilentModeReceiver.kt` — F51e (try-catch)
- `android/app/src/main/kotlin/com/aura/hala/AdhanPlayer.kt` — F51k (fallback tracking + leak)
- `android/app/src/main/kotlin/com/aura/hala/PrayerRescheduleService.kt` — F51l (fallback recalc)

**Out of scope (separate tracking):**
- F51l — `PrayerBootReceiver` `goAsync()`: the foreground service started in the same block keeps the process alive; risk is theoretical. Address when the boot path is revisited.
- F51h — widget null defaulting to "Asr": cosmetic only; PrayerWidgets reads the keys set by this fix.
- F51k — audio focus / `AudioAttributes`, vibration-fires-twice on custom failure: separate spec.

---

## F51e — Silent-mode ringer can corrupt across prayer windows

### Problem

Two independent bugs in the silent-mode cycle can leave the phone stuck on vibrate after the user expects normal mode:

**Bug 1 — ringer saved while already in vibrate (PrayerAlarmReceiver.kt ~816–817)**  
When an adhan fires and the silent-mode vibrate window begins, the code unconditionally saves the current ringer mode as `saved_ringer_mode`. If the user had pressed "Keep Silent" on a previous prayer (which sets the phone to vibrate permanently and leaves `is_silent_active=true`), `audioManager.ringerMode` is already `RINGER_MODE_VIBRATE` at the time the new adhan fires. The save writes vibrate as the "original" mode, so the auto-restore after the next prayer also returns to vibrate instead of normal.

**Bug 2 — `restoreRingerMode` lacks try-catch (ToggleSilentModeReceiver.kt ~389)**  
`audioManager.ringerMode = savedRingerMode` can throw `SecurityException` on API 23+ when restoring `RINGER_MODE_SILENT` without DND access, or on some OEM skins for any ringer change. The exception propagates out of the function uncaught, leaving silent-mode state dirty and notification UI in an inconsistent state. `PrayerBootReceiver` already shows the correct pattern.

### Fix

**Bug 1 — guard the ringer save**  
Before writing `saved_ringer_mode`, check whether a previous silent-mode cycle is still flagged active. If so, skip the write; the saved value from the original activation (before any vibrate was set) is still correct.

```kotlin
// PrayerAlarmReceiver.kt — replace lines ~815–817
// Before
val currentRingerMode = audioManager.ringerMode
silentPrefs.edit().putInt("saved_ringer_mode", currentRingerMode).apply()

// After — only save when not already in a silent-mode cycle
if (!silentPrefs.getBoolean("is_silent_active", false)) {
    val currentRingerMode = audioManager.ringerMode
    silentPrefs.edit().putInt("saved_ringer_mode", currentRingerMode).apply()
    Log.d(TAG, "📱 Saved ringer mode: $currentRingerMode")
} else {
    Log.d(TAG, "📱 Silent already active — keeping saved_ringer_mode unchanged")
}
```

**Bug 2 — wrap the restore**  
Wrap the assignment in `try/catch` matching the pattern already in `PrayerBootReceiver`:

```kotlin
// ToggleSilentModeReceiver.kt — replace the body of restoreRingerMode (~line 384)
private fun restoreRingerMode(context: Context) {
    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    val sharedPrefs = context.getSharedPreferences("aura_silent_mode", Context.MODE_PRIVATE)
    val savedRingerMode = sharedPrefs.getInt("saved_ringer_mode", AudioManager.RINGER_MODE_NORMAL)
    try {
        audioManager.ringerMode = savedRingerMode
        Log.d("SilentOffReceiver", "🔊 Restored ringer mode to: $savedRingerMode")
    } catch (e: SecurityException) {
        Log.e("SilentOffReceiver", "❌ Restore failed (DND access missing): ${e.message}")
    } catch (e: Exception) {
        Log.e("SilentOffReceiver", "❌ Restore failed: ${e.message}")
    }
}
```

---

## F51g — `cancelAllAlarms` does not cancel post-check alarms

### Problem

`PrayerAlarmReceiver.cancelAllAlarms()` cancels adhan alarms (request codes 1001–1006) and pre-prayer reminder alarms (2101–2106 via `cancelReminderAlarms`), but **not** post-prayer-check alarms (request code = adhan code + 2000, i.e. 3001–3006). This was always the gap; the F70 work added the reminder cancel but did not close it.

When prayer times are rescheduled (e.g. after a location change → `cancelAllPrayerAlarms` method channel → Dart calls rescheduling), the old post-check alarms survive and fire at the stale time. The user then receives a post-check card for a prayer time that no longer matches the new schedule.

`cancelPostPrayerCheck(context, prayerName, requestCode)` already exists in the same companion object; it cancels the alarm via `requestCode + 2000`. Cancelling a PendingIntent for which no alarm was armed is harmless (the alarm manager silently does nothing).

### Fix

Add a post-check cancellation loop inside `cancelAllAlarms`, immediately after the existing reminder cancel:

```kotlin
// PrayerAlarmReceiver.kt — inside cancelAllAlarms(), after the cancelReminderAlarms block
try {
    for (prayer in listOf("Fajr", "Sunrise", "Zuhr", "Asr", "Maghrib", "Isha")) {
        cancelPostPrayerCheck(context, prayer, getNotificationId(prayer))
    }
    Log.d(TAG, "📋 [POST_CHECK] All post-check alarms cancelled")
} catch (e: Exception) {
    Log.e(TAG, "❌ [POST_CHECK] cancel failed: ${e.message}")
}
```

No callers need to change; this is strictly additive within the existing function.

---

## F51h — Tomorrow's Fajr calculated as today's Fajr + 24 h

### Problem

In `updateNextPrayer()` (called each time an adhan fires to update the `next_prayer_*` scalars), when no future prayer is found for today (i.e. Isha has just fired), the code falls back to:

```kotlin
// PrayerAlarmReceiver.kt ~line 744
nextPrayerTime = storedFajrTime + (24 * 60 * 60 * 1000)
```

This approximation is inaccurate: prayer times shift by minutes each day due to seasonal variation. The widget countdown and foreground notification show the wrong time until the native calculator next runs (typically the foreground service or the 00:05 daily recalc).

### Fix

Replace the fallback estimate with a call to `NativePrayerCalculator.calculateAndSave(context)`, which loads tomorrow's pre-cached Dart times (or falls back to the native adhan calculation), saves the correct `next_prayer_*` scalars, and schedules tomorrow's alarms. After the call, the `editor.putString` block below is unnecessary; skip it and return.

```kotlin
// PrayerAlarmReceiver.kt — replace the "if (nextPrayerName == null)" block (~lines 739–753)
if (nextPrayerName == null) {
    Log.d(TAG, "🌙 [UPDATE] No future prayer today — triggering native recalc for tomorrow")
    // calculateAndSave is synchronous; it updates next_prayer_* and schedules alarms
    NativePrayerCalculator.calculateAndSave(context)
    return   // updateWidgets is called by calculateAndSave internally
}
```

If `calculateAndSave` is ever gated (session inactive), it returns false and the widget retains its last value until the next recalc; that is acceptable and no worse than the current approximation.

---

## F51k — Fallback adhan MediaPlayer is untracked; file-not-found leaks a player

### Problem

**Bug 1 — untracked fallback player**  
`playDefaultSound()` creates a local `val player = MediaPlayer()` that is never stored in the `mediaPlayer` field. `stop()` checks `mediaPlayer?.isPlaying`, and `isPlaying()` returns `mediaPlayer?.isPlaying == true`, so neither method can reach the fallback player. If the user taps a stop button or the adhan screen is dismissed while the fallback sound plays, the notification sound continues until it completes on its own.

**Bug 2 — MediaPlayer not released when res/raw file not found**  
`playAdhanFile()` sets `mediaPlayer = MediaPlayer()` before the resource ID lookup. When the resource is not found (`resourceId == 0`), the method logs and returns `false` without calling `releasePlayer()`. The `MediaPlayer` instance is set in `mediaPlayer` but never started or released, leaving a leaked object.

### Fix

**Bug 1 — store fallback player in `mediaPlayer`**

```kotlin
// AdhanPlayer.kt — replace playDefaultSound()
private fun playDefaultSound(context: Context) {
    try {
        val player = MediaPlayer()
        player.setDataSource(context, android.provider.Settings.System.DEFAULT_NOTIFICATION_URI)
        player.prepare()
        player.start()
        mediaPlayer = player   // stop() and isPlaying() can now reach it
        player.setOnCompletionListener {
            if (mediaPlayer == player) mediaPlayer = null
            player.release()
        }
        Log.d(TAG, "Played default notification sound as fallback")
    } catch (e: Exception) {
        Log.e(TAG, "Error playing default sound", e)
    }
}
```

**Bug 2 — release on file-not-found**

```kotlin
// AdhanPlayer.kt — inside the else branch in playAdhanFile() (~line 312)
} else {
    Log.w(TAG, "❌ [BUILT-IN] NOT FOUND in res/raw: $fileName")
    mediaPlayer?.release()
    mediaPlayer = null
    return false
}
```

---

## F51l — Boot reschedule does not fall back to native recalculation

### Problem

`PrayerRescheduleService.rescheduleAllPrayers()` reads today's prayer times from `aura_prayer_times` and schedules any that are still in the future. When all stored times have already passed (boot on a new day, or first boot with no stored times), every prayer is skipped (`timeMs <= now`) and `scheduled == 0`. The service logs "Flutter will reschedule on next launch" and exits without arming any alarms.

If the user never manually opens the app after the boot, prayer alarms for the next prayer window may be missing until `PrayerRecalcWorker` (WorkManager) runs. WorkManager typically fires within minutes, so the gap is small but nonzero; on a reboot shortly before Fajr it can mean a missed alarm.

The fix is to call `NativePrayerCalculator.calculateAndSave(this)` when `scheduled == 0`. This is synchronous, reads tomorrow's pre-cached times when available (the Dart client writes `cached_{date}_*` for the next 6 days), and falls back to the built-in adhan calculation. It schedules all five alarms and updates `next_prayer_*`. It already gates on `SessionState.isSessionActive`, so a signed-out boot does nothing (consistent with the F70 design).

```kotlin
// PrayerRescheduleService.kt — replace the if/else block at ~lines 143–147
if (scheduled == 0) {
    Log.w(TAG, "⚠️ [RESCHEDULE] No future times in cache — running native recalc")
    NativePrayerCalculator.calculateAndSave(this)
} else {
    Log.d(TAG, "✅ [RESCHEDULE] Scheduled $scheduled prayer alarms from real times")
}
```

---

## Contract check

| Contract | Verdict |
|----------|---------|
| SharedPreferences key names | Unchanged |
| `aura_silent_mode` keys | Read-only change to the ringer-save guard; no new key |
| `cancelPostPrayerCheck` signature | Existing function, unchanged |
| `cancelAllAlarms` behaviour | Strictly additive (cancels more, never less) |
| `NativePrayerCalculator.calculateAndSave` | Called from two new sites; already called from multiple existing sites; signature unchanged |
| Notification IDs / channels | Unchanged |
| Method-channel names | Unchanged |
| Firestore paths | Unchanged |
| New Kotlin files | None |

---

## Tests

All tests are pure-function unit tests or mock-based; none requires Robolectric.

| ID | Description | File |
|----|-------------|------|
| T1 | `cancelAllAlarms` calls `cancelPostPrayerCheck` for all 6 prayers | `PrayerAlarmReceiverTest.kt` |
| T2 | Ringer save is skipped when `is_silent_active=true` in the adhan-fire path | `PrayerAlarmReceiverTest.kt` |
| T3 | Ringer save runs when `is_silent_active=false` | `PrayerAlarmReceiverTest.kt` |
| T4 | `restoreRingerMode` does not throw when `setRingerMode` raises `SecurityException` | `ToggleSilentModeReceiverTest.kt` |
| T5 | `playDefaultSound` sets `mediaPlayer` to the new player so `isPlaying()` returns true | `AdhanPlayerTest.kt` |
| T6 | `playAdhanFile` returns false and `mediaPlayer == null` when res/raw file not found | `AdhanPlayerTest.kt` |
| T7 | `rescheduleAllPrayers` calls `calculateAndSave` when all stored times are in the past | `PrayerRescheduleServiceTest.kt` |

Test files live under `android/app/src/test/kotlin/com/aura/hala/`.

---

## Device checks

| Step | Description |
|------|-------------|
| S60 | Tap "Keep Silent" on the vibrate notification for prayer N; at prayer N+1 the ringer restore returns the phone to its pre-N mode (normal or ring), not to vibrate |
| S61 | With all cached prayer times in the past (simulated via adb date), clear app data and reboot; prayer alarms arm within 60 s without opening the app |
| S62 | After Isha fires, widget shows tomorrow's correct Fajr time (not Fajr + 24 h) |
