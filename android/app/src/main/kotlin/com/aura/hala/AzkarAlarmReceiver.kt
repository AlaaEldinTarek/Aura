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
import java.util.Date

/**
 * BroadcastReceiver that fires 10 minutes after iqama time finishes.
 * Launches AzkarFullScreenActivity (post-prayer azkar reminder).
 */
class AzkarAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AzkarAlarmReceiver"
        const val ACTION_AZKAR_ALARM = "com.aura.hala.AZKAR_ALARM"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_PRAYER_NAME_AR = "prayer_name_ar"

        private const val CHANNEL_ID = "azkar_reminder"
        private const val CHANNEL_NAME = "Post-Prayer Azkar"

        // Notification IDs 9001–9006
        fun getAzkarNotificationId(prayerName: String): Int = when (prayerName) {
            "Fajr"          -> 9001
            "Sunrise"       -> 9002
            "Dhuhr", "Zuhr" -> 9003
            "Asr"           -> 9004
            "Maghrib"       -> 9005
            "Isha"          -> 9006
            else            -> 9000
        }

        // Request codes use base offset 3000 for azkar alarms
        fun getAzkarRequestCode(prayerName: String): Int = when (prayerName) {
            "Fajr"          -> 3001
            "Sunrise"       -> 3002
            "Dhuhr", "Zuhr" -> 3003
            "Asr"           -> 3004
            "Maghrib"       -> 3005
            "Isha"          -> 3006
            else            -> 3000
        }

        /**
         * Schedule the azkar alarm.
         * triggerTimeMs = iqamaTimeMs + 10 min, or currentTime + 15 min if no iqama.
         */
        fun schedule(context: Context, prayerName: String, prayerNameAr: String, triggerTimeMs: Long) {
            val now = System.currentTimeMillis()
            if (triggerTimeMs <= now) {
                Log.w(TAG, "⚠️ [AZKAR] Trigger time already past for $prayerName, skipping")
                return
            }

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
                Log.w(TAG, "⚠️ [AZKAR] No exact alarm permission for $prayerName")
                return
            }

            val intent = Intent(context, AzkarAlarmReceiver::class.java).apply {
                action = ACTION_AZKAR_ALARM
                putExtra(EXTRA_PRAYER_NAME, prayerName)
                putExtra(EXTRA_PRAYER_NAME_AR, prayerNameAr)
            }

            val requestCode = getAzkarRequestCode(prayerName)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerTimeMs, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTimeMs, pendingIntent)
            }

            val triggerStr = DateFormat.format("HH:mm", Date(triggerTimeMs))
            val delayMin = (triggerTimeMs - now) / 1000 / 60
            Log.d(TAG, "✅ [AZKAR] Scheduled for $prayerName at $triggerStr ($delayMin min from now)")
        }

        fun cancel(context: Context, prayerName: String) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AzkarAlarmReceiver::class.java).apply {
                action = ACTION_AZKAR_ALARM
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                getAzkarRequestCode(prayerName),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
            Log.d(TAG, "❌ [AZKAR] Cancelled for $prayerName")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: return
        val prayerNameAr = intent.getStringExtra(EXTRA_PRAYER_NAME_AR) ?: prayerName

        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "🤲 [AZKAR] Alarm fired for $prayerName")

        ensureChannel(context)

        // Show a heads-up notification + launch full-screen activity
        val activityIntent = AzkarFullScreenActivity.getIntent(context, prayerName, prayerNameAr)
        val fullScreenPi = PendingIntent.getActivity(
            context,
            getAzkarRequestCode(prayerName),
            activityIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val prefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
        val isArabic = prefs.getString("language", "en") == "ar"

        val title = if (isArabic) "أذكار بعد الصلاة 🤲" else "Post-Prayer Azkar 🤲"
        val body  = if (isArabic) "حان وقت أذكار بعد صلاة $prayerNameAr" else "Time for post-prayer azkar after $prayerName"

        val notif = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setFullScreenIntent(fullScreenPi, true)
            .setContentIntent(fullScreenPi)
            .setTimeoutAfter(60_000)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(getAzkarNotificationId(prayerName), notif)
            Log.d(TAG, "📳 [AZKAR] Notification posted for $prayerName")
        } catch (e: SecurityException) {
            Log.w(TAG, "⚠️ [AZKAR] No POST_NOTIFICATIONS permission: ${e.message}")
        }

        // Launch the full-screen activity directly
        try {
            activityIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(activityIntent)
            Log.d(TAG, "✅ [AZKAR] Full-screen activity launched")
        } catch (e: Exception) {
            Log.e(TAG, "❌ [AZKAR] Failed to launch activity: ${e.message}")
        }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Reminder to perform post-prayer azkar"
                    enableVibration(true)
                }
                nm.createNotificationChannel(channel)
                Log.d(TAG, "✅ [AZKAR] Notification channel created")
            }
        }
    }
}
