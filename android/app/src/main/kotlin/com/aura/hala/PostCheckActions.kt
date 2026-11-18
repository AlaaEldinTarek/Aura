package com.aura.hala

/**
 * The four actions of the post-prayer check notification (IDs 6001-6006).
 * Spec: docs/designs/fix-post-check-remind-later.md (F72, phase R1b). All four live in the custom
 * layout (system action buttons cannot be coloured per button on EMUI): Done / Late / Missed as a
 * coloured row in the expanded view, Remind Later as the corner button. Pure data: the PendingIntents
 * are built in PrayerAlarmReceiver from this table.
 */
object PostCheckActions {
    enum class Placement { BUTTON, CORNER }  // BUTTON = coloured row (expanded view)

    data class Spec(
        val key: String,
        val action: String,
        val requestOffset: Int,
        val labelEn: String,
        val labelAr: String,
        val placement: Placement
    )

    /** Offset of the "tap the body" activity PendingIntent (not an action). */
    const val CONTENT_OFFSET = 5

    val ALL: List<Spec> = listOf(
        Spec("done", PrayerAlarmReceiver.ACTION_POST_DONE, 1, "Done", "صلّيت", Placement.BUTTON),
        Spec("late", PrayerAlarmReceiver.ACTION_POST_LATE, 2, "Late", "متأخر", Placement.BUTTON),
        Spec("missed", PrayerAlarmReceiver.ACTION_POST_MISSED, 3, "Missed", "فاتتني", Placement.BUTTON),
        Spec("later", PrayerAlarmReceiver.ACTION_POST_LATER, 4, "Remind Later", "ذكّرني لاحقاً", Placement.CORNER)
    )

    fun buttons(): List<Spec> = ALL.filter { it.placement == Placement.BUTTON }

    fun corner(): Spec = ALL.first { it.placement == Placement.CORNER }

    fun requestCode(notificationId: Int, spec: Spec): Int = notificationId + spec.requestOffset

    fun contentRequestCode(notificationId: Int): Int = notificationId + CONTENT_OFFSET

    fun label(spec: Spec, isArabic: Boolean): String = if (isArabic) spec.labelAr else spec.labelEn
}
