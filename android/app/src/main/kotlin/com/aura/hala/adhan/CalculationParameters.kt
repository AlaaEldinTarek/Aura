// Ported from adhan 2.0.0+1 (pub.dev), lib/src/calculation_parameters.dart — line-by-line port.
// Copyright (c) 2020 Riajul Islam. MIT License; see LICENSE in this folder.
package com.aura.hala.adhan

/**
 * Parameters used for PrayerTime calculation customization
 *
 * Note that, for many cases, you can use [CalculationMethod.getParameters] to get a
 * pre-computed set of calculation parameters depending on one of the available
 * [CalculationMethod].
 */
internal class CalculationParameters(
    /** The method used to do the calculation */
    var method: CalculationMethod = CalculationMethod.other,

    /** The angle of the sun used to calculate fajr */
    var fajrAngle: Double,

    /** The angle of the sun used to calculate Maghrib */
    var maghribAngle: Double? = null,

    /** The angle of the sun used to calculate isha */
    var ishaAngle: Double? = null,

    /** Minutes after Maghrib (if set, the time for Isha will be Maghrib plus IshaInterval) */
    var ishaInterval: Int = 0,

    /** The madhab used to calculate Asr */
    var madhab: Madhab = Madhab.shafi,

    /** Rules for placing bounds on Fajr and Isha for high latitude areas */
    var highLatitudeRule: HighLatitudeRule = HighLatitudeRule.middle_of_the_night,

    /** Used to optionally add or subtract a set amount of time from each prayer time */
    var adjustments: PrayerAdjustments = PrayerAdjustments(),

    /** Used for method adjustments */
    var methodAdjustments: PrayerAdjustments = PrayerAdjustments(),
) {

    /**
     * Set the method adjustments for the current calculation parameters
     * @param adjustments the prayer adjustments
     * @return this calculation parameters instance
     */
    fun withMethodAdjustments(adjustments: PrayerAdjustments): CalculationParameters {
        methodAdjustments = adjustments
        return this
    }

    fun nightPortions(): NightPortions {
        return when (highLatitudeRule) {
            HighLatitudeRule.middle_of_the_night -> NightPortions(1.0 / 2.0, 1.0 / 2.0)
            HighLatitudeRule.seventh_of_the_night -> NightPortions(1.0 / 7.0, 1.0 / 7.0)
            HighLatitudeRule.twilight_angle -> {
                val isha = ishaAngle ?: throw IllegalArgumentException("ishaAngle's value isn't define")
                NightPortions(fajrAngle / 60.0, isha / 60.0)
            }
        }
    }
}

internal class NightPortions(val fajr: Double, val isha: Double)
