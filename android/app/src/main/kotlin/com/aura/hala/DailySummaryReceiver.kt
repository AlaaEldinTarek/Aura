package com.aura.hala

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.util.Calendar

class DailySummaryReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "DailySummaryReceiver"
        private const val ACTION = "com.aura.hala.DAILY_PRAYER_SUMMARY"
        private const val NOTIFICATION_ID = 7001
        private const val REQUEST_CODE = 7001
        private val PRAYER_NAMES = listOf("Fajr", "Zuhr", "Asr", "Maghrib", "Isha")

        fun schedule(context: Context, timeStr: String) {
            val parts = timeStr.split(":")
            val hour = parts.getOrNull(0)?.toIntOrNull() ?: 21
            val minute = parts.getOrNull(1)?.toIntOrNull() ?: 0

            val calendar = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                if (timeInMillis <= System.currentTimeMillis()) {
                    add(Calendar.DAY_OF_YEAR, 1)
                }
            }

            val intent = Intent(context, DailySummaryReceiver::class.java).apply {
                action = ACTION
            }
            val pending = PendingIntent.getBroadcast(
                context, REQUEST_CODE, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pending)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pending)
            }
            Log.d(TAG, "📅 Daily summary scheduled for ${String.format("%02d:%02d", hour, minute)}")
        }

        fun cancel(context: Context) {
            val intent = Intent(context, DailySummaryReceiver::class.java).apply { action = ACTION }
            val pending = PendingIntent.getBroadcast(
                context, REQUEST_CODE, intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            pending?.let {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                alarmManager.cancel(it)
                it.cancel()
                Log.d(TAG, "📅 Daily summary cancelled")
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION) return
        Log.d(TAG, "📅 Daily summary receiver fired")

        // Ensure channel exists — receiver fires without app being open
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel("prayer_tracking") == null) {
                val ch = android.app.NotificationChannel(
                    "prayer_tracking", "Prayer Tracking",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply { description = "Post-prayer check and daily summary" }
                nm.createNotificationChannel(ch)
            }
        }

        val flutterPrefs = context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)
        val trackingEnabled = flutterPrefs.getBoolean("prayer_tracking_notifications_enabled", true)
        if (!trackingEnabled) {
            Log.d(TAG, "📅 Tracking disabled, skipping summary")
            rescheduleForTomorrow(context)
            return
        }

        val today = todayDateKey()
        val prayerPrefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
        val untracked = PRAYER_NAMES.filter { name ->
            val key = "prayer_status_${name}_$today"
            !prayerPrefs.contains(key)
        }

        if (untracked.isEmpty()) {
            Log.d(TAG, "📅 All prayers tracked today, no notification needed")
            rescheduleForTomorrow(context)
            return
        }

        val language = flutterPrefs.getString("language", "en") ?: "en"
        val isArabic = language == "ar"
        val count = untracked.size

        val title = if (isArabic) "تذكير الصلاة اليومي" else "Daily Prayer Reminder"
        val body = if (isArabic) {
            "لديك $count ${if (count == 1) "صلاة" else "صلوات"} لم تُسجَّل اليوم"
        } else {
            "You have $count untracked ${if (count == 1) "prayer" else "prayers"} today"
        }

        val tapIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("route", "/prayer_tracking")
        }
        val tapPending = PendingIntent.getActivity(
            context, NOTIFICATION_ID, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, "prayer_tracking")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(tapPending)

        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, builder.build())
            Log.d(TAG, "📅 Daily summary shown: $count untracked prayers")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to show daily summary: ${e.message}")
        }

        rescheduleForTomorrow(context)
    }

    private fun rescheduleForTomorrow(context: Context) {
        val flutterPrefs = context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)
        val timeStr = flutterPrefs.getString("daily_summary_time", "21:00") ?: "21:00"
        schedule(context, timeStr)
    }

    private fun todayDateKey(): String {
        val cal = Calendar.getInstance()
        return "${cal.get(Calendar.YEAR)}-${String.format("%02d", cal.get(Calendar.MONTH) + 1)}-${String.format("%02d", cal.get(Calendar.DAY_OF_MONTH))}"
    }
}
