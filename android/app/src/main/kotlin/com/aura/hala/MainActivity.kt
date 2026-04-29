package com.aura.hala

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.app.AlertDialog
import android.app.NotificationChannel
import android.app.NotificationManager
import android.graphics.Color
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val RINGER_CHANNEL = "com.aura.hala/ringer_mode"
    private val APP_CHANNEL = "com.aura.hala/app_control"
    private val NAVIGATION_CHANNEL = "com.aura.hala/navigation"
    private val WIDGET_CHANNEL = "com.aura.hala/widgets"
    private val ADHAN_CHANNEL = "com.aura.hala/adhan"
    private val PRAYER_CHANNEL = "com.aura.hala/prayer_alarms"
    private val BACKGROUND_SERVICE_CHANNEL = "com.aura.hala/background_service"
    private val FOCUS_MODE_CHANNEL = "com.aura.hala/focus_mode"

    private var currentRoute: String = "/"
    private var navigationChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Create notification channel early to ensure it exists before alarms fire
        createNotificationChannel()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShortcutIntent(intent)
        handleReminderPickerIntent(intent)
        handlePostPrayerPickerIntent(intent)
        handlePrayerStatusUpdateIntent(intent)
        handleQuranReaderIntent(intent)
    }

    private fun handleShortcutIntent(intent: Intent) {
        val route = intent.getStringExtra("route")
        if (route != null) {
            Log.d("MainActivity", "🔗 [SHORTCUT] Route: $route")
            navigationChannel?.invokeMethod("navigateToRoute", mapOf("route" to route))
        }
    }

    private fun handleQuranReaderIntent(intent: Intent) {
        if (intent.getBooleanExtra("open_quran_reader", false)) {
            Log.d("MainActivity", "📖 [QURAN] Opening Quran reader")
            navigationChannel?.invokeMethod("openQuranReader", null)
        }
    }

    private fun handleReminderPickerIntent(intent: Intent) {
        if (intent.getBooleanExtra("open_reminder_picker", false)) {
            val prayerName = intent.getStringExtra("reminder_prayer_name") ?: return
            val prayerNameAr = intent.getStringExtra("reminder_prayer_name_ar") ?: prayerName
            val prayerTime = intent.getLongExtra("reminder_prayer_time", 0L)
            Log.d("MainActivity", "🔕 [REMINDER_PICKER] Opening picker for $prayerName")
            navigationChannel?.invokeMethod("openReminderPicker", mapOf(
                "prayerName" to prayerName,
                "prayerNameAr" to prayerNameAr,
                "prayerTime" to prayerTime
            ))
        }
    }

    private fun handlePrayerStatusUpdateIntent(intent: Intent) {
        if (intent.getBooleanExtra("update_prayer_status", false)) {
            val prayerName = intent.getStringExtra("prayer_name") ?: return
            val status = intent.getStringExtra("prayer_status") ?: return
            Log.d("MainActivity", "📋 [PRAYER_STATUS] Updating $prayerName → $status")
            navigationChannel?.invokeMethod("updatePrayerStatus", mapOf(
                "prayerName" to prayerName,
                "status" to status
            ))
        }
    }

    private fun handlePostPrayerPickerIntent(intent: Intent) {
        if (intent.getBooleanExtra("open_post_prayer_picker", false)) {
            val prayerName = intent.getStringExtra("prayer_name") ?: return
            val prayerNameAr = intent.getStringExtra("prayer_name_ar") ?: prayerName
            val prayerTime = intent.getLongExtra("prayer_time", 0L)
            Log.d("MainActivity", "📋 [POST_PRAYER_PICKER] Opening picker for $prayerName")
            navigationChannel?.invokeMethod("openPostPrayerPicker", mapOf(
                "prayerName" to prayerName,
                "prayerNameAr" to prayerNameAr,
                "prayerTime" to prayerTime
            ))
        }
    }

    private fun createNotificationChannel() {
        Log.d("MainActivity", "═══════════════════════════════════════")
        Log.d("MainActivity", "🔔 [CHANNEL] createNotificationChannel() called")
        Log.d("MainActivity", "🔔 [CHANNEL] Android SDK: ${Build.VERSION.SDK_INT}, O: ${Build.VERSION_CODES.O}")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "prayer_times"
            val channelName = "Prayer Times"
            val channelDescription = "Notifications for prayer times"

            Log.d("MainActivity", "🔔 [CHANNEL] Creating channel: id='$channelId', name='$channelName'")

            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
                enableVibration(true)
                enableLights(true)
                lightColor = Color.BLUE
                setShowBadge(true)
                setBypassDnd(false) // Don't bypass DND, user controls this
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)

            Log.d("MainActivity", "✅ [CHANNEL] Notification channel '$channelId' created with importance: $importance")

            // Verify channel was created
            val createdChannel = notificationManager.getNotificationChannel(channelId)
            if (createdChannel != null) {
                Log.d("MainActivity", "✅ [CHANNEL] VERIFIED - Channel exists with importance: ${createdChannel.importance}")
            } else {
                Log.e("MainActivity", "❌ [CHANNEL] ERROR - Channel not found after creation!")
            }

            // Prayer tracking channel (post-prayer check + daily summary)
            val trackingChannel = NotificationChannel(
                "prayer_tracking",
                "Prayer Tracking",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Post-prayer check and daily summary notifications"
                enableVibration(false)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(trackingChannel)
            Log.d("MainActivity", "✅ [CHANNEL] prayer_tracking channel created")

            // Quran reminder channel
            val quranChannel = NotificationChannel("quran_reminder", "Quran Reminder", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Daily Quran reading reminders"
                enableVibration(true)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(quranChannel)
            Log.d("MainActivity", "✅ [CHANNEL] Quran reminder channel created")
        } else {
            Log.d("MainActivity", "⏭️ [CHANNEL] SDK < O, notification channel not needed")
        }
        Log.d("MainActivity", "═══════════════════════════════════════")
    }

    override fun onResume() {
        super.onResume()
        // Check permissions when app resumes
        checkAndRequestPermissions()
    }

    private fun checkAndRequestPermissions() {
        // Check exact alarm permission (Android 12+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            if (!alarmManager.canScheduleExactAlarms()) {
                Log.d("MainActivity", "⚠️ Exact alarm permission NOT granted")
            } else {
                Log.d("MainActivity", "✅ Exact alarm permission granted")
            }
        }

        // Check battery optimization
        if (!isIgnoringBatteryOptimizations()) {
            Log.d("MainActivity", "⚠️ Battery optimization NOT disabled")
        } else {
            Log.d("MainActivity", "✅ Battery optimization disabled")
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            return powerManager.isIgnoringBatteryOptimizations(packageName)
        }
        return true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Ringer Mode Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RINGER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getRingerMode" -> {
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    result.success(audioManager.ringerMode)
                }
                "setRingerMode" -> {
                    val mode = call.argument<Int>("mode")
                    if (mode != null) {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        audioManager.ringerMode = mode
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Mode not provided", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // App Control Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_URL_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "URL not provided", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Navigation Channel - for tracking current route and handling shortcuts
        navigationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL)
        navigationChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "setCurrentRoute" -> {
                    val route = call.argument<String>("route")
                    if (route != null) {
                        this.currentRoute = route
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Route not provided", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Check if launched from a shortcut (cold start)
        handleShortcutIntent(intent)
        // Check if launched from reminder picker (cold start)
        handleReminderPickerIntent(intent)
        handlePostPrayerPickerIntent(intent)
        handlePrayerStatusUpdateIntent(intent)

        // Widget Channel - for updating home screen widgets
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updatePrayerWidgets" -> {
                    val prayerTimes = call.argument<Map<String, String>>("prayerTimes")
                    val nextPrayerName = call.argument<String>("nextPrayerName")
                    val nextPrayerNameAr = call.argument<String>("nextPrayerNameAr")
                    val nextPrayerTime = call.argument<Long>("nextPrayerTime")
                    val language = call.argument<String>("language") ?: "en"
                    val locationName = call.argument<String>("locationName") ?: "Unknown"
                    val themeMode = call.argument<String>("themeMode") ?: "system"

                    // Save to SharedPreferences for widgets to read
                    val prefs = getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
                    val editor = prefs.edit()

                    editor.putString("language", language)
                    editor.putString("location_name", locationName)
                    editor.putString("themeMode", themeMode)

                    prayerTimes?.forEach { (key, value) ->
                        editor.putString(key, value)
                    }

                    editor.putString("next_prayer_name", nextPrayerName)
                    editor.putString("next_prayer_name_ar", nextPrayerNameAr)
                    editor.putString("next_prayer_time", nextPrayerTime?.toString())

                    // Save iqama times for adhan mode iqama countdown
                    val iqamaTimes = call.argument<Map<String, String>>("iqamaTimes")
                    iqamaTimes?.forEach { (key, value) ->
                        editor.putString(key, value)
                    }

                    editor.apply()

                    // Update widgets
                    updateWidgets()

                    result.success(true)
                }
                "updateTasksWidget" -> {
                    val taskCount = call.argument<Int>("taskCount") ?: 0
                    val tasksDone = call.argument<Int>("tasksDone") ?: 0
                    val tasksTotal = call.argument<Int>("tasksTotal") ?: 0
                    val language = call.argument<String>("language") ?: "en"
                    val themeMode = call.argument<String>("themeMode") ?: "system"

                    val prefs = getSharedPreferences("aura_tasks_widget", Context.MODE_PRIVATE)
                    val editor = prefs.edit()

                    editor.putInt("task_count", taskCount)
                    editor.putInt("tasks_done", tasksDone)
                    editor.putInt("tasks_total", tasksTotal)
                    editor.putInt("streak", call.argument<Int>("streak") ?: 0)
                    editor.putString("language", language)
                    editor.putString("themeMode", themeMode)

                    for (i in 0 until 5) {
                        editor.putString("task_${i}_id", call.argument<String>("task_${i}_id"))
                        editor.putString("task_${i}_title", call.argument<String>("task_${i}_title"))
                        editor.putString("task_${i}_time", call.argument<String>("task_${i}_time"))
                        editor.putString("task_${i}_priority", call.argument<String>("task_${i}_priority"))
                        editor.putString("task_${i}_category", call.argument<String>("task_${i}_category"))
                        editor.putInt("task_${i}_subtaskDone", call.argument<Int>("task_${i}_subtaskDone") ?: 0)
                        editor.putInt("task_${i}_subtaskTotal", call.argument<Int>("task_${i}_subtaskTotal") ?: 0)
                        editor.putBoolean("task_${i}_overdue", call.argument<Boolean>("task_${i}_overdue") ?: false)
                    }
                    editor.apply()

                    updateTasksWidget()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Adhan Channel - for playing adhan at prayer times
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ADHAN_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playAdhan" -> {
                    val prayerName = call.argument<String>("prayerName") ?: "Fajr"
                    Log.d("AdhanChannel", "Flutter requested adhan for $prayerName")
                    // Play adhan using native MediaPlayer (works even if Flutter is paused)
                    AdhanPlayer.play(this, prayerName)
                    result.success(true)
                }
                "stopAdhan" -> {
                    Log.d("AdhanChannel", "Flutter requested stop adhan")
                    AdhanPlayer.stop()
                    result.success(true)
                }
                "setAdhanEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    val prefs = getSharedPreferences("aura_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("adhan_enabled", enabled).apply()
                    Log.d("AdhanChannel", "Adhan enabled set to $enabled")
                    result.success(true)
                }
                "isAdhanEnabled" -> {
                    val prefs = getSharedPreferences("aura_prefs", Context.MODE_PRIVATE)
                    val enabled = prefs.getBoolean("adhan_enabled", true)
                    result.success(enabled)
                }
                "setCustomAdhan" -> {
                    val path = call.argument<String>("path")
                    AdhanPlayer.setCustomAdhan(path)
                    Log.d("AdhanChannel", "Custom adhan set to: $path")
                    result.success(true)
                }
                "getCustomAdhan" -> {
                    val path = AdhanPlayer.getCustomAdhan()
                    result.success(path)
                }
                else -> result.notImplemented()
            }
        }

        // Prayer Alarms Channel - for scheduling native alarms at exact prayer times
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRAYER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "schedulePrayerAlarm" -> {
                    val prayerName = call.argument<String>("prayerName") ?: return@setMethodCallHandler result.error("INVALID_ARGUMENT", "prayerName required", null)
                    val prayerNameAr = call.argument<String>("prayerNameAr") ?: prayerName
                    val prayerTime = call.argument<Long>("prayerTime") ?: return@setMethodCallHandler result.error("INVALID_ARGUMENT", "prayerTime required", null)
                    val requestCode = call.argument<Int>("requestCode") ?: 0

                    Log.d("PrayerChannel", "🔔 Scheduling alarm for $prayerName at $prayerTime")
                    PrayerAlarmReceiver.schedulePrayerAlarm(this, prayerName, prayerNameAr, prayerTime, requestCode)
                    result.success(true)
                }
                "scheduleReminderAlarm" -> {
                    val prayerName = call.argument<String>("prayerName") ?: return@setMethodCallHandler result.error("INVALID_ARGUMENT", "prayerName required", null)
                    val prayerNameAr = call.argument<String>("prayerNameAr") ?: prayerName
                    val prayerTime = call.argument<Long>("prayerTime") ?: return@setMethodCallHandler result.error("INVALID_ARGUMENT", "prayerTime required", null)
                    val requestCode = call.argument<Int>("requestCode") ?: 0
                    val delayMinutes = call.argument<Int>("delayMinutes")

                    if (delayMinutes != null && delayMinutes > 0) {
                        Log.d("PrayerChannel", "🔕 Scheduling delayed reminder for $prayerName ($delayMinutes min)")
                        PrayerAlarmReceiver.scheduleDelayedReminder(this, prayerName, prayerNameAr, prayerTime, requestCode, delayMinutes)
                    } else {
                        Log.d("PrayerChannel", "⏰ Scheduling reminder alarm for $prayerName (45 min before)")
                        PrayerAlarmReceiver.scheduleReminderAlarm(this, prayerName, prayerNameAr, prayerTime, requestCode)
                    }
                    result.success(true)
                }
                "testAdhanNow" -> {
                    val prayerName = call.argument<String>("prayerName") ?: "Zuhr"
                    val prayerNameAr = when (prayerName) {
                        "Fajr" -> "الفجر"
                        "Dhuhr", "Zuhr" -> "الظهر"
                        "Asr" -> "العصر"
                        "Maghrib" -> "المغرب"
                        "Isha" -> "العشاء"
                        else -> "الظهر"
                    }
                    Log.d("PrayerChannel", "🧪 TESTING ADHAN in 10 seconds for $prayerName")

                    // Schedule alarm to fire in 10 seconds
                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                    val testTime = System.currentTimeMillis() + (10 * 1000)

                    val intent = Intent(this, PrayerAlarmReceiver::class.java).apply {
                        putExtra(PrayerAlarmReceiver.EXTRA_PRAYER_NAME, prayerName)
                        putExtra(PrayerAlarmReceiver.EXTRA_PRAYER_NAME_AR, prayerNameAr)
                        putExtra(PrayerAlarmReceiver.EXTRA_PRAYER_TIME, testTime)
                    }

                    val pendingIntent = android.app.PendingIntent.getBroadcast(
                        this,
                        9999, // Test request code
                        intent,
                        android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                    )

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setExactAndAllowWhileIdle(
                            android.app.AlarmManager.RTC_WAKEUP,
                            testTime,
                            pendingIntent
                        )
                    } else {
                        alarmManager.setExact(
                            android.app.AlarmManager.RTC_WAKEUP,
                            testTime,
                            pendingIntent
                        )
                    }

                    Log.d("PrayerChannel", "🧪 Test alarm scheduled in 10 seconds for $prayerName")
                    result.success(true)
                }
                "cancelAllPrayerAlarms" -> {
                    Log.d("PrayerChannel", "Cancelling all prayer alarms")
                    PrayerAlarmReceiver.cancelAllAlarms(this)
                    result.success(true)
                }
                "schedulePostPrayerCheck" -> {
                    val prayerName = call.argument<String>("prayerName")
                        ?: return@setMethodCallHandler result.error("INVALID", "prayerName required", null)
                    val prayerNameAr = call.argument<String>("prayerNameAr") ?: prayerName
                    val prayerTime = call.argument<Long>("prayerTime")
                        ?: return@setMethodCallHandler result.error("INVALID", "prayerTime required", null)
                    val requestCode = call.argument<Int>("requestCode") ?: 0
                    PrayerAlarmReceiver.schedulePostPrayerCheck(this, prayerName, prayerNameAr, prayerTime, requestCode)
                    result.success(true)
                }
                "cancelPostPrayerCheck" -> {
                    val prayerName = call.argument<String>("prayerName")
                        ?: return@setMethodCallHandler result.error("INVALID", "prayerName required", null)
                    val requestCode = call.argument<Int>("requestCode") ?: 0
                    PrayerAlarmReceiver.cancelPostPrayerCheck(this, prayerName, requestCode)
                    result.success(true)
                }
                "markPrayerTracked" -> {
                    val prayerName = call.argument<String>("prayerName")
                        ?: return@setMethodCallHandler result.error("INVALID", "prayerName required", null)
                    val status = call.argument<String>("status") ?: "on_time"
                    PrayerAlarmReceiver.markPrayerTracked(this, prayerName, status)
                    result.success(true)
                }
                "getNativePrayerStatuses" -> {
                    val prefs = getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
                    val statuses = mutableMapOf<String, String>()
                    for ((key, value) in prefs.all) {
                        if (key.startsWith("prayer_status_") && value is String) {
                            statuses[key] = value
                        }
                    }
                    Log.d("PrayerChannel", "📊 Returning ${statuses.size} native prayer statuses")
                    result.success(statuses)
                }
                "clearNativePrayerStatus" -> {
                    val key = call.argument<String>("key")
                    if (key != null) {
                        val prefs = getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
                        prefs.edit().remove(key).apply()
                        Log.d("PrayerChannel", "🗑️ Cleared native prayer status: $key")
                    }
                    result.success(true)
                }
                "canScheduleExactAlarms" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                        result.success(alarmManager.canScheduleExactAlarms())
                    } else {
                        result.success(true) // Permission not needed on older versions
                    }
                }
                "openExactAlarmSettings" -> {
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                data = Uri.parse("package:$packageName")
                            }
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                            }
                        }
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "❌ Failed to open exact alarm settings: ${e.message}")
                        result.success(true)
                    }
                }
                "scheduleDailySummary" -> {
                    val timeStr = call.argument<String>("time") ?: "21:00"
                    DailySummaryReceiver.schedule(this, timeStr)
                    result.success(true)
                }
                "cancelDailySummary" -> {
                    DailySummaryReceiver.cancel(this)
                    result.success(true)
                }
                "scheduleQuranReminderAlarm" -> {
                    val hour = call.argument<Int>("hour") ?: return@setMethodCallHandler result.error("INVALID", "hour required", null)
                    val minute = call.argument<Int>("minute") ?: return@setMethodCallHandler result.error("INVALID", "minute required", null)
                    val slot = call.argument<Int>("slot") ?: 0
                    val language = call.argument<String>("language") ?: "en"
                    val snoozeMinutes = call.argument<Int>("snoozeMinutes") ?: 30
                    Log.d("PrayerChannel", "📖 Scheduling Quran reminder slot $slot at $hour:$minute")
                    PrayerAlarmReceiver.scheduleQuranReminderAlarm(this, hour, minute, slot, language, snoozeMinutes)
                    result.success(true)
                }
                "cancelQuranReminderAlarms" -> {
                    Log.d("PrayerChannel", "📖 Cancelling all Quran alarms")
                    PrayerAlarmReceiver.cancelQuranReminderAlarms(this)
                    result.success(true)
                }
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "openBatteryOptimizationSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "❌ Failed to open battery optimization settings: ${e.message}")
                        // Fallback to app details settings
                        try {
                            val fallbackIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(fallbackIntent)
                        } catch (e2: Exception) {
                            Log.e("MainActivity", "❌ Fallback also failed: ${e2.message}")
                        }
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Background Service Channel - for managing foreground service
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKGROUND_SERVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    Log.d("BackgroundService", "Starting foreground service")
                    PrayerForegroundService.startService(this)
                    result.success(true)
                }
                "stopForegroundService" -> {
                    Log.d("BackgroundService", "Stopping foreground service")
                    PrayerForegroundService.stopService(this)
                    result.success(true)
                }
                "isForegroundServiceRunning" -> {
                    val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                    val isRunning = activityManager.getRunningServices(Integer.MAX_VALUE)
                        .any { it.service.className == PrayerForegroundService::class.java.name }
                    result.success(isRunning)
                }
                "updatePrayerTimes" -> {
                    val prayerTimes = call.argument<Map<String, String>>("prayerTimes") ?: emptyMap()
                    val nextPrayerName = call.argument<String>("nextPrayerName") ?: "Maghrib"
                    val nextPrayerNameAr = call.argument<String>("nextPrayerNameAr") ?: "المغرب"
                    val nextPrayerTime = call.argument<Long>("nextPrayerTime") ?: System.currentTimeMillis()
                    val language = call.argument<String>("language") ?: "en"

                    // Save to SharedPreferences
                    PrayerForegroundService.updatePrayerTimes(
                        this, prayerTimes, nextPrayerName, nextPrayerNameAr, nextPrayerTime, language
                    )

                    // Also notify the running service instance directly
                    try {
                        val service = PrayerForegroundService.getInstance()
                        if (service != null) {
                            service.updateFromFlutter(
                                prayerTimes, nextPrayerName, nextPrayerNameAr, nextPrayerTime, language
                            )
                            Log.d("BackgroundService", "✅ Updated running service instance: next = $nextPrayerName")
                        } else {
                            Log.d("BackgroundService", "Service not running, data saved to SharedPreferences")
                        }
                    } catch (e: Exception) {
                        Log.w("BackgroundService", "Could not update running service: ${e.message}")
                    }

                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Focus Mode Channel - for scheduling focus mode at task time
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOCUS_MODE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleFocusAlarm" -> {
                    val taskId = call.argument<String>("taskId") ?: return@setMethodCallHandler result.error("INVALID_ARGUMENT", "taskId required", null)
                    val taskTitle = call.argument<String>("taskTitle") ?: "Focus Mode"
                    val taskDesc = call.argument<String>("taskDesc") ?: ""
                    val triggerTime = call.argument<Long>("triggerTime") ?: return@setMethodCallHandler result.error("INVALID_ARGUMENT", "triggerTime required", null)
                    val durationMinutes = call.argument<Int>("durationMinutes") ?: 25
                    val language = call.argument<String>("language") ?: "en"

                    Log.d("FocusModeChannel", "🎯 Scheduling focus mode for '$taskTitle' at $triggerTime")
                    FocusModeReceiver.scheduleFocusAlarm(this, taskId, taskTitle, taskDesc, triggerTime, durationMinutes, language)
                    result.success(true)
                }
                "cancelFocusAlarm" -> {
                    val taskId = call.argument<String>("taskId") ?: return@setMethodCallHandler result.error("INVALID_ARGUMENT", "taskId required", null)
                    Log.d("FocusModeChannel", "🗑️ Cancelling focus alarm for task $taskId")
                    FocusModeReceiver.cancelFocusAlarm(this, taskId)
                    result.success(true)
                }
                "canDrawOverlays" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(this))
                    } else {
                        result.success(true)
                    }
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e("FocusModeChannel", "❌ Failed to open overlay settings: ${e.message}")
                            result.success(false)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "getFocusCompletedTaskId" -> {
                    val prefs = getSharedPreferences("${packageName}_preferences", Context.MODE_PRIVATE)
                    val taskId = prefs.getString("focus_completed_task_id", null)
                    if (taskId != null) {
                        prefs.edit().remove("focus_completed_task_id").remove("focus_task_was_completed").apply()
                    }
                    result.success(taskId)
                }
                "isAccessibilityServiceEnabled" -> {
                    // Accessibility service removed — always return false
                    result.success(false)
                }
                "requestAccessibilityPermission" -> {
                    // Accessibility service removed — no-op
                    result.success(false)
                }
                "hasDndAccess" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                        result.success(notificationManager.isNotificationPolicyAccessGranted)
                    } else {
                        result.success(true)
                    }
                }
                "requestDndAccess" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e("FocusModeChannel", "❌ Failed to open DND settings: ${e.message}")
                            result.success(false)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "startFocusService" -> {
                    val taskId = call.argument<String>("taskId") ?: return@setMethodCallHandler result.error("INVALID_ARGUMENT", "taskId required", null)
                    val taskTitle = call.argument<String>("taskTitle") ?: "Focus Mode"
                    val taskDesc = call.argument<String>("taskDesc") ?: ""
                    val durationMinutes = call.argument<Int>("durationMinutes") ?: 25
                    val language = call.argument<String>("language") ?: "en"
                    Log.d("FocusModeChannel", "🎯 Starting focus service for '$taskTitle'")
                    FocusModeService.start(this, taskId, taskTitle, taskDesc, durationMinutes, language)
                    result.success(true)
                }
                "stopFocusService" -> {
                    Log.d("FocusModeChannel", "⏹️ Stopping focus service")
                    FocusModeService.stop(this)
                    result.success(true)
                }
                "isFocusServiceRunning" -> {
                    result.success(FocusModeService.isRunning)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun updateWidgets() {
        val appWidgetManager = getSystemService(Context.APPWIDGET_SERVICE) as AppWidgetManager

        // Update All Prayers Widget
        val allWidgetComponent = ComponentName(this, AllPrayersWidget::class.java)
        val allWidgetIds = appWidgetManager.getAppWidgetIds(allWidgetComponent)
        for (appWidgetId in allWidgetIds) {
            AllPrayersWidget().updateAppWidget(this, appWidgetManager, appWidgetId)
        }

        // Update Daily Content Widget
        val dailyComponent = ComponentName(this, DailyContentWidget::class.java)
        for (id in appWidgetManager.getAppWidgetIds(dailyComponent)) {
            DailyContentWidget.updateAppWidget(this, appWidgetManager, id)
        }
    }

    private fun updateTasksWidget() {
        val appWidgetManager = getSystemService(Context.APPWIDGET_SERVICE) as AppWidgetManager

        // Tasks Widget (4x3)
        val tasksComponent = ComponentName(this, TasksWidget::class.java)
        for (id in appWidgetManager.getAppWidgetIds(tasksComponent)) {
            TasksWidget().updateAppWidget(this, appWidgetManager, id)
        }

        // Next Task Widget (4x1)
        val nextComponent = ComponentName(this, NextTaskWidget::class.java)
        for (id in appWidgetManager.getAppWidgetIds(nextComponent)) {
            NextTaskWidget().updateAppWidget(this, appWidgetManager, id)
        }

        // Update Daily Content Widget too
        val dailyComponent = ComponentName(this, DailyContentWidget::class.java)
        for (id in appWidgetManager.getAppWidgetIds(dailyComponent)) {
            DailyContentWidget.updateAppWidget(this, appWidgetManager, id)
        }
    }
}
