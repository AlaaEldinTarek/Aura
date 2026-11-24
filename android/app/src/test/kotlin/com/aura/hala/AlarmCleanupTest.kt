package com.aura.hala

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * F70 P2: the logout cleanup's cancel table and the hard rules R1-R3.
 * Spec: docs/designs/fix-f70-logout-alarms.md. JVM only: the PendingIntent calls need a device (device check reads
 * `dumpsys alarm` before and after); these tests pin WHICH (receiver class, action, request code) triples are cancelled.
 */
class AlarmCleanupTest {

    private fun source(name: String): String {
        val f = File("src/main/kotlin/com/aura/hala/$name")
        assertTrue("source not found: ${f.absolutePath}", f.exists())
        return f.readText().replace("\r\n", "\n") // checkout may use CRLF
    }

    private data class Row(val receiver: String, val action: String?, val code: Int, val service: Boolean = false)

    private fun actual(): List<Row> = AlarmCleanup.specs().map {
        Row(it.receiver.simpleName, it.action, it.requestCode, it.kind == CancelKind.SERVICE)
    }

    private fun range(receiver: String, action: String?, codes: IntRange) = codes.map { Row(receiver, action, it) }

    /** Every pair the ARMING code uses, written out by hand from the arming call sites (the inventory of the spec). */
    private fun expected(): List<Row> =
        // A1 adhan 1001-1006, A5 delayed reminder 2001-2006, A2 reminder 2101-2106, A3 post-check 3001-3006
        range("PrayerAlarmReceiver", null, 1001..1006) +
            range("PrayerAlarmReceiver", null, 2001..2006) +
            range("PrayerAlarmReceiver", null, 2101..2106) +
            range("PrayerAlarmReceiver", null, 3001..3006) +
            // A4 azkar 3001-3006 (same codes as the post-check, other class AND action)
            range("AzkarAlarmReceiver", "com.aura.hala.AZKAR_ALARM", 3001..3006) +
            // A6 daily recalc, A8 prayer summary, A9 Jumu'ah
            listOf(Row("DailyRecalcReceiver", "com.aura.hala.DAILY_RECALC", 9100)) +
            listOf(Row("DailySummaryReceiver", "com.aura.hala.DAILY_PRAYER_SUMMARY", 7001)) +
            listOf(Row("JumuahReminderReceiver", null, 8001)) +
            // C1/C3 task reminders (also the snooze re-arm: same id), C2 due-now (id + 4, ACTION_DUE_NOW)
            range("TaskReminderReceiver", null, 4000..4999) +
            range("TaskReminderReceiver", "com.aura.hala.TASK_DUE_NOW", 4004..5003) +
            // C4 3999, C5 4001, C6 5100-5119, prayer notifications 1-6 / 5001-5006, C7 "remind again" = id + 5000
            nativeNotificationCodes().map { Row("NativeNotificationReceiver", null, it) } +
            // C9 focus alarms 5000 + abs(hash % 1000)
            range("FocusModeReceiver", "com.aura.hala.FOCUS_MODE_ALARM", 5000..5999) +
            // B1 service restart alarm (PendingIntent.getService, request code 1)
            listOf(Row("PrayerForegroundService", null, 1, service = true))

    private fun nativeNotificationCodes(): List<Int> {
        val base = (1..6).toList() + listOf(3999, 4001) + (5001..5006).toList() + (5100..5119).toList()
        return (base + base.map { it + 5000 }).distinct()
    }

    // ── Completeness and exactness (R3) ──────────────────────────────────────

    @Test
    fun table_isExactlyTheInventory() {
        assertEquals(expected().toSet(), actual().toSet())
    }

    @Test
    fun table_hasNoDuplicates() {
        val a = actual()
        assertEquals(a.size, a.toSet().size)
    }

    @Test
    fun codesSharedByTwoReceivers_areCancelledPerReceiver() {
        // 3001-3006: post-check (PrayerAlarmReceiver, no action) AND azkar (AzkarAlarmReceiver + action)
        for (code in 3001..3006) {
            val rows = actual().filter { it.code == code }
            assertTrue(rows.contains(Row("PrayerAlarmReceiver", null, code)))
            assertTrue(rows.contains(Row("AzkarAlarmReceiver", "com.aura.hala.AZKAR_ALARM", code)))
        }
        // 4001: task reminder AND daily digest (NativeNotificationReceiver)
        assertTrue(actual().contains(Row("TaskReminderReceiver", null, 4001)))
        assertTrue(actual().contains(Row("NativeNotificationReceiver", null, 4001)))
    }

    @Test
    fun everySpecKeepsItsReceiversArmingAction() {
        // an action that differs from the arming one matches nothing (PendingIntent identity = class + action + code)
        for (s in AlarmCleanup.specs()) {
            when (s.receiver.simpleName) {
                "AzkarAlarmReceiver" -> assertEquals("com.aura.hala.AZKAR_ALARM", s.action)
                "DailyRecalcReceiver" -> assertEquals("com.aura.hala.DAILY_RECALC", s.action)
                "DailySummaryReceiver" -> assertEquals("com.aura.hala.DAILY_PRAYER_SUMMARY", s.action)
                "FocusModeReceiver" -> assertEquals("com.aura.hala.FOCUS_MODE_ALARM", s.action)
                "PrayerAlarmReceiver", "JumuahReminderReceiver", "NativeNotificationReceiver", "PrayerForegroundService" ->
                    assertEquals(null, s.action)
                "TaskReminderReceiver" -> assertTrue(s.action == null || s.action == "com.aura.hala.TASK_DUE_NOW")
                else -> throw AssertionError("unexpected receiver ${s.receiver.simpleName}")
            }
        }
    }

    // ── R1: silent-mode restore is never touched ─────────────────────────────

    @Test
    fun r1_noSpecTargetsASilentModeReceiver() {
        val names = AlarmCleanup.specs().map { it.receiver.simpleName }
        assertFalse(names.contains("SilentOffReceiver"))
        assertFalse(names.contains("ToggleSilentModeReceiver"))
    }

    @Test
    fun r1_cleanupSourceNeverMentionsSilentMode() {
        val s = source("AlarmCleanup.kt")
        assertFalse(s.contains("Silent"))
        assertFalse(s.contains("silent"))
        assertFalse(s.contains("SILENT"))
    }

    // ── R2: 3999 means two things, each cancelled only by its owner ──────────

    @Test
    fun r2_3999IsOnlyTheDailySummaryOfTheNativeNotificationReceiver() {
        val rows = actual().filter { it.code == 3999 }
        assertEquals(listOf(Row("NativeNotificationReceiver", null, 3999)), rows)
    }

    @Test
    fun r2_noLiteral3999InTheCleanup() {
        // the daily summary id comes from the receiver's own table, never a generic "cancel PendingIntent 3999"
        assertFalse(source("AlarmCleanup.kt").contains("3999"))
    }

    // ── R3: lookups never create a PendingIntent ─────────────────────────────

    @Test
    fun r3_cleanupUsesNoCreateAndNeverUpdateCurrent() {
        val s = source("AlarmCleanup.kt")
        assertTrue(s.contains("FLAG_NO_CREATE"))
        assertFalse(s.contains("FLAG_UPDATE_CURRENT"))
        assertFalse(s.contains("FLAG_ONE_SHOT"))
    }

    @Test
    fun r3_theServiceRestartSpecMatchesTheArmingCode() {
        // PrayerForegroundService arms its restart with getService(request code 1, no action)
        val s = source("PrayerForegroundService.kt")
        assertTrue(s.contains("PendingIntent.getService(\n            applicationContext, REQ_RESTART, restartIntent"))
        assertTrue(s.contains("private const val REQ_RESTART = 1"))
    }

    // ── What the cleanup does besides alarms ─────────────────────────────────

    @Test
    fun cleanupStopsReArmersAndTheService() {
        val s = source("AlarmCleanup.kt")
        assertTrue(s.contains("PrayerRecalcWorker.cancel"))
        assertTrue(s.contains("PrayerForegroundService.stopService"))
        assertTrue("posted Aura notifications are removed", s.contains("cancelAll()"))
    }

    @Test
    fun cleanupNeverDeletesChannels() {
        assertFalse(source("AlarmCleanup.kt").contains("deleteNotificationChannel"))
    }

    @Test
    fun eachStepHasItsOwnTryCatch() {
        // one failing step must not stop the others (spec: Behavior)
        val s = source("AlarmCleanup.kt")
        assertTrue(s.contains("private inline fun step("))
        assertTrue(s.split("step(\"").size - 1 >= 4)
    }

    // ── Channel contract ─────────────────────────────────────────────────────

    @Test
    fun channelMethod_isRegisteredWithTryCatch() {
        val s = source("MainActivity.kt")
        val at = s.indexOf("\"cancelAllAppAlarms\" ->")
        assertTrue(at > 0)
        val block = s.substring(at, at + 900)
        assertTrue(block.contains("AlarmCleanup.cancelAll"))
        assertTrue(block.contains("catch"))
        assertTrue(block.contains("result.success"))
    }

    @Test
    fun channelMethod_isInTheContract() {
        val f = File("../../.project-docs/contracts/method-channels.md")
        assertTrue("contract not found: ${f.absolutePath}", f.exists())
        assertTrue(f.readText().contains("cancelAllAppAlarms"))
    }

    @Test
    fun noNotificationIdOrChannelChanged_guard() {
        // the ids the cleanup relies on stay as the contract lists them
        assertEquals(1001, PrayerAlarmReceiver.getNotificationId("Fajr"))
        assertEquals(1006, PrayerAlarmReceiver.getNotificationId("Isha"))
        assertEquals(1003, PrayerAlarmReceiver.getNotificationId("Zuhr"))
        assertEquals(1003, PrayerAlarmReceiver.getNotificationId("Dhuhr"))
        assertEquals(6001, PrayerAlarmReceiver.getPostCheckNotificationId("Fajr"))
        assertEquals(3001, AzkarAlarmReceiver.getAzkarRequestCode("Fajr"))
        assertEquals(3006, AzkarAlarmReceiver.getAzkarRequestCode("Isha"))
        assertEquals(2101, ReminderLogic.requestCode(1001))
        assertEquals(2106, ReminderLogic.requestCode(1006))
        assertEquals(4004, TaskReminderCard.dueNowRequestCode(4000))
        assertEquals(10100, NativeReminderCard.remindAgainNotificationId(5100))
    }
}
