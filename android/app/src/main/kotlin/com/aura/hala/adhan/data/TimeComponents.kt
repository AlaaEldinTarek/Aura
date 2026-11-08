// Ported from adhan 2.0.0+1 (pub.dev), lib/src/data/time_components.dart — line-by-line port.
// Copyright (c) 2020 Riajul Islam. MIT License; see LICENSE in this folder.
package com.aura.hala.adhan.data

import com.aura.hala.adhan.extensions.copyWith
import java.time.ZonedDateTime
import kotlin.math.floor

internal class TimeComponents(val hours: Int, val minutes: Int, val seconds: Int) {

    fun dateComponents(date: ZonedDateTime): ZonedDateTime {
        return date.copyWith(hour = hours, minute = minutes, second = seconds)
    }

    companion object {
        fun fromDouble(value: Double): TimeComponents {
            if (value.isInfinite() || value.isNaN()) {
                throw IllegalArgumentException("value should not be infinite or NaN")
            }

            val hours = floor(value).toInt()
            val minutes = floor((value - hours) * 60.0).toInt()
            val seconds = floor((value - (hours + minutes / 60.0)) * 60 * 60).toInt()
            return TimeComponents(hours, minutes, seconds)
        }
    }
}
