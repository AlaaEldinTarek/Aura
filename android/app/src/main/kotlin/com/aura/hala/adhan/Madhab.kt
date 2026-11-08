// Ported from adhan 2.0.0+1 (pub.dev), lib/src/madhab.dart — line-by-line port.
// Copyright (c) 2020 Riajul Islam. MIT License; see LICENSE in this folder.
package com.aura.hala.adhan

import com.aura.hala.adhan.internal.ShadowLength

/** Madhab for determining how Asr is calculated */
internal enum class Madhab {
    /** Shafi Madhab */
    shafi,

    /** Hanafi Madhab */
    hanafi
}

internal fun Madhab.getShadowLength(): ShadowLength {
    return when (this) {
        Madhab.shafi -> ShadowLength.single
        Madhab.hanafi -> ShadowLength.double
    }
}
