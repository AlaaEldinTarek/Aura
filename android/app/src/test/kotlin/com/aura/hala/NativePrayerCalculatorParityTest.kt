package com.aura.hala

import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * FX-0 Kotlin parity: NativePrayerCalculator.calculate must match the adhan
 * package (plus the documented app adjustments) within ±1 min for every row
 * of the golden fixture (test/fixtures/prayer_parity.csv, written by
 * tool/generate_prayer_parity_fixture.dart).
 */
class NativePrayerCalculatorParityTest {

    private val fixture = File("../../test/fixtures/prayer_parity.csv")

    @Test
    fun everyFixtureRowWithinOneMinute() {
        val lines = fixture.readLines().drop(1).filter { it.isNotBlank() }
        assertEquals(3640, lines.size)

        val names = listOf("fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha")
        val failures = mutableListOf<String>()
        var worst = 0L
        for (line in lines) {
            val f = line.split(',')
            val (y, m, d) = f[4].split('-').map { it.toInt() }
            val result = NativePrayerCalculator.calculate(
                f[1].toDouble(), f[2].toDouble(), y, m, d,
                TimeZone.getTimeZone(f[3]), f[5], f[6]
            )
            val actual = listOf(
                result.fajr, result.sunrise, result.dhuhr,
                result.asr, result.maghrib, result.isha
            )
            for (i in names.indices) {
                val expected = f[7 + i].toLong()
                val diff = kotlin.math.abs(actual[i] - expected)
                if (diff > worst) worst = diff
                if (diff > 60_000L) {
                    failures += "${f[0]} ${f[4]} ${f[5]} ${f[6]} ${names[i]}: " +
                        "off by ${diff / 1000} s"
                }
            }
        }
        assertTrue(
            "${failures.size} of ${lines.size * 6} times off by more than 1 min " +
                "(worst ${worst / 1000} s). First: ${failures.take(20).joinToString("; ")}",
            failures.isEmpty()
        )
    }

    /** Guards the hard-coded DST dates of the fixture (spec item 6). */
    @Test
    fun dstDatesAreTransitionDays() {
        val cases = listOf(
            Triple("Africa/Cairo", "2026-04-24", "2026-04-23T22:00:00Z"),
            Triple("Africa/Cairo", "2026-10-29", "2026-10-29T21:00:00Z"),
            Triple("Europe/London", "2026-03-29", "2026-03-29T01:00:00Z"),
            Triple("Europe/London", "2026-10-25", "2026-10-25T01:00:00Z"),
            Triple("America/Toronto", "2026-03-08", "2026-03-08T07:00:00Z"),
            Triple("America/New_York", "2026-03-08", "2026-03-08T07:00:00Z"),
            Triple("America/Toronto", "2026-11-01", "2026-11-01T06:00:00Z"),
            Triple("America/New_York", "2026-11-01", "2026-11-01T06:00:00Z"),
        )
        for ((zoneId, date, expected) in cases) {
            val zone = ZoneId.of(zoneId)
            val day = LocalDate.parse(date)
            val start = day.atStartOfDay(zone).toInstant()
            val end = day.plusDays(1).atStartOfDay(zone).toInstant()
            val t = zone.rules.nextTransition(start.minusSeconds(1)).instant
            assertEquals("$zoneId $date", Instant.parse(expected), t)
            assertTrue("$zoneId $date: transition inside the day", !t.isBefore(start) && t.isBefore(end))
        }
    }
}
