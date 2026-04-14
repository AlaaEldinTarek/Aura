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

    private var currentRoute: String = "/"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Create notification channel early to ensure it exists before alarms fire
        createNotificationChannel()
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

        // Navigation Channel - for tracking current route (future use)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL).setMethodCallHandler { call, result ->
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
                    editor.apply()

                    // Update widgets
                    updateWidgets()

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

                    Log.d("PrayerChannel", "⏰ Scheduling reminder alarm for $prayerName (10 min before)")
                    PrayerAlarmReceiver.scheduleReminderAlarm(this, prayerName, prayerNameAr, prayerTime, requestCode)
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
    }

    private fun updateWidgets() {
        val appWidgetManager = getSystemService(Context.APPWIDGET_SERVICE) as AppWidgetManager

        // Update Next Prayer Widget
        val nextWidgetComponent = ComponentName(this, NextPrayerWidget::class.java)
        val nextWidgetIds = appWidgetManager.getAppWidgetIds(nextWidgetComponent)
        for (appWidgetId in nextWidgetIds) {
            NextPrayerWidget().updateAppWidget(this, appWidgetManager, appWidgetId)
        }

        // Update All Prayers Widget
        val allWidgetComponent = ComponentName(this, AllPrayersWidget::class.java)
        val allWidgetIds = appWidgetManager.getAppWidgetIds(allWidgetComponent)
        for (appWidgetId in allWidgetIds) {
            AllPrayersWidget().updateAppWidget(this, appWidgetManager, appWidgetId)
        }
    }
}
