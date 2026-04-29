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
import java.util.Calendar

class JumuahReminderReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "JumuahReminder"
        private const val NOTIFICATION_ID = 8001
        private const val CHANNEL_ID = "jumuah_reminder"
        private const val REQUEST_CODE = 8001

        fun schedule(context: Context) {
            val flutterPrefs = context.getSharedPreferences(
                "${context.packageName}_preferences", Context.MODE_PRIVATE
            )
            val enabled = flutterPrefs.getBoolean("jumua_reminder_enabled", true)
            if (!enabled) {
                Log.d(TAG, "Jumu'ah reminder disabled, skipping schedule")
                return
            }

            // Read today's Zuhr time (epoch millis) from aura_prayer_times
            val prayerPrefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
            val zuhrMillis = prayerPrefs.getLong("dhuhr_time", 0L)

            var remHour: Int
            var remMinute: Int

            if (zuhrMillis > 0) {
                val zuhrCal = Calendar.getInstance().apply { timeInMillis = zuhrMillis }
                remHour = zuhrCal.get(Calendar.HOUR_OF_DAY)
                remMinute = zuhrCal.get(Calendar.MINUTE) - 30
                if (remMinute < 0) {
                    remMinute += 60
                    remHour -= 1
                    if (remHour < 0) remHour = 23
                }
            } else {
                // Default: 11:30 AM if no Zuhr time stored yet
                remHour = 11
                remMinute = 30
            }

            val cal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, remHour)
                set(Calendar.MINUTE, remMinute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

            // Advance to next Friday
            while (cal.get(Calendar.DAY_OF_WEEK) != Calendar.FRIDAY) {
                cal.add(Calendar.DAY_OF_MONTH, 1)
            }
            // If that Friday time has already passed, jump one more week
            if (cal.timeInMillis <= System.currentTimeMillis()) {
                cal.add(Calendar.WEEK_OF_YEAR, 1)
            }

            val intent = Intent(context, JumuahReminderReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context, REQUEST_CODE, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, cal.timeInMillis, pendingIntent
                    )
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pendingIntent)
                }
                Log.d(TAG, "✅ Jumu'ah reminder scheduled for ${cal.time} ($remHour:${remMinute.toString().padStart(2,'0')})")
            } catch (e: SecurityException) {
                // Fallback for devices without exact alarm permission
                alarmManager.set(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pendingIntent)
                Log.d(TAG, "⚠️ Jumu'ah reminder scheduled (inexact) for ${cal.time}")
            }
        }

        fun cancel(context: Context) {
            val intent = Intent(context, JumuahReminderReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context, REQUEST_CODE, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(pendingIntent)
            Log.d(TAG, "✅ Jumu'ah reminder cancelled")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val flutterPrefs = context.getSharedPreferences(
            "${context.packageName}_preferences", Context.MODE_PRIVATE
        )
        if (!flutterPrefs.getBoolean("jumua_reminder_enabled", true)) return

        val prayerPrefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
        val isArabic = (prayerPrefs.getString("language", "en") ?: "en") == "ar"

        showNotification(context, isArabic)

        // Self-reschedule for next Friday
        schedule(context)
    }

    private fun showNotification(context: Context, isArabic: Boolean) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Jumu'ah Reminder",
                NotificationManager.IMPORTANCE_HIGH
            ).apply { description = "Weekly Friday prayer reminder" }
            notificationManager.createNotificationChannel(channel)
        }

        val title = if (isArabic) "جمعة مباركة 🕌" else "Jumu'ah Mubarak 🕌"
        val body = if (isArabic)
            "اقترب وقت صلاة الجمعة، لا تفوّتها"
        else
            "Friday prayer time is approaching. Don't miss it!"

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
        Log.d(TAG, "✅ Jumu'ah notification shown")
    }
}
