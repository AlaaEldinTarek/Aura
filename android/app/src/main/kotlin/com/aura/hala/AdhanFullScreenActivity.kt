package com.aura.hala

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Simple Full-Screen Activity for Adhan
 * Shows when prayer time arrives - works on lock screen and unlocked screen
 * Compatible with Android 10+ and all devices including Huawei
 */
class AdhanFullScreenActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "AdhanFullScreen"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_PRAYER_NAME_AR = "prayer_name_ar"

        fun getIntent(context: Context, prayerName: String, prayerNameAr: String): Intent {
            return Intent(context, AdhanFullScreenActivity::class.java).apply {
                putExtra(EXTRA_PRAYER_NAME, prayerName)
                putExtra(EXTRA_PRAYER_NAME_AR, prayerNameAr)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS or
                        Intent.FLAG_ACTIVITY_NO_HISTORY
            }
        }
    }

    private lateinit var prayerName: String
    private lateinit var prayerNameAr: String
    private var adhanPlaying = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Get prayer info
        prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "Fajr"
        prayerNameAr = intent.getStringExtra(EXTRA_PRAYER_NAME_AR) ?: "الفجر"

        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "🕌 [ADHAN] Full screen for: $prayerName ($prayerNameAr)")
        Log.d(TAG, "📱 [ADHAN] Android SDK: ${Build.VERSION.SDK_INT}")

        // Setup full screen (over lock screen) - compatible with all devices
        setupFullScreen()

        // Set UI
        setContentView(R.layout.activity_adhan_fullscreen)
        setupUI()

        // Play adhan
        playAdhan()

        Log.d(TAG, "✅ [ADHAN] Full screen activity ready")
    }

    private fun setupFullScreen() {
        // For Android 12+ (API 31+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Use turnScreenOn and setShowWhenLocked for Android 12+
            try {
                setTurnScreenOn(true)
                setShowWhenLocked(true)
                Log.d(TAG, "✅ [ADHAN] Using Android 12+ APIs")
            } catch (e: Exception) {
                Log.w(TAG, "⚠️ [ADHAN] Android 12+ APIs failed: ${e.message}")
                // Fallback to window flags
                setupWindowFlags()
            }
        }
        // For Android 10-11 (API 29-30)
        else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Use window flags for Android 10-11
            setupWindowFlags()
            Log.d(TAG, "✅ [ADHAN] Using window flags for Android 10-11")
        }
        // For older versions
        else {
            setupWindowFlags()
            Log.d(TAG, "✅ [ADHAN] Using window flags for older Android")
        }

        // Keep screen on
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        Log.d(TAG, "✅ [ADHAN] Full screen mode set")
    }

    private fun setupWindowFlags() {
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )
    }

    private fun setupUI() {
        // Get language
        val prefs = getSharedPreferences("${packageName}_preferences", MODE_PRIVATE)
        val isArabic = prefs.getString("language", "en") == "ar"

        // Set prayer name
        findViewById<TextView>(R.id.prayerTitle).text = if (isArabic) prayerNameAr else prayerName

        // Set time
        val time = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
        findViewById<TextView>(R.id.prayerTime).text = time

        // Set message
        val msg = if (isArabic) "حان الآن موعد صلاة $prayerNameAr" else "It's time for $prayerName prayer"
        findViewById<TextView>(R.id.prayerMessage).text = msg

        // Stop button
        findViewById<Button>(R.id.btnStop).apply {
            text = if (isArabic) "إيقاف" else "Stop"
            setOnClickListener {
                stopAdhan()
            }
        }

        // Silent mode button
        val silentEnabled = prefs.getBoolean("silent_mode_enabled", true)
        findViewById<Button>(R.id.btnSilentMode).apply {
            if (silentEnabled) {
                visibility = View.VISIBLE
                text = if (isArabic) "وضع صامت (20 دقيقة)" else "Silent Mode (20 min)"
                setOnClickListener {
                    enableSilentMode()
                }
            } else {
                visibility = View.GONE
            }
        }

        // Close button
        findViewById<Button>(R.id.btnClose).apply {
            text = if (isArabic) "إغلاق" else "Close"
            setOnClickListener {
                finish()
            }
        }

        Log.d(TAG, "✅ [ADHAN] UI setup complete")
    }

    private fun playAdhan() {
        if (AdhanPlayer.isPlaying()) {
            AdhanPlayer.stop()
        }
        AdhanPlayer.play(this, prayerName)
        Log.d(TAG, "🎵 [ADHAN] Playing adhan for $prayerName")
    }

    private fun stopAdhan() {
        AdhanPlayer.stop()
        adhanPlaying = false

        // Update UI
        findViewById<Button>(R.id.btnStop).apply {
            isEnabled = false
            alpha = 0.5f
        }

        val prefs = getSharedPreferences("${packageName}_preferences", MODE_PRIVATE)
        val isArabic = prefs.getString("language", "en") == "ar"
        findViewById<TextView>(R.id.prayerMessage).text = if (isArabic) "تم إيقاف الأذان" else "Azan stopped"

        Log.d(TAG, "⏹️ [ADHAN] Stopped")
    }

    private fun enableSilentMode() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val prefs = getSharedPreferences("aura_silent_mode", MODE_PRIVATE)

        // Save current mode
        prefs.edit().putInt("saved_ringer_mode", audioManager.ringerMode).apply()

        // Check DND permission
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val hasDndPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                notificationManager.isNotificationPolicyAccessGranted
            } catch (e: Exception) {
                false
            }
        } else {
            true
        }

        // Set silent or vibrate mode
        try {
            if (hasDndPermission) {
                audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
                Log.d(TAG, "🔕 [ADHAN] Silent mode enabled")
            } else {
                audioManager.ringerMode = AudioManager.RINGER_MODE_VIBRATE
                Log.d(TAG, "📳 [ADHAN] Vibrate mode enabled (no DND permission)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ [ADHAN] Error setting silent mode: ${e.message}")
        }

        // Mark as active and save end time
        prefs.edit().putBoolean("is_silent_active", true).apply()
        val endTime = System.currentTimeMillis() + (20 * 60 * 1000)
        prefs.edit().putLong("silent_end_time", endTime).apply()

        // Schedule restore
        scheduleSilentRestore(endTime)

        // Show toast
        val prefs2 = getSharedPreferences("${packageName}_preferences", MODE_PRIVATE)
        val isArabic = prefs2.getString("language", "en") == "ar"
        val toastMsg = if (hasDndPermission) {
            if (isArabic) "وضع صامت لمدة 20 دقيقة" else "Silent mode for 20 minutes"
        } else {
            if (isArabic) "وضع اهتزاز لمدة 20 دقيقة" else "Vibrate mode for 20 minutes"
        }
        Toast.makeText(this, toastMsg, Toast.LENGTH_SHORT).show()

        Log.d(TAG, "✅ [ADHAN] Silent mode enabled, will restore in 20 min")
    }

    private fun scheduleSilentRestore(time: Long) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, SilentOffReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this, 3999, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Use setExactAndAllowWhileIdle for Android 6+ for better reliability
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, time, pendingIntent)
        }

        val timeStr = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(time))
        Log.d(TAG, "⏰ [ADHAN] Silent restore scheduled for $timeStr")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "📱 [ADHAN] Activity destroyed")
    }

    override fun onBackPressed() {
        // Allow closing with back button
        super.onBackPressed()
        Log.d(TAG, "📱 [ADHAN] Back pressed")
    }
}
