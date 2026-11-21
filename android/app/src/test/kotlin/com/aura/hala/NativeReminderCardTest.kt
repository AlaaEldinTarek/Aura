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

    // --- Text built here from a kind and numbers (follows the app language live) ---

    @Test
    fun wird_titleAndBody_bothLanguages() {
        assertEquals("Wird Reminder", NativeReminderCard.titleFor("wird", "x", false))
        assertEquals("تذكير الورد", NativeReminderCard.titleFor("wird", "x", true))
        assertEquals("Read your daily Wird — 5 pages today", NativeReminderCard.bodyFor("wird", 5, 0, "x", false))
        assertEquals("اقرأ وردك اليومي — ٥ صفحة اليوم", NativeReminderCard.bodyFor("wird", 5, 0, "x", true))
    }

    @Test
    fun digest_bodyCases_bothLanguages() {
        assertEquals("Today's Tasks", NativeReminderCard.titleFor("digest", "x", false))
        assertEquals("ملخص مهامك اليوم", NativeReminderCard.titleFor("digest", "x", true))
        assertEquals("3 tasks today · 2 overdue", NativeReminderCard.bodyFor("digest", 3, 2, "x", false))
        assertEquals("٣ مهمة اليوم · ٢ متأخرة", NativeReminderCard.bodyFor("digest", 3, 2, "x", true))
        assertEquals("You have 4 tasks today — let's go!", NativeReminderCard.bodyFor("digest", 4, 0, "x", false))
        assertEquals("لديك ٤ مهمة اليوم — ابدأ يومك!", NativeReminderCard.bodyFor("digest", 4, 0, "x", true))
        assertEquals("Clean day! No tasks due today 🎉", NativeReminderCard.bodyFor("digest", 0, 0, "x", false))
        assertEquals("يوم نظيف! لا مهام اليوم 🎉", NativeReminderCard.bodyFor("digest", 0, 0, "x", true))
    }

    @Test
    fun arabicBodies_haveNoLatinDigits() {
        for (n in listOf(0, 1, 7, 12)) {
            assertFalse(NativeReminderCard.bodyFor("wird", n, 0, "x", true).any { it in '0'..'9' })
            assertFalse(NativeReminderCard.bodyFor("digest", n, n, "x", true).any { it in '0'..'9' })
        }
    }

    @Test
    fun unknownOrMissingKind_keepsTheTextDartSent_oldAlarmsStillWork() {
        assertEquals("Old title", NativeReminderCard.titleFor(null, "Old title", true))
        assertEquals("Old body", NativeReminderCard.bodyFor(null, 0, 0, "Old body", true))
        assertEquals("Old body", NativeReminderCard.bodyFor("", 0, 0, "Old body", false))
        assertEquals("Old body", NativeReminderCard.bodyFor("other", 1, 1, "Old body", false))
    }
}
