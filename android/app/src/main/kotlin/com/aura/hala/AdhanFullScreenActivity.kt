package com.aura.hala

import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.animation.ValueAnimator
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Full-Screen Activity for Adhan
 * Shows when prayer time arrives - works on lock screen and unlocked screen
 * Compatible with Android 10+ and all devices including Huawei
 *
 * Features: gradient background, prayer-specific icon, pulse animation
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
    private var pulseAnimator: ObjectAnimator? = null

    private val tickHandler = Handler(Looper.getMainLooper())
    private var iqamaTimeMs = 0L
    private var isArabic = false
    private var iqamaPhaseStarted = false

    private val tickRunnable = object : Runnable {
        override fun run() {
            if (isFinishing || isDestroyed) return

            if (AdhanPlayer.isPlaying()) {
                // Adhan still playing — check again soon
                tickHandler.postDelayed(this, 500)
                return
            }

            // Adhan audio has stopped — switch to iqama countdown phase
            if (!iqamaPhaseStarted) {
                iqamaPhaseStarted = true
                stopPulseAnimation()
                findViewById<TextView>(R.id.prayerMessage).visibility = View.GONE
                val label = findViewById<TextView>(R.id.iqamaLabel)
                val countdown = findViewById<TextView>(R.id.iqamaCountdown)
                label.visibility = View.VISIBLE
                countdown.visibility = View.VISIBLE
                label.text = if (isArabic) "الإقامة بعد" else "Iqama in"
            }

            val now = System.currentTimeMillis()
            val countdown = findViewById<TextView>(R.id.iqamaCountdown)
            val label = findViewById<TextView>(R.id.iqamaLabel)

            if (iqamaTimeMs > 0 && now < iqamaTimeMs) {
                val remaining = iqamaTimeMs - now
                val minutes = (remaining / 60_000).toInt()
                val seconds = ((remaining % 60_000) / 1000).toInt()
                countdown.text = String.format("%d:%02d", minutes, seconds)
                tickHandler.postDelayed(this, 500)
            } else if (iqamaTimeMs > 0) {
                // Iqama time reached — show briefly then auto-close
                label.text = if (isArabic) "حان وقت الإقامة" else "Stand for prayer"
                countdown.text = if (isArabic) "🕌" else "🕌"
                tickHandler.postDelayed({ stopAdhanAndFinish() }, 3000)
            } else {
                // No iqama configured — just show a done state
                label.visibility = View.GONE
                countdown.text = if (isArabic) "حان وقت الصلاة" else "Time to pray"
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Get prayer info
        prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "Fajr"
        prayerNameAr = intent.getStringExtra(EXTRA_PRAYER_NAME_AR) ?: "الفجر"

        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "🕌 [ADHAN] Full screen for: $prayerName ($prayerNameAr)")
        Log.d(TAG, "📱 [ADHAN] Android SDK: ${Build.VERSION.SDK_INT}")

        // Setup full screen (over lock screen)
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
        stopPulseAnimation()
        if (AdhanPlayer.isPlaying()) {
            AdhanPlayer.stop()
            Log.d(TAG, "⏹️ [ADHAN] Stopped adhan audio")
        }
        finish()
    }

    /**
     * Start pulse animation on prayer icon
     */
    private fun startPulseAnimation() {
        val prayerIcon = findViewById<ImageView>(R.id.prayerIcon)
        pulseAnimator = ObjectAnimator.ofPropertyValuesHolder(
            prayerIcon,
            PropertyValuesHolder.ofFloat("scaleX", 1f, 1.08f, 1f),
            PropertyValuesHolder.ofFloat("scaleY", 1f, 1.08f, 1f)
        ).apply {
            duration = 2000
            repeatCount = ValueAnimator.INFINITE
            start()
        }
        Log.d(TAG, "🎵 [ADHAN] Started pulse animation")
    }

    /**
     * Stop pulse animation
     */
    private fun stopPulseAnimation() {
        pulseAnimator?.cancel()
        pulseAnimator = null
        try {
            val prayerIcon = findViewById<ImageView>(R.id.prayerIcon)
            prayerIcon.scaleX = 1f
            prayerIcon.scaleY = 1f
        } catch (e: Exception) {
            // View might be gone
        }
    }

    /**
     * Get prayer-specific icon resource
     */
    private fun getPrayerIconRes(): Int {
        return when (prayerName) {
            "Fajr" -> R.drawable.ic_prayer_fajr
            "Sunrise" -> R.drawable.ic_prayer_dhuhr
            "Dhuhr", "Zuhr" -> R.drawable.ic_prayer_dhuhr
            "Asr" -> R.drawable.ic_prayer_afternoon
            "Maghrib" -> R.drawable.ic_prayer_maghrib
            "Isha" -> R.drawable.ic_prayer_isha
            else -> R.mipmap.ic_launcher
        }
    }

    /**
     * Catch volume button presses — stop adhan immediately
     */
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            Log.d(TAG, "🔊 [ADHAN] Volume button pressed — stopping adhan")
            if (AdhanPlayer.isPlaying()) {
                AdhanPlayer.stop()
                // The tickRunnable will detect audio stopped and switch to iqama countdown
            }
            // Don't consume — let system adjust volume normally
            return super.onKeyDown(keyCode, event)
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun setupUI() {
        // Get language from aura_prayer_times (saved by Flutter MethodChannel)
        val prefs = getSharedPreferences("aura_prayer_times", MODE_PRIVATE)
        isArabic = prefs.getString("language", "en") == "ar"
        iqamaTimeMs = prefs.getLong("adhan_iqama_time", 0L)

        // Start polling for adhan end → iqama countdown
        tickHandler.post(tickRunnable)

        // Set prayer-specific icon
        findViewById<ImageView>(R.id.prayerIcon).setImageResource(getPrayerIconRes())

        // Start pulse animation while adhan is playing
        startPulseAnimation()

        // Set prayer name
        findViewById<TextView>(R.id.prayerTitle).text = if (isArabic) prayerNameAr else prayerName

        // Set time (12-hour format with Arabic locale when Arabic is enabled)
        val timeFormat = if (isArabic) {
            SimpleDateFormat("h:mm a", Locale("ar"))
        } else {
            SimpleDateFormat("h:mm a", Locale.getDefault())
        }
        val time = timeFormat.format(Date())
        findViewById<TextView>(R.id.prayerTime).text = time

        // Set message
        val msg = if (isArabic) "حان الآن موعد صلاة $prayerNameAr" else "It's time for $prayerName prayer"
        findViewById<TextView>(R.id.prayerMessage).text = msg

        // X dismiss button at top — always visible
        findViewById<Button>(R.id.btnDismiss).setOnClickListener {
            stopAdhanAndFinish()
        }

        // Vibration control buttons — show only when silent/vibrate mode is active
        val silentPrefs = getSharedPreferences("aura_silent_mode", MODE_PRIVATE)
        val isSilentActive = silentPrefs.getBoolean("is_silent_active", false)
        val silentEnabled = silentPrefs.getBoolean("silent_mode_enabled", true)
        val btnContainer = findViewById<android.widget.LinearLayout>(R.id.btnContainer)

        if (silentEnabled && isSilentActive) {
            btnContainer.visibility = View.VISIBLE

            // Stop Vibrate — turns off vibration then closes
            findViewById<Button>(R.id.btnVibrateAlways).apply {
                text = if (isArabic) "إيقاف الاهتزاز" else "Stop Vibrate"
                setOnClickListener {
                    val dismissIntent = Intent(this@AdhanFullScreenActivity, ToggleSilentModeReceiver::class.java).apply {
                        action = "com.aura.hala.DISMISS_SILENT"
                        putExtra(PrayerAlarmReceiver.EXTRA_PRAYER_NAME, prayerName)
                    }
                    sendBroadcast(dismissIntent)
                    isEnabled = false
                    alpha = 0.5f
                }
            }

            // Keep Vibrate — no-op, vibration continues, screen stays open
            findViewById<Button>(R.id.btnKeepVibrate).apply {
                text = if (isArabic) "إبقاء الاهتزاز" else "Keep Vibrate"
                setOnClickListener { }
            }
        } else {
            btnContainer.visibility = View.GONE
        }

        Log.d(TAG, "✅ [ADHAN] UI setup complete")
    }

    override fun onDestroy() {
        super.onDestroy()
        tickHandler.removeCallbacks(tickRunnable)
        stopPulseAnimation()
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
