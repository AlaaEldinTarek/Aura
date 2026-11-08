// Ported from adhan 2.0.0+1 (pub.dev), lib/src/internal/double_util.dart — line-by-line port.
// Copyright (c) 2020 Riajul Islam. MIT License; see LICENSE in this folder.
package com.aura.hala.adhan.internal

import kotlin.math.floor

internal object DoubleUtil {
    fun normalizeWithBound(value: Double, max: Double): Double {
        return value - (max * floor(value / max))
    }

    fun unwindAngle(value: Double): Double {
        return normalizeWithBound(value, 360.0)
    }

    fun closestAngle(angle: Double): Double {
        if (angle >= -180 && angle <= 180) {
            return angle
        }
        return angle - (360 * dartRound(angle / 360))
    }
}

/**
 * Dart's `round()` / `roundToDouble()`: half away from zero. Not `Math.round`
 * (rounds -2.5 to -2) and not `kotlin.math.round` (half to even).
 */
internal fun dartRound(x: Double): Double = if (x >= 0) floor(x + 0.5) else -floor(-x + 0.5)
