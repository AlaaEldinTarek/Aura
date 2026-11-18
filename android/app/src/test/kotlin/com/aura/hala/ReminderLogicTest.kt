package com.aura.hala

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ReminderLogicTest {

    @Test
    fun normalize_keeps_offered_values() {
        for (v in listOf(5, 10, 15, 30)) assertEquals(v, ReminderLogic.normalizeMinutes(v))
    }

    @Test
    fun normalize_maps_zero_negative_and_unlisted_to_ten() {
        for (v in listOf(0, -5, 7, 45, 1000)) assertEquals(10, ReminderLogic.normalizeMinutes(v))
    }

    @Test
    fun trigger_time_is_prayer_minus_minutes() {
        val prayer = 10_000_000L
        assertEquals(prayer - 15 * 60_000L, ReminderLogic.triggerTime(prayer, 15, 0L))
    }

    @Test
    fun trigger_time_uses_ten_for_bad_minutes() {
        val prayer = 10_000_000L
        assertEquals(prayer - 10 * 60_000L, ReminderLogic.triggerTime(prayer, 0, 0L))
    }

    @Test
    fun trigger_time_is_null_when_already_past() {
        val prayer = 10_000_000L
        assertNull(ReminderLogic.triggerTime(prayer, 10, prayer - 5 * 60_000L))
        assertNull(ReminderLogic.triggerTime(prayer, 10, prayer))
    }

    @Test
    fun arm_only_if_master_on_and_not_sunrise() {
        assertTrue(ReminderLogic.shouldArm(masterOn = true, prayerName = "Zuhr"))
        assertFalse(ReminderLogic.shouldArm(masterOn = false, prayerName = "Zuhr"))
        assertFalse(ReminderLogic.shouldArm(masterOn = true, prayerName = "Sunrise"))
    }

    @Test
    fun clear_reminder_matches_prayer_with_zuhr_alias() {
        assertTrue(ReminderLogic.shouldClear("Asr", "Asr"))
        assertTrue(ReminderLogic.shouldClear("Zuhr", "Dhuhr"))
        assertTrue(ReminderLogic.shouldClear("Dhuhr", "Zuhr"))
        assertFalse(ReminderLogic.shouldClear("Asr", "Maghrib"))
        assertFalse(ReminderLogic.shouldClear(null, "Asr"))
    }

    @Test
    fun request_code_is_adhan_code_plus_1100() {
        assertEquals(2103, ReminderLogic.requestCode(1003))
        assertEquals(2101, ReminderLogic.requestCode(1001))
        assertEquals(2106, ReminderLogic.requestCode(1006))
    }

    @Test
    fun titles() {
        assertEquals("Prayer reminder", ReminderLogic.title(false))
        assertEquals("تذكير بالصلاة", ReminderLogic.title(true))
    }

    @Test
    fun english_body() {
        assertEquals("Zuhr in 10 minutes", ReminderLogic.body("Zuhr", "الظهر", 10, false))
    }

    @Test
    fun arabic_body_uses_eastern_numerals_and_unit_by_n() {
        assertEquals("أذان العصر بعد ٥ دقائق", ReminderLogic.body("Asr", "العصر", 5, true))
        assertEquals("أذان العصر بعد ١٠ دقائق", ReminderLogic.body("Asr", "العصر", 10, true))
        assertEquals("أذان العصر بعد ١٥ دقيقة", ReminderLogic.body("Asr", "العصر", 15, true))
        assertEquals("أذان العصر بعد ٣٠ دقيقة", ReminderLogic.body("Asr", "العصر", 30, true))
    }

    @Test
    fun bad_n_falls_back_to_ten_in_text() {
        assertEquals("Zuhr in 10 minutes", ReminderLogic.body("Zuhr", "الظهر", 0, false))
    }
}
