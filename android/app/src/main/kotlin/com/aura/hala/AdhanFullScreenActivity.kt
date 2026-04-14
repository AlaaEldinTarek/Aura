package com.aura.hala

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Simple Full-Screen Activity for Adhan
 * Shows when prayer time arrives - works on lock screen and unlocked screen
 * Compatible with Android 10+ and all devices including Huawei
 *
 * Adhan stops when: user closes activity, presses volume buttons
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

        Log.d(TAG, "✅ [ADHAN] Full screen activity ready")
    }

    private fun setupFullScreen() {
        // For Android 12+ (API 31+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                setTurnScreenOn(true)
                setShowWhenLocked(true)
                Log.d(TAG, "✅ [ADHAN] Using Android 12+ APIs")
            } catch (e: Exception) {
                Log.w(TAG, "⚠️ [ADHAN] Android 12+ APIs failed: ${e.message}")
                setupWindowFlags()
            }
        }
        // For Android 10-11 (API 29-30)
        else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
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

    /**
     * Stop adhan and close activity
     */
    private fun stopAdhanAndFinish() {
        if (AdhanPlayer.isPlaying()) {
            AdhanPlayer.stop()
            Log.d(TAG, "⏹️ [ADHAN] Stopped adhan audio")
        }
        finish()
    }

    /**
     * Catch volume button presses — stop adhan immediately
     */
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            Log.d(TAG, "🔊 [ADHAN] Volume button pressed — stopping adhan")
            if (AdhanPlayer.isPlaying()) {
                AdhanPlayer.stop()
                // Update message
                val prefs = getSharedPreferences("${packageName}_preferences", MODE_PRIVATE)
                val isArabic = prefs.getString("language", "en") == "ar"
                findViewById<TextView>(R.id.prayerMessage).text =
                    if (isArabic) "تم إيقاف الأذان" else "Azan stopped"
            }
            // Don't consume — let system adjust volume normally
            return super.onKeyDown(keyCode, event)
        }
        return super.onKeyDown(keyCode, event)
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

        // Stop Vibrate button — sends same broadcast as notification (ToggleSilentModeReceiver DISMISS_SILENT)
        val silentPrefs = getSharedPreferences("aura_silent_mode", MODE_PRIVATE)
        val isSilentActive = silentPrefs.getBoolean("is_silent_active", false)
        val silentEnabled = prefs.getBoolean("silent_mode_enabled", true)
        findViewById<Button>(R.id.btnVibrateAlways).apply {
            if (silentEnabled && isSilentActive) {
                visibility = View.VISIBLE
                text = if (isArabic) "إيقاف الاهتزاز" else "Stop Vibrate"
                setOnClickListener {
                    val dismissIntent = Intent(this@AdhanFullScreenActivity, ToggleSilentModeReceiver::class.java).apply {
                        action = "com.aura.hala.DISMISS_SILENT"
                        putExtra(PrayerAlarmReceiver.EXTRA_PRAYER_NAME, prayerName)
                    }
                    sendBroadcast(dismissIntent)

                    // Update UI
                    isEnabled = false
                    alpha = 0.5f
                }
            } else {
                visibility = View.GONE
            }
        }

        // Close button — stops adhan + closes activity
        findViewById<Button>(R.id.btnClose).apply {
            text = if (isArabic) "إغلاق" else "Close"
            setOnClickListener {
                stopAdhanAndFinish()
            }
        }

        Log.d(TAG, "✅ [ADHAN] UI setup complete")
    }

    override fun onDestroy() {
        super.onDestroy()
        // Stop adhan when activity is destroyed (swipe away, back button, etc.)
        if (AdhanPlayer.isPlaying()) {
            AdhanPlayer.stop()
            Log.d(TAG, "⏹️ [ADHAN] Stopped adhan on destroy")
        }
        Log.d(TAG, "📱 [ADHAN] Activity destroyed")
    }

    override fun onBackPressed() {
        stopAdhanAndFinish()
    }
}
