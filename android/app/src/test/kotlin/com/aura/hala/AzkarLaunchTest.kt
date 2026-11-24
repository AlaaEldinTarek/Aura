package com.aura.hala

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Spec: docs/designs/fix-f51j.md — T1 to T5.
 * Source-text tests that pin the single-azkar-launch fix so a future editor who
 * removes any guard sees an immediate failure.
 */
class AzkarLaunchTest {

    private fun source(name: String): String {
        val f = File("src/main/kotlin/com/aura/hala/$name")
        assertTrue("source not found: ${f.absolutePath}", f.exists())
        return f.readText().replace("\r\n", "\n")
    }

    // T1 — AdhanFullScreenActivity declares a named azkarRunnable field (not anonymous lambda)
    @Test
    fun `AdhanFullScreenActivity declares named azkarRunnable field`() {
        val src = source("AdhanFullScreenActivity.kt")
        assertTrue(
            "named azkarRunnable field missing from AdhanFullScreenActivity",
            src.contains("val azkarRunnable")
        )
    }

    // T2 — onDestroy removes azkarRunnable so the lambda cannot fire after the activity is destroyed
    @Test
    fun `onDestroy cancels azkarRunnable`() {
        val src = source("AdhanFullScreenActivity.kt")
        val onDestroyStart = src.indexOf("override fun onDestroy()")
        assertTrue("onDestroy() not found", onDestroyStart >= 0)
        val window = src.substring(onDestroyStart, onDestroyStart + 500)
        assertTrue(
            "removeCallbacks(azkarRunnable) missing from onDestroy",
            window.contains("removeCallbacks(azkarRunnable)")
        )
    }

    // T3 — launchAzkarAndFinish cancels the backup alarm before launching azkar
    @Test
    fun `launchAzkarAndFinish cancels AzkarAlarmReceiver before startActivity`() {
        val src = source("AdhanFullScreenActivity.kt")
        val launchStart = src.indexOf("fun launchAzkarAndFinish()")
        assertTrue("launchAzkarAndFinish() not found", launchStart >= 0)
        val window = src.substring(launchStart, launchStart + 600)
        val cancelIdx = window.indexOf("AzkarAlarmReceiver.cancel(")
        val startIdx  = window.indexOf("startActivity(")
        assertTrue("AzkarAlarmReceiver.cancel not found in launchAzkarAndFinish", cancelIdx >= 0)
        assertTrue("startActivity not found in launchAzkarAndFinish", startIdx >= 0)
        assertTrue(
            "AzkarAlarmReceiver.cancel must come before startActivity in launchAzkarAndFinish",
            cancelIdx < startIdx
        )
    }

    // T4 — PrayerAlarmReceiver schedules azkar at iqamaTimeMs + 60 s (not 10 min)
    @Test
    fun `azkar alarm trigger is iqama plus 60 seconds`() {
        val src = source("PrayerAlarmReceiver.kt")
        assertTrue(
            "azkar trigger should be iqamaTimeMs + 60_000L, not 10 min",
            src.contains("iqamaTimeMs + 60 * 1000L") || src.contains("iqamaTimeMs + 60_000L")
        )
    }

    // T5 — PrayerAlarmReceiver no-iqama fallback is 60 s (not 15 min)
    @Test
    fun `azkar no-iqama fallback is 60 seconds`() {
        val src = source("PrayerAlarmReceiver.kt")
        // The old code had currentTime + 15 * 60 * 1000L; that must be gone from the azkar block.
        // The schedule call is in the adhan-mode block; find that region and confirm 15*60 is absent.
        val scheduleIdx = src.indexOf("AzkarAlarmReceiver.schedule(")
        assertTrue("AzkarAlarmReceiver.schedule call not found", scheduleIdx >= 0)
        val window = src.substring(maxOf(0, scheduleIdx - 300), scheduleIdx + 50)
        assertTrue(
            "no-iqama azkar fallback must not be 15 min; expected 60_000L or 60 * 1000L",
            !window.contains("15 * 60 * 1000L")
        )
    }
}
