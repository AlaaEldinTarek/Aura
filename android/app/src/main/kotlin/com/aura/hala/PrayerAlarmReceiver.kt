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
        const val ACTION_REMINDER_PRAYED = "com.aura.hala.REMINDER_PRAYED"
        const val ACTION_REMINDER_LATE = "com.aura.hala.REMINDER_LATE"
        const val ACTION_REMINDER_MISSED = "com.aura.hala.REMINDER_MISSED"
        const val ACTION_REMINDER_LATER = "com.aura.hala.REMINDER_LATER"

        // Post-prayer check actions
        const val EXTRA_IS_POST_CHECK = "is_post_check"
        const val ACTION_POST_DONE = "com.aura.hala.POST_DONE"
        const val ACTION_POST_LATE = "com.aura.hala.POST_LATE"
        const val ACTION_POST_MISSED = "com.aura.hala.POST_MISSED"
        const val ACTION_POST_LATER = "com.aura.hala.POST_LATER"

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


        // Post-prayer check notification IDs (6001-6006)
        private const val POST_CHECK_FAJR = 6001
        private const val POST_CHECK_SUNRISE = 6002
        private const val POST_CHECK_DHUHR = 6003
        private const val POST_CHECK_ASR = 6004
        private const val POST_CHECK_MAGHRIB = 6005
        private const val POST_CHECK_ISHA = 6006


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

        fun getPostCheckNotificationId(prayerName: String): Int {
            return when (prayerName) {
                "Fajr" -> POST_CHECK_FAJR
                "Sunrise" -> POST_CHECK_SUNRISE
                "Dhuhr", "Zuhr" -> POST_CHECK_DHUHR
                "Asr" -> POST_CHECK_ASR
                "Maghrib" -> POST_CHECK_MAGHRIB
                "Isha" -> POST_CHECK_ISHA
                else -> 6000
            }
        }

        /**
         * Schedule a 45-minute reminder alarm before prayer time
         */
        fun scheduleReminderAlarm(
            context: Context,
            prayerName: String,
            prayerNameAr: String,
            prayerTime: Long,
            requestCode: Int
        ) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            // Schedule 45 minutes before prayer time
            val reminderTime = prayerTime - (45 * 60 * 1000) // 45 minutes in milliseconds
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
            Log.d(TAG, "⏰ Reminder time: $reminderTimeStr (45 min before $prayerTimeStr)")
            Log.d(TAG, "⏳ Time until reminder: $delayMinutes minutes")
            Log.d(TAG, "🎯 Request code: ${requestCode + 1000}")
            Log.d(TAG, "═══════════════════════════════════════")
        }

        /**
         * Schedule a delayed reminder (for "Remind Later" from picker).
         * Fires at now + delayMinutes, clears then re-sets reminder_active.
         */
        fun scheduleDelayedReminder(
            context: Context,
            prayerName: String,
            prayerNameAr: String,
            prayerTime: Long,
            requestCode: Int,
            delayMinutes: Int
        ) {
            // First clear the current reminder mode so notification goes back to normal
            val prefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("reminder_active", false).apply()

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerTime = System.currentTimeMillis() + (delayMinutes * 60 * 1000L)

            val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
                putExtra(EXTRA_PRAYER_NAME, prayerName)
                putExtra(EXTRA_PRAYER_NAME_AR, prayerNameAr)
                putExtra(EXTRA_PRAYER_TIME, prayerTime)
                putExtra(EXTRA_IS_REMINDER, true)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            }

            val triggerStr = DateFormat.format("HH:mm", Date(triggerTime))
            Log.d(TAG, "🔕 [DELAYED_REMINDER] $prayerName → will re-remind at $triggerStr ($delayMinutes min)")
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
            for (prayer in listOf("Fajr", "Sunrise", "Zuhr", "Asr", "Maghrib", "Isha")) {
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

        /**
         * Schedule a post-prayer check alarm 30 minutes after prayer time
         */
        fun schedulePostPrayerCheck(
            context: Context,
            prayerName: String,
            prayerNameAr: String,
            prayerTime: Long,
            requestCode: Int
        ) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerTime = prayerTime + (30 * 60 * 1000L) // 30 min after prayer
            val now = System.currentTimeMillis()

            if (triggerTime <= now) {
                Log.w(TAG, "⚠️ [POST_CHECK] $prayerName post-check time has passed, skipping")
                return
            }

            val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
                putExtra(EXTRA_PRAYER_NAME, prayerName)
                putExtra(EXTRA_PRAYER_NAME_AR, prayerNameAr)
                putExtra(EXTRA_PRAYER_TIME, prayerTime)
                putExtra(EXTRA_IS_POST_CHECK, true)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode + 2000, // Offset to avoid conflict
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            }

            val triggerStr = DateFormat.format("HH:mm", Date(triggerTime))
            val delayMin = (triggerTime - now) / 1000 / 60
            Log.d(TAG, "📋 [POST_CHECK] Scheduled for $prayerName → $triggerStr ($delayMin min from now, req=${requestCode + 2000})")
        }

        /**
         * Cancel a pending post-prayer check alarm
         */
        fun cancelPostPrayerCheck(context: Context, prayerName: String, requestCode: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, PrayerAlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode + 2000,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)

            val notifId = getPostCheckNotificationId(prayerName)
            NotificationManagerCompat.from(context).cancel(notifId)
            Log.d(TAG, "📋 [POST_CHECK] Cancelled for $prayerName")
        }

        /**
         * Write prayer status to SharedPreferences (called from Flutter side)
         */
        fun markPrayerTracked(context: Context, prayerName: String, status: String) {
            val prefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
            val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
            prefs.edit().putString("prayer_status_${prayerName}_${today}", status).apply()
            Log.d(TAG, "📋 [POST_CHECK] Marked $prayerName as $status (Flutter)")
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
        val action = intent.action
        val isPostCheck = intent.getBooleanExtra(EXTRA_IS_POST_CHECK, false)

        // Handle post-prayer check notification button actions
        if (action == ACTION_POST_DONE || action == ACTION_POST_LATE ||
            action == ACTION_POST_MISSED || action == ACTION_POST_LATER) {
            handlePostPrayerCheckAction(context, action, prayerName, prayerNameAr, prayerTime)
            return
        }

        // Handle post-prayer check alarm (30 min after adhan)
        if (isPostCheck) {
            val prefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
            val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
            val statusKey = "prayer_status_${prayerName}_${today}"
            val alreadyTracked = prefs.contains(statusKey)

            if (alreadyTracked) {
                Log.d(TAG, "📋 [POST_CHECK] $prayerName already tracked, skipping notification")
            } else {
                Log.d(TAG, "📋 [POST_CHECK] $prayerName NOT tracked → showing notification")
                showPostPrayerCheckNotification(context, prayerName, prayerNameAr, prayerTime)
            }
            return
        }

        // Handle reminder actions from foreground service notification
        if (action == ACTION_REMINDER_PRAYED || action == ACTION_REMINDER_LATE ||
            action == ACTION_REMINDER_MISSED || action == ACTION_REMINDER_LATER) {
            handleReminderAction(context, action, prayerName, prayerNameAr, prayerTime)
            return
        }

        if (isReminder) {
            // 45-min reminder: write to SharedPreferences for foreground service to pick up
            Log.d(TAG, "⏰ [REMINDER] 45-minute reminder for $prayerName → activating reminder mode")
            val prefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
            prefs.edit()
                .putString("reminder_prayer_name", prayerName)
                .putString("reminder_prayer_name_ar", prayerNameAr)
                .putLong("reminder_prayer_time", prayerTime)
                .putBoolean("reminder_active", true)
                .apply()
            return
        }

        // This is the actual prayer time alarm
        val scheduledTimeStr = DateFormat.format("HH:mm:ss", Date(prayerTime))
        Log.d(TAG, "📿 [PRAYER] Name: $prayerName ($prayerNameAr)")
        Log.d(TAG, "⏰ [PRAYER] Scheduled for: $scheduledTimeStr")

        val defaultPrefs = context.getSharedPreferences("aura_silent_mode", Context.MODE_PRIVATE)
        val silentModeEnabled = defaultPrefs.getBoolean("silent_mode_enabled", true)
        Log.d(TAG, "🔧 [SETTINGS] Silent mode enabled: $silentModeEnabled")

        // Play adhan audio (except Sunrise — no adhan for sunrise)
        if (prayerName != "Sunrise") {
            try {
                AdhanPlayer.play(context, prayerName)
                Log.d(TAG, "🎵 [ADHAN] Playing adhan audio for $prayerName")
            } catch (e: Exception) {
                Log.e(TAG, "❌ [ADHAN] Error playing adhan: ${e.message}")
            }
        } else {
            Log.d(TAG, "⏭️ [ADHAN] Sunrise - skipping adhan audio")
        }

        // Enable vibrate mode for this prayer (except Sunrise)
        if (prayerName != "Sunrise") {
            if (silentModeEnabled) {
                Log.d(TAG, "📳 [VIBRATE] Enabling vibrate mode for $prayerName")
                enableSilentModeForPrayer(context, prayerName, prayerNameAr)
            } else {
                Log.d(TAG, "⏭️ [VIBRATE] Vibrate mode disabled in settings")
            }
        } else {
            Log.d(TAG, "⏭️ [ADHAN] Sunrise - skipping vibrate mode")
        }

        // Show notification AFTER silent mode is enabled (so buttons are correct)
        Log.d(TAG, "📱 [NOTIFICATION] About to call showPrayerNotification for $prayerName")
        showPrayerNotification(context, prayerName, prayerNameAr, prayerTime)
        Log.d(TAG, "📱 [NOTIFICATION] Returned from showPrayerNotification for $prayerName")

        // Launch full screen adhan activity directly (not relying on fullScreenIntent)
        try {
            val fullScreenIntent = AdhanFullScreenActivity.getIntent(context, prayerName, prayerNameAr)
            fullScreenIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(fullScreenIntent)
            Log.d(TAG, "📱 [FULLSCREEN] Launched full screen adhan activity")
        } catch (e: Exception) {
            Log.e(TAG, "❌ [FULLSCREEN] Error launching full screen: ${e.message}")
        }

        // ── Activate adhan mode in foreground service ─────────────────────
        // This switches the persistent notification to show iqama countdown
        if (prayerName != "Sunrise") {
            val adhanPrefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
            val iqamaKey = when (prayerName) {
                "Fajr"         -> "fajr_iqama_time"
                "Zuhr", "Dhuhr" -> "dhuhr_iqama_time"
                "Asr"          -> "asr_iqama_time"
                "Maghrib"      -> "maghrib_iqama_time"
                "Isha"         -> "isha_iqama_time"
                else           -> null
            }
            val iqamaTimeMs = iqamaKey?.let {
                adhanPrefs.getString(it, null)?.toLongOrNull()
            } ?: 0L

            adhanPrefs.edit()
                .putBoolean("adhan_active", true)
                .putString("adhan_prayer_name", prayerName)
                .putString("adhan_prayer_name_ar", prayerNameAr)
                .putLong("adhan_end_time", currentTime + 20 * 60 * 1000L)
                .putLong("adhan_iqama_time", iqamaTimeMs)
                .apply()
            Log.d(TAG, "✅ [ADHAN_MODE] Activated for $prayerName | iqama=${iqamaTimeMs} | end=${currentTime + 20*60*1000L}")
        }

        // Update next prayer for widget and app
        updateNextPrayer(context, prayerName)

        // Schedule post-prayer check (30 min after adhan)
        if (prayerName != "Sunrise") {
            val flutterPrefs = context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)
            val trackingEnabled = flutterPrefs.getBoolean("prayer_tracking_notifications_enabled", true)
            if (trackingEnabled) {
                schedulePostPrayerCheck(context, prayerName, prayerNameAr, prayerTime, getNotificationId(prayerName))
            } else {
                Log.d(TAG, "📋 [POST_CHECK] Skipping $prayerName — tracking notifications disabled")
            }
        }

        // After Fajr or Isha, request Flutter to recalculate prayer times for the new day.
        // PrayerRescheduleService uses placeholder times, so we rely on Flutter (which has
        // the Adhan library) for accurate rescheduling via requestFlutterUpdate().
        if (prayerName == "Fajr" || prayerName == "Isha") {
            Log.d(TAG, "🔄 Triggering Flutter update after $prayerName for fresh prayer times")
            PrayerForegroundService.requestFlutterUpdateStatic(context)
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
        val now = System.currentTimeMillis()

        // Find the next prayer based on the current one
        val prayerOrder = listOf("Fajr", "Sunrise", "Zuhr", "Asr", "Maghrib", "Isha")
        val currentIndex = prayerOrder.indexOf(currentPrayerName)

        if (currentIndex >= 0) {
            var nextPrayerName: String? = null
            var nextPrayerTime: Long = 0L

            // Try to find a future prayer from the next one onwards
            for (i in (currentIndex + 1) until prayerOrder.size) {
                val candidateName = prayerOrder[i]
                val timeKey = if (candidateName == "Zuhr") "dhuhr_time" else "${candidateName.lowercase()}_time"
                val storedTime = prefs.getString(timeKey, null)?.toLongOrNull() ?: 0L
                if (storedTime > now) {
                    nextPrayerName = candidateName
                    nextPrayerTime = storedTime
                    break
                }
            }

            // If no future prayer found today, next is Fajr tomorrow
            if (nextPrayerName == null) {
                val fajrTimeKey = "fajr_time"
                val storedFajrTime = prefs.getString(fajrTimeKey, null)?.toLongOrNull() ?: 0L
                nextPrayerName = "Fajr"
                // Add 24 hours to get tomorrow's Fajr
                nextPrayerTime = storedFajrTime + (24 * 60 * 60 * 1000)
                Log.d(TAG, "🌙 [UPDATE] No future prayer today, next is Fajr tomorrow")
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

        // Set to vibrate mode (not silent/DND — user preference)
        try {
            audioManager.ringerMode = AudioManager.RINGER_MODE_VIBRATE
            Log.d(TAG, "📳 Enabled VIBRATE mode for prayer")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error setting vibrate mode: ${e.message}")
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
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(false)
            .setOngoing(false)
            .setShowWhen(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            // Tap notification → opens full-screen adhan → closing stops adhan
            .setContentIntent(fullScreenPendingIntent)
            // Auto-show full screen on lock screen / when screen is off
            .setFullScreenIntent(fullScreenPendingIntent, true)
        Log.d(TAG, "📱 [NOTIFICATION] Notification built with contentIntent + fullScreenIntent")

        // Add silent mode buttons based on settings and current state
        if (silentModeEnabled && isSilentActive) {
            builder.addAction(
                android.R.drawable.ic_media_play,
                if (isArabic) "إيقاف الاهتزاز" else "Stop Vibrate",
                dismissSilentPendingIntent
            )
            builder.addAction(
                android.R.drawable.ic_media_pause,
                if (isArabic) "اهتزاز دائم" else "Vibrate Always",
                extendSilentPendingIntent
            )
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
     * Handle reminder action buttons from foreground service notification.
     * Saves prayer status to SharedPreferences and clears reminder mode.
     */
    private fun handleReminderAction(
        context: Context,
        action: String,
        prayerName: String,
        prayerNameAr: String,
        prayerTime: Long
    ) {
        val prefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)

        when (action) {
            ACTION_REMINDER_PRAYED -> {
                val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
                prefs.edit()
                    .putString("prayer_status_${prayerName}_${today}", "on_time")
                    .putBoolean("reminder_active", false)
                    .remove("reminder_prayer_name")
                    .remove("reminder_prayer_name_ar")
                    .remove("reminder_prayer_time")
                    .apply()
                Log.d(TAG, "✅ [REMINDER] Marked $prayerName as prayed (on_time)")
                notifyFlutterPrayerStatus(context, prayerName, "on_time")
            }
            ACTION_REMINDER_LATE -> {
                val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
                prefs.edit()
                    .putString("prayer_status_${prayerName}_${today}", "late")
                    .putBoolean("reminder_active", false)
                    .remove("reminder_prayer_name")
                    .remove("reminder_prayer_name_ar")
                    .remove("reminder_prayer_time")
                    .apply()
                Log.d(TAG, "⏰ [REMINDER] Marked $prayerName as late")
                notifyFlutterPrayerStatus(context, prayerName, "late")
            }
            ACTION_REMINDER_MISSED -> {
                val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
                prefs.edit()
                    .putString("prayer_status_${prayerName}_${today}", "missed")
                    .putBoolean("reminder_active", false)
                    .remove("reminder_prayer_name")
                    .remove("reminder_prayer_name_ar")
                    .remove("reminder_prayer_time")
                    .apply()
                Log.d(TAG, "❌ [REMINDER] Marked $prayerName as missed")
                notifyFlutterPrayerStatus(context, prayerName, "missed")
            }
            ACTION_REMINDER_LATER -> {
                try {
                    val intent = Intent(context, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        putExtra("open_reminder_picker", true)
                        putExtra("reminder_prayer_name", prayerName)
                        putExtra("reminder_prayer_name_ar", prayerNameAr)
                        putExtra("reminder_prayer_time", prayerTime)
                    }
                    context.startActivity(intent)
                    Log.d(TAG, "🔕 [REMINDER] Opening reminder picker for $prayerName")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ [REMINDER] Failed to open picker: ${e.message}")
                }
            }
        }
    }

    /**
     * Show post-prayer check notification with Done/Late/Missed/Remind Later buttons
     */
    private fun showPostPrayerCheckNotification(
        context: Context,
        prayerName: String,
        prayerNameAr: String,
        prayerTime: Long
    ) {
        // Ensure prayer_tracking channel exists — receiver can fire without the app ever being opened
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            if (nm.getNotificationChannel("prayer_tracking") == null) {
                val ch = android.app.NotificationChannel(
                    "prayer_tracking", "Prayer Tracking",
                    android.app.NotificationManager.IMPORTANCE_DEFAULT
                ).apply { description = "Post-prayer check and daily summary" }
                nm.createNotificationChannel(ch)
            }
        }

        val defaultPrefs = context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)
        val language = defaultPrefs.getString("language", "en") ?: "en"
        val isArabic = language == "ar"

        val prayerLabel = if (isArabic) prayerNameAr else prayerName
        val title = if (isArabic) "هل صليت $prayerLabel؟" else "Did you pray $prayerLabel?"
        val body = if (isArabic) "سجّل صلاتك الآن" else "Log your prayer now"

        val notificationId = getPostCheckNotificationId(prayerName)

        // Done button
        val doneIntent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            action = ACTION_POST_DONE
            putExtra(EXTRA_PRAYER_NAME, prayerName)
            putExtra(EXTRA_PRAYER_NAME_AR, prayerNameAr)
            putExtra(EXTRA_PRAYER_TIME, prayerTime)
        }
        val donePending = PendingIntent.getBroadcast(
            context, notificationId + 1, doneIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Late button
        val lateIntent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            action = ACTION_POST_LATE
            putExtra(EXTRA_PRAYER_NAME, prayerName)
            putExtra(EXTRA_PRAYER_NAME_AR, prayerNameAr)
            putExtra(EXTRA_PRAYER_TIME, prayerTime)
        }
        val latePending = PendingIntent.getBroadcast(
            context, notificationId + 2, lateIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Missed button
        val missedIntent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            action = ACTION_POST_MISSED
            putExtra(EXTRA_PRAYER_NAME, prayerName)
            putExtra(EXTRA_PRAYER_NAME_AR, prayerNameAr)
            putExtra(EXTRA_PRAYER_TIME, prayerTime)
        }
        val missedPending = PendingIntent.getBroadcast(
            context, notificationId + 3, missedIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Remind Later button → opens app picker
        val laterIntent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            action = ACTION_POST_LATER
            putExtra(EXTRA_PRAYER_NAME, prayerName)
            putExtra(EXTRA_PRAYER_NAME_AR, prayerNameAr)
            putExtra(EXTRA_PRAYER_TIME, prayerTime)
        }
        val laterPending = PendingIntent.getBroadcast(
            context, notificationId + 4, laterIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Tap notification → opens app
        val contentIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val contentPending = PendingIntent.getActivity(
            context, notificationId + 5, contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, "prayer_tracking")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(contentPending)
            .addAction(0, if (isArabic) "صلّيت" else "Done", donePending)
            .addAction(0, if (isArabic) "متأخر" else "Late", latePending)
            .addAction(0, if (isArabic) "فاتتني" else "Missed", missedPending)
            .addAction(0, if (isArabic) "ذكّرني لاحقاً" else "Remind Later", laterPending)

        try {
            val notificationManager = NotificationManagerCompat.from(context)
            notificationManager.notify(notificationId, builder.build())
            Log.d(TAG, "📋 [POST_CHECK] Notification shown for $prayerName")
        } catch (e: Exception) {
            Log.e(TAG, "❌ [POST_CHECK] Error showing notification: ${e.message}")
        }
    }

    /**
     * Handle button actions from post-prayer check notification
     */
    private fun handlePostPrayerCheckAction(
        context: Context,
        action: String,
        prayerName: String,
        prayerNameAr: String,
        prayerTime: Long
    ) {
        val prefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
        val notificationId = getPostCheckNotificationId(prayerName)

        when (action) {
            ACTION_POST_DONE -> {
                val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
                prefs.edit().putString("prayer_status_${prayerName}_${today}", "on_time").apply()
                NotificationManagerCompat.from(context).cancel(notificationId)
                Log.d(TAG, "✅ [POST_CHECK] Marked $prayerName as on_time")
                notifyFlutterPrayerStatus(context, prayerName, "on_time")
            }
            ACTION_POST_LATE -> {
                val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
                prefs.edit().putString("prayer_status_${prayerName}_${today}", "late").apply()
                NotificationManagerCompat.from(context).cancel(notificationId)
                Log.d(TAG, "⏰ [POST_CHECK] Marked $prayerName as late")
                notifyFlutterPrayerStatus(context, prayerName, "late")
            }
            ACTION_POST_MISSED -> {
                val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
                prefs.edit().putString("prayer_status_${prayerName}_${today}", "missed").apply()
                NotificationManagerCompat.from(context).cancel(notificationId)
                Log.d(TAG, "❌ [POST_CHECK] Marked $prayerName as missed")
                notifyFlutterPrayerStatus(context, prayerName, "missed")
            }
            ACTION_POST_LATER -> {
                NotificationManagerCompat.from(context).cancel(notificationId)
                try {
                    val intent = Intent(context, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        putExtra("open_post_prayer_picker", true)
                        putExtra(EXTRA_PRAYER_NAME, prayerName)
                        putExtra(EXTRA_PRAYER_NAME_AR, prayerNameAr)
                        putExtra(EXTRA_PRAYER_TIME, prayerTime)
                    }
                    context.startActivity(intent)
                    Log.d(TAG, "🔕 [POST_CHECK] Opening picker for $prayerName")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ [POST_CHECK] Failed to open picker: ${e.message}")
                }
            }
        }
    }

    private fun notifyFlutterPrayerStatus(context: Context, prayerName: String, status: String) {
        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("update_prayer_status", true)
                putExtra("prayer_name", prayerName)
                putExtra("prayer_status", status)
            }
            context.startActivity(intent)
            Log.d(TAG, "📡 [PRAYER_STATUS] Notified Flutter: $prayerName → $status")
        } catch (e: Exception) {
            Log.e(TAG, "❌ [PRAYER_STATUS] Failed to notify Flutter: ${e.message}")
        }
    }
}
