package com.aura.hala

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.text.format.DateFormat
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import com.aura.hala.R
import java.util.Date

/**
 * BroadcastReceiver for handling silent mode actions from Adhan notification buttons
 * Actions: ENABLE_SILENT, DISMISS_SILENT, EXTEND_SILENT
 */
class ToggleSilentModeReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ToggleSilentMode"
        private const val PREFS_NAME = "aura_silent_mode"
        private const val KEY_SAVED_RINGER_MODE = "saved_ringer_mode"
        private const val KEY_SILENT_END_TIME = "silent_end_time"
        private const val KEY_IS_SILENT_ACTIVE = "is_silent_active"

        // Default silent mode duration (20 minutes)
        private const val DEFAULT_SILENT_DURATION_MINUTES = 20

        // Request code for silent OFF alarm
        private const val SILENT_OFF_REQUEST_CODE = 3999
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        val prayerName = intent.getStringExtra(PrayerAlarmReceiver.EXTRA_PRAYER_NAME) ?: "Prayer"
        val prayerNameAr = intent.getStringExtra(PrayerAlarmReceiver.EXTRA_PRAYER_NAME_AR) ?: prayerName

        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "🔕 Silent Mode action: $action for $prayerName")

        when (action) {
            "com.aura.hala.ENABLE_SILENT" -> {
                enableSilentMode(context, prayerName, prayerNameAr)
            }
            "com.aura.hala.DISMISS_SILENT" -> {
                dismissSilentMode(context)
            }
            "com.aura.hala.EXTEND_SILENT" -> {
                extendSilentMode(context, prayerName, prayerNameAr)
            }
            else -> {
                Log.w(TAG, "Unknown action: $action")
            }
        }
    }

    /**
     * Enable silent mode immediately
     */
    private fun enableSilentMode(context: Context, prayerName: String, prayerNameAr: String) {
        Log.d(TAG, "🔕 Enabling silent mode for $prayerName")

        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val sharedPrefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        // Check if we have DND permission
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
        sharedPrefs.edit().putInt(KEY_SAVED_RINGER_MODE, currentRingerMode).apply()
        Log.d(TAG, "📱 Saved current ringer mode: $currentRingerMode")
        Log.d(TAG, "🔐 Has DND permission: $hasDndPermission")

        // Set to silent mode
        try {
            if (hasDndPermission) {
                audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
                Log.d(TAG, "🔕 Enabled SILENT mode")
            } else {
                // Fallback: Use vibrate mode
                audioManager.ringerMode = AudioManager.RINGER_MODE_VIBRATE
                Log.d(TAG, "⚠️ No DND permission, using VIBRATE mode")
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ SecurityException: ${e.message}")
            // Fallback to vibrate mode
            try {
                audioManager.ringerMode = AudioManager.RINGER_MODE_VIBRATE
                Log.d(TAG, "⚠️ Fallback to vibrate mode")
            } catch (e2: Exception) {
                Log.e(TAG, "❌ Failed to set ringer mode: ${e2.message}")
            }
        }

        // Mark silent mode as active
        sharedPrefs.edit().putBoolean(KEY_IS_SILENT_ACTIVE, true).apply()

        // Calculate silent end time
        val silentEndTime = System.currentTimeMillis() + (DEFAULT_SILENT_DURATION_MINUTES * 60 * 1000)
        sharedPrefs.edit().putLong(KEY_SILENT_END_TIME, silentEndTime).apply()
        Log.d(TAG, "⏰ Silent mode will end in $DEFAULT_SILENT_DURATION_MINUTES minutes")

        // Schedule automatic silent OFF
        scheduleSilentOff(context, silentEndTime)

        // Show toast
        showSilentModeToast(context, prayerName, prayerNameAr, !hasDndPermission)
    }

    /**
     * Dismiss silent mode immediately (restore ringer)
     */
    private fun dismissSilentMode(context: Context) {
        Log.d(TAG, "✋ Dismissing silent mode")

        val sharedPrefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isSilentActive = sharedPrefs.getBoolean(KEY_IS_SILENT_ACTIVE, false)

        if (!isSilentActive) {
            Log.d(TAG, "⚠️ Silent mode is not active")
            return
        }

        // Vibrate before restoring ringer mode
        Log.d(TAG, "📳 Vibrating before restoring ringer mode...")
        vibrate(context)

        // Cancel the silent OFF alarm
        cancelSilentOffAlarm(context)

        // Restore ringer mode
        restoreRingerMode(context)

        // Mark silent mode as inactive
        sharedPrefs.edit().putBoolean(KEY_IS_SILENT_ACTIVE, false).apply()

        // Show toast
        val language = getLanguage(context)
        val isArabic = language == "ar"
        val message = if (isArabic) {
            "تم إلغاء الوضع الصامت"
        } else {
            "Silent mode dismissed"
        }
        android.widget.Toast.makeText(context, message, android.widget.Toast.LENGTH_SHORT).show()

        Log.d(TAG, "✅ Silent mode dismissed")
    }

    /**
     * Vibrate device
     */
    private fun vibrate(context: Context) {
        try {
            val vibrator = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as android.os.VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
            }

            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                // Vibrate pattern: 200ms on, 100ms off, 200ms on
                vibrator.vibrate(
                    android.os.VibrationEffect.createWaveform(longArrayOf(0, 200, 100, 200), -1)
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(longArrayOf(0, 200, 100, 200), -1)
            }
            Log.d(TAG, "✅ Vibration completed")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error vibrating: ${e.message}")
        }
    }

    /**
     * Keep Silent - permanently set to VIBRATE mode (no auto restore)
     * User must manually change ringer mode back
     */
    private fun extendSilentMode(context: Context, prayerName: String, prayerNameAr: String) {
        Log.d(TAG, "🔕 Keep Silent - setting permanent VIBRATE mode for $prayerName")

        val sharedPrefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

        // Cancel the silent OFF alarm (no automatic restore)
        cancelSilentOffAlarm(context)
        Log.d(TAG, "❌ Cancelled auto-restore alarm - will stay in VIBRATE until user changes it")

        // Set to VIBRATE mode permanently (not SILENT)
        try {
            audioManager.ringerMode = AudioManager.RINGER_MODE_VIBRATE
            Log.d(TAG, "📳 Set to VIBRATE mode (permanent)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error setting ringer mode: ${e.message}")
        }

        // Update silent end time to 0 (indicates permanent mode)
        sharedPrefs.edit().putLong(KEY_SILENT_END_TIME, 0).apply()

        // Show toast
        showKeepSilentToast(context)

        Log.d(TAG, "✅ Keep Silent activated - phone will vibrate until user changes ringer mode")
    }

    /**
     * Show a toast message when silent mode is enabled
     */
    private fun showSilentModeToast(
        context: Context,
        prayerName: String,
        prayerNameAr: String,
        noDndPermission: Boolean
    ) {
        val language = getLanguage(context)
        val isArabic = language == "ar"

        val message = if (noDndPermission) {
            if (isArabic) {
                "وضع الاهتزاز لصلاة $prayerNameAr"
            } else {
                "Vibrate mode for $prayerName"
            }
        } else {
            if (isArabic) {
                "وضع صامت لصلاة $prayerNameAr - 20 دقيقة"
            } else {
                "Silent mode for $prayerName - 20 minutes"
            }
        }

        android.widget.Toast.makeText(context, message, android.widget.Toast.LENGTH_LONG).show()
    }

    /**
     * Show toast when Keep Silent is activated (permanent vibrate mode)
     */
    private fun showKeepSilentToast(context: Context) {
        val language = getLanguage(context)
        val isArabic = language == "ar"

        val message = if (isArabic) {
            "وضع اهتزاز دائم - غيّر الوضع يدوياً من الإعدادات"
        } else {
            "Permanent vibrate mode - Change manually from settings"
        }

        android.widget.Toast.makeText(context, message, android.widget.Toast.LENGTH_LONG).show()
    }

    /**
     * Get language preference
     */
    private fun getLanguage(context: Context): String {
        val sharedPrefs = context.getSharedPreferences("aura_prefs", Context.MODE_PRIVATE)
        return sharedPrefs.getString("language", "en") ?: "en"
    }

    /**
     * Schedule silent OFF alarm
     */
    private fun scheduleSilentOff(context: Context, silentEndTime: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val silentOffIntent = Intent(context, SilentOffReceiver::class.java)
        val pendingIntentOff = PendingIntent.getBroadcast(
            context,
            SILENT_OFF_REQUEST_CODE,
            silentOffIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Set exact alarm
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                silentEndTime,
                pendingIntentOff
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                silentEndTime,
                pendingIntentOff
            )
        }

        val timeStr = DateFormat.format("HH:mm", Date(silentEndTime))
        Log.d(TAG, "⏰ Scheduled silent OFF at $timeStr")
    }

    /**
     * Cancel silent OFF alarm
     */
    private fun cancelSilentOffAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val silentOffIntent = Intent(context, SilentOffReceiver::class.java)
        val pendingIntentOff = PendingIntent.getBroadcast(
            context,
            SILENT_OFF_REQUEST_CODE,
            silentOffIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntentOff)

        Log.d(TAG, "❌ Cancelled previous silent OFF alarm")
    }
}

/**
 * Receiver that turns OFF silent mode automatically after timer
 * This fires after 20 minutes to:
 * 1. Cancel the adhan notification
 * 2. Restore ringer mode to previous state
 */
class SilentOffReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "SilentOffReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "🔔 Silent OFF received (auto restore after 20 min)")

        // Cancel all prayer notifications
        cancelAllPrayerNotifications(context)

        // Restore ringer mode to previous state
        restoreRingerMode(context)

        // Mark silent mode as inactive
        val sharedPrefs = context.getSharedPreferences("aura_silent_mode", Context.MODE_PRIVATE)
        sharedPrefs.edit().putBoolean("is_silent_active", false).apply()

        // Show toast to notify user
        val language = getLanguagePreference(context)
        val isArabic = language == "ar"
        val message = if (isArabic) {
            "انتهى الوضع الصامت - عودة للوضع الطبيعي"
        } else {
            "Silent mode ended - Sound restored"
        }
        android.widget.Toast.makeText(context, message, android.widget.Toast.LENGTH_SHORT).show()

        Log.d(TAG, "✅ Silent mode automatically restored, notifications cancelled")
    }

    /**
     * Cancel all prayer notifications
     */
    private fun cancelAllPrayerNotifications(context: Context) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Cancel each prayer notification
        for (prayer in listOf("Fajr", "Sunrise", "Zuhr", "Dhuhr", "Asr", "Maghrib", "Isha")) {
            val notificationId = PrayerAlarmReceiver.getNotificationId(prayer)
            notificationManager.cancel(notificationId)
        }

        Log.d(TAG, "✅ Cancelled all prayer notifications")
    }

    /**
     * Get language preference
     */
    private fun getLanguagePreference(context: Context): String {
        val sharedPrefs = context.getSharedPreferences("aura_prefs", Context.MODE_PRIVATE)
        return sharedPrefs.getString("language", "en") ?: "en"
    }
}

/**
 * Helper function to restore ringer mode
 */
private fun restoreRingerMode(context: Context) {
    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    val sharedPrefs = context.getSharedPreferences("aura_silent_mode", Context.MODE_PRIVATE)

    val savedRingerMode = sharedPrefs.getInt("saved_ringer_mode", AudioManager.RINGER_MODE_NORMAL)
    audioManager.ringerMode = savedRingerMode

    Log.d("SilentOffReceiver", "🔊 Restored ringer mode to: $savedRingerMode")
}
