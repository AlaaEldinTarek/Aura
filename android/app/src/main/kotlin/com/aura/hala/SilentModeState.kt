package com.aura.hala

/**
 * Pure decisions about the vibrate-window state kept in the `aura_silent_mode`
 * prefs (`is_silent_active`, `silent_end_time`). No Android classes, so they are
 * unit tested. Spec: docs/designs/fix-boot-start-service.md, section 4.
 *
 * `silent_end_time == 0` with the flag on is a legitimate state, not a stale one:
 * "Keep Vibrate" sets it to mean permanent vibrate (ToggleSilentModeReceiver).
 */
object SilentModeState {
    /** How long after the window ended a flag still counts as normal (the end alarm may be late). */
    const val STALE_GRACE_MS = 5 * 60 * 1000L

    /**
     * True when the flag is stale and may be cleared on app start: the flag is on, the
     * window is a timed one (end time above 0), and it ended more than [graceMs] ago.
     * Permanent vibrate (end time 0) is never stale.
     */
    fun shouldClearStaleSilent(
        isActive: Boolean,
        endTime: Long,
        now: Long,
        graceMs: Long = STALE_GRACE_MS,
    ): Boolean = isActive && endTime > 0 && now >= endTime + graceMs

    /**
     * Whether the adhan screen shows the vibration buttons: the flag is on and either
     * permanent vibrate (end time 0) or the timed window is not over yet. A timed
     * window follows the same rule as the foreground notification
     * (PrayerForegroundService.vibrationButtonsVisible).
     */
    fun adhanButtonsVisible(isActive: Boolean, endTime: Long, now: Long): Boolean =
        isActive && (endTime == 0L || now < endTime)
}
