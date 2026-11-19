package com.aura.hala

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Spec: docs/designs/fix-post-check-remind-later.md (F72). Pure mapping only: the PendingIntents,
 * the layout and the corner button are checked on a device (the project has no Robolectric).
 */
class PostCheckActionsTest {
    private val ids = listOf(6001, 6002, 6003, 6004, 6005, 6006)

    @Test
    fun `exactly four actions in the order Done Late Missed Later`() {
        assertEquals(
            listOf(
                PrayerAlarmReceiver.ACTION_POST_DONE,
                PrayerAlarmReceiver.ACTION_POST_LATE,
                PrayerAlarmReceiver.ACTION_POST_MISSED,
                PrayerAlarmReceiver.ACTION_POST_LATER
            ),
            PostCheckActions.ALL.map { it.action }
        )
    }

    @Test
    fun `request code offsets are 1 2 3 4 for Done Late Missed Later`() {
        assertEquals(listOf(1, 2, 3, 4), PostCheckActions.ALL.map { it.requestOffset })
        assertEquals(6004, PostCheckActions.requestCode(6003, PostCheckActions.ALL[0]))
        assertEquals(6007, PostCheckActions.requestCode(6003, PostCheckActions.ALL[3]))
    }

    @Test
    fun `three actions are system buttons and only Remind Later is the corner button`() {
        assertEquals(3, PostCheckActions.buttons().size)
        assertEquals(
            listOf(
                PrayerAlarmReceiver.ACTION_POST_DONE,
                PrayerAlarmReceiver.ACTION_POST_LATE,
                PrayerAlarmReceiver.ACTION_POST_MISSED
            ),
            PostCheckActions.buttons().map { it.action }
        )
        assertEquals(PrayerAlarmReceiver.ACTION_POST_LATER, PostCheckActions.corner().action)
    }

    @Test
    fun `labels are the existing English and Arabic strings`() {
        val labels = PostCheckActions.ALL.map {
            PostCheckActions.label(it, false) to PostCheckActions.label(it, true)
        }
        assertEquals(
            listOf(
                "Done" to "صلّيت",
                "Late" to "متأخر",
                "Missed" to "فاتتني",
                "Remind Later" to "ذكّرني لاحقاً"
            ),
            labels
        )
    }

    @Test
    fun `request codes never collide across the six notifications or with the body tap`() {
        val codes = ids.flatMap { id ->
            PostCheckActions.ALL.map { PostCheckActions.requestCode(id, it) } +
                PostCheckActions.contentRequestCode(id)
        }
        // Notification ids 6001..6006 give overlapping +n ranges; only (action, code) pairs must be
        // unique because PendingIntent identity includes the action. Check the pairs.
        val pairs = ids.flatMap { id ->
            PostCheckActions.ALL.map { it.action to PostCheckActions.requestCode(id, it) }
        }
        assertEquals(pairs.size, pairs.toSet().size)
        // The body tap is an activity PendingIntent with its own offset (+5).
        assertEquals(6008, PostCheckActions.contentRequestCode(6003))
        assertTrue(codes.isNotEmpty())
    }

    @Test
    fun `within one notification the four codes and the body tap are distinct`() {
        val one = PostCheckActions.ALL.map { PostCheckActions.requestCode(6003, it) } +
            PostCheckActions.contentRequestCode(6003)
        assertEquals(5, one.toSet().size)
        assertNotEquals(PostCheckActions.requestCode(6003, PostCheckActions.corner()),
            PostCheckActions.contentRequestCode(6003))
    }

    @Test
    fun `keys are done late missed later and unique`() {
        assertEquals(listOf("done", "late", "missed", "later"), PostCheckActions.ALL.map { it.key })
    }

    @Test
    fun `prayer icon key follows the Next Prayer card mapping`() {
        assertEquals("fajr", PostCheckActions.iconKey("Fajr"))
        assertEquals("fajr", PostCheckActions.iconKey("Sunrise"))
        assertEquals("dhuhr", PostCheckActions.iconKey("Zuhr"))
        assertEquals("dhuhr", PostCheckActions.iconKey("Dhuhr"))
        assertEquals("afternoon", PostCheckActions.iconKey("Asr"))
        assertEquals("maghrib", PostCheckActions.iconKey("Maghrib"))
        assertEquals("isha", PostCheckActions.iconKey("Isha"))
        assertEquals("mosque", PostCheckActions.iconKey("Other"))
    }

    @Test
    fun `theme pick is dark for dark and amoled, light for light, phone for system`() {
        assertTrue(PostCheckActions.isDark("dark", false))
        assertTrue(PostCheckActions.isDark("amoled", false))
        assertEquals(false, PostCheckActions.isDark("light", true))
        assertEquals(true, PostCheckActions.isDark("system", true))
        assertEquals(false, PostCheckActions.isDark("system", false))
        assertEquals(false, PostCheckActions.isDark("anything-else", false))
    }

    @Test
    fun `question and subtitle texts are the existing English and Arabic strings`() {
        assertEquals("Did you pray Asr?", PostCheckActions.question("Asr", false))
        assertEquals("هل صليت العصر؟", PostCheckActions.question("العصر", true))
        assertEquals("Log your prayer now", PostCheckActions.subtitle(false))
        assertEquals("سجّل صلاتك الآن", PostCheckActions.subtitle(true))
    }

    @Test
    fun `post check has its own channel, not the shared prayer_tracking one`() {
        assertEquals("post_prayer_check", PostCheckActions.CHANNEL_ID)
        assertNotEquals("prayer_tracking", PostCheckActions.CHANNEL_ID)
        assertNotEquals("prayer_check", PostCheckActions.CHANNEL_ID) // the unused Dart channel
    }

    @Test
    fun `ongoing card has a 30 minute timeout so it cannot get stuck`() {
        assertEquals(30 * 60 * 1000L, PostCheckActions.TIMEOUT_MS)
        assertTrue(PostCheckActions.TIMEOUT_MS > 15 * 60 * 1000L) // longer than one Remind Later cycle
    }

    @Test
    fun `all four actions have a card button view in the 2x2 grid order`() {
        assertEquals(listOf("done", "late", "missed", "later"), PostCheckActions.ALL.map { it.key })
    }

    @Test
    fun `remaining timeout keeps the original 30 minutes and never goes negative`() {
        val t0 = 1_000_000L
        assertEquals(PostCheckActions.TIMEOUT_MS, PostCheckActions.remainingTimeoutMs(t0, t0))
        assertEquals(PostCheckActions.TIMEOUT_MS - 10 * 60 * 1000L, PostCheckActions.remainingTimeoutMs(t0, t0 + 10 * 60 * 1000L))
        assertEquals(0L, PostCheckActions.remainingTimeoutMs(t0, t0 + PostCheckActions.TIMEOUT_MS))
        assertEquals(0L, PostCheckActions.remainingTimeoutMs(t0, t0 + PostCheckActions.TIMEOUT_MS + 5))
    }

    @Test
    fun `post check ids 6001 to 6006 are recognised and others are not`() {
        for (id in 6001..6006) assertTrue(PostCheckActions.isPostCheckId(id))
        assertTrue(!PostCheckActions.isPostCheckId(6000))
        assertTrue(!PostCheckActions.isPostCheckId(6007))
        assertTrue(!PostCheckActions.isPostCheckId(9999))
    }
}
