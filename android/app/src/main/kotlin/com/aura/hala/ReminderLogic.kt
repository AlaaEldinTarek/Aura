package com.aura.hala

/**
 * Pure rules for the pre-prayer reminder (no Android types, unit tested).
 * Dart twin: lib/core/utils/pre_prayer_reminder.dart; both are tested against
 * the same expected strings. Spec: docs/designs/fix-prayer-reminder.md.
 */
object ReminderLogic {
    const val KEY_MINUTES = "notification_reminder_minutes"
    const val KEY_MASTER = "prayer_notifications_enabled"
    const val DEFAULT_MINUTES = 10
    private val OPTIONS = setOf(5, 10, 15, 30)

    /** Request code of a prayer's reminder alarm: adhan code (1001..1006) + 1100 = 2101..2106. */
    fun requestCode(adhanRequestCode: Int): Int = adhanRequestCode + 1100

    /** 0, negative, unlisted values read as 10. */
    fun normalizeMinutes(value: Int): Int = if (value in OPTIONS) value else DEFAULT_MINUTES

    /** Trigger time, or null when the reminder time is already past. */
    fun triggerTime(prayerTime: Long, minutes: Int, now: Long): Long? {
        val t = prayerTime - normalizeMinutes(minutes) * 60_000L
        return if (t <= now) null else t
    }

    /** Armed only if the "Reminder Prayer" switch is on; Sunrise never. */
    fun shouldArm(masterOn: Boolean, prayerName: String): Boolean =
        masterOn && prayerName != "Sunrise"

    private fun canon(name: String?): String? = if (name == "Dhuhr") "Zuhr" else name

    /** True when the fired prayer is the one the active reminder belongs to. */
    fun shouldClear(reminderPrayerName: String?, firedPrayerName: String): Boolean =
        reminderPrayerName != null && canon(reminderPrayerName) == canon(firedPrayerName)

    fun title(isArabic: Boolean): String = if (isArabic) "تذكير بالصلاة" else "Prayer reminder"

    /** 5 and 10 -> "دقائق", 15 and 30 -> "دقيقة" (unit chosen by N). */
    fun arabicUnit(minutes: Int): String = if (normalizeMinutes(minutes) <= 10) "دقائق" else "دقيقة"

    fun toEastern(number: Int): String =
        number.toString().map { c -> if (c in '0'..'9') ('٠' + (c - '0')) else c }.joinToString("")

    /** "{prayer} in {N} minutes" / "أذان {prayer} بعد {N} {unit}". */
    fun body(prayerEn: String, prayerAr: String, minutes: Int, isArabic: Boolean): String {
        val n = normalizeMinutes(minutes)
        return if (isArabic) "أذان $prayerAr بعد ${toEastern(n)} ${arabicUnit(n)}"
        else "$prayerEn in $n minutes"
    }
}
