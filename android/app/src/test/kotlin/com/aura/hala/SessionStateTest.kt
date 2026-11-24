package com.aura.hala

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** F70 P2: the session gate (D1-C, fail-open). Spec: docs/designs/fix-f70-logout-alarms.md. */
class SessionStateTest {

    private fun source(name: String): String {
        val f = File("src/main/kotlin/com/aura/hala/$name")
        assertTrue("source not found: ${f.absolutePath}", f.exists())
        return f.readText().replace("\r\n", "\n") // checkout may use CRLF
    }

    // ── Pure decision: shouldArm(isGuest, hasUser) ───────────────────────────

    @Test
    fun signedIn_isActive() = assertTrue(SessionState.shouldArm(isGuest = false, hasUser = true))

    @Test
    fun guest_isActive() = assertTrue(SessionState.shouldArm(isGuest = true, hasUser = false))

    @Test
    fun guestWithStaleUser_isActive() = assertTrue(SessionState.shouldArm(isGuest = true, hasUser = true))

    @Test
    fun signedOutNoGuest_isClosed() = assertFalse(SessionState.shouldArm(isGuest = false, hasUser = false))

    @Test
    fun unknownUserRead_failsOpen() {
        // The Firebase read threw or the SDK was not ready: arm (an unknown read must never switch a real user's alarms off)
        assertTrue(SessionState.shouldArm(isGuest = false, hasUser = null))
    }

    @Test
    fun unknownUserRead_guestStillActive() = assertTrue(SessionState.shouldArm(isGuest = true, hasUser = null))

    @Test
    fun readsTheExistingGuestPref_notANewKey() {
        val s = source("SessionState.kt")
        assertTrue(s.contains("\"is_guest\""))
        assertTrue("must read through FlutterPrefs", s.contains("FlutterPrefs.getBoolean"))
        assertFalse("no new pref key for D1-C", s.contains("alarms_suspended"))
        assertFalse(s.contains("_preferences"))
    }

    @Test
    fun logsTheGateDecision_forTheDeviceCheck() {
        val s = source("SessionState.kt")
        assertTrue(s.contains("currentUserNull="))
        assertTrue(s.contains("isGuest="))
    }

    // ── The four re-armers consult the gate BEFORE they schedule anything ────

    private fun assertGateBefore(file: String, gateMarker: String, scheduleMarker: String) {
        val s = source(file)
        val gate = s.indexOf(gateMarker)
        val sched = s.indexOf(scheduleMarker)
        assertTrue("$file: gate '$gateMarker' missing", gate >= 0)
        assertTrue("$file: '$scheduleMarker' missing", sched >= 0)
        assertTrue("$file: gate must come before '$scheduleMarker'", gate < sched)
    }

    @Test
    fun calculateAndSave_returnsBeforeAnySchedule() {
        val s = source("NativePrayerCalculator.kt")
        val body = s.substring(s.indexOf("fun calculateAndSave"))
        val gate = body.indexOf("SessionState.isSessionActive")
        assertTrue(gate >= 0)
        assertTrue(gate < body.indexOf("reschedule(context, times)"))
        assertTrue(gate < body.indexOf("prefs.edit()"))
    }

    @Test
    fun bootBlock_skipsTheReArmWhenClosed() {
        val s = source("PrayerBootReceiver.kt")
        val gate = s.indexOf("SessionState.isSessionActive")
        assertTrue(gate >= 0)
        assertTrue(gate < s.indexOf("reschedulePrayerAlarms(context)\n"))
        assertTrue(gate < s.indexOf("DailyRecalcReceiver.schedule(context)"))
        assertTrue(gate < s.indexOf("PrayerRecalcWorker.schedule(context)"))
        // the stale ringer restore stays outside the gate: logout must never leave the phone on vibrate
        assertTrue(s.indexOf("Restored ringer mode") < gate)
    }

    @Test
    fun startServiceIfAllowed_isGated() =
        assertGateBefore("PrayerForegroundService.kt", "SessionState.isSessionActive", "startService(context)\n            return true")

    @Test
    fun restartAlarm_isGated() {
        val s = source("PrayerForegroundService.kt")
        val fn = s.substring(s.indexOf("private fun shouldAutoRestart"))
        val end = fn.indexOf("isAutoStartAllowed(settingEnabled, userStopped)")
        assertTrue(fn.substring(0, end).contains("SessionState.isSessionActive"))
    }

    @Test
    fun stickyRecreation_isGated() {
        val s = source("PrayerForegroundService.kt")
        val fn = s.substring(s.indexOf("override fun onStartCommand"), s.indexOf("override fun onBind"))
        assertTrue(fn.contains("SessionState.isSessionActive"))
    }

    @Test
    fun dailyRecalc_scheduleAndFire_areGated() {
        val s = source("DailyRecalcReceiver.kt")
        val schedule = s.substring(s.indexOf("fun schedule(context"), s.indexOf("override fun onReceive"))
        assertTrue(schedule.contains("SessionState.isSessionActive"))
        assertTrue(schedule.indexOf("SessionState.isSessionActive") < schedule.indexOf("setExactAndAllowWhileIdle"))
        val fire = s.substring(s.indexOf("override fun onReceive"))
        assertTrue(fire.indexOf("SessionState.isSessionActive") < fire.indexOf("calculateAndSave"))
    }

    @Test
    fun periodicWorker_doWorkIsGated() =
        assertGateBefore("PrayerRecalcWorker.kt", "SessionState.isSessionActive", "calculateAndSave")
}
