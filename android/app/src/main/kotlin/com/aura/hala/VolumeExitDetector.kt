package com.aura.hala

import android.os.SystemClock

class VolumeExitDetector(
    private val requiredCount: Int = 3,
    private val windowMs: Long = 1500L,
    private val clock: () -> Long = { SystemClock.elapsedRealtime() }
) {
    private val timestamps = mutableListOf<Long>()

    fun recordPress(): Boolean {
        val now = clock()
        timestamps.add(now)
        timestamps.removeAll { now - it > windowMs }
        return timestamps.size >= requiredCount
    }

    fun reset() {
        timestamps.clear()
    }
}
