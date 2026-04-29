package com.aura.hala

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.text.format.DateFormat
import android.util.Log
import androidx.core.app.NotificationCompat
import com.aura.hala.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.Date

/**
 * Service that reschedules prayer time alarms
 * Runs in the background to calculate and schedule all prayer times
 */
class PrayerRescheduleService : Service() {

    companion object {
        private const val TAG = "PrayerRescheduleService"
        private const val NOTIFICATION_ID = 2000
        private const val CHANNEL_ID = "prayer_reschedule"
        private const val CHANNEL_NAME = "Prayer Reschedule"
    }

    private val serviceScope = CoroutineScope(Dispatchers.IO + Job())
    private var isRunning = false

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service started")

        if (!isRunning) {
            isRunning = true
            startForeground(NOTIFICATION_ID, createNotification())

            serviceScope.launch {
                try {
                    rescheduleAllPrayers()
                    delay(1000) // Brief delay to ensure all alarms are set
                } finally {
                    stopSelf()
                    isRunning = false
                }
            }
        }

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
    }

    private fun createNotificationChannel() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Reschedules prayer time notifications"
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Rescheduling Prayers")
            .setContentText("Setting up prayer time alarms...")
            .setSmallIcon(R.drawable.ic_notification)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    /**
     * Reschedule prayer alarms using real times saved by Flutter in aura_prayer_times.
     * Never uses placeholder times — inaccurate placeholders caused double adhan when
     * a placeholder fired after the real prayer had already played.
     */
    private suspend fun rescheduleAllPrayers() {
        Log.d(TAG, "Rescheduling prayer alarms from saved real times")

        val prayerPrefs = getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()

        // Prayers as stored by Flutter's PrayerWidgetService (key → English name, Arabic name)
        val prayerMap = listOf(
            Triple("fajr_time",    "Fajr",    "الفجر"),
            Triple("dhuhr_time",   "Zuhr",    "الظهر"),
            Triple("asr_time",     "Asr",     "العصر"),
            Triple("maghrib_time", "Maghrib", "المغرب"),
            Triple("isha_time",    "Isha",    "العشاء")
        )

        var scheduled = 0
        for ((key, name, nameAr) in prayerMap) {
            val timeMs = prayerPrefs.getString(key, null)?.toLongOrNull() ?: continue
            if (timeMs <= now) {
                Log.d(TAG, "⏭️ [RESCHEDULE] $name already passed ($key), skipping")
                continue
            }
            PrayerAlarmReceiver.schedulePrayerAlarm(
                this, name, nameAr, timeMs,
                PrayerAlarmReceiver.getNotificationId(name)
            )
            Log.d(TAG, "✅ [RESCHEDULE] $name → ${DateFormat.format("HH:mm", Date(timeMs))}")
            scheduled++
            delay(100)
        }

        if (scheduled == 0) {
            Log.w(TAG, "⚠️ [RESCHEDULE] No real prayer times found in aura_prayer_times — Flutter will reschedule on next launch")
        } else {
            Log.d(TAG, "✅ [RESCHEDULE] Scheduled $scheduled prayer alarms from real times")
        }
    }

    // Kept as dead code reference only — replaced by reading real times from SharedPreferences
    @Suppress("unused")
    private fun calculatePrayerTimes(dateMillis: Long, latitude: Double, longitude: Double): List<PrayerTime> {
        val calendar = java.util.Calendar.getInstance()
        calendar.timeInMillis = dateMillis
        val baseTime = calendar.apply {
            set(java.util.Calendar.HOUR_OF_DAY, 6)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
        }.timeInMillis
        return listOf(
            PrayerTime("Fajr", "الفجر", baseTime),
            PrayerTime("Sunrise", "الشروق", baseTime + 1800000),
            PrayerTime("Zuhr", "الظهر", baseTime + 21600000),
            PrayerTime("Asr", "العصر", baseTime + 36000000),
            PrayerTime("Maghrib", "المغرب", baseTime + 46800000),
            PrayerTime("Isha", "العشاء", baseTime + 57600000)          // 8:00 PM
        )
    }

    data class PrayerTime(
        val name: String,
        val nameAr: String,
        val time: Long
    )
}
