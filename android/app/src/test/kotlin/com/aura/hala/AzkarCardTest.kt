package com.aura.hala

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** T6: post-prayer azkar card (docs/designs/fix-themed-notifications.md). Look only; the launch code must not change. */
class AzkarCardTest {

    private fun source(name: String): String {
        // gradle unit tests run with the module (android/app) as the working directory
        val f = File("src/main/kotlin/com/aura/hala/$name")
        assertTrue("source not found: ${f.absolutePath}", f.exists())
        return f.readText()
    }

    @Test
    fun title_namesThePrayerJustFinished() {
        assertEquals("Azkar after Asr", AzkarCard.title("Asr", "العصر", false, false))
        assertEquals("أذكار بعد صلاة العصر", AzkarCard.title("Asr", "العصر", true, false))
        assertEquals("Azkar after Zuhr", AzkarCard.title("Dhuhr", "الظهر", false, false))
        assertEquals("Azkar after Zuhr", AzkarCard.title("Zuhr", "الظهر", false, false))
    }

    @Test
    fun title_fridayZuhrIsJumuah() {
        assertEquals("Azkar after Jumu'ah", AzkarCard.title("Zuhr", "الظهر", false, true))
        assertEquals("أذكار بعد صلاة الجمعة", AzkarCard.title("Dhuhr", "الظهر", true, true))
        // other prayers are not renamed on Friday
        assertEquals("Azkar after Asr", AzkarCard.title("Asr", "العصر", false, true))
    }

    @Test
    fun body_andButton_followLanguage() {
        assertEquals("Two minutes of dhikr after prayer 🤲", AzkarCard.body(false))
        assertEquals("دقيقتان من الذكر بعد الصلاة 🤲", AzkarCard.body(true))
        assertEquals("Start azkar", AzkarCard.startLabel(false))
        assertEquals("ابدأ الأذكار", AzkarCard.startLabel(true))
    }

    @Test
    fun firstDhikr_arabicTextWithCount_arabicDigitsInArabic() {
        assertEquals("أَسْتَغْفِرُ اللَّهَ ×3", AzkarCard.firstDhikr(false))
        assertEquals("أَسْتَغْفِرُ اللَّهَ ×٣", AzkarCard.firstDhikr(true))
    }

    @Test
    fun firstDhikr_isTheFirstItemOfTheAzkarScreen_noDrift() {
        val screen = source("AzkarFullScreenActivity.kt")
        assertTrue(
            "the card shows the first dhikr of the azkar screen; update AzkarCard.FIRST_DHIKR_AR / FIRST_DHIKR_COUNT too",
            screen.contains("items.add(AzkarItem(\"${AzkarCard.FIRST_DHIKR_AR}\", ${AzkarCard.FIRST_DHIKR_COUNT}))")
        )
    }

    @Test
    fun refreshTimeout_isWhatIsLeftOfTheSixtySeconds() {
        assertEquals(60_000L, AzkarCard.INITIAL_TIMEOUT_MS)
        assertEquals(40_000L, AzkarCard.remainingTimeoutMs(postedAtMs = 1_000_000L, nowMs = 1_020_000L))
        assertEquals(1_000L, AzkarCard.remainingTimeoutMs(postedAtMs = 1_000_000L, nowMs = 1_070_000L))
    }

    @Test
    fun idsAndCodes_unchanged() {
        assertEquals(9003, AzkarAlarmReceiver.getAzkarNotificationId("Dhuhr"))
        assertEquals(9003, AzkarAlarmReceiver.getAzkarNotificationId("Zuhr"))
        assertEquals(3004, AzkarAlarmReceiver.getAzkarRequestCode("Asr"))
        assertEquals("azkar_reminder", AzkarCard.CHANNEL_ID)
    }

    /**
     * The owner's rule: the look changes, the launch does not. These are the exact lines of the receiver that open the
     * azkar screen and decide how the notification behaves; if one of them is edited this test fails.
     */
    @Test
    fun launchCode_inTheReceiver_isUnchanged() {
        val r = source("AzkarAlarmReceiver.kt")
        val mustStay = listOf(
            ".setFullScreenIntent(fullScreenPi, true)",
            ".setContentIntent(fullScreenPi)",
            ".setTimeoutAfter(60_000)",
            ".setAutoCancel(true)",
            ".setPriority(NotificationCompat.PRIORITY_HIGH)",
            ".setCategory(NotificationCompat.CATEGORY_ALARM)",
            "getAzkarRequestCode(prayerName),\n            activityIntent,\n            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE",
            "activityIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)",
            "context.startActivity(activityIntent)",
            "AzkarFullScreenActivity.getIntent(context, prayerName, prayerNameAr)",
            "NotificationManagerCompat.from(context).notify(getAzkarNotificationId(prayerName), notif)",
            "NotificationManager.IMPORTANCE_HIGH"
        )
        val text = r.replace("\r\n", "\n")
        for (line in mustStay) assertTrue("launch code changed, missing: $line", text.contains(line))
        assertFalse("not ongoing", text.contains("setOngoing"))
    }
}
