// Ported from adhan 2.0.0+1 (pub.dev), lib/src/coordinates.dart — line-by-line port.
// Copyright (c) 2020 Riajul Islam. MIT License; see LICENSE in this folder.
package com.aura.hala.adhan

import kotlin.math.abs

/** Coordinates representing a particular place */
internal class Coordinates(val latitude: Double, val longitude: Double, validate: Boolean = false) {

    /**
     * If you pass `true` with [validate] param then
     * it will throw [IllegalArgumentException] if [latitude] or [longitude] is invalid.
     */
    init {
        if (validate) {
            if (!(latitude.isFinite() && abs(latitude) <= 90)) {
                throw IllegalArgumentException(
                    "Invalid Latitude supplied, Latitude must be a number between -90 and 90"
                )
            }

            if (!(longitude.isFinite() && abs(longitude) <= 180)) {
                throw IllegalArgumentException(
                    "Invalid longitude supplied, Longitude must a number between -180 and 180"
                )
            }
        }
    }
}
