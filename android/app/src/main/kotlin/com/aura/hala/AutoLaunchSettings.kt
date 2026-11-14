package com.aura.hala

/**
 * The EMUI (Huawei) screens where a user lets an app be started by the system after a
 * reboot ("App launch": Auto-launch, Secondary launch, Run in background). Without it
 * EMUI can block the boot broadcast, so the prayer service does not start until the
 * app is opened. Spec: docs/designs/fix-boot-start-service.md, section 3 and phase P1.
 *
 * Pure data and selection, no Android classes, so it is unit tested. The caller
 * (MainActivity) resolves and starts the targets and falls back to the app details
 * screen when none of them opens.
 */
object AutoLaunchSettings {
    const val HSM_PACKAGE = "com.huawei.systemmanager"

    /** One screen to try: an explicit activity class, or an action handled by the package. */
    data class Target(
        val packageName: String,
        val className: String?,
        val action: String?,
    )

    /** In the order to try them (both activities and the action resolve on the EMUI 12 test phone). */
    val CANDIDATES: List<Target> = listOf(
        Target(HSM_PACKAGE, "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity", null),
        Target(HSM_PACKAGE, "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity", null),
        Target(HSM_PACKAGE, null, "huawei.intent.action.HSM_STARTUPAPP_MANAGER"),
    )

    /**
     * True on a Huawei phone (EMUI), by the manufacturer name only: no Huawei activity is
     * resolved. Honor is not included (its menu is not verified). Spec section 3a, P1b.
     */
    fun isEmuiManufacturer(manufacturer: String?): Boolean =
        manufacturer.equals("HUAWEI", ignoreCase = true)

    /** The first candidate for which [resolves] is true, or null (stops asking once one is found). */
    fun firstResolvable(resolves: (Target) -> Boolean): Target? = CANDIDATES.firstOrNull(resolves)
}
