package com.aura.hala

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** T3: daily prayer summary card text rules (docs/designs/fix-themed-notifications.md). */
class DailySummaryCardTest {

    @Test
    fun title_followsLanguage() {
        assertEquals("Daily Prayer Reminder", DailySummaryCard.title(false))
        assertEquals("تذكير الصلاة اليومي", DailySummaryCard.title(true))
    }

    @Test
    fun lockScreen_showsTheFullTextNotAGenericVersion() {
        assertEquals(androidx.core.app.NotificationCompat.VISIBILITY_PUBLIC, DailySummaryCard.VISIBILITY)
    }

    @Test
    fun body_english_singularAndPlural() {
        assertEquals("You have 1 untracked prayer today", DailySummaryCard.body(1, false))
        assertEquals("You have 3 untracked prayers today", DailySummaryCard.body(3, false))
        assertEquals("You have 5 untracked prayers today", DailySummaryCard.body(5, false))
    }

    @Test
    fun body_arabic_usesArabicNumerals() {
        assertEquals("لديك ١ صلاة لم تُسجَّل اليوم", DailySummaryCard.body(1, true))
        assertEquals("لديك ٣ صلوات لم تُسجَّل اليوم", DailySummaryCard.body(3, true))
        assertEquals("لديك ٥ صلوات لم تُسجَّل اليوم", DailySummaryCard.body(5, true))
    }

    @Test
    fun body_arabic_hasNoLatinDigits() {
        for (n in 1..5) {
            assertFalse(DailySummaryCard.body(n, true).any { it in '0'..'9' })
        }
    }

    @Test
    fun body_english_keepsLatinDigits() {
        assertTrue(DailySummaryCard.body(4, false).contains("4"))
    }

    @Test
    fun requestCodes_matchTheOldIds() {
        assertEquals(7001, DailySummaryCard.NOTIFICATION_ID)
        assertEquals(7001, DailySummaryCard.tapRequestCode())
    }

    private val all = listOf("Fajr", "Zuhr", "Asr", "Maghrib", "Isha")

    @Test
    fun untrackedNames_dropsTheTrackedOnes() {
        assertEquals(all, DailySummaryCard.untrackedNames(all) { false })
        assertEquals(listOf("Fajr", "Isha"), DailySummaryCard.untrackedNames(all) { it in setOf("Zuhr", "Asr", "Maghrib") })
        assertEquals(emptyList<String>(), DailySummaryCard.untrackedNames(all) { true })
    }

    // F51c: not-yet-due predicate (simulates the new lambda in DailySummaryReceiver.onReceive)
    private fun isTrackedF51c(name: String, prayerMs: Long, hasStatusKey: Boolean, now: Long, today: String): Boolean {
        val notYetDue = prayerMs > 0L && prayerMs > now &&
            DailySummaryReceiver.dateKey(java.util.Calendar.getInstance().apply { timeInMillis = prayerMs }) == today
        return notYetDue || hasStatusKey
    }

    @Test
    fun f51c_futureToday_excludedFromUntracked() {
        val now = 1_732_452_000_000L  // arbitrary "now"
        val today = DailySummaryReceiver.dateKey(java.util.Calendar.getInstance().apply { timeInMillis = now })
        val prayerMs = now + 2 * 60 * 60 * 1000L  // 2 hours in the future, same day
        val result = DailySummaryCard.untrackedNames(listOf("Isha")) {
            isTrackedF51c(it, prayerMs, hasStatusKey = false, now = now, today = today)
        }
        assertEquals(emptyList<String>(), result)
    }

    @Test
    fun f51c_pastToday_untracked_included() {
        val now = 1_732_452_000_000L
        val today = DailySummaryReceiver.dateKey(java.util.Calendar.getInstance().apply { timeInMillis = now })
        val prayerMs = now - 60 * 60 * 1000L  // 1 hour in the past, same day
        val result = DailySummaryCard.untrackedNames(listOf("Fajr")) {
            isTrackedF51c(it, prayerMs, hasStatusKey = false, now = now, today = today)
        }
        assertEquals(listOf("Fajr"), result)
    }

    @Test
    fun f51c_stalePrayerMs_treatedAsPast_untracked_included() {
        val now = 1_732_452_000_000L
        val today = DailySummaryReceiver.dateKey(java.util.Calendar.getInstance().apply { timeInMillis = now })
        // yesterday's epoch — prayerMs > now is false (yesterday's time is in the past), so notYetDue = false
        val yesterdayMs = now - 25 * 60 * 60 * 1000L
        val result = DailySummaryCard.untrackedNames(listOf("Isha")) {
            isTrackedF51c(it, yesterdayMs, hasStatusKey = false, now = now, today = today)
        }
        assertEquals(listOf("Isha"), result)
    }

    @Test
    fun f51c_zeroOrMissingTime_treatedAsPast_untracked_included() {
        val now = 1_732_452_000_000L
        val today = DailySummaryReceiver.dateKey(java.util.Calendar.getInstance().apply { timeInMillis = now })
        val result = DailySummaryCard.untrackedNames(listOf("Maghrib")) {
            isTrackedF51c(it, prayerMs = 0L, hasStatusKey = false, now = now, today = today)
        }
        assertEquals(listOf("Maghrib"), result)
    }

    @Test
    fun timeout_isUntilEndOfDay_atLeastOneMinute() {
        assertEquals(3_600_000L, DailySummaryCard.timeoutAfterMs(nowMs = 1_000_000L, endOfDayMs = 4_600_000L))
        assertEquals(60_000L, DailySummaryCard.timeoutAfterMs(nowMs = 5_000_000L, endOfDayMs = 5_010_000L))
        assertEquals(60_000L, DailySummaryCard.timeoutAfterMs(nowMs = 5_000_000L, endOfDayMs = 1_000L))
    }
}
