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
        const val EXTRA_NOTIFICATION_ID = "notification_id"
        const val EXTRA_TASK_ID = "task_id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_IS_ARABIC = "is_arabic"

        private const val SNOOZE_MINUTES = 30

        fun schedule(
            context: Context,
            notificationId: Int,
            taskId: String,
            title: String,
            body: String,
            triggerAtMs: Long,
            isArabic: Boolean
        ) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, TaskReminderReceiver::class.java).apply {
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
                putExtra(EXTRA_TASK_ID, taskId)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_IS_ARABIC, isArabic)
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

        fun cancel(context: Context, notificationId: Int) {
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
        val title = intent.getStringExtra(EXTRA_TITLE) ?: return
        val body = intent.getStringExtra(EXTRA_BODY) ?: ""
        val isArabic = intent.getBooleanExtra(EXTRA_IS_ARABIC, false)

        if (intent.action == ACTION_SNOOZE) {
            // "Remind Later" → dismiss and re-arm in 30 minutes, no app launch
            NotificationManagerCompat.from(context).cancel(notificationId)
            schedule(
                context, notificationId, taskId, title,
                if (isArabic) "لا تزال المهمة معلقة" else "Your task is still pending",
                System.currentTimeMillis() + SNOOZE_MINUTES * 60 * 1000L,
                isArabic
            )
            Log.d(TAG, "🔕 Task reminder snoozed $SNOOZE_MINUTES min id=$notificationId")
            return
        }

        Log.d(TAG, "🔔 Task reminder fired id=$notificationId task=$taskId")
        ensureChannel(context)

        // Tap → open the app on the Tasks tab (handleWidgetTabIntent reads this extra)
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("widget_target_tab", 3)
        }
        val tapPending = PendingIntent.getActivity(
            context, notificationId + 1, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val snoozeIntent = Intent(context, TaskReminderReceiver::class.java).apply {
            action = ACTION_SNOOZE
            putExtra(EXTRA_NOTIFICATION_ID, notificationId)
            putExtra(EXTRA_TASK_ID, taskId)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_IS_ARABIC, isArabic)
        }
        val snoozePending = PendingIntent.getBroadcast(
            context, notificationId + 2, snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(tapPending)
            .addAction(0, if (isArabic) "ذكرني لاحقاً" else "Remind Later", snoozePending)

        try {
            NotificationManagerCompat.from(context).notify(notificationId, builder.build())
            Log.d(TAG, "✅ Task reminder posted id=$notificationId")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error posting task reminder: ${e.message}")
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
