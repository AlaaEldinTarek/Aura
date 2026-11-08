// Ported from adhan 2.0.0+1 (pub.dev), lib/src/internal/shadow_length.dart — line-by-line port.
// Copyright (c) 2020 Riajul Islam. MIT License; see LICENSE in this folder.
package com.aura.hala.adhan.internal

internal class ShadowLength private constructor(private val shadowLength: Double) {

    fun getShadowLength(): Double {
        return shadowLength
    }

    companion object {
        val single: ShadowLength get() = ShadowLength(1.0)

        val double: ShadowLength get() = ShadowLength(2.0)
    }
}
