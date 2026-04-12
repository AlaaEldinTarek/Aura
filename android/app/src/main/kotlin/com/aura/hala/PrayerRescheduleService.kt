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
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    /**
     * Reschedule all prayer alarms for today and tomorrow
     */
    private suspend fun rescheduleAllPrayers() {
        Log.d(TAG, "Rescheduling all prayer alarms")

        val sharedPrefs = getSharedPreferences("aura_prefs", Context.MODE_PRIVATE)

        // Get saved location
        val latitude = sharedPrefs.getFloat("saved_latitude", 0.0f).toDouble()
        val longitude = sharedPrefs.getFloat("saved_longitude", 0.0f).toDouble()

        if (latitude == 0.0 || longitude == 0.0) {
            Log.w(TAG, "No saved location, skipping prayer schedule")
            return
        }

        // Get calculation method preference
        val calculationMethod = sharedPrefs.getString("calculation_method", "muslim_world_league") ?: "muslim_world_league"

        Log.d(TAG, "Using location: $latitude, $longitude")
        Log.d(TAG, "Using calculation method: $calculationMethod")

        // Get prayer times for today (this would use a prayer calculation library)
        // For now, we'll create placeholder times
        val now = System.currentTimeMillis()
        val prayerTimes = calculatePrayerTimes(now, latitude, longitude)

        // Schedule each prayer alarm
        for (prayer in prayerTimes) {
            if (prayer.time > now) {
                PrayerAlarmReceiver.schedulePrayerAlarm(
                    this,
                    prayer.name,
                    prayer.nameAr,
                    prayer.time,
                    PrayerAlarmReceiver.getNotificationId(prayer.name)
                )
                val timeStr = DateFormat.format("HH:mm", Date(prayer.time))
                Log.d(TAG, "Scheduled ${prayer.name} for $timeStr")
                delay(100) // Small delay between scheduling
            }
        }

        Log.d(TAG, "All prayer alarms rescheduled")
    }

    /**
     * Calculate prayer times for a given date
     * This is a simplified version - in production, use a proper prayer calculation library
     */
    private fun calculatePrayerTimes(dateMillis: Long, latitude: Double, longitude: Double): List<PrayerTime> {
        val calendar = java.util.Calendar.getInstance()
        calendar.timeInMillis = dateMillis

        // Simplified prayer time calculations
        // In production, use the Adhan library or similar
        val baseTime = calendar.apply {
            set(java.util.Calendar.HOUR_OF_DAY, 6)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
        }.timeInMillis

        return listOf(
            PrayerTime("Fajr", "الفجر", baseTime),                      // 6:00 AM
            PrayerTime("Sunrise", "الشروق", baseTime + 1800000),      // 6:30 AM
            PrayerTime("Zuhr", "الظهر", baseTime + 21600000),        // 12:00 PM
            PrayerTime("Asr", "العصر", baseTime + 36000000),          // 4:00 PM
            PrayerTime("Maghrib", "المغرب", baseTime + 46800000),     // 6:00 PM
            PrayerTime("Isha", "العشاء", baseTime + 57600000)          // 8:00 PM
        )
    }

    data class PrayerTime(
        val name: String,
        val nameAr: String,
        val time: Long
    )
}
