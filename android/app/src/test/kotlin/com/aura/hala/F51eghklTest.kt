package com.aura.hala

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Spec: docs/designs/fix-f51eghkl.md — T1 to T7.
 * Source-text tests that pin the specific guards/fixes added for each finding so a future
 * editor who removes them sees an immediate failure.
 */
class F51eghklTest {

    private fun source(name: String): String {
        val f = File("src/main/kotlin/com/aura/hala/$name")
        assertTrue("source not found: ${f.absolutePath}", f.exists())
        return f.readText().replace("\r\n", "\n")
    }

    // T1 — cancelAllAlarms cancels post-check alarms (F51g)
    @Test
    fun `cancelAllAlarms contains cancelPostPrayerCheck loop`() {
        val src = source("PrayerAlarmReceiver.kt")
        // The fix adds a loop inside cancelAllAlarms that calls cancelPostPrayerCheck for all prayers.
        val cancelAllStart = src.indexOf("fun cancelAllAlarms")
        assertTrue("cancelAllAlarms not found", cancelAllStart >= 0)
        // Find the end of the function (next top-level fun or closing brace after the block).
        val window = src.substring(cancelAllStart, cancelAllStart + 1500)
        assertTrue("cancelPostPrayerCheck not found inside cancelAllAlarms", window.contains("cancelPostPrayerCheck"))
    }

    // T2 — ringer save is skipped when is_silent_active = true (F51e)
    @Test
    fun `ringer save is guarded when silent already active`() {
        val src = source("PrayerAlarmReceiver.kt")
        assertTrue(
            "is_silent_active guard missing from ringer-save path",
            src.contains("keeping saved_ringer_mode unchanged")
        )
    }

    // T3 — ringer save runs in the false-active branch (F51e)
    @Test
    fun `ringer save wrapped in is_silent_active conditional`() {
        val src = source("PrayerAlarmReceiver.kt")
        assertTrue(
            "conditional ringer save not found",
            src.contains("!silentPrefs.getBoolean(\"is_silent_active\", false)")
        )
    }

    // T4 — restoreRingerMode wraps ringer assignment in try/catch (F51e)
    @Test
    fun `restoreRingerMode has SecurityException catch`() {
        val src = source("ToggleSilentModeReceiver.kt")
        assertTrue("restoreRingerMode definition not found", src.contains("private fun restoreRingerMode"))
        // SecurityException must appear in the same file (inside the function).
        assertTrue("SecurityException catch missing in restoreRingerMode", src.contains("SecurityException"))
        // The unique log message added by the fix pins the try/catch to this specific function.
        assertTrue("fix log line missing",
            src.contains("Restore failed (DND access missing)"))
    }

    // T5 — playDefaultSound stores the player in mediaPlayer so stop()/isPlaying() can reach it (F51k)
    @Test
    fun `playDefaultSound assigns player to mediaPlayer field`() {
        val src = source("AdhanPlayer.kt")
        val fnStart = src.indexOf("private fun playDefaultSound")
        assertTrue("playDefaultSound not found", fnStart >= 0)
        val window = src.substring(fnStart, fnStart + 500)
        assertTrue("mediaPlayer assignment missing in playDefaultSound", window.contains("mediaPlayer = player"))
    }

    // T6 — playAdhanFile releases mediaPlayer on the file-not-found path so there is no leak (F51k)
    @Test
    fun `playAdhanFile releases mediaPlayer when res raw file not found`() {
        val src = source("AdhanPlayer.kt")
        val notFoundIdx = src.indexOf("NOT FOUND in res/raw")
        assertTrue("NOT FOUND in res/raw log line missing", notFoundIdx >= 0)
        // The release must appear within 200 chars after the log line.
        val window = src.substring(notFoundIdx, minOf(notFoundIdx + 200, src.length))
        assertTrue("mediaPlayer?.release() not found after NOT FOUND log", window.contains("mediaPlayer?.release()"))
        assertTrue("mediaPlayer = null not found after NOT FOUND log", window.contains("mediaPlayer = null"))
    }

    // T7 — PrayerRescheduleService calls calculateAndSave when scheduled == 0 (F51l)
    @Test
    fun `PrayerRescheduleService calls calculateAndSave when no future times found`() {
        val src = source("PrayerRescheduleService.kt")
        // Both the guard condition and the call must appear in the source.
        assertTrue("calculateAndSave not found in PrayerRescheduleService", src.contains("calculateAndSave"))
        assertTrue("scheduled == 0 guard not found", src.contains("scheduled == 0"))
        // They must be close together (within the same if-block).
        val guardIdx = src.indexOf("scheduled == 0")
        val window = src.substring(guardIdx, minOf(guardIdx + 200, src.length))
        assertTrue("calculateAndSave not found near scheduled == 0", window.contains("calculateAndSave"))
    }
}
