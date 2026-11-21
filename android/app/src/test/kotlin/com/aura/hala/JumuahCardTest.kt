package com.aura.hala

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** T7: Jumu'ah reminder card rules (docs/designs/fix-themed-notifications.md, TC3 plan). */
class JumuahCardTest {

    @Test
    fun text_followsLanguage() {
        assertEquals("Jumu'ah Mubarak 🕌", JumuahCard.title(false))
        assertEquals("جمعة مباركة 🕌", JumuahCard.title(true))
        assertEquals("Friday prayer time is approaching. Don't miss it!", JumuahCard.fallbackBody(false))
        assertEquals("اقترب وقت صلاة الجمعة، لا تفوّتها", JumuahCard.fallbackBody(true))
        assertEquals("Jumu'ah in %s", JumuahCard.countdownFormat(false))
        assertEquals("الجمعة بعد %s", JumuahCard.countdownFormat(true))
    }

    @Test
    fun countdown_onlyWhenZuhrIsKnownAndComingWithinTheWindow() {
        val now = 1_000_000_000L
        val min = 60_000L
        assertTrue(JumuahCard.countdownAvailable(now + 30 * min, now))
        assertTrue(JumuahCard.countdownAvailable(now + 90 * min, now))
        // unknown (0), already past, or implausibly far (stale time from another day): no countdown
        assertFalse(JumuahCard.countdownAvailable(0L, now))
        assertFalse(JumuahCard.countdownAvailable(now - 1, now))
        assertFalse(JumuahCard.countdownAvailable(now, now))
        assertFalse(JumuahCard.countdownAvailable(now + 91 * min, now))
    }

    @Test
    fun countdownBase_isElapsedPlusRemaining() {
        assertEquals(5_000L + 30 * 60_000L, JumuahCard.countdownBase(1_000_000L + 30 * 60_000L, 1_000_000L, 5_000L))
    }

    @Test
    fun timeout_removesTheCardAtZuhr_orAfterHalfAnHourWithoutACountdown() {
        val now = 1_000_000_000L
        val min = 60_000L
        assertEquals(30 * min, JumuahCard.timeoutAfterMs(now + 30 * min, now, true))
        assertEquals(1_000L, JumuahCard.timeoutAfterMs(now + 100, now, true))
        assertEquals(30 * min, JumuahCard.timeoutAfterMs(0L, now, false))
    }

    @Test
    fun modeFor_countdownOrText() {
        assertEquals(JumuahCard.Mode.COUNTDOWN, JumuahCard.modeFor(true))
        assertEquals(JumuahCard.Mode.TEXT, JumuahCard.modeFor(false))
    }

    @Test
    fun testZuhr_isHalfAnHourAhead_soTheDevTileShowsThirtyMinutes() {
        assertEquals(1_000_000L + 30 * 60_000L, JumuahCard.testZuhrMs(1_000_000L))
    }

    @Test
    fun idsAndCodes_unchanged() {
        assertEquals(8001, JumuahCard.NOTIFICATION_ID)
        assertEquals("jumuah_reminder", JumuahCard.CHANNEL_ID)
        assertEquals(androidx.core.app.NotificationCompat.VISIBILITY_PUBLIC, JumuahCard.VISIBILITY)
    }
}
