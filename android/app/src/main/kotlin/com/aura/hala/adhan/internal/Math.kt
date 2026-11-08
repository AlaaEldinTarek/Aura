// Ported from adhan 2.0.0+1 (pub.dev), lib/src/internal/math.dart — line-by-line port.
// Copyright (c) 2020 Riajul Islam. MIT License; see LICENSE in this folder.
package com.aura.hala.adhan.internal

import kotlin.math.PI

/** Constant factor to convert and angle from degrees to radians. */
internal const val DEGREES_2_RADIANS: Double = PI / 180.0

/** Constant factor to convert and angle from radians to degrees. */
internal const val RADIANS_2_DEGREES: Double = 180.0 / PI

/** Convert [radians] to degrees. */
internal fun degrees(radians: Double): Double = radians * RADIANS_2_DEGREES

/** Convert [degrees] to radians. */
internal fun radians(degrees: Double): Double = degrees * DEGREES_2_RADIANS
