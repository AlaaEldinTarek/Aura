package com.aura.hala

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar
import java.util.Locale

class DailySummaryReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "DailySummaryReceiver"
        private const val ACTION = "com.aura.hala.DAILY_PRAYER_SUMMARY"
        private const val REQUEST_CODE = 7001
        internal val PRAYER_NAMES = listOf("Fajr", "Zuhr", "Asr", "Maghrib", "Isha")

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

        /** YYYY-MM-DD key for prayer_status_* prefs; Locale.US like the writers (F51a: never device digits). */
        internal fun dateKey(cal: Calendar): String = String.format(
            Locale.US, "%04d-%02d-%02d",
            cal.get(Calendar.YEAR), cal.get(Calendar.MONTH) + 1, cal.get(Calendar.DAY_OF_MONTH)
        )

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

        // Housekeeping: prayer_status_* keys are kept as "synced" forever otherwise
        pruneOldPrayerStatuses(context)

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

        val trackingEnabled = FlutterPrefs.getBoolean(context, "prayer_tracking_notifications_enabled", true)
        if (!trackingEnabled) {
            Log.d(TAG, "📅 Tracking disabled, skipping summary")
            rescheduleForTomorrow(context)
            return
        }

        val today = todayDateKey()
        val prayerPrefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
        val untracked = DailySummaryCard.untrackedNames(PRAYER_NAMES) { name ->
            prayerPrefs.contains("prayer_status_${name}_$today")
        }

        if (untracked.isEmpty()) {
            Log.d(TAG, "📅 All prayers tracked today, no notification needed")
            rescheduleForTomorrow(context)
            return
        }

        // Themed card (T3): app theme + language, Arabic numerals, tap opens Prayer Tracking (unchanged)
        DailySummaryCard.show(context, untracked.size, null)

        rescheduleForTomorrow(context)
    }

    private fun rescheduleForTomorrow(context: Context) {
        val timeStr = FlutterPrefs.getString(context, "daily_summary_time", "21:00")
        schedule(context, timeStr)
    }

    private fun todayDateKey(): String = dateKey(Calendar.getInstance())

    /** Remove prayer_status_{name}_{YYYY-MM-DD} keys older than 7 days. */
    private fun pruneOldPrayerStatuses(context: Context) {
        val prefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
        val cutoffCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -7) }
        val cutoff = dateKey(cutoffCal)
        val editor = prefs.edit()
        var removed = 0
        for (key in prefs.all.keys) {
            if (!key.startsWith("prayer_status_")) continue
            val date = key.substringAfterLast('_')
            // ISO dates compare correctly as strings
            if (date.length == 10 && date < cutoff) {
                editor.remove(key)
                removed++
            }
        }
        if (removed > 0) {
            editor.apply()
            Log.d(TAG, "🧹 Pruned $removed prayer status keys older than $cutoff")
        }
    }
}
