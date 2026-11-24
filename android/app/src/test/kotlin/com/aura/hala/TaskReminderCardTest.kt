package com.aura.hala

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.assertNotEquals
import org.junit.Test

/**
 * Spec: docs/designs/fix-themed-notifications.md (T2). Pure parts only: the request codes and the button label stay
 * exactly as the plain task reminder had them (contract), and the four layouts are distinct.
 */
class TaskReminderCardTest {
    @Test
    fun `tap and snooze request codes are id+1 and id+2 as before`() {
        assertEquals(1235, TaskReminderCard.tapRequestCode(1234))
        assertEquals(1236, TaskReminderCard.snoozeRequestCode(1234))
    }

    @Test
    fun `button label is Remind Later in English and the Arabic wording as before`() {
        assertEquals("Remind Later", TaskReminderCard.snoozeLabel(false))
        assertEquals("ذكّرني لاحقاً", TaskReminderCard.snoozeLabel(true))
    }

    @Test
    fun `four layouts for the four theme and language combinations are all different`() {
        val ids = listOf(false, true).flatMap { dark -> listOf(false, true).map { ar -> TaskReminderCard.layoutId(dark, ar) } }
        assertEquals(4, ids.toSet().size)
        assertNotEquals(TaskReminderCard.layoutId(false, false), TaskReminderCard.layoutId(true, false))
    }

    @Test
    fun `lock screen public version shows only the generic title, never the task`() {
        assertEquals("Aura - Task reminder", TaskReminderCard.publicTitle(false))
        assertEquals("هالة - تذكير بمهمة", TaskReminderCard.publicTitle(true))
    }

    @Test
    fun `remind later delay is the user setting, 30 only when it is missing or invalid`() {
        assertEquals(15, TaskReminderCard.snoozeDelayMinutes(15))
        assertEquals(60, TaskReminderCard.snoozeDelayMinutes(60))
        assertEquals(30, TaskReminderCard.snoozeDelayMinutes(30))
        assertEquals(30, TaskReminderCard.snoozeDelayMinutes(0))
        assertEquals(30, TaskReminderCard.snoozeDelayMinutes(-5))
    }

    @Test
    fun `body follows the app language, in Arabic with Arabic numerals`() {
        assertEquals("Task is due now", TaskReminderCard.bodyText(TaskReminderCard.BODY_DUE_NOW, 0, false, "x"))
        assertEquals("حان موعد المهمة الآن", TaskReminderCard.bodyText(TaskReminderCard.BODY_DUE_NOW, 0, true, "x"))
        assertEquals("Task due in 30 minutes", TaskReminderCard.bodyText(TaskReminderCard.BODY_BEFORE, 30, false, "x"))
        assertEquals("موعد المهمة بعد \u0663\u0660 دقيقة", TaskReminderCard.bodyText(TaskReminderCard.BODY_BEFORE, 30, true, "x"))
        assertEquals("You have a task due today", TaskReminderCard.bodyText(TaskReminderCard.BODY_TODAY, 0, false, "x"))
        assertEquals("لديك مهمة مستحقة اليوم", TaskReminderCard.bodyText(TaskReminderCard.BODY_TODAY, 0, true, "x"))
        assertEquals("Your task is still pending", TaskReminderCard.bodyText(TaskReminderCard.BODY_PENDING, 0, false, "x"))
        assertEquals("لا تزال المهمة معلقة", TaskReminderCard.bodyText(TaskReminderCard.BODY_PENDING, 0, true, "x"))
    }

    @Test
    fun `arabic minutes unit - plural for 3 to 10, singular for 1, 2 and 11 plus`() {
        fun body(m: Int) = TaskReminderCard.bodyText(TaskReminderCard.BODY_BEFORE, m, true, "x")
        assertEquals("موعد المهمة بعد دقيقة واحدة", body(1))
        assertEquals("موعد المهمة بعد دقيقتان", body(2))
        assertEquals("موعد المهمة بعد ٣ دقائق", body(3))
        assertEquals("موعد المهمة بعد ٥ دقائق", body(5))
        assertEquals("موعد المهمة بعد ١٠ دقائق", body(10))
        assertEquals("موعد المهمة بعد ١١ دقيقة", body(11))
        assertEquals("موعد المهمة بعد ١٥ دقيقة", body(15))
        assertEquals("موعد المهمة بعد ٦٠ دقيقة", body(60))
    }

    @Test
    fun `an alarm scheduled before this change has no kind, so its ready-made text is kept`() {
        assertEquals("Task due in 5 minutes", TaskReminderCard.bodyText(null, 0, false, "Task due in 5 minutes"))
        assertEquals("Task due in 5 minutes", TaskReminderCard.bodyText("", 0, true, "Task due in 5 minutes"))
    }

    @Test
    fun `done label`() {
        assertEquals("Done", TaskReminderCard.doneLabel(false))
        assertEquals("إتمام", TaskReminderCard.doneLabel(true))
    }

    @Test
    fun `done button request code is id+3 and tap and snooze are unchanged`() {
        assertEquals(1237, TaskReminderCard.doneRequestCode(1234))
        assertEquals(1235, TaskReminderCard.tapRequestCode(1234))
        assertEquals(1236, TaskReminderCard.snoozeRequestCode(1234))
    }

    @Test
    fun `pending done ids are appended without losing an earlier one and without duplicates`() {
        assertEquals("a", TaskReminderCard.addPendingDoneId("", "a"))
        assertEquals("a,b", TaskReminderCard.addPendingDoneId("a", "b"))
        assertEquals("a,b", TaskReminderCard.addPendingDoneId("a,b", "a"))
        assertEquals("a", TaskReminderCard.addPendingDoneId("  ", "a"))
    }

    // ---- TC1: live countdown to the due time ----

    @Test
    fun `due-now alarm request code is id+4, apart from tap, snooze and done`() {
        assertEquals(1238, TaskReminderCard.dueNowRequestCode(1234))
        assertEquals(setOf(1235, 1236, 1237, 1238), setOf(
            TaskReminderCard.tapRequestCode(1234), TaskReminderCard.snoozeRequestCode(1234),
            TaskReminderCard.doneRequestCode(1234), TaskReminderCard.dueNowRequestCode(1234)
        ))
    }

    @Test
    fun `countdown only for the before kind and only while the due time is ahead`() {
        val now = 1_000_000L
        assertTrue(TaskReminderCard.showsCountdown(TaskReminderCard.BODY_BEFORE, now + 60_000, now))
        assertFalse(TaskReminderCard.showsCountdown(TaskReminderCard.BODY_BEFORE, now, now))
        assertFalse(TaskReminderCard.showsCountdown(TaskReminderCard.BODY_BEFORE, now - 1, now))
        assertFalse(TaskReminderCard.showsCountdown(TaskReminderCard.BODY_BEFORE, 0L, now)) // no due time sent
        assertFalse(TaskReminderCard.showsCountdown(TaskReminderCard.BODY_DUE_NOW, now + 60_000, now))
        assertFalse(TaskReminderCard.showsCountdown(TaskReminderCard.BODY_TODAY, now + 60_000, now))
        assertFalse(TaskReminderCard.showsCountdown(TaskReminderCard.BODY_PENDING, now + 60_000, now))
        assertFalse(TaskReminderCard.showsCountdown(null, now + 60_000, now))
    }

    @Test
    fun `a before card whose due time has passed reads as due now (refresh after the due time)`() {
        val now = 1_000_000L
        assertEquals(TaskReminderCard.BODY_BEFORE, TaskReminderCard.effectiveKind(TaskReminderCard.BODY_BEFORE, now + 1, now))
        assertEquals(TaskReminderCard.BODY_DUE_NOW, TaskReminderCard.effectiveKind(TaskReminderCard.BODY_BEFORE, now, now))
        assertEquals(TaskReminderCard.BODY_DUE_NOW, TaskReminderCard.effectiveKind(TaskReminderCard.BODY_BEFORE, now - 5_000, now))
        assertEquals(TaskReminderCard.BODY_BEFORE, TaskReminderCard.effectiveKind(TaskReminderCard.BODY_BEFORE, 0L, now)) // unknown due time: unchanged
        assertEquals(TaskReminderCard.BODY_TODAY, TaskReminderCard.effectiveKind(TaskReminderCard.BODY_TODAY, now - 5_000, now))
    }

    @Test
    fun `chronometer base is the elapsed-realtime moment of the due time, so a re-post keeps the timer correct`() {
        // due in 5 minutes
        assertEquals(50_000L + 300_000L, TaskReminderCard.countdownBase(dueAtMs = 2_000_300_000L, nowMs = 2_000_000_000L, elapsedNowMs = 50_000L))
        // a refresh 2 minutes later: same absolute due time, base moves with the clock, remaining stays consistent
        assertEquals(170_000L + 180_000L, TaskReminderCard.countdownBase(dueAtMs = 2_000_300_000L, nowMs = 2_000_120_000L, elapsedNowMs = 170_000L))
    }

    @Test
    fun `countdown text format has one timer slot, in both languages`() {
        assertEquals("Due in %s", TaskReminderCard.countdownFormat(false))
        assertEquals("موعد المهمة بعد %s", TaskReminderCard.countdownFormat(true))
    }

    // ---- TC1 fix: never a negative time ----

    @Test
    fun `countdown card expires just after the due time, so a late repost can never leave a long negative time`() {
        val now = 1_000_000L
        val eod = now + 5 * 3_600_000L
        // due in 5 minutes: removed 2 s after the due moment if the due-now repost never came
        assertEquals(
            300_000L + TaskReminderCard.COUNTDOWN_GRACE_MS,
            TaskReminderCard.timeoutAfterMs(TaskReminderCard.BODY_BEFORE, now + 300_000L, now, eod)
        )
        assertEquals(2_000L, TaskReminderCard.COUNTDOWN_GRACE_MS)
        // never zero or negative (a timeout of 0 means "no timeout")
        assertTrue(TaskReminderCard.timeoutAfterMs(TaskReminderCard.BODY_BEFORE, now + 1, now, eod) >= 1_000L)
    }

    @Test
    fun `ongoing card still expires - due now 30 minutes after the due time, today and pending at the end of the day`() {
        val now = 1_000_000L
        val eod = now + 5 * 3_600_000L
        assertEquals(30 * 60_000L, TaskReminderCard.timeoutAfterMs(TaskReminderCard.BODY_DUE_NOW, 0L, now, eod))
        assertEquals(30 * 60_000L, TaskReminderCard.DUE_NOW_TIMEOUT_MS)
        assertEquals(5 * 3_600_000L, TaskReminderCard.timeoutAfterMs(TaskReminderCard.BODY_TODAY, 0L, now, eod))
        assertEquals(5 * 3_600_000L, TaskReminderCard.timeoutAfterMs(TaskReminderCard.BODY_PENDING, 0L, now, eod))
        assertEquals(5 * 3_600_000L, TaskReminderCard.timeoutAfterMs(null, 0L, now, eod)) // alarm armed before TC1
        // posted a moment before midnight: at least one minute, never zero
        assertEquals(60_000L, TaskReminderCard.timeoutAfterMs(TaskReminderCard.BODY_TODAY, 0L, now, now + 5_000L))
    }

    @Test
    fun `due-now repost shows the body and hides the countdown (a re-applied RemoteViews keeps old view states)`() {
        // countdown card
        assertEquals(TaskReminderCard.Mode.COUNTDOWN, TaskReminderCard.modeFor(true))
        // every other card must explicitly reset the two views, because SystemUI re-applies the update on the
        // existing view and only touches what the new RemoteViews sets
        assertEquals(TaskReminderCard.Mode.TEXT, TaskReminderCard.modeFor(false))
    }

    // ---- TC1: the lock-screen public version keeps the buttons and the timer, only the title is generic ----

    @Test
    fun `public version differs from the full card only by the title, which never names the task`() {
        assertEquals("Buy milk", TaskReminderCard.titleFor(false, "Buy milk", false))
        assertEquals("Aura - Task reminder", TaskReminderCard.titleFor(true, "Buy milk", false))
        assertEquals("هالة - تذكير بمهمة", TaskReminderCard.titleFor(true, "اشتري حليب", true))
        assertEquals("اشتري حليب", TaskReminderCard.titleFor(false, "اشتري حليب", true))
    }
}
