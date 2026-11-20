package com.aura.hala

import org.junit.Assert.assertEquals
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
        assertEquals("ذكرني لاحقاً", TaskReminderCard.snoozeLabel(true))
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
}
