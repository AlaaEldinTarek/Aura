// Ported from adhan 2.0.0+1 (pub.dev), lib/src/data/date_components.dart — line-by-line port.
// Copyright (c) 2020 Riajul Islam. MIT License; see LICENSE in this folder.
package com.aura.hala.adhan.data

import java.time.ZonedDateTime

internal data class DateComponents(val year: Int, val month: Int, val day: Int) {

    companion object {
        /**
         * Convenience method that returns a [DateComponents] from a given date
         *
         * @param date the date
         * @return the [DateComponents] (in the date's zone)
         */
        fun from(date: ZonedDateTime): DateComponents {
            return DateComponents(date.year, date.monthValue, date.dayOfMonth)
        }
    }
}
