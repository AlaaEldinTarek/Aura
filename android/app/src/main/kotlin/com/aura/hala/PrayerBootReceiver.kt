package com.aura.hala

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.util.Log

/**
 * BroadcastReceiver that handles device boot events
 * Restarts prayer time alarms after device restart
 */
class PrayerBootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PrayerBootReceiver"

        // Boot actions for different manufacturers
        private const val ACTION_BOOT_COMPLETED = "android.intent.action.BOOT_COMPLETED"
        private const val ACTION_QUICKBOOT_POWERON = "android.intent.action.QUICKBOOT_POWERON"
        private const val ACTION_HTC_QUICKBOOT = "com.htc.intent.action.QUICKBOOT_POWERON"
        private const val ACTION_HUAWEI_BOOT = "android.intent.action.ACTION_BOOT_COMPLETED"
        private const val ACTION_EMUI_BOOT = "android.intent.action.REBOOT"
        private const val ACTION_MY_PACKAGE_REPLACED = "android.intent.action.MY_PACKAGE_REPLACED"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d(TAG, "Boot event received: $action")

        when (action) {
            ACTION_BOOT_COMPLETED,
            ACTION_QUICKBOOT_POWERON,
            ACTION_HTC_QUICKBOOT,
            ACTION_HUAWEI_BOOT,
            ACTION_EMUI_BOOT,
            ACTION_MY_PACKAGE_REPLACED -> {
                Log.d(TAG, "Restarting prayer alarms after boot")

                // Android persists ringerMode across reboots; restore it if silent mode was active.
                val silentPrefs = context.getSharedPreferences("aura_silent_mode", Context.MODE_PRIVATE)
                if (silentPrefs.getBoolean("is_silent_active", false)) {
                    val savedRingerMode = silentPrefs.getInt("saved_ringer_mode", AudioManager.RINGER_MODE_NORMAL)
                    try {
                        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        audioManager.ringerMode = savedRingerMode
                        Log.d(TAG, "🔕 [SILENT] Restored ringer mode to $savedRingerMode on boot")
                    } catch (e: SecurityException) {
                        // Do Not Disturb access may be missing on some OEM skins; still clear the flag below.
                        Log.e(TAG, "❌ [SILENT] Failed to restore ringer mode (DND access missing): ${e.message}")
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ [SILENT] Failed to restore ringer mode: ${e.message}")
                    }
                    // Always clear the flag, even if the ringer restore failed.
                    silentPrefs.edit()
                        .putBoolean("is_silent_active", false)
                        .putLong("silent_end_time", 0)
                        .apply()
                    Log.d(TAG, "🔕 [SILENT] Cleared stale silent-mode state on boot")
                }

                // Wait a bit for the system to fully start
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    reschedulePrayerAlarms(context)
                    rescheduleDailySummary(context)
                    rescheduleJumuahReminder(context)
                    restartForegroundService(context)
                    DailyRecalcReceiver.schedule(context)
                    PrayerRecalcWorker.schedule(context)
                }, 30000) // 30 seconds delay
            }
        }
    }

    /**
     * Reschedule all prayer alarms after boot
     */
    private fun reschedulePrayerAlarms(context: Context) {
        Log.d(TAG, "Rescheduling prayer alarms")

        val serviceIntent = Intent(context, PrayerRescheduleService::class.java)

        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "Prayer reschedule service started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start prayer reschedule service: ${e.message}")
        }
    }

    private fun rescheduleJumuahReminder(context: Context) {
        JumuahReminderReceiver.schedule(context)
        Log.d(TAG, "Jumu'ah reminder rescheduled after boot")
    }

    private fun restartForegroundService(context: Context) {
        try {
            if (PrayerForegroundService.startServiceIfAllowed(context, "boot")) {
                Log.d(TAG, "✅ Prayer foreground service restarted after boot")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to restart prayer foreground service: ${e.message}")
        }
    }

    private fun rescheduleDailySummary(context: Context) {
        val trackingEnabled = FlutterPrefs.getBoolean(context, "prayer_tracking_notifications_enabled", true)
        if (!trackingEnabled) return
        val timeStr = FlutterPrefs.getString(context, "daily_summary_time", "21:00")
        DailySummaryReceiver.schedule(context, timeStr)
        Log.d(TAG, "Daily prayer summary rescheduled for $timeStr")
    }
}
