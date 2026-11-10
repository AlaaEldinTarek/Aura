package com.aura.hala

import org.junit.Assert.*
import org.junit.Test

class ForegroundAutoStartTest {
    @Test
    fun `enabled and not stopped allows start`() {
        assertTrue(PrayerForegroundService.isAutoStartAllowed(settingEnabled = true, userStopped = false))
    }

    @Test
    fun `disabled setting blocks start`() {
        assertFalse(PrayerForegroundService.isAutoStartAllowed(settingEnabled = false, userStopped = false))
    }

    @Test
    fun `user stopped blocks start`() {
        assertFalse(PrayerForegroundService.isAutoStartAllowed(settingEnabled = true, userStopped = true))
    }

    @Test
    fun `disabled and stopped blocks start`() {
        assertFalse(PrayerForegroundService.isAutoStartAllowed(settingEnabled = false, userStopped = true))
    }
}
