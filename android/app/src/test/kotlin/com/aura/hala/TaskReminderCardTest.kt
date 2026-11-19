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
}
