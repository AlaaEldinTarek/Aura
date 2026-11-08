// Ported from adhan 2.0.0+1 (pub.dev), lib/src/internal/solar_time.dart — line-by-line port.
// Copyright (c) 2020 Riajul Islam. MIT License; see LICENSE in this folder.
package com.aura.hala.adhan.internal

import com.aura.hala.adhan.Coordinates
import java.time.Duration
import java.time.ZonedDateTime
import kotlin.math.abs
import kotlin.math.atan
import kotlin.math.tan

internal class SolarTime(today: ZonedDateTime, coordinates: Coordinates) {
    val transit: Double

    val sunrise: Double

    val sunset: Double

    private val observer: Coordinates
    private val solar: SolarCoordinates
    private val prevSolar: SolarCoordinates
    private val nextSolar: SolarCoordinates
    private val approximateTransit: Double

    init {
        // Dart `add(Duration(days: 1))`: exactly 24 h.
        val tomorrow = today.plus(Duration.ofDays(1))

        val yesterday = today.minus(Duration.ofDays(1))

        prevSolar = SolarCoordinates(CalendricalHelper.julianDayByDate(yesterday))
        solar = SolarCoordinates(CalendricalHelper.julianDayByDate(today))
        nextSolar = SolarCoordinates(CalendricalHelper.julianDayByDate(tomorrow))

        approximateTransit = Astronomical.approximateTransit(
            coordinates.longitude,
            solar.apparentSiderealTime, solar.rightAscension
        )
        val solarAltitude = -50.0 / 60.0

        observer = coordinates
        transit = Astronomical.correctedTransit(
            approximateTransit,
            coordinates.longitude,
            solar.apparentSiderealTime,
            solar.rightAscension,
            prevSolar.rightAscension,
            nextSolar.rightAscension
        )
        sunrise = Astronomical.correctedHourAngle(
            approximateTransit,
            solarAltitude,
            coordinates,
            false,
            solar.apparentSiderealTime,
            solar.rightAscension,
            prevSolar.rightAscension,
            nextSolar.rightAscension,
            solar.declination,
            prevSolar.declination,
            nextSolar.declination
        )
        sunset = Astronomical.correctedHourAngle(
            approximateTransit,
            solarAltitude,
            coordinates,
            true,
            solar.apparentSiderealTime,
            solar.rightAscension,
            prevSolar.rightAscension,
            nextSolar.rightAscension,
            solar.declination,
            prevSolar.declination,
            nextSolar.declination
        )
    }

    fun hourAngle(angle: Double, afterTransit: Boolean): Double {
        return Astronomical.correctedHourAngle(
            approximateTransit,
            angle,
            observer,
            afterTransit,
            solar.apparentSiderealTime,
            solar.rightAscension,
            prevSolar.rightAscension,
            nextSolar.rightAscension,
            solar.declination,
            prevSolar.declination,
            nextSolar.declination
        )
    }

    // hours from transit
    fun afternoon(shadowLength: ShadowLength): Double {
        // TODO (from Swift version) source shadow angle calculation
        val tangent = abs(observer.latitude - solar.declination)
        val inverse = shadowLength.getShadowLength() + tan(radians(tangent))
        val angle = degrees(atan(1.0 / inverse))

        return hourAngle(angle, true)
    }
}
