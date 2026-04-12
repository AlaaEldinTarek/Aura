package com.aura.hala

import android.content.Context
import android.media.AudioManager
import android.util.Log
import android.app.AlarmManager
import android.app.PendingIntent
import android.os.Build

/**
 * Silent mode automation - simplified version
 * The silent mode notification has been moved to the Adhan notification buttons
 * This file now only contains helper functions
 */

private const val TAG = "SilentMode"

// Default silent mode duration (20 minutes)
private const val DEFAULT_SILENT_DURATION_MINUTES = 20

/**
 * Helper object for silent mode operations
 * NOTE: Silent mode is now controlled from the Adhan notification buttons
 * This scheduler is kept for backward compatibility but no longer shows separate notifications
 */
object SilentModeScheduler {

    /**
     * Trigger silent mode at prayer time
     * NOTE: This no longer shows a separate notification
     * Silent mode is now enabled via the button on the Adhan notification
     */
    fun triggerSilentMode(
        context: Context,
        prayerName: String,
        prayerNameAr: String,
        durationMinutes: Int = DEFAULT_SILENT_DURATION_MINUTES
    ) {
        Log.d(TAG, "🔕 Silent mode trigger requested for $prayerName ($prayerNameAr)")
        Log.d(TAG, "ℹ️ Silent mode is now controlled via Adhan notification button")
        // No longer showing separate notification
        // User clicks "Silent Mode" button on Adhan notification to enable it
    }

    /**
     * Cancel all silent mode operations
     */
    fun cancelAll(context: Context) {
        // Cancel any pending alarms
        cancelSilentOffAlarm(context)
        restoreRingerMode(context)
        Log.d(TAG, "🛑 All silent mode cancelled")
    }

    /**
     * Cancel silent OFF alarm
     */
    fun cancelSilentOffAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val silentOffIntent = android.content.Intent(context, SilentOffReceiver::class.java)
        val pendingIntentOff = PendingIntent.getBroadcast(
            context,
            3999,
            silentOffIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntentOff)

        Log.d(TAG, "❌ Cancelled silent OFF alarm")
    }

    /**
     * Restore ringer mode
     */
    private fun restoreRingerMode(context: Context) {
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val sharedPrefs = context.getSharedPreferences("aura_silent_mode", Context.MODE_PRIVATE)

        val savedRingerMode = sharedPrefs.getInt("saved_ringer_mode", AudioManager.RINGER_MODE_NORMAL)
        audioManager.ringerMode = savedRingerMode

        // Mark silent mode as inactive
        sharedPrefs.edit().putBoolean("is_silent_active", false).apply()

        Log.d(TAG, "🔊 Restored ringer mode to: $savedRingerMode")
    }
}

// Remove all the old receiver classes since they're no longer needed
// The silent mode is now handled by ToggleSilentModeReceiver and SilentOffReceiver in ToggleSilentModeReceiver.kt
