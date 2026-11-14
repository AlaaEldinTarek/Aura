package com.aura.hala

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Spec: docs/designs/fix-boot-start-service.md, section 4 (4a and 4b, corrected
 * for permanent vibrate: end time 0). Pure decisions only; the app-start call in
 * MainActivity and the adhan screen are checked on a device.
 */
class SilentModeStateTest {
    private val end = 1_000_000L
    private val grace = SilentModeState.STALE_GRACE_MS

    // --- 4b: clear stale flags on app start ---

    @Test
    fun `inactive flag is never cleared`() {
        assertFalse(SilentModeState.shouldClearStaleSilent(false, end, end + 10 * grace, grace))
    }

    @Test
    fun `window still running is not cleared`() {
        assertFalse(SilentModeState.shouldClearStaleSilent(true, end, end - 1, grace))
    }

    @Test
    fun `window just ended, inside the grace, is not cleared`() {
        assertFalse(SilentModeState.shouldClearStaleSilent(true, end, end + 1, grace))
        assertFalse(SilentModeState.shouldClearStaleSilent(true, end, end + grace - 1, grace))
    }

    @Test
    fun `exactly at the end of the grace is cleared`() {
        assertTrue(SilentModeState.shouldClearStaleSilent(true, end, end + grace, grace))
    }

    @Test
    fun `past the grace is cleared`() {
        assertTrue(SilentModeState.shouldClearStaleSilent(true, end, end + grace + 60_000L, grace))
    }

    @Test
    fun `permanent vibrate (end time 0) is never cleared`() {
        // Keep Vibrate sets the end time to 0 on purpose (ToggleSilentModeReceiver).
        assertFalse(SilentModeState.shouldClearStaleSilent(true, 0L, 5_000_000_000L, grace))
        assertFalse(SilentModeState.shouldClearStaleSilent(true, 0L, 0L, grace))
    }

    @Test
    fun `the default grace is five minutes`() {
        assertEquals(5 * 60 * 1000L, SilentModeState.STALE_GRACE_MS)
        assertTrue(SilentModeState.shouldClearStaleSilent(true, end, end + SilentModeState.STALE_GRACE_MS))
        assertFalse(SilentModeState.shouldClearStaleSilent(true, end, end + SilentModeState.STALE_GRACE_MS - 1))
    }

    // --- 4a: vibration buttons on the adhan screen ---

    @Test
    fun `adhan screen hides the buttons when the flag is off`() {
        assertFalse(SilentModeState.adhanButtonsVisible(false, end, end - 1))
        assertFalse(SilentModeState.adhanButtonsVisible(false, 0L, 0L))
    }

    @Test
    fun `adhan screen shows the buttons in permanent vibrate`() {
        assertTrue(SilentModeState.adhanButtonsVisible(true, 0L, 5_000_000_000L))
    }

    @Test
    fun `adhan screen shows the buttons while the window runs`() {
        assertTrue(SilentModeState.adhanButtonsVisible(true, end, end - 1))
    }

    @Test
    fun `adhan screen hides the buttons once the window is over`() {
        assertFalse(SilentModeState.adhanButtonsVisible(true, end, end))
        assertFalse(SilentModeState.adhanButtonsVisible(true, end, end + 1))
    }

    @Test
    fun `for a timed window the adhan screen follows the notification rule`() {
        val nows = listOf(end - 10, end - 1, end, end + 1, end + 10)
        for (active in listOf(true, false)) {
            for (now in nows) {
                assertEquals(
                    "active=$active now=$now",
                    PrayerForegroundService.vibrationButtonsVisible(active, end, now),
                    SilentModeState.adhanButtonsVisible(active, end, now)
                )
            }
        }
    }
}
