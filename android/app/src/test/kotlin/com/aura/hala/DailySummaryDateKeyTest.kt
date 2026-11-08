package com.aura.hala

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * F51a: DailySummaryReceiver date keys must match the prayer_status_* writers
 * (SimpleDateFormat("yyyy-MM-dd", Locale.US)) whatever the device locale.
 */
class DailySummaryDateKeyTest {

    private lateinit var savedLocale: Locale

    @Before
    fun saveLocale() {
        savedLocale = Locale.getDefault()
    }

    @After
    fun restoreLocale() {
        Locale.setDefault(savedLocale)
    }

    private fun date(y: Int, m: Int, d: Int): Calendar =
        Calendar.getInstance().apply { clear(); set(y, m - 1, d) }

    private fun writerKey(cal: Calendar): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(cal.time)

    private fun cutoffFor(today: Calendar): String =
        DailySummaryReceiver.dateKey(
            (today.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, -7) }
        )

    private fun assertKeysMatchWriters() {
        val today = date(2026, 11, 8)
        assertEquals("2026-11-08", DailySummaryReceiver.dateKey(today))
        assertEquals(writerKey(today), DailySummaryReceiver.dateKey(today))
        assertEquals("2026-01-05", DailySummaryReceiver.dateKey(date(2026, 1, 5)))
    }

    private fun assertCutoffOrdering() {
        val today = date(2026, 11, 8)
        val cutoff = cutoffFor(today)
        assertEquals("2026-11-01", cutoff)
        assertFalse("3-day-old key must survive", writerKey(date(2026, 11, 5)) < cutoff)
        assertFalse("today's key must survive", writerKey(today) < cutoff)
        assertTrue("10-day-old key must be pruned", writerKey(date(2026, 10, 29)) < cutoff)
    }

    @Test
    fun usLocale_keysMatchWriters() {
        Locale.setDefault(Locale.US)
        assertKeysMatchWriters()
    }

    @Test
    fun usLocale_cutoffOrdering() {
        Locale.setDefault(Locale.US)
        assertCutoffOrdering()
    }

    @Test
    fun arabicLocale_keysMatchWriters() {
        Locale.setDefault(Locale.forLanguageTag("ar-EG"))
        assertNotEquals("precondition: ar-EG must format Arabic-Indic digits", "05", String.format("%02d", 5))
        assertKeysMatchWriters()
    }

    @Test
    fun arabicLocale_cutoffOrdering() {
        Locale.setDefault(Locale.forLanguageTag("ar-EG"))
        assertNotEquals("precondition: ar-EG must format Arabic-Indic digits", "05", String.format("%02d", 5))
        assertCutoffOrdering()
    }
}
