package com.aura.hala

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import kotlin.math.abs

/**
 * BroadcastReceiver for Focus Mode.
 *
 * Uses notification with fullScreenIntent (same pattern as Adhan)
 * to reliably show over lock screen on ALL devices including Huawei/EMUI.
 * Also starts FocusModeService for guaranteed persistence.
 */
class FocusModeReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "FocusModeReceiver"
        const val EXTRA_TASK_ID = "task_id"
        const val EXTRA_TASK_TITLE = "task_title"
        const val EXTRA_TASK_DESC = "task_desc"
        const val EXTRA_DURATION_MINUTES = "duration_minutes"
        const val EXTRA_LANGUAGE = "language"

        private const val ACTION_FOCUS_ALARM = "com.aura.hala.FOCUS_MODE_ALARM"
        const val ACTION_FOCUS_COMPLETE = "com.aura.hala.FOCUS_TASK_COMPLETE"

        private const val REQUEST_CODE_BASE = 5000
        private const val FOCUS_NOTIFICATION_CHANNEL = "focus_mode"
        private const val FOCUS_NOTIFICATION_ID = 5999

        fun scheduleFocusAlarm(
            context: Context,
            taskId: String,
            taskTitle: String,
            taskDesc: String,
            triggerTimeMillis: Long,
            durationMinutes: Int,
            language: String
        ) {
            val requestCode = REQUEST_CODE_BASE + abs(taskId.hashCode() % 1000)

            val intent = Intent(context, FocusModeReceiver::class.java).apply {
                action = ACTION_FOCUS_ALARM
                putExtra(EXTRA_TASK_ID, taskId)
                putExtra(EXTRA_TASK_TITLE, taskTitle)
                putExtra(EXTRA_TASK_DESC, taskDesc)
                putExtra(EXTRA_DURATION_MINUTES, durationMinutes)
                putExtra(EXTRA_LANGUAGE, language)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTimeMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerTimeMillis,
                    pendingIntent
                )
            }

            Log.d(TAG, "🎯 [FOCUS] Scheduled alarm for '$taskTitle' at $triggerTimeMillis (duration=${durationMinutes}min)")
        }

        fun cancelFocusAlarm(context: Context, taskId: String) {
            val requestCode = REQUEST_CODE_BASE + abs(taskId.hashCode() % 1000)
            val intent = Intent(context, FocusModeReceiver::class.java).apply {
                action = ACTION_FOCUS_ALARM
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pendingIntent != null) {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
                Log.d(TAG, "🗑️ [FOCUS] Cancelled alarm for task $taskId")
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_FOCUS_ALARM -> {
                val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: return
                val taskTitle = intent.getStringExtra(EXTRA_TASK_TITLE) ?: "Focus Mode"
                val taskDesc = intent.getStringExtra(EXTRA_TASK_DESC) ?: ""
                val durationMinutes = intent.getIntExtra(EXTRA_DURATION_MINUTES, 25)
                val language = intent.getStringExtra(EXTRA_LANGUAGE) ?: "en"

                Log.d(TAG, "🎯 [FOCUS] Alarm triggered for task: $taskTitle")

                // 1. Start the foreground service FIRST (most important for persistence)
                FocusModeService.start(
                    context, taskId, taskTitle, taskDesc, durationMinutes, language
                )

                // 2. Create notification channel
                createNotificationChannel(context)

                // 3. Build full-screen intent (just for the notification, not for launching)
                val focusIntent = Intent(context, FocusModeActivity::class.java).apply {
                    putExtra(FocusModeActivity.EXTRA_TASK_ID, taskId)
                    putExtra(FocusModeActivity.EXTRA_TASK_TITLE, taskTitle)
                    putExtra(FocusModeActivity.EXTRA_TASK_DESC, taskDesc)
                    putExtra(FocusModeActivity.EXTRA_DURATION_MINUTES, durationMinutes)
                    putExtra(FocusModeActivity.EXTRA_LANGUAGE, language)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TASK
                }

                val fullScreenPendingIntent = PendingIntent.getActivity(
                    context,
                    FOCUS_NOTIFICATION_ID,
                    focusIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                // 4. Build high-priority notification with fullScreenIntent
                val isArabic = language == "ar"
                val builder = NotificationCompat.Builder(context, FOCUS_NOTIFICATION_CHANNEL)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle(if (isArabic) "وضع التركيز" else "Focus Mode")
                    .setContentText(if (isArabic) taskTitle else taskTitle)
                    .setPriority(NotificationCompat.PRIORITY_MAX)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setAutoCancel(true)
                    .setFullScreenIntent(fullScreenPendingIntent, true)
                    .setContentIntent(fullScreenPendingIntent)

                // 5. Show notification
                val notificationManager = NotificationManagerCompat.from(context)
                try {
                    notificationManager.notify(FOCUS_NOTIFICATION_ID, builder.build())
                    Log.d(TAG, "✅ [FOCUS] Notification with fullScreenIntent shown")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ [FOCUS] Notification failed: ${e.message}")
                }

                // 6. Launch directly (belt and suspenders)
                try {
                    context.startActivity(focusIntent)
                    Log.d(TAG, "✅ [FOCUS] FocusModeActivity launched directly")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ [FOCUS] Direct launch failed: ${e.message}")
                }
            }

            ACTION_FOCUS_COMPLETE -> {
                val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: return
                Log.d(TAG, "✅ [FOCUS] Task completed: $taskId")

                // Stop the foreground service
                FocusModeService.stop(context)

                // Cancel the notification
                val notificationManager = NotificationManagerCompat.from(context)
                notificationManager.cancel(FOCUS_NOTIFICATION_ID)

                // Save completion to SharedPreferences
                val prefs = context.getSharedPreferences("aura_focus_mode", Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("completed_task_id", taskId)
                    .putLong("completed_at", System.currentTimeMillis())
                    .apply()

                // Send broadcast to Flutter
                val flutterIntent = Intent("com.aura.hala.FOCUS_TASK_DONE")
                flutterIntent.setPackage(context.packageName)
                flutterIntent.putExtra(EXTRA_TASK_ID, taskId)
                context.sendBroadcast(flutterIntent)

                Log.d(TAG, "✅ [FOCUS] Task completion broadcast sent")
            }
        }
    }

    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                FOCUS_NOTIFICATION_CHANNEL,
                "Focus Mode",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Focus mode notifications"
                enableVibration(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
            Log.d(TAG, "✅ [FOCUS] Notification channel created")
        }
    }
}
