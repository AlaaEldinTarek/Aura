package com.aura.hala

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Spec: docs/designs/fix-boot-start-service.md, section 3a and phase P1b. Only the
 * manufacturer check is pure and tested here; the dialog is checked on a Huawei phone.
 */
class AutoLaunchSettingsTest {
    @Test
    fun `Huawei is recognised whatever the letter case`() {
        for (m in listOf("HUAWEI", "huawei", "Huawei")) {
            assertTrue(m, AutoLaunchSettings.isEmuiManufacturer(m))
        }
    }

    @Test
    fun `other makers, blank and null are not EMUI`() {
        for (m in listOf("HONOR", "samsung", "Xiaomi", "OPPO", "", " ", null)) {
            assertFalse(m ?: "null", AutoLaunchSettings.isEmuiManufacturer(m))
        }
    }
}
