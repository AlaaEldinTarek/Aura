package com.aura.hala

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** T4: Wird / task digest / legacy prayer reminder card rules (docs/designs/fix-themed-notifications.md). */
class NativeReminderCardTest {

    @Test
    fun buttons_onlyWhenAPrayerNameIsAttached() {
        assertFalse(NativeReminderCard.hasButtons(null))
        assertFalse(NativeReminderCard.hasButtons(""))
        assertFalse(NativeReminderCard.hasButtons("  "))
        assertTrue(NativeReminderCard.hasButtons("Fajr"))
    }

    @Test
    fun labels_followLanguage_wordingUnchanged() {
        assertEquals("Mark as Prayed", NativeReminderCard.markPrayedLabel(false))
        assertEquals("أديت الصلاة", NativeReminderCard.markPrayedLabel(true))
        assertEquals("Remind Me Again", NativeReminderCard.remindAgainLabel(false))
        assertEquals("ذكرني مرة أخرى", NativeReminderCard.remindAgainLabel(true))
    }

    @Test
    fun remindAgainBody_arabicUsesArabicNumerals() {
        assertEquals("Prayer in 5 minutes", NativeReminderCard.remindAgainBody(false))
        assertEquals("الصلاة بعد ٥ دقائق", NativeReminderCard.remindAgainBody(true))
    }

    @Test
    fun requestCodes_unchanged() {
        assertEquals(106, NativeReminderCard.tapRequestCode(105))
        assertEquals(107, NativeReminderCard.prayedRequestCode(105))
        assertEquals(108, NativeReminderCard.againRequestCode(105))
        assertEquals(5105, NativeReminderCard.remindAgainNotificationId(105))
    }

    @Test
    fun timeout_isUntilEndOfDay_atLeastOneMinute() {
        assertEquals(3_600_000L, NativeReminderCard.timeoutAfterMs(nowMs = 1_000_000L, endOfDayMs = 4_600_000L))
        assertEquals(60_000L, NativeReminderCard.timeoutAfterMs(nowMs = 5_000_000L, endOfDayMs = 5_010_000L))
    }

    @Test
    fun lockScreen_showsTheFullText() {
        assertEquals(androidx.core.app.NotificationCompat.VISIBILITY_PUBLIC, NativeReminderCard.VISIBILITY)
    }
}
