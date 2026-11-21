package com.aura.hala

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** T9: Focus Mode service (5998) and reschedule service (2000) text follow the app language. Language only. */
class ServiceNotificationTextTest {

    private fun source(name: String): String {
        val f = File("src/main/kotlin/com/aura/hala/$name")
        assertTrue("source not found: ${f.absolutePath}", f.exists())
        return f.readText().replace("\r\n", "\n")
    }

    @Test
    fun focusModeTitle_followsLanguage() {
        assertEquals("Focus Mode Active", ServiceNotificationText.focusModeTitle(false))
        assertEquals("وضع التركيز نشط", ServiceNotificationText.focusModeTitle(true))
    }

    @Test
    fun rescheduleText_followsLanguage() {
        assertEquals("Rescheduling Prayers", ServiceNotificationText.rescheduleTitle(false))
        assertEquals("جارٍ إعادة جدولة الصلوات", ServiceNotificationText.rescheduleTitle(true))
        assertEquals("Setting up prayer time alarms...", ServiceNotificationText.rescheduleBody(false))
        assertEquals("جارٍ ضبط تنبيهات أوقات الصلاة...", ServiceNotificationText.rescheduleBody(true))
    }

    @Test
    fun services_useTheHelper_andNoEnglishOnlyLeftovers() {
        val focus = source("FocusModeService.kt")
        val resched = source("PrayerRescheduleService.kt")
        assertTrue(focus.contains(".setContentTitle(ServiceNotificationText.focusModeTitle(isArabic))"))
        assertFalse(focus.contains("if (isArabic) \"Focus Mode Active\" else \"Focus Mode Active\""))
        assertTrue(resched.contains("ServiceNotificationText.rescheduleTitle(isArabic)"))
        assertTrue(resched.contains("ServiceNotificationText.rescheduleBody(isArabic)"))
    }

    @Test
    fun idsAndChannels_unchanged() {
        assertEquals(5998, FocusModeService.NOTIFICATION_ID)
        assertEquals("focus_mode_service", FocusModeService.CHANNEL_ID)
        val resched = source("PrayerRescheduleService.kt")
        assertTrue(resched.contains("private const val NOTIFICATION_ID = 2000"))
        assertTrue(resched.contains("private const val CHANNEL_ID = \"prayer_reschedule\""))
    }
}
