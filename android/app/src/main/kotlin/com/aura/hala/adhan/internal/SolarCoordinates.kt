// Ported from adhan 2.0.0+1 (pub.dev), lib/src/internal/solar_coordinates.dart — line-by-line port.
// Copyright (c) 2020 Riajul Islam. MIT License; see LICENSE in this folder.
package com.aura.hala.adhan.internal

import kotlin.math.asin
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

internal class SolarCoordinates(julianDay: Double) {
    /**
     * The declination of the sun, the angle between
     * the rays of the Sun and the plane of the Earth's
     * equator, in degrees.
     */
    val declination: Double

    /**
     * Right ascension of the Sun, the angular distance on the
     * celestial equator from the vernal equinox to the hour circle,
     * in degrees.
     */
    val rightAscension: Double

    /**
     * Apparent sidereal time, the hour angle of the vernal
     * equinox, in degrees.
     */
    val apparentSiderealTime: Double

    init {
        val T = CalendricalHelper.julianCentury(julianDay)
        val L0 = Astronomical.meanSolarLongitude(/* julianCentury */ T)
        val Lp = Astronomical.meanLunarLongitude(/* julianCentury */ T)
        val omega =
            Astronomical.ascendingLunarNodeLongitude(/* julianCentury */ T)
        val lambda = radians(
            Astronomical.apparentSolarLongitude(
                /* julianCentury*/ T,
                /* meanLongitude */ L0
            )
        )

        val theta0 = Astronomical.meanSiderealTime(/* julianCentury */ T)
        val deltaPsi = Astronomical.nutationInLongitude(
            /* julianCentury */ T,
            /* solarLongitude */ L0,
            /* lunarLongitude */ Lp,
            /* ascendingNode */ omega
        )
        val deltaEpsilon = Astronomical.nutationInObliquity(
            /* julianCentury */ T,
            /* solarLongitude */ L0,
            /* lunarLongitude */ Lp,
            /* ascendingNode */ omega
        )

        val epsilon0 =
            Astronomical.meanObliquityOfTheEcliptic(/* julianCentury */ T)
        val epsilonApp = radians(
            Astronomical.apparentObliquityOfTheEcliptic(
                /* julianCentury */ T,
                /* meanObliquityOfTheEcliptic */ epsilon0
            )
        )

        /* Equation from Astronomical Algorithms page 165 */
        declination = degrees(asin(sin(epsilonApp) * sin(lambda)))

        /* Equation from Astronomical Algorithms page 165 */
        rightAscension = DoubleUtil.unwindAngle(
            degrees(atan2(cos(epsilonApp) * sin(lambda), cos(lambda)))
        )

        /* Equation from Astronomical Algorithms page 88 */
        apparentSiderealTime = theta0 +
            (((deltaPsi * 3600) * cos(radians(epsilon0 + deltaEpsilon))) / 3600)
    }
}
