package com.aura.hala

/**
 * Whether this is a Huawei (EMUI) phone, where the user must let Aura start after a
 * reboot ("App launch": Auto-launch, Secondary launch, Run in background). Without it
 * EMUI can block the boot broadcast, so the prayer service does not start until the
 * app is opened. Spec: docs/designs/fix-boot-start-service.md, section 3a and phase P1b.
 *
 * Pure, no Android classes, so it is unit tested. No Huawei activity is resolved or
 * started: the explicit EMUI screens and the implicit action were tried on the test
 * phone and did not open for a third-party app (the action opened a system chooser).
 */
object AutoLaunchSettings {
    /**
     * True on a Huawei phone, by the manufacturer name only. Honor is not included
     * (its menu is not verified).
     */
    fun isEmuiManufacturer(manufacturer: String?): Boolean =
        manufacturer.equals("HUAWEI", ignoreCase = true)
}
