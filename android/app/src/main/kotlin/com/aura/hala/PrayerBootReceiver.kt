package com.aura.hala

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
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

                // Wait a bit for the system to fully start
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    reschedulePrayerAlarms(context)
                }, 30000) // 30 seconds delay
            }
        }
    }

    /**
     * Reschedule all prayer alarms after boot
     */
    private fun reschedulePrayerAlarms(context: Context) {
        Log.d(TAG, "Rescheduling prayer alarms")

        // Check if notifications are enabled
        val sharedPrefs = context.getSharedPreferences("aura_prefs", Context.MODE_PRIVATE)
        val notificationsEnabled = sharedPrefs.getBoolean("notifications_enabled", true)

        if (!notificationsEnabled) {
            Log.d(TAG, "Notifications are disabled, skipping alarm reschedule")
            return
        }

        // Start the prayer reschedule service
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
}
