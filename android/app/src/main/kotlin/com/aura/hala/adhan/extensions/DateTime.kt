// Ported from adhan 2.0.0+1 (pub.dev), lib/src/extensions/datetime.dart — line-by-line port.
// Copyright (c) 2020 Riajul Islam. MIT License; see LICENSE in this folder.
package com.aura.hala.adhan.extensions

import java.time.LocalDateTime
import java.time.ZonedDateTime

/**
 * Dart `DateTime.copyWith`: rebuilds the date from fields with Dart's
 * constructor semantics — out-of-range fields roll over (a minute of 60 moves
 * into the next hour). Fields are normalised with `java.time` plus-arithmetic
 * on a local date-time, then placed in this value's zone.
 */
internal fun ZonedDateTime.copyWith(
    year: Int? = null,
    month: Int? = null,
    day: Int? = null,
    hour: Int? = null,
    minute: Int? = null,
    second: Int? = null,
    nanosecond: Int? = null,
): ZonedDateTime {
    val local = LocalDateTime.of(year ?: this.year, 1, 1, 0, 0)
        .plusMonths(((month ?: this.monthValue) - 1).toLong())
        .plusDays(((day ?: this.dayOfMonth) - 1).toLong())
        .plusHours((hour ?: this.hour).toLong())
        .plusMinutes((minute ?: this.minute).toLong())
        .plusSeconds((second ?: this.second).toLong())
        .plusNanos((nanosecond ?: this.nano).toLong())
    return local.atZone(zone)
}

/**
 * Dart `dayOfYear`: `difference(DateTime(year)).inDays + 1`, where
 * `DateTime(year)` is local midnight of 1 January on the host. The package
 * calls it on a UTC midnight; on a host with a UTC offset in [0, 24 h) that
 * equals the calendar day of the year, which is what this returns. The golden
 * fixture is generated on such a host (spec item 2).
 */
internal val ZonedDateTime.adhanDayOfYear: Int
    get() = this.dayOfYear
