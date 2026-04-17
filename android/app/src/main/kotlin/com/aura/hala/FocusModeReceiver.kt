package com.aura.hala

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import kotlin.math.abs

/**
 * BroadcastReceiver for Focus Mode.
 *
 * Two roles:
 * 1. Triggered by AlarmManager at task time → launches FocusModeActivity
 * 2. Receives "task complete" broadcast from FocusModeActivity → notifies Flutter
 *
 * Universal compatibility: uses FLAG_IMMUTABLE for Android 12+,
 * setExactAndAllowWhileIdle for reliable wake-up on all OEMs.
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

        // Request code base for focus mode alarms (5000-5999)
        private const val REQUEST_CODE_BASE = 5000

        /**
         * Schedule a focus mode alarm at the given time.
         * Works on all Android versions and OEM devices.
         */
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

            // Use exact alarm that wakes the device
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

        /**
         * Cancel a scheduled focus mode alarm.
         */
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

                // Launch full-screen focus mode activity
                val focusIntent = Intent(context, FocusModeActivity::class.java).apply {
                    putExtra(FocusModeActivity.EXTRA_TASK_ID, taskId)
                    putExtra(FocusModeActivity.EXTRA_TASK_TITLE, taskTitle)
                    putExtra(FocusModeActivity.EXTRA_TASK_DESC, taskDesc)
                    putExtra(FocusModeActivity.EXTRA_DURATION_MINUTES, durationMinutes)
                    putExtra(FocusModeActivity.EXTRA_LANGUAGE, language)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
                }
                context.startActivity(focusIntent)

                Log.d(TAG, "✅ [FOCUS] FocusModeActivity launched")
            }

            ACTION_FOCUS_COMPLETE -> {
                val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: return
                Log.d(TAG, "✅ [FOCUS] Task completed: $taskId")

                // Notify Flutter via SharedPreferences that task is completed
                val prefs = context.getSharedPreferences("aura_focus_mode", Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("completed_task_id", taskId)
                    .putLong("completed_at", System.currentTimeMillis())
                    .apply()

                // Send broadcast to Flutter (via MainActivity)
                val flutterIntent = Intent("com.aura.hala.FOCUS_TASK_DONE")
                flutterIntent.setPackage(context.packageName)
                flutterIntent.putExtra(EXTRA_TASK_ID, taskId)
                context.sendBroadcast(flutterIntent)

                Log.d(TAG, "✅ [FOCUS] Task completion broadcast sent")
            }
        }
    }
}
