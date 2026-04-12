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
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StyleSpan
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.res.ResourcesCompat
import java.util.Date

class PrayerForegroundService : Service() {

    private val CHANNEL_ID = "prayer_foreground_channel"
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
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Prayer Times Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps prayer times running in background"
                setShowBadge(false)
            }

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
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

        // If we have old prayer times, clear them and trigger a reload
        if (hasOldPrayerTimes) {
            Log.w(TAG, "Detected old prayer times, clearing cache")
            prayerTimes.clear()
            // Don't set nextPrayerTime to null, let checkAndUpdateNextPrayer handle it
        }

        Log.d(TAG, "Loaded prayer times: ${prayerTimes.size} prayers")
    }

    // Check if we need to move to next prayer (called every update cycle)
    private fun checkAndUpdateNextPrayer() {
        // Skip if prayer data not loaded yet
        if (!isPrayerDataLoaded || nextPrayerTime == null) {
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

        // Load prayer icon
        val bigLogo = loadPrayerIcon()

        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setLargeIcon(bigLogo)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
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
            // Show countdown to next prayer
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
                "حتى موعد الأذان"
            } else {
                "Until Azan"
            }

            // Create a title with bold prayer name
            val fullTitle = "$nextPrayerText - $prayerName"
            val spannableTitle = SpannableString(fullTitle)
            val boldStart = fullTitle.indexOf(prayerName)
            val boldEnd = boldStart + prayerName.length
            if (boldStart >= 0) {
                spannableTitle.setSpan(
                    StyleSpan(Typeface.BOLD),
                    boldStart,
                    boldEnd,
                    Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
                )
            }

            notificationBuilder
                .setContentTitle(spannableTitle)
                .setContentText("⏰ $timeString • $untilText")

            Log.d(TAG, "📱 [NOTIFICATION] Showing countdown: $prayerName in $timeString")
        }

        return notificationBuilder.build()
    }

    private fun loadPrayerIcon(): Bitmap? {
        // Use actual drawable resources instead of emoji text
        val resId = when (nextPrayerName?.lowercase()) {
            "fajr" -> R.drawable.ic_prayer_fajr
            "sunrise" -> R.drawable.ic_prayer_sunrise
            "dhuhr", "zuhr" -> R.drawable.ic_prayer_dhuhr
            "asr" -> R.drawable.ic_prayer_afternoon
            "maghrib" -> R.drawable.ic_prayer_maghrib
            "isha" -> R.drawable.ic_prayer_isha
            else -> R.drawable.ic_mosque
        }

        return try {
            val original = BitmapFactory.decodeResource(resources, resId)
            if (original != null) {
                Bitmap.createScaledBitmap(original, 256, 256, true)
            } else {
                // Fallback to app launcher icon
                val fallback = BitmapFactory.decodeResource(resources, R.drawable.ic_launcher_foreground)
                if (fallback != null) {
                    Bitmap.createScaledBitmap(fallback, 256, 256, true)
                } else {
                    null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading prayer icon: ${e.message}")
            null
        }
    }

    private fun calculateTimeRemaining(): Pair<Long, String> {
        // Return 0 if prayer data not loaded
        if (nextPrayerTime == null) {
            return Pair(0, "--:--:--")
        }

        val now = System.currentTimeMillis()
        val prayerTime = nextPrayerTime!!

        var remaining = prayerTime - now

        // If prayer time has passed (shouldn't happen after checkAndUpdateNextPrayer, but just in case)
        if (remaining < 0) {
            Log.w(TAG, "Prayer time has passed, remaining is negative. This should be handled by checkAndUpdateNextPrayer()")
            // Don't add 24 hours - let checkAndUpdateNextPrayer handle the transition
            // Just show "Now" briefly until the next update cycle
            remaining = 0
        }

        val hours = remaining / 3600000
        val minutes = (remaining % 3600000) / 60000
        val seconds = (remaining % 60000) / 1000

        val timeString = if (currentLanguage == "ar") {
            when {
                hours > 0 -> "${toEasternArabic(hours)} س ${toEasternArabic(minutes)} د ${toEasternArabic(seconds)} ث"
                minutes > 0 -> "${toEasternArabic(minutes)} د ${toEasternArabic(seconds)} ث"
                else -> "${toEasternArabic(seconds)} ث"
            }
        } else {
            when {
                hours > 0 -> "$hours h $minutes m $seconds s"
                minutes > 0 -> "$minutes m $seconds s"
                else -> "$seconds s"
            }
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
