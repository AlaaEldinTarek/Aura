package com.aura.hala

/**
 * Text of the two foreground-service notifications that had English-only strings (docs/designs/fix-themed-
 * notifications.md, T9): Focus Mode service (id 5998) and the prayer reschedule service (id 2000). Language only:
 * no layout, id or channel change. Neither string contains a number, so no Arabic digits are needed.
 */
object ServiceNotificationText {
    fun focusModeTitle(isArabic: Boolean): String = if (isArabic) "وضع التركيز نشط" else "Focus Mode Active"

    fun rescheduleTitle(isArabic: Boolean): String = if (isArabic) "جارٍ إعادة جدولة الصلوات" else "Rescheduling Prayers"

    fun rescheduleBody(isArabic: Boolean): String =
        if (isArabic) "جارٍ ضبط تنبيهات أوقات الصلاة..." else "Setting up prayer time alarms..."
}
