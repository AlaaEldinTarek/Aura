package com.aura.hala

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.widget.RemoteViews
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StyleSpan
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.res.ResourcesCompat
import java.util.Date

class PrayerForegroundService : Service() {

    private val CHANNEL_ID = "prayer_foreground_channel_v4"
    // Use 9999 to avoid conflict with prayer alarm notifications (1001-1006)
    private val NOTIFICATION_ID = 9999
    private val UPDATE_INTERVAL = 1000L

    private var handler: Handler? = null
    private var updateRunnable: Runnable? = null

    private var nextPrayerName: String? = null
    private var nextPrayerNameAr: String? = null
    private var nextPrayerTime: Long? = null
    private var currentLanguage: String = "en"
    private var isPrayerDataLoaded: Boolean = false

    // Store all prayer times to automatically move to next prayer
    private var prayerTimes: MutableMap<String, Long> = mutableMapOf()

    companion object {
        private const val TAG = "PrayerForegroundService"
        @Volatile
        private var instance: PrayerForegroundService? = null

        fun getInstance(): PrayerForegroundService? = instance

        fun startService(context: Context) {
            val intent = Intent(context, PrayerForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, PrayerForegroundService::class.java)
            context.stopService(intent)
        }

        // Update prayer times from Flutter (called via MethodChannel)
        fun updatePrayerTimes(
            context: Context,
            prayerTimesMap: Map<String, String>,
            nextPrayer: String?,
            nextPrayerAr: String?,
            nextTime: Long?,
            language: String
        ) {
            val prefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
            val editor = prefs.edit()

            // Save all prayer times
            for ((key, value) in prayerTimesMap) {
                editor.putString(key, value)
            }

            // Save next prayer info
            if (nextPrayer != null) editor.putString("next_prayer_name", nextPrayer)
            if (nextPrayerAr != null) editor.putString("next_prayer_name_ar", nextPrayerAr)
            if (nextTime != null) editor.putString("next_prayer_time", nextTime.toString())
            editor.putString("language", language)

            editor.apply()

            Log.d(TAG, "Prayer times updated from Flutter: next prayer = $nextPrayer at $nextTime")
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        loadPrayerTimes()
        startForeground(NOTIFICATION_ID, createNotification())
        startCountdownUpdate()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Delete old channel to allow importance upgrade
            manager.deleteNotificationChannel(CHANNEL_ID)

            val channel = NotificationChannel(
                CHANNEL_ID,
                "Prayer Times Service",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Shows next prayer countdown"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null)       // No sound — updates every second
                enableVibration(false)     // No vibration on updates
            }

            manager.createNotificationChannel(channel)
        }
    }

    private fun loadPrayerTimes() {
        val prefs = getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
        nextPrayerName = prefs.getString("next_prayer_name", null)
        nextPrayerNameAr = prefs.getString("next_prayer_name_ar", null)
        nextPrayerTime = prefs.getString("next_prayer_time", null)?.toLongOrNull()
        currentLanguage = prefs.getString("language", "en") ?: "en"

        // Mark as loaded only if we have valid prayer data
        isPrayerDataLoaded = (nextPrayerName != null && nextPrayerTime != null)

        if (!isPrayerDataLoaded) {
            Log.w(TAG, "⚠️ [LOAD] Prayer data not loaded yet, showing loading state")
        } else {
            Log.d(TAG, "✅ [LOAD] Prayer data loaded: next = $nextPrayerName at $nextPrayerTime")
        }

        // Get current date (in days since epoch)
        val currentDay = System.currentTimeMillis() / 86400000
        var hasOldPrayerTimes = false

        // Load all prayer times for automatic transition
        val prayerNames = listOf("fajr_time", "sunrise_time", "dhuhr_time", "asr_time", "maghrib_time", "isha_time")
        for (prayerKey in prayerNames) {
            val timeStr = prefs.getString(prayerKey, null)
            if (timeStr != null) {
                val time = timeStr.toLongOrNull()
                if (time != null) {
                    val prayerDay = time / 86400000
                    // Check if prayer time is from a previous day (more than 1 day old)
                    if (prayerDay < currentDay - 1) {
                        hasOldPrayerTimes = true
                        Log.w(TAG, "Prayer time $prayerKey is from old date ($prayerDay vs $currentDay)")
                    }
                    prayerTimes[prayerKey] = time
                }
            }
        }

        // If we have old prayer times, clear them and trigger a reload from Flutter
        if (hasOldPrayerTimes) {
            Log.w(TAG, "Detected old prayer times, clearing cache and requesting Flutter update")
            prayerTimes.clear()
            isPrayerDataLoaded = false
            // Request Flutter to recalculate prayer times by launching MainActivity
            requestFlutterUpdate()
        }

        Log.d(TAG, "Loaded prayer times: ${prayerTimes.size} prayers")
    }

    // Check if we need to move to next prayer (called every update cycle)
    private fun checkAndUpdateNextPrayer() {
        // Skip if prayer data not loaded yet
        if (!isPrayerDataLoaded || nextPrayerTime == null) {
            // Try reloading prayer times in case Flutter updated them
            if (!isPrayerDataLoaded) {
                loadPrayerTimes()
            }
            return
        }

        val now = System.currentTimeMillis()

        // If current prayer time has passed, find the next one
        if (nextPrayerTime!! < now) {
            Log.d(TAG, "Current prayer time has passed, reloading and finding next prayer...")

            // Reload prayer times from SharedPreferences to ensure fresh data
            loadPrayerTimes()

            // Find the next prayer based on current time
            val nextPrayer = findNextPrayer(now)
            if (nextPrayer != null) {
                nextPrayerName = nextPrayer.first
                nextPrayerNameAr = nextPrayer.second
                nextPrayerTime = nextPrayer.third

                // Save to prefs for persistence
                val prefs = getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("next_prayer_name", nextPrayerName)
                    .putString("next_prayer_name_ar", nextPrayerNameAr)
                    .putString("next_prayer_time", nextPrayerTime.toString())
                    .apply()

                Log.d(TAG, "✅ [UPDATE] Updated to next prayer: $nextPrayerName at $nextPrayerTime (${nextPrayerTime?.let { Date(it) }})")
            } else {
                Log.w(TAG, "⚠️ [UPDATE] No next prayer found - prayer times may be invalid")
            }
        }
    }

    // Find the next prayer based on current time
    private fun findNextPrayer(currentTime: Long): Triple<String, String, Long>? {
        val prayerOrder = listOf(
            Triple("Fajr", "الفجر", "fajr_time"),
            Triple("Sunrise", "الشروق", "sunrise_time"),
            Triple("Zuhr", "الظهر", "dhuhr_time"),
            Triple("Asr", "العصر", "asr_time"),
            Triple("Maghrib", "المغرب", "maghrib_time"),
            Triple("Isha", "العشاء", "isha_time")
        )

        Log.d(TAG, "🔍 [FIND_NEXT] Current time: $currentTime (${Date(currentTime)})")

        // Find first prayer that hasn't passed yet
        for (prayer in prayerOrder) {
            val prayerTime = prayerTimes[prayer.third]
            if (prayerTime != null) {
                Log.d(TAG, "🔍 [FIND_NEXT] ${prayer.first}: $prayerTime (${Date(prayerTime)}) - isAfter: ${prayerTime > currentTime}")
                if (prayerTime > currentTime) {
                    Log.d(TAG, "✅ [FIND_NEXT] Found next prayer: ${prayer.first}")
                    return Triple(prayer.first, prayer.second, prayerTime)
                }
            } else {
                Log.d(TAG, "⚠️ [FIND_NEXT] ${prayer.first}: time is null")
            }
        }

        // If all prayers have passed, return Fajr for tomorrow
        val fajrTime = prayerTimes["fajr_time"]
        if (fajrTime != null) {
            // Check if fajrTime is from today or yesterday
            val fajrDate = fajrTime / 86400000
            val currentDate = currentTime / 86400000

            val tomorrowFajr = if (fajrDate < currentDate) {
                // Fajr time is from yesterday, add time to reach today first
                ((currentDate - fajrDate) * 86400000) + fajrTime + 86400000
            } else {
                // Fajr time is from today, add 24 hours
                fajrTime + 86400000
            }
            Log.d(TAG, "✅ [FIND_NEXT] All prayers passed, returning Fajr for tomorrow at $tomorrowFajr (${Date(tomorrowFajr)})")
            return Triple("Fajr", "الفجر", tomorrowFajr)
        }

        Log.w(TAG, "❌ [FIND_NEXT] No prayer times available!")
        return null
    }

    private fun startCountdownUpdate() {
        handler = Handler(Looper.getMainLooper())

        updateRunnable = object : Runnable {
            override fun run() {
                updateNotification()
                handler?.postDelayed(this, UPDATE_INTERVAL)
            }
        }

        handler?.post(updateRunnable!!)
    }

    private fun updateNotification() {
        // Check if we need to move to next prayer before updating notification
        checkAndUpdateNextPrayer()

        // Reload language from SharedPreferences to get latest preference
        val prefs = getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
        currentLanguage = prefs.getString("language", "en") ?: "en"

        val notification = createNotification()
        val manager = NotificationManagerCompat.from(this)
        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val primaryColor = 0xFF007DFF.toInt()

        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(pendingIntent)
            .setColor(primaryColor)
            .setShowWhen(false)

        // Show loading state if prayer data not loaded yet
        if (!isPrayerDataLoaded || nextPrayerName == null) {
            val loadingTitle = if (currentLanguage == "ar") {
                "جاري تحميل مواقيت الصلاة..."
            } else {
                "Loading prayer times..."
            }

            notificationBuilder
                .setContentTitle(loadingTitle)
                .setContentText("🕌 Aura App")

            Log.d(TAG, "📱 [NOTIFICATION] Showing loading state")
        } else {
            // Show countdown to next prayer with custom layout
            val (timeRemaining, timeString) = calculateTimeRemaining()

            val nextPrayerText = if (currentLanguage == "ar") {
                "الصلاة القادمة"
            } else {
                "Next Prayer"
            }

            val prayerName = if (currentLanguage == "ar") {
                nextPrayerNameAr ?: ""
            } else {
                nextPrayerName ?: ""
            }

            val untilText = if (currentLanguage == "ar") {
                "حتى الأذان"
            } else {
                "Until Azan"
            }

            // Always dark layout - immune to OEM theme overrides
            val isArabic = currentLanguage == "ar"
            val layoutId = if (isArabic) R.layout.notification_large_rtl else R.layout.notification_large
            val contentView = RemoteViews(packageName, layoutId)

            // Header: "Aura - Next Prayer"
            val headerText = if (isArabic) "هالة - $nextPrayerText" else "Aura - $nextPrayerText"
            contentView.setTextViewText(R.id.notification_header, headerText)

            // Prayer icon
            val prayerIcon = loadPrayerIcon()
            if (prayerIcon != null) {
                contentView.setImageViewBitmap(R.id.notification_logo, prayerIcon)
            }

            // Prayer info
            contentView.setTextViewText(R.id.notification_title, prayerName)
            contentView.setTextViewText(R.id.notification_time, timeString)
            contentView.setViewVisibility(R.id.notification_until, android.view.View.VISIBLE)
            contentView.setTextViewText(R.id.notification_until, untilText)

            notificationBuilder
                .setContentTitle("Aura - $nextPrayerText")
                .setCustomContentView(contentView)
                .setCustomBigContentView(contentView)

            Log.d(TAG, "📱 [NOTIFICATION] Showing countdown: $prayerName in $timeString")
        }

        return notificationBuilder.build()
    }

    private fun loadPrayerIcon(): Bitmap? {
        // Icon based on phone clock time, not prayer times
        val calendar = java.util.Calendar.getInstance()
        val hour = calendar.get(java.util.Calendar.HOUR_OF_DAY)

        val resId = when (hour) {
            in 0..4 -> R.drawable.ic_prayer_isha       // Night (midnight–4:59)
            in 5..6 -> R.drawable.ic_prayer_fajr        // Dawn (5:00–6:59)
            in 7..11 -> R.drawable.ic_prayer_dhuhr      // Morning (7:00–11:59)
            in 12..15 -> R.drawable.ic_prayer_dhuhr     // Afternoon (12:00–15:59)
            in 16..17 -> R.drawable.ic_prayer_afternoon  // Late afternoon (16:00–17:59)
            in 18..19 -> R.drawable.ic_prayer_maghrib    // Evening (18:00–19:59)
            else -> R.drawable.ic_prayer_isha            // Night (20:00–23:59)
        }

        return try {
            val drawable = ResourcesCompat.getDrawable(resources, resId, null)
            if (drawable != null) {
                val bitmap = Bitmap.createBitmap(128, 128, Bitmap.Config.ARGB_8888)
                val canvas = android.graphics.Canvas(bitmap)
                drawable.setBounds(0, 0, 128, 128)
                drawable.draw(canvas)
                bitmap
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading prayer icon: ${e.message}")
            null
        }
    }

    private fun calculateTimeRemaining(): Pair<Long, String> {
        // Return 0 if prayer data not loaded
        if (nextPrayerTime == null) {
            return Pair(0, "--:--")
        }

        val now = System.currentTimeMillis()
        val prayerTime = nextPrayerTime!!

        var remaining = prayerTime - now

        // If prayer time has passed
        if (remaining < 0) {
            remaining = 0
        }

        val hours = remaining / 3600000
        val minutes = (remaining % 3600000) / 60000

        // Digital clock style: 02:15 (no seconds)
        val timeString = if (currentLanguage == "ar") {
            String.format("%s:%s", toEasternArabic(hours), toEasternArabic(minutes))
        } else {
            String.format("%d:%02d", hours, minutes)
        }

        return Pair(remaining, timeString)
    }

    override fun onDestroy() {
        instance = null
        handler?.removeCallbacks(updateRunnable!!)
        super.onDestroy()

        val restartIntent = Intent(applicationContext, PrayerForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(restartIntent)
        } else {
            startService(restartIntent)
        }
    }

    // Method to update prayer times from within the service
    fun updateFromFlutter(prayerTimesMap: Map<String, String>, nextPrayer: String, nextPrayerAr: String, nextTime: Long, language: String) {
        // Update language
        currentLanguage = language

        // Update next prayer info
        nextPrayerName = nextPrayer
        nextPrayerNameAr = nextPrayerAr
        nextPrayerTime = nextTime
        isPrayerDataLoaded = true

        // Update all prayer times
        val prayerKeys = listOf("fajr_time", "sunrise_time", "dhuhr_time", "asr_time", "maghrib_time", "isha_time")
        for (key in prayerKeys) {
            val value = prayerTimesMap[key]
            if (value != null) {
                val time = value.toLongOrNull()
                if (time != null) {
                    prayerTimes[key] = time
                }
            }
        }

        Log.d(TAG, "✅ [UPDATE] Updated from Flutter: next prayer = $nextPrayer at $nextTime")

        // Force update notification immediately
        updateNotification()
    }

    /**
     * Request Flutter to recalculate prayer times by launching MainActivity briefly.
     * This ensures fresh prayer times are saved to SharedPreferences when the app
     * hasn't been opened for a new day.
     */
    private fun requestFlutterUpdate() {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("refresh_prayer_times", true)
            }
            startActivity(intent)
            Log.d(TAG, "✅ [REFRESH] Launched MainActivity to refresh prayer times")
        } catch (e: Exception) {
            Log.e(TAG, "❌ [REFRESH] Failed to launch MainActivity: ${e.message}")
        }
    }

    // Convert Western Arabic numerals to Eastern Arabic numerals
    private fun toEasternArabic(number: Long): String {
        val western = "0123456789"
        val eastern = "٠١٢٣٤٥٦٧٨٩"
        return number.toString().map { digit ->
            val index = western.indexOf(digit)
            if (index >= 0) eastern[index] else digit
        }.joinToString("")
    }
}
