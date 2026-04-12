package com.aura.hala

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class BackgroundServiceHandler(private val context: Context) {

    companion object {
        private const val CHANNEL = "com.aura.hala/background_service"
        private const val TAG = "BackgroundServiceHandler"
    }

    fun setup(methodChannel: MethodChannel) {
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    PrayerForegroundService.startService(context)
                    result.success(null)
                }
                "stopForegroundService" -> {
                    PrayerForegroundService.stopService(context)
                    result.success(null)
                }
                "isForegroundServiceRunning" -> {
                    // Check if service is running
                    val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                    val isRunning = activityManager.getRunningServices(Integer.MAX_VALUE)
                        .any { it.service.className == PrayerForegroundService::class.java.name }
                    result.success(isRunning)
                }
                "updatePrayerTimes" -> {
                    // Update prayer times in foreground service
                    try {
                        val prayerTimesMap = call.argument<Map<String, String>>("prayerTimes") ?: emptyMap()
                        val nextPrayerName = call.argument<String>("nextPrayerName")
                        val nextPrayerNameAr = call.argument<String>("nextPrayerNameAr")
                        val nextPrayerTime = call.argument<Long>("nextPrayerTime")
                        val language = call.argument<String>("language") ?: "en"

                        // Save to SharedPreferences for persistence
                        PrayerForegroundService.updatePrayerTimes(
                            context,
                            prayerTimesMap,
                            nextPrayerName,
                            nextPrayerNameAr,
                            nextPrayerTime,
                            language
                        )

                        // Update the running service if it's active
                        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                        val isRunning = activityManager.getRunningServices(Integer.MAX_VALUE)
                            .any { it.service.className == PrayerForegroundService::class.java.name }

                        if (isRunning && nextPrayerName != null && nextPrayerNameAr != null && nextPrayerTime != null) {
                            // Service is running, update it directly
                            Log.d(TAG, "Foreground service is running, updating prayer times")
                            // Note: We'd need to get the service instance to call updateFromFlutter
                            // For now, the SharedPreferences update will be picked up on next service restart
                        }

                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error updating prayer times: ${e.message}")
                        result.error("UPDATE_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
