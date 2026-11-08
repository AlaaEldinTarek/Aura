// Ported from adhan 2.0.0+1 (pub.dev), lib/src/prayer_times.dart — line-by-line port.
// Copyright (c) 2020 Riajul Islam. MIT License; see LICENSE in this folder.
package com.aura.hala.adhan

import com.aura.hala.adhan.data.CalendarUtil
import com.aura.hala.adhan.data.DateComponents
import com.aura.hala.adhan.data.TimeComponents
import com.aura.hala.adhan.extensions.adhanDayOfYear
import com.aura.hala.adhan.internal.SolarTime
import com.aura.hala.adhan.internal.dartRound
import java.time.Duration
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlin.math.abs

/**
 * Calculate PrayerTimes for [dateComponents] at [coordinates].
 *
 * The package outputs local times of the host (`toLocal()`); this port takes
 * the zone explicitly ([zone]) and converts each instant with that zone's
 * offset at that instant. Not ported: `today` / `utc` / `utcOffset`
 * factories and `currentPrayer` … `timeForPrayer` (unused).
 *
 * @param coordinates the coordinates of the location
 * @param dateComponents the date components for that location
 * @param calculationParameters the parameters for the calculation
 * @param zone the zone the output times are expressed in
 */
internal class PrayerTimes(
    val coordinates: Coordinates,
    dateComponents: DateComponents,
    val calculationParameters: CalculationParameters,
    val zone: ZoneId,
) {
    val fajr: ZonedDateTime

    val sunrise: ZonedDateTime

    val dhuhr: ZonedDateTime

    val asr: ZonedDateTime

    val maghrib: ZonedDateTime

    val isha: ZonedDateTime

    val dateComponents: DateComponents

    init {
        fun valid(value: Double): Boolean = !(value.isInfinite() || value.isNaN())

        var value: Double

        val date = CalendarUtil.resolveTimeByDateComponents(dateComponents)
        this.dateComponents = DateComponents.from(date)

        var tempFajr: ZonedDateTime? = null
        val tempSunrise: ZonedDateTime
        val tempDhuhr: ZonedDateTime
        val tempAsr: ZonedDateTime
        var tempMaghrib: ZonedDateTime
        var tempIsha: ZonedDateTime? = null

        val year = date.year
        val dayOfYear = date.adhanDayOfYear

        val solarTime = SolarTime(date, coordinates)

        var timeComponents = TimeComponents.fromDouble(solarTime.transit)
        val transit = timeComponents.dateComponents(date)

        timeComponents = TimeComponents.fromDouble(solarTime.sunrise)
        val sunriseComponents = timeComponents.dateComponents(date)

        timeComponents = TimeComponents.fromDouble(solarTime.sunset)
        val sunsetComponents = timeComponents.dateComponents(date)

        val tomorrow = date.plus(Duration.ofDays(1))
        val tomorrowSolarTime = SolarTime(tomorrow, coordinates)
        val tomorrowSunriseComponents =
            TimeComponents.fromDouble(tomorrowSolarTime.sunrise)

        tempDhuhr = transit
        tempSunrise = sunriseComponents

        timeComponents = TimeComponents.fromDouble(
            solarTime.afternoon(calculationParameters.madhab.getShadowLength())
        )
        tempAsr = timeComponents.dateComponents(date)

        // get night length
        val tomorrowSunrise = tomorrowSunriseComponents.dateComponents(tomorrow)
        val night = tomorrowSunrise.toInstant().toEpochMilli() -
            sunsetComponents.toInstant().toEpochMilli()

        value = solarTime.hourAngle(-calculationParameters.fajrAngle, false)

        if (valid(value)) {
            timeComponents = TimeComponents.fromDouble(value)
            tempFajr = timeComponents.dateComponents(date)
        }

        if (calculationParameters.method == CalculationMethod.moon_sighting_committee &&
            coordinates.latitude >= 55
        ) {
            tempFajr = sunriseComponents.plusSeconds(-1 * night / 7000)
        }

        val nightPortions = calculationParameters.nightPortions()

        val safeFajr: ZonedDateTime
        if (calculationParameters.method == CalculationMethod.moon_sighting_committee) {
            safeFajr = seasonAdjustedMorningTwilight(
                coordinates.latitude, dayOfYear, year, sunriseComponents
            )
        } else {
            val portion = nightPortions.fajr
            val nightFraction = (portion * night / 1000).toLong()
            safeFajr = sunriseComponents.plusSeconds(-1 * nightFraction)
        }

        if (tempFajr == null || tempFajr.isBefore(safeFajr)) {
            tempFajr = safeFajr
        }

        // Isha calculation with check against safe value
        if (calculationParameters.ishaInterval > 0) {
            tempIsha = sunsetComponents
                .plusSeconds(calculationParameters.ishaInterval * 60L)
        } else {
            value = solarTime.hourAngle(-calculationParameters.ishaAngle!!, true)

            if (calculationParameters.ishaAngle != null && valid(value)) {
                timeComponents = TimeComponents.fromDouble(
                    solarTime.hourAngle(-calculationParameters.ishaAngle!!, true)
                )
                tempIsha = timeComponents.dateComponents(date)
            }

            if (calculationParameters.method == CalculationMethod.moon_sighting_committee &&
                coordinates.latitude >= 55
            ) {
                val nightFraction = night / 7000
                tempIsha = sunsetComponents.plusSeconds(nightFraction)
            }

            val safeIsha: ZonedDateTime
            if (calculationParameters.method == CalculationMethod.moon_sighting_committee) {
                safeIsha = seasonAdjustedEveningTwilight(
                    coordinates.latitude, dayOfYear, year, sunsetComponents
                )
            } else {
                val portion = nightPortions.isha
                val nightFraction = (portion * night / 1000).toLong()
                safeIsha = sunsetComponents.plusSeconds(nightFraction)
            }

            if (tempIsha == null || (tempIsha.isAfter(safeIsha))) {
                tempIsha = safeIsha
            }
        }

        tempMaghrib = sunsetComponents
        val maghribAngle = calculationParameters.maghribAngle
        if (maghribAngle != null) {
            val angleBasedMaghrib = TimeComponents.fromDouble(
                solarTime.hourAngle(-1 * maghribAngle, true)
            ).dateComponents(date)
            if (sunsetComponents.isBefore(angleBasedMaghrib) &&
                tempIsha!!.isAfter(angleBasedMaghrib)
            ) {
                tempMaghrib = angleBasedMaghrib
            }
        }

        // Assign final times to public struct members with all offsets
        fajr = CalendarUtil.roundedMinute(
            tempFajr
                .plusMinutes(calculationParameters.adjustments.fajr.toLong())
                .plusMinutes(calculationParameters.methodAdjustments.fajr.toLong())
                .withZoneSameInstant(zone)
        )
        sunrise = CalendarUtil.roundedMinute(
            tempSunrise
                .plusMinutes(calculationParameters.adjustments.sunrise.toLong())
                .plusMinutes(calculationParameters.methodAdjustments.sunrise.toLong())
                .withZoneSameInstant(zone)
        )
        dhuhr = CalendarUtil.roundedMinute(
            tempDhuhr
                .plusMinutes(calculationParameters.adjustments.dhuhr.toLong())
                .plusMinutes(calculationParameters.methodAdjustments.dhuhr.toLong())
                .withZoneSameInstant(zone)
        )
        asr = CalendarUtil.roundedMinute(
            tempAsr
                .plusMinutes(calculationParameters.adjustments.asr.toLong())
                .plusMinutes(calculationParameters.methodAdjustments.asr.toLong())
                .withZoneSameInstant(zone)
        )
        maghrib = CalendarUtil.roundedMinute(
            tempMaghrib
                .plusMinutes(calculationParameters.adjustments.maghrib.toLong())
                .plusMinutes(calculationParameters.methodAdjustments.maghrib.toLong())
                .withZoneSameInstant(zone)
        )
        isha = CalendarUtil.roundedMinute(
            tempIsha!!
                .plusMinutes(calculationParameters.adjustments.isha.toLong())
                .plusMinutes(calculationParameters.methodAdjustments.isha.toLong())
                .withZoneSameInstant(zone)
        )
    }

    companion object {
        private fun seasonAdjustedMorningTwilight(
            latitude: Double, day: Int, year: Int, sunrise: ZonedDateTime
        ): ZonedDateTime {
            val a = 75 + ((28.65 / 55.0) * abs(latitude))
            val b = 75 + ((19.44 / 55.0) * abs(latitude))
            val c = 75 + ((32.74 / 55.0) * abs(latitude))
            val d = 75 + ((48.10 / 55.0) * abs(latitude))

            val adjustment: Double
            val dyy = daysSinceSolstice(day, year, latitude)
            adjustment = if (dyy < 91) {
                a + (b - a) / 91.0 * dyy
            } else if (dyy < 137) {
                b + (c - b) / 46.0 * (dyy - 91)
            } else if (dyy < 183) {
                c + (d - c) / 46.0 * (dyy - 137)
            } else if (dyy < 229) {
                d + (c - d) / 46.0 * (dyy - 183)
            } else if (dyy < 275) {
                c + (b - c) / 46.0 * (dyy - 229)
            } else {
                b + (a - b) / 91.0 * (dyy - 275)
            }

            return sunrise.plusSeconds(-dartRound(adjustment * 60.0).toLong())
        }

        private fun seasonAdjustedEveningTwilight(
            latitude: Double, day: Int, year: Int, sunset: ZonedDateTime
        ): ZonedDateTime {
            val a = 75 + ((25.60 / 55.0) * abs(latitude))
            val b = 75 + ((2.050 / 55.0) * abs(latitude))
            val c = 75 - ((9.210 / 55.0) * abs(latitude))
            val d = 75 + ((6.140 / 55.0) * abs(latitude))

            val adjustment: Double
            val dyy = daysSinceSolstice(day, year, latitude)
            adjustment = if (dyy < 91) {
                a + (b - a) / 91.0 * dyy
            } else if (dyy < 137) {
                b + (c - b) / 46.0 * (dyy - 91)
            } else if (dyy < 183) {
                c + (d - c) / 46.0 * (dyy - 137)
            } else if (dyy < 229) {
                d + (c - d) / 46.0 * (dyy - 183)
            } else if (dyy < 275) {
                c + (b - c) / 46.0 * (dyy - 229)
            } else {
                b + (a - b) / 91.0 * (dyy - 275)
            }

            return sunset.plusSeconds(dartRound(adjustment * 60.0).toLong())
        }

        fun daysSinceSolstice(dayOfYear: Int, year: Int, latitude: Double): Int {
            var daysSinceSolistice: Int
            val northernOffset = 10
            val isLeapYear = CalendarUtil.isLeapYear(year)
            val southernOffset = if (isLeapYear) 173 else 172
            val daysInYear = if (isLeapYear) 366 else 365

            if (latitude >= 0) {
                daysSinceSolistice = dayOfYear + northernOffset
                if (daysSinceSolistice >= daysInYear) {
                    daysSinceSolistice = daysSinceSolistice - daysInYear
                }
            } else {
                daysSinceSolistice = dayOfYear - southernOffset
                if (daysSinceSolistice < 0) {
                    daysSinceSolistice = daysSinceSolistice + daysInYear
                }
            }
            return daysSinceSolistice
        }
    }
}
