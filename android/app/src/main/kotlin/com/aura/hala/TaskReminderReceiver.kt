package com.aura.hala

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.text.format.DateFormat
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.aura.hala.R
import java.util.Date

/**
 * Native delivery for task reminders.
 *
 * flutter_local_notifications schedules its alarms against its own receiver
 * (com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver).
 * Huawei/EMUI power management silently drops those broadcasts at the queue
 * level (enqueued + finished in the same millisecond, never dispatched),
 * while broadcasts to receivers in OUR package (PrayerAlarmReceiver etc.)
 * are delivered. So task reminders are scheduled against this receiver
 * instead. All timing/language logic stays in Dart — the final title/body
 * arrive ready-made as intent extras.
 */
class TaskReminderReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "TaskReminderReceiver"

        // Same channel id the Flutter plugin used, so the user's existing
        // channel settings (sound/importance) carry over.
        const val CHANNEL_ID = "task_reminders"

        const val ACTION_SNOOZE = "com.aura.hala.TASK_REMIND_LATER"
        const val ACTION_DONE = "com.aura.hala.TASK_DONE"
        const val ACTION_DUE_NOW = "com.aura.hala.TASK_DUE_NOW"
        const val EXTRA_DUE_AT = "due_at"
        const val EXTRA_BODY_KIND = "body_kind"
        const val EXTRA_BODY_MINUTES = "body_minutes"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
        const val EXTRA_TASK_ID = "task_id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_IS_ARABIC = "is_arabic"

        fun schedule(
            context: Context,
            notificationId: Int,
            taskId: String,
            title: String,
            body: String,
            triggerAtMs: Long,
            isArabic: Boolean,
            bodyKind: String? = null,
            bodyMinutes: Int = 0,
            dueAtMs: Long = 0L
        ) {
            // A new reminder (first arm, edit, Remind Later) replaces any due-now repost armed for the old card
            cancelDueNow(context, notificationId)
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, TaskReminderReceiver::class.java).apply {
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
                putExtra(EXTRA_TASK_ID, taskId)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_IS_ARABIC, isArabic)
                if (bodyKind != null) putExtra(EXTRA_BODY_KIND, bodyKind)
                putExtra(EXTRA_BODY_MINUTES, bodyMinutes)
                putExtra(EXTRA_DUE_AT, dueAtMs)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context, notificationId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
            }
            Log.d(TAG, "⏰ Task reminder scheduled id=$notificationId at ${DateFormat.format("MM-dd HH:mm", Date(triggerAtMs))}")
        }

        /** TC1: silent "due now" re-post of the card at the task's due time (request code id+4, action TASK_DUE_NOW). */
        fun scheduleDueNow(context: Context, notificationId: Int, taskId: String, title: String, body: String, dueAtMs: Long) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, TaskReminderReceiver::class.java).apply {
                action = ACTION_DUE_NOW
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
                putExtra(EXTRA_TASK_ID, taskId)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context, TaskReminderCard.dueNowRequestCode(notificationId), intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, dueAtMs, pendingIntent)
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, dueAtMs, pendingIntent)
                }
                Log.d(TAG, "⏰ Task due-now repost scheduled id=$notificationId at ${DateFormat.format("MM-dd HH:mm:ss", Date(dueAtMs))}")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Could not schedule due-now repost: ${e.message}")
            }
        }

        fun cancelDueNow(context: Context, notificationId: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, TaskReminderReceiver::class.java).apply { action = ACTION_DUE_NOW }
            val pendingIntent = PendingIntent.getBroadcast(
                context, TaskReminderCard.dueNowRequestCode(notificationId), intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        }

        fun cancel(context: Context, notificationId: Int) {
            cancelDueNow(context, notificationId)
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, TaskReminderReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context, notificationId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
            NotificationManagerCompat.from(context).cancel(notificationId)
            Log.d(TAG, "🗑️ Task reminder cancelled id=$notificationId")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)
        val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: ""

        if (intent.action == ACTION_DONE) {
            // "Done" -> remove the card, cancel any pending Remind Later alarm (same request code) so no more
            // reminders come, and hand the task id to the app, which COMPLETES it (never un-completes) on its next
            // open or resume: same path as the Tasks widget (`pending_complete_task_id`, main_wrapper_screen.dart).
            cancel(context, notificationId)
            if (taskId.isNotBlank()) {
                FlutterPrefs.putString(
                    context, "pending_complete_task_id",
                    TaskReminderCard.addPendingDoneId(FlutterPrefs.getString(context, "pending_complete_task_id", ""), taskId)
                )
                FlutterPrefs.remove(context, "task_snoozed_until_$taskId")
            }
            Log.d(TAG, "✅ Task reminder Done id=$notificationId task=$taskId (completed by the app on its next open)")
            return
        }

        if (intent.action == ACTION_DUE_NOW) {
            // The due time has come: change the card that is still showing to "Task is due now" (same id, original
            // time, no new sound). A card the user already dismissed stays dismissed.
            val dueTitle = intent.getStringExtra(EXTRA_TITLE) ?: return
            val shownWhen = TaskReminderCard.shownWhen(context, notificationId)
            if (shownWhen == null) {
                Log.d(TAG, "⏭️ Task due now id=$notificationId: card no longer showing, nothing to update")
                return
            }
            TaskReminderCard.show(
                context, notificationId, taskId, dueTitle, intent.getStringExtra(EXTRA_BODY) ?: "",
                TaskReminderCard.BODY_DUE_NOW, 0, 0L, shownWhen
            )
            Log.d(TAG, "⏰ Task due now id=$notificationId: card switched to the due-now text")
            return
        }

        val title = intent.getStringExtra(EXTRA_TITLE) ?: return
        val body = intent.getStringExtra(EXTRA_BODY) ?: ""
        val isArabic = intent.getBooleanExtra(EXTRA_IS_ARABIC, false)

        if (intent.action == ACTION_SNOOZE) {
            // "Remind Later" -> dismiss and re-arm after the user's task reminder setting (read now, so a changed
            // setting applies), no app launch. Each press re-arms again.
            NotificationManagerCompat.from(context).cancel(notificationId)
            val snoozeMinutes = TaskReminderCard.snoozeDelayMinutes(
                FlutterPrefs.getInt(context, "task_reminder_minutes", TaskReminderCard.DEFAULT_REMINDER_MINUTES)
            )
            val triggerAt = System.currentTimeMillis() + snoozeMinutes * 60 * 1000L
            schedule(
                context, notificationId, taskId, title,
                if (isArabic) "لا تزال المهمة معلقة" else "Your task is still pending",
                triggerAt, isArabic, TaskReminderCard.BODY_PENDING, 0
            )
            // Tell Dart's bulk re-arm (rescheduleAllTaskReminders, edits) that a snooze owns this id, like the old
            // Dart snooze did (`task_snoozed_until_<id>`, read in NotificationService.scheduleTaskReminder).
            if (taskId.isNotBlank()) FlutterPrefs.putLong(context, "task_snoozed_until_$taskId", triggerAt)
            Log.d(TAG, "🔕 Task reminder snoozed $snoozeMinutes min id=$notificationId")
            return
        }

        Log.d(TAG, "🔔 Task reminder fired id=$notificationId task=$taskId")
        ensureChannel(context)

        // The card (layout by app theme and language, body in the app language, Done and Remind Later buttons) is
        // built in TaskReminderCard so a theme or language change can re-post it (themed notifications, T2/T2b).
        val kind = intent.getStringExtra(EXTRA_BODY_KIND)?.takeIf { it.isNotEmpty() }
        val dueAt = intent.getLongExtra(EXTRA_DUE_AT, 0L)
        TaskReminderCard.show(
            context, notificationId, taskId, title, body, kind,
            intent.getIntExtra(EXTRA_BODY_MINUTES, 0), dueAt, null
        )
        // Countdown card: switch it to "due now" at the due time (TC1)
        if (TaskReminderCard.showsCountdown(kind, dueAt, System.currentTimeMillis())) {
            scheduleDueNow(context, notificationId, taskId, title, body, dueAt)
        }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(CHANNEL_ID, "Task Reminders", NotificationManager.IMPORTANCE_HIGH).apply {
                        description = "Reminders for tasks with due dates"
                    }
                )
            }
        }
    }
}
