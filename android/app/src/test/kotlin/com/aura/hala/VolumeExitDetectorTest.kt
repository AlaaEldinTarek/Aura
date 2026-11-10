package com.aura.hala

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VolumeExitDetectorTest {

    private var fakeTime = 0L
    private val detector = VolumeExitDetector(
        requiredCount = 3,
        windowMs = 1500L,
        clock = { fakeTime }
    )

    @Test
    fun `3 presses within window triggers exit`() {
        fakeTime = 0L
        assertFalse(detector.recordPress())
        fakeTime = 500L
        assertFalse(detector.recordPress())
        fakeTime = 1000L
        assertTrue(detector.recordPress())
    }

    @Test
    fun `2 presses within window does not trigger exit`() {
        fakeTime = 0L
        assertFalse(detector.recordPress())
        fakeTime = 500L
        assertFalse(detector.recordPress())
    }

    @Test
    fun `3 presses spread over more than 1_5s does not trigger exit`() {
        fakeTime = 0L
        assertFalse(detector.recordPress())
        fakeTime = 800L
        assertFalse(detector.recordPress())
        fakeTime = 2000L
        assertFalse(detector.recordPress())
    }

    @Test
    fun `4 rapid presses triggers exit on 3rd`() {
        fakeTime = 0L
        assertFalse(detector.recordPress())
        fakeTime = 400L
        assertFalse(detector.recordPress())
        fakeTime = 800L
        assertTrue(detector.recordPress())
        fakeTime = 1200L
        assertTrue(detector.recordPress())
    }

    @Test
    fun `reset clears state`() {
        fakeTime = 0L
        assertFalse(detector.recordPress())
        fakeTime = 500L
        assertFalse(detector.recordPress())
        detector.reset()
        fakeTime = 1000L
        assertFalse(detector.recordPress())
    }
}
