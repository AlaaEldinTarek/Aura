package com.aura.hala

/**
 * The one Arabic count rule for notification text (Wird pages, digest tasks, task card minutes), owner rule 2026-11-21:
 * 1 = no digit, the singular plus "واحدة" ([one]); 2 = the dual, no digit ([dual]); 3-10 = Arabic digits + [plural];
 * 11 and more (and 0) = Arabic digits + [singular].
 */
object ArabicCount {
    fun phrase(count: Int, singular: String, dual: String, plural: String, one: String): String = when {
        count == 1 -> one
        count == 2 -> dual
        count in 3..10 -> "${ThemedNotification.withArabicNumerals(count.toString())} $plural"
        else -> "${ThemedNotification.withArabicNumerals(count.toString())} $singular"
    }

    fun pages(count: Int): String = phrase(count, "صفحة", "صفحتان", "صفحات", "صفحة واحدة")
    fun tasks(count: Int): String = phrase(count, "مهمة", "مهمتان", "مهام", "مهمة واحدة")
    fun overdueTasks(count: Int): String =
        phrase(count, "مهمة متأخرة", "مهمتان متأخرتان", "مهام متأخرة", "مهمة متأخرة واحدة")
    fun minutes(count: Int): String = phrase(count, "دقيقة", "دقيقتان", "دقائق", "دقيقة واحدة")
}
