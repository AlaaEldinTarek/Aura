// Ported from adhan 2.0.0+1 (pub.dev), lib/src/data/calendar_util.dart — line-by-line port.
// Copyright (c) 2020 Riajul Islam. MIT License; see LICENSE in this folder.
package com.aura.hala.adhan.data

import com.aura.hala.adhan.extensions.copyWith
import com.aura.hala.adhan.internal.dartRound
import java.time.ZoneOffset
import java.time.ZonedDateTime

internal object CalendarUtil {
    /**
     * Whether or not a year is a leap year (has 366 days)
     *
     * @param year the year
     * @return whether or not its a leap year
     */
    fun isLeapYear(year: Int): Boolean {
        return year % 4 == 0 && !(year % 100 == 0 && year % 400 != 0)
    }

    /**
     * Date and time with a rounded minute
     *
     * This returns a date with the seconds rounded and added to the minute
     * @param when the date and time
     * @return date and time with 0 seconds and minutes including rounded seconds
     */
    fun roundedMinute(`when`: ZonedDateTime): ZonedDateTime {
        val minute = `when`.minute
        val second = `when`.second
        return `when`.copyWith(minute = (minute + dartRound(second / 60.0).toInt()), second = 0)
    }

    /**
     * Gets a UTC date-time for the particular date
     *
     * @param components the date components
     * @return date-time set to 00:00:00 at UTC
     */
    fun resolveTimeByDateComponents(components: DateComponents): ZonedDateTime {
        return resolveTime(components.year, components.month, components.day)
    }

    /**
     * Gets UTC date-time for the particular date
     *
     * @param year the year
     * @param month the month
     * @param day the day
     * @return date-time set to 00:00:00 at UTC
     */
    fun resolveTime(year: Int, month: Int, day: Int): ZonedDateTime {
        return ZonedDateTime.of(year, month, day, 0, 0, 0, 0, ZoneOffset.UTC)
    }
}
