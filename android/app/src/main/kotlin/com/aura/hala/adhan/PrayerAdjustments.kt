// Ported from adhan 2.0.0+1 (pub.dev), lib/src/prayer_adjustments.dart — line-by-line port.
// Copyright (c) 2020 Riajul Islam. MIT License; see LICENSE in this folder.
package com.aura.hala.adhan

/**
 * Adjustment value for prayer times, in minutes
 * These values are added (or subtracted) from the prayer time that is calculated before
 * returning the result times.
 */
internal class PrayerAdjustments(
    /** Fajr offset in minutes */
    var fajr: Int = 0,

    /** Sunrise offset in minutes */
    var sunrise: Int = 0,

    /** Dhuhr offset in minutes */
    var dhuhr: Int = 0,

    /** Asr offset in minutes */
    var asr: Int = 0,

    /** Maghrib offset in minutes */
    var maghrib: Int = 0,

    /** Isha offset in minutes */
    var isha: Int = 0,
)
