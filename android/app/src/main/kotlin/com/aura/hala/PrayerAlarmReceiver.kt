package com.aura.hala

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.text.format.DateFormat
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.aura.hala.R
import java.util.Date

/**
 * BroadcastReceiver for handling prayer time alarms
 * This receiver is triggered when a prayer time alarm goes off
 */
class PrayerAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PrayerAlarmReceiver"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_PRAYER_NAME_AR = "prayer_name_ar"
        const val EXTRA_PRAYER_TIME = "prayer_time"
        const val EXTRA_IS_REMINDER = "is_reminder"
        const val ACTION_STOP_ADHAN = "com.aura.hala.STOP_ADHAN"
        const val ACTION_TOGGLE_SILENT = "com.aura.hala.TOGGLE_SILENT"
        const val ACTION_REMIND_AGAIN = "com.aura.hala.REMIND_AGAIN"

        // Notification IDs for each prayer
        private const val NOTIFICATION_FAJR = 1001
        private const val NOTIFICATION_SUNRISE = 1002
        private const val NOTIFICATION_DHUHR = 1003
        private const val NOTIFICATION_ASR = 1004
        private const val NOTIFICATION_MAGHRIB = 1005
        private const val NOTIFICATION_ISHA = 1006

        // Reminder notification IDs (offset by 2000)
        private const val REMINDER_FAJR = 2001
        private const val REMINDER_SUNRISE = 2002
        private const val REMINDER_DHUHR = 2003
        private const val REMINDER_ASR = 2004
        private const val REMINDER_MAGHRIB = 2005
        private const val REMINDER_ISHA = 2006

        fun getNotificationId(prayerName: String): Int {
            return when (prayerName) {
                "Fajr" -> NOTIFICATION_FAJR
                "Sunrise" -> NOTIFICATION_SUNRISE
                "Dhuhr", "Zuhr" -> NOTIFICATION_DHUHR
                "Asr" -> NOTIFICATION_ASR
                "Maghrib" -> NOTIFICATION_MAGHRIB
                "Isha" -> NOTIFICATION_ISHA
                else -> 1000
            }
        }

        fun getReminderNotificationId(prayerName: String): Int {
            return when (prayerName) {
                "Fajr" -> REMINDER_FAJR
                "Sunrise" -> REMINDER_SUNRISE
                "Dhuhr", "Zuhr" -> REMINDER_DHUHR
                "Asr" -> REMINDER_ASR
                "Maghrib" -> REMINDER_MAGHRIB
                "Isha" -> REMINDER_ISHA
                else -> 2000
            }
        }

        /**
         * Schedule a 10-minute reminder alarm before prayer time
         */
        fun scheduleReminderAlarm(
            context: Context,
            prayerName: String,
            prayerNameAr: String,
            prayerTime: Long,
            requestCode: Int
        ) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            // Schedule 10 minutes before prayer time
            val reminderTime = prayerTime - (10 * 60 * 1000) // 10 minutes in milliseconds
            val now = System.currentTimeMillis()

            // Only schedule if reminder time is in the future
            if (reminderTime <= now) {
                Log.w(TAG, "⚠️ [REMINDER] $prayerName reminder time has passed, skipping")
                return
            }

            // Check if exact alarm permission is granted (Android 12+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (!alarmManager.canScheduleExactAlarms()) {
                    Log.w(TAG, "⚠️ EXACT ALARM PERMISSION NOT GRANTED for $prayerName reminder")
                }
            }

            val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
                putExtra(EXTRA_PRAYER_NAME, prayerName)
                putExtra(EXTRA_PRAYER_NAME_AR, prayerNameAr)
                putExtra(EXTRA_PRAYER_TIME, prayerTime)
                putExtra(EXTRA_IS_REMINDER, true)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode + 1000, // Offset to avoid conflict with prayer alarm
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Use setExactAndAllowWhileIdle for precise timing even in Doze mode
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    reminderTime,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    reminderTime,
                    pendingIntent
                )
            }

            val delay = reminderTime - now
            val delayMinutes = delay / 1000 / 60
            val reminderTimeStr = DateFormat.format("HH:mm", Date(reminderTime))
            val prayerTimeStr = DateFormat.format("HH:mm", Date(prayerTime))
            val nowStr = DateFormat.format("HH:mm", Date(now))

            Log.d(TAG, "═══════════════════════════════════════")
            Log.d(TAG, "🔔 [REMINDER SCHEDULED] $prayerName")
            Log.d(TAG, "⏰ Current time: $nowStr")
            Log.d(TAG, "⏰ Reminder time: $reminderTimeStr (10 min before $prayerTimeStr)")
            Log.d(TAG, "⏳ Time until reminder: $delayMinutes minutes")
            Log.d(TAG, "🎯 Request code: ${requestCode + 1000}")
            Log.d(TAG, "═══════════════════════════════════════")
        }

        /**
         * Schedule an alarm for a specific prayer time
         */
        fun schedulePrayerAlarm(
            context: Context,
            prayerName: String,
            prayerNameAr: String,
            prayerTime: Long,
            requestCode: Int
        ) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            // Check if exact alarm permission is granted (Android 12+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (!alarmManager.canScheduleExactAlarms()) {
                    Log.w(TAG, "⚠️ EXACT ALARM PERMISSION NOT GRANTED for $prayerName")
                    // Continue anyway - system may still allow it
                } else {
                    Log.d(TAG, "✅ Exact alarm permission granted")
                }
            }

            val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
                putExtra(EXTRA_PRAYER_NAME, prayerName)
                putExtra(EXTRA_PRAYER_NAME_AR, prayerNameAr)
                putExtra(EXTRA_PRAYER_TIME, prayerTime)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Use setExactAndAllowWhileIdle for precise timing even in Doze mode
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    prayerTime,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    prayerTime,
                    pendingIntent
                )
            }

            val now = System.currentTimeMillis()
            val delay = prayerTime - now
            val delayMinutes = delay / 1000 / 60
            val timeStr = DateFormat.format("HH:mm", Date(prayerTime))
            val nowStr = DateFormat.format("HH:mm", Date(now))

            Log.d(TAG, "═══════════════════════════════════════")
            Log.d(TAG, "🔔 [ALARM SCHEDULED] $prayerName")
            Log.d(TAG, "⏰ Current time: $nowStr")
            Log.d(TAG, "⏰ Alarm time: $timeStr")
            Log.d(TAG, "⏳ Time until alarm: $delayMinutes minutes")
            Log.d(TAG, "🎯 Request code: $requestCode")
            Log.d(TAG, "═══════════════════════════════════════")
        }

        /**
         * Cancel all prayer alarms
         */
        fun cancelAllAlarms(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            // Cancel each prayer alarm
            for (prayer in listOf("Fajr", "Sunrise", "Zuhr", "Dhuhr", "Asr", "Maghrib", "Isha")) {
                val intent = Intent(context, PrayerAlarmReceiver::class.java)
                val requestCode = getNotificationId(prayer)
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    requestCode,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pendingIntent)
            }

            Log.d(TAG, "All prayer alarms cancelled")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val currentTime = System.currentTimeMillis()
        val timeStr = DateFormat.format("HH:mm:ss", Date(currentTime))
        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "🔔 [PRAYER ALARM] Received at $timeStr")
        Log.d(TAG, "🔔 [PRAYER ALARM] Intent action: ${intent.action}")

        val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: return
        val prayerNameAr = intent.getStringExtra(EXTRA_PRAYER_NAME_AR) ?: prayerName
        val prayerTime = intent.getLongExtra(EXTRA_PRAYER_TIME, 0)
        val isReminder = intent.getBooleanExtra(EXTRA_IS_REMINDER, false)

        if (isReminder) {
            // This is a 10-minute reminder notification
            Log.d(TAG, "⏰ [REMINDER] 10-minute reminder for $prayerName")
            showReminderNotification(context, prayerName, prayerNameAr, prayerTime)
            return
        }

        // This is the actual prayer time alarm
        val scheduledTimeStr = DateFormat.format("HH:mm:ss", Date(prayerTime))
        Log.d(TAG, "📿 [PRAYER] Name: $prayerName ($prayerNameAr)")
        Log.d(TAG, "⏰ [PRAYER] Scheduled for: $scheduledTimeStr")

        val defaultPrefs = context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)
        val silentModeEnabled = defaultPrefs.getBoolean("silent_mode_enabled", true)
        Log.d(TAG, "🔧 [SETTINGS] Silent mode enabled: $silentModeEnabled")

        // Play adhan for this prayer (except Sunrise)
        if (prayerName != "Sunrise") {
            Log.d(TAG, "🎵 [ADHAN] Starting adhan playback for $prayerName")
            AdhanPlayer.play(context, prayerName)

            // Enable silent mode immediately (if enabled in settings)
            if (silentModeEnabled) {
                Log.d(TAG, "🔕 [SILENT] Enabling silent mode for $prayerName")
                enableSilentModeForPrayer(context, prayerName, prayerNameAr)
            } else {
                Log.d(TAG, "⏭️ [SILENT] Silent mode disabled in settings")
            }
        } else {
            Log.d(TAG, "⏭️ [ADHAN] Sunrise - skipping adhan and silent mode")
        }

        // Show notification AFTER silent mode is enabled (so buttons are correct)
        Log.d(TAG, "📱 [NOTIFICATION] About to call showPrayerNotification for $prayerName")
        showPrayerNotification(context, prayerName, prayerNameAr, prayerTime)
        Log.d(TAG, "📱 [NOTIFICATION] Returned from showPrayerNotification for $prayerName")

        // Update next prayer for widget and app
        updateNextPrayer(context, prayerName)

        // Schedule next day's prayers
        if (prayerName == "Isha") {
            Log.d(TAG, "Last prayer of the day, scheduling tomorrow's prayers")
            // Trigger service to reschedule for tomorrow
            val serviceIntent = Intent(context, PrayerRescheduleService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }
    }

    /**
     * Update next prayer after current prayer time has passed
     */
    private fun updateNextPrayer(context: Context, currentPrayerName: String) {
        Log.d(TAG, "🔄 [UPDATE] Updating next prayer after $currentPrayerName")

        // Get prayer times from shared preferences
        val prefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
        val editor = prefs.edit()

        // Find the next prayer based on the current one
        val prayerOrder = listOf("Fajr", "Sunrise", "Zuhr", "Dhuhr", "Asr", "Maghrib", "Isha")
        val currentIndex = prayerOrder.indexOf(currentPrayerName)

        if (currentIndex >= 0) {
            val nextPrayerName: String
            val nextPrayerTime: Long

            if (currentIndex < prayerOrder.size - 1) {
                // Get next prayer in the same day
                nextPrayerName = prayerOrder[currentIndex + 1]
                val nextPrayerTimeKey = "${nextPrayerName.lowercase()}_time"
                val storedTime = prefs.getString(nextPrayerTimeKey, null)
                nextPrayerTime = storedTime?.toLongOrNull() ?: 0L
            } else {
                // After Isha, next prayer is Fajr tomorrow
                nextPrayerName = "Fajr"
                val fajrTimeKey = "fajr_time"
                val storedFajrTime = prefs.getString(fajrTimeKey, null)
                val fajrTime = storedFajrTime?.toLongOrNull() ?: 0L

                // Add 24 hours to get tomorrow's Fajr
                nextPrayerTime = fajrTime + (24 * 60 * 60 * 1000)

                Log.d(TAG, "🌙 [UPDATE] After Isha, next prayer is Fajr tomorrow")
            }

            if (nextPrayerTime > 0) {
                // Update next prayer in shared preferences
                editor.putString("next_prayer_name", nextPrayerName)
                editor.putString("next_prayer_name_ar", getArabicName(nextPrayerName))
                editor.putString("next_prayer_time", nextPrayerTime.toString())
                editor.apply()

                Log.d(TAG, "✅ [UPDATE] Next prayer updated to: $nextPrayerName at $nextPrayerTime")

                // Update widgets
                updateWidgets(context)
            }
        }
    }

    /**
     * Get Arabic name for prayer
     */
    private fun getArabicName(prayerName: String): String {
        return when (prayerName) {
            "Fajr" -> "الفجر"
            "Sunrise" -> "الشروق"
            "Dhuhr", "Zuhr" -> "الظهر"
            "Asr" -> "العصر"
            "Maghrib" -> "المغرب"
            "Isha" -> "العشاء"
            else -> prayerName
        }
    }

    /**
     * Update all widgets with new next prayer
     */
    private fun updateWidgets(context: Context) {
        Log.d(TAG, "📱 [UPDATE] Updating widgets")

        val appWidgetManager = AppWidgetManager.getInstance(context)

        // Update Next Prayer Widget
        val nextWidgetComponent = ComponentName(context, NextPrayerWidget::class.java)
        val nextWidgetIds = appWidgetManager.getAppWidgetIds(nextWidgetComponent)

        nextWidgetIds.forEach { widgetId ->
            NextPrayerWidget().updateAppWidget(context, appWidgetManager, widgetId)
        }
        Log.d(TAG, "✅ [UPDATE] Updated ${nextWidgetIds.size} NextPrayerWidget(s)")

        // Update All Prayers Widget
        val allWidgetComponent = ComponentName(context, AllPrayersWidget::class.java)
        val allWidgetIds = appWidgetManager.getAppWidgetIds(allWidgetComponent)

        allWidgetIds.forEach { widgetId ->
            AllPrayersWidget().updateAppWidget(context, appWidgetManager, widgetId)
        }
        Log.d(TAG, "✅ [UPDATE] Updated ${allWidgetIds.size} AllPrayersWidget(s)")
    }

    /**
     * Enable silent mode immediately when Adhan fires
     */
    private fun enableSilentModeForPrayer(context: Context, prayerName: String, prayerNameAr: String) {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val silentPrefs = context.getSharedPreferences("aura_silent_mode", Context.MODE_PRIVATE)

        // Check DND permission
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val hasDndPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                notificationManager.isNotificationPolicyAccessGranted
            } catch (e: Exception) {
                false
            }
        } else {
            true
        }

        // Save current ringer mode
        val currentRingerMode = audioManager.ringerMode
        silentPrefs.edit().putInt("saved_ringer_mode", currentRingerMode).apply()
        Log.d(TAG, "📱 Saved ringer mode: $currentRingerMode, DND permission: $hasDndPermission")

        // Set to silent mode
        try {
            if (hasDndPermission) {
                audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
                Log.d(TAG, "🔕 Enabled SILENT mode")
            } else {
                audioManager.ringerMode = AudioManager.RINGER_MODE_VIBRATE
                Log.d(TAG, "🔕 Enabled VIBRATE mode (no DND permission)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error setting silent mode: ${e.message}")
        }

        // Mark silent mode as active
        silentPrefs.edit().putBoolean("is_silent_active", true).apply()

        // Calculate end time (20 minutes from now)
        val silentEndTime = System.currentTimeMillis() + (20 * 60 * 1000)
        silentPrefs.edit().putLong("silent_end_time", silentEndTime).apply()
        Log.d(TAG, "⏰ Silent mode will auto-restore in 20 minutes")

        // Schedule auto-restore
        scheduleSilentModeRestore(context, silentEndTime)
    }

    /**
     * Schedule silent mode to auto-restore after 20 minutes
     */
    private fun scheduleSilentModeRestore(context: Context, silentEndTime: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, SilentOffReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            3999,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                silentEndTime,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                silentEndTime,
                pendingIntent
            )
        }

        val timeStr = DateFormat.format("HH:mm", Date(silentEndTime))
        Log.d(TAG, "⏰ Scheduled silent mode restore at $timeStr")
    }

    private fun showPrayerNotification(
        context: Context,
        prayerName: String,
        prayerNameAr: String,
        prayerTime: Long
    ) {
        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "📱 [NOTIFICATION] ===== showPrayerNotification START =====")
        Log.d(TAG, "📱 [NOTIFICATION] Prayer: $prayerName ($prayerNameAr)")

        // Get language preference from default SharedPreferences (Flutter uses this)
        val defaultPrefs = context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)
        val language = defaultPrefs.getString("language", "en") ?: "en"
        val isArabic = language == "ar"
        Log.d(TAG, "📱 [NOTIFICATION] Language: $language, isArabic: $isArabic")

        // Check if silent mode is enabled
        val silentModeEnabled = defaultPrefs.getBoolean("silent_mode_enabled", true)
        Log.d(TAG, "📱 [NOTIFICATION] Silent mode enabled in settings: $silentModeEnabled")

        // Check if silent mode is currently active
        val silentPrefs = context.getSharedPreferences("aura_silent_mode", Context.MODE_PRIVATE)
        val isSilentActive = silentPrefs.getBoolean("is_silent_active", false)
        Log.d(TAG, "📱 [NOTIFICATION] Silent mode currently active: $isSilentActive")

        val title = if (isArabic) prayerNameAr else prayerName
        val message = if (isArabic) {
            "حان الآن موعد صلاة $prayerNameAr"
        } else {
            "It's time for $prayerName prayer"
        }
        Log.d(TAG, "📱 [NOTIFICATION] Title: '$title', Message: '$message'")

        // Get notification ID for this prayer
        val notificationId = getNotificationId(prayerName)
        Log.d(TAG, "📱 [NOTIFICATION] Notification ID: $notificationId")

        // Check if notification channel exists
        val systemNotificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = systemNotificationManager.getNotificationChannel("prayer_times")
            if (channel != null) {
                Log.d(TAG, "📱 [NOTIFICATION] Channel 'prayer_times' EXISTS - importance: ${channel.importance}")
            } else {
                Log.e(TAG, "❌ [NOTIFICATION] Channel 'prayer_times' DOES NOT EXIST!")
            }
        }

        // Create Stop Adhan intent and pending intent
        val stopIntent = Intent(context, StopAdhanReceiver::class.java).apply {
            action = ACTION_STOP_ADHAN
            putExtra(EXTRA_PRAYER_NAME, prayerName)
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        // Create Enable Silent Mode intent and pending intent
        val enableSilentIntent = Intent(context, ToggleSilentModeReceiver::class.java).apply {
            action = "com.aura.hala.ENABLE_SILENT"
            putExtra(EXTRA_PRAYER_NAME, prayerName)
            putExtra(EXTRA_PRAYER_NAME_AR, prayerNameAr)
        }
        val enableSilentPendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId + 100,
            enableSilentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        // Create Dismiss Silent Mode intent and pending intent
        val dismissSilentIntent = Intent(context, ToggleSilentModeReceiver::class.java).apply {
            action = "com.aura.hala.DISMISS_SILENT"
            putExtra(EXTRA_PRAYER_NAME, prayerName)
        }
        val dismissSilentPendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId + 101,
            dismissSilentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        // Create Extend Silent Mode intent and pending intent
        val extendSilentIntent = Intent(context, ToggleSilentModeReceiver::class.java).apply {
            action = "com.aura.hala.EXTEND_SILENT"
            putExtra(EXTRA_PRAYER_NAME, prayerName)
            putExtra(EXTRA_PRAYER_NAME_AR, prayerNameAr)
        }
        val extendSilentPendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId + 102,
            extendSilentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        // Create full-screen intent for lock screen activity (before builder)
        val fullScreenIntent = AdhanFullScreenActivity.getIntent(context, prayerName, prayerNameAr)
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            notificationId + 1000,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        // Build notification
        Log.d(TAG, "📱 [NOTIFICATION] Building notification...")
        val builder = NotificationCompat.Builder(context, "prayer_times")
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(false)
            .setOngoing(false)
            .setShowWhen(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            // Tap notification → open full-screen adhan
            .setContentIntent(fullScreenPendingIntent)
            // Auto-show full screen on lock screen / when screen is off
            .setFullScreenIntent(fullScreenPendingIntent, true)
            // Add Stop button
            .addAction(
                android.R.drawable.ic_media_pause,
                if (isArabic) "إيقاف" else "Stop",
                stopPendingIntent
            )
        Log.d(TAG, "📱 [NOTIFICATION] Notification built with contentIntent + fullScreenIntent")

        // Add silent mode buttons based on settings and current state
        if (silentModeEnabled) {
            if (isSilentActive) {
                builder.addAction(
                    android.R.drawable.ic_media_play,
                    if (isArabic) "إلغاء الصامت" else "Dismiss",
                    dismissSilentPendingIntent
                )
                builder.addAction(
                    android.R.drawable.ic_media_pause,
                    if (isArabic) "اهتزاز دائم" else "Vibrate Always",
                    extendSilentPendingIntent
                )
            } else {
                builder.addAction(
                    android.R.drawable.ic_lock_silent_mode,
                    if (isArabic) "وضع صامت" else "Silent Mode",
                    enableSilentPendingIntent
                )
            }
        }

        // Add big text style for expanded content on lock screen
        val bigTextStyle = NotificationCompat.BigTextStyle()
            .bigText(message)
            .setBigContentTitle(title)
        builder.setStyle(bigTextStyle)

        // Show notification
        Log.d(TAG, "📱 [NOTIFICATION] ===== CALLING notificationManager.notify() =====")
        val notificationManager = NotificationManagerCompat.from(context)
        try {
            notificationManager.notify(notificationId, builder.build())
            Log.d(TAG, "✅ [NOTIFICATION] ===== notificationManager.notify() COMPLETED =====")
            Log.d(TAG, "✅ [NOTIFICATION] Notification SUCCESSFULLY SHOWN for $prayerName (ID: $notificationId)" +
                      (if (silentModeEnabled) " with SILENT MODE buttons" else " with STOP button only"))
        } catch (e: Exception) {
            Log.e(TAG, "❌ [NOTIFICATION] ERROR showing notification: ${e.message}", e)
        }
        Log.d(TAG, "📱 [NOTIFICATION] ===== showPrayerNotification END =====")
    }

    /**
     * Show 10-minute reminder notification
     */
    private fun showReminderNotification(
        context: Context,
        prayerName: String,
        prayerNameAr: String,
        prayerTime: Long
    ) {
        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "⏰ [REMINDER] Showing 10-minute reminder for $prayerName")

        // Get language preference
        val defaultPrefs = context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)
        val language = defaultPrefs.getString("language", "en") ?: "en"
        val isArabic = language == "ar"

        // Check if prayer notifications are enabled
        val notificationsEnabled = defaultPrefs.getBoolean("prayer_notifications_enabled", true)
        if (!notificationsEnabled) {
            Log.d(TAG, "⏰ [REMINDER] Prayer notifications disabled, skipping reminder")
            return
        }

        val title = if (isArabic) prayerNameAr else prayerName
        val message = if (isArabic) {
            "الصلاة بعد 10 دقائق"
        } else {
            "Prayer in 10 minutes"
        }

        val notificationId = getReminderNotificationId(prayerName)

        // Create Remind Again action
        val remindAgainIntent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            putExtra(EXTRA_PRAYER_NAME, prayerName)
            putExtra(EXTRA_PRAYER_NAME_AR, prayerNameAr)
            putExtra(EXTRA_PRAYER_TIME, prayerTime)
            putExtra(EXTRA_IS_REMINDER, true)
            action = ACTION_REMIND_AGAIN
        }
        val remindAgainPendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId + 100,
            remindAgainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        // Build notification
        val builder = NotificationCompat.Builder(context, "prayer_times")
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)  // Auto-cancel when tapped
            .setShowWhen(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setVibrate(longArrayOf(0, 300, 200, 300))
            .addAction(
                android.R.drawable.ic_menu_revert,
                if (isArabic) "ذكرني مرة أخرى" else "Remind Me Again",
                remindAgainPendingIntent
            )

        // Add big text style
        val bigTextStyle = NotificationCompat.BigTextStyle()
            .bigText(message)
            .setBigContentTitle(title)
        builder.setStyle(bigTextStyle)

        // Show notification
        val notificationManager = NotificationManagerCompat.from(context)
        try {
            notificationManager.notify(notificationId, builder.build())
            Log.d(TAG, "✅ [REMINDER] Notification shown for $prayerName (ID: $notificationId)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ [REMINDER] ERROR showing notification: ${e.message}", e)
        }
    }
}
