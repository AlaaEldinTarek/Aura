package com.aura.hala

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Spec: docs/designs/fix-themed-notifications.md (T0). Pure rules only (the project has no Robolectric):
 * the theme rule and the 4-layout pick shared by every themed notification.
 */
class ThemedNotificationTest {
    @Test
    fun `dark and amoled are dark, light is light, system follows the phone`() {
        assertEquals(true, ThemedNotification.isDark("dark", false))
        assertEquals(true, ThemedNotification.isDark("amoled", false))
        assertEquals(false, ThemedNotification.isDark("light", true))
        assertEquals(true, ThemedNotification.isDark("system", true))
        assertEquals(false, ThemedNotification.isDark("system", false))
        assertEquals(false, ThemedNotification.isDark("unknown-value", false))
    }

    @Test
    fun `layout pick maps the four theme and language combinations to four different layouts`() {
        val picks = listOf(
            ThemedNotification.pickLayout(false, false, 1, 2, 3, 4),
            ThemedNotification.pickLayout(true, false, 1, 2, 3, 4),
            ThemedNotification.pickLayout(false, true, 1, 2, 3, 4),
            ThemedNotification.pickLayout(true, true, 1, 2, 3, 4)
        )
        assertEquals(listOf(1, 2, 3, 4), picks) // light LTR, dark LTR, light RTL, dark RTL
    }

    @Test
    fun `the post check theme rule is the shared rule`() {
        for (mode in listOf("dark", "amoled", "light", "system", "x")) {
            for (night in listOf(true, false)) {
                assertEquals(ThemedNotification.isDark(mode, night), PostCheckActions.isDark(mode, night))
            }
        }
    }
}
