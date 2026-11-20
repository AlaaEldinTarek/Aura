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
    fun publicTitle_isGenericAndFollowsLanguage() {
        assertEquals("Aura - Daily Prayer Reminder", DailySummaryCard.publicTitle(false))
        assertEquals("هالة - تذكير الصلاة اليومي", DailySummaryCard.publicTitle(true))
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
}
