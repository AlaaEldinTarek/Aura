package com.aura.hala

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Spec: docs/designs/fix-boot-start-service.md, section 3 and phase P1. Only the
 * order of the EMUI screens to try and the choice of the first one that exists are
 * pure and tested here. Whether a screen really opens for a third-party app is
 * checked on a Huawei phone.
 */
class AutoLaunchSettingsTest {
    private val list = AutoLaunchSettings.CANDIDATES[0]
    private val control = AutoLaunchSettings.CANDIDATES[1]
    private val action = AutoLaunchSettings.CANDIDATES[2]

    @Test
    fun `three EMUI targets, in the order of the spec`() {
        assertEquals(3, AutoLaunchSettings.CANDIDATES.size)
        assertEquals(
            "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            list.className
        )
        assertEquals(
            "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity",
            control.className
        )
        assertEquals("huawei.intent.action.HSM_STARTUPAPP_MANAGER", action.action)
        assertNull(action.className)
    }

    @Test
    fun `every target belongs to the Huawei system manager`() {
        for (t in AutoLaunchSettings.CANDIDATES) {
            assertEquals("com.huawei.systemmanager", t.packageName)
            assertTrue("a target needs a class or an action", t.className != null || t.action != null)
        }
    }

    @Test
    fun `the first target that resolves is chosen`() {
        assertEquals(list, AutoLaunchSettings.firstResolvable { true })
    }

    @Test
    fun `targets that do not resolve are skipped`() {
        assertEquals(control, AutoLaunchSettings.firstResolvable { it == control || it == action })
        assertEquals(action, AutoLaunchSettings.firstResolvable { it == action })
    }

    @Test
    fun `no target resolves gives null so the caller uses the app details screen`() {
        assertNull(AutoLaunchSettings.firstResolvable { false })
    }

    @Test
    fun `later targets are not asked once one resolves`() {
        val asked = mutableListOf<AutoLaunchSettings.Target>()
        AutoLaunchSettings.firstResolvable { asked.add(it); it == control }
        assertEquals(listOf(list, control), asked)
    }

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
