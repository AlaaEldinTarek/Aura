package com.aura.hala

import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.animation.ValueAnimator
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.CountDownTimer
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ProgressBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import java.util.Locale
import java.util.concurrent.TimeUnit

/**
 * Focus Mode Activity - Full screen lock that silences the phone and shows a countdown timer.
 *
 * Universal compatibility:
 * - Android 5.0+ (API 21+)
 * - All OEM devices: Huawei, Honor, Xiaomi, Samsung, Oppo, Vivo, Realme, etc.
 *
 * Features:
 * - Full-screen over lock screen and other apps
 * - DND / silent mode with fallback for restricted devices
 * - Countdown timer with circular progress
 * - Emergency exit: volume up 3 times quickly
 * - Immersive sticky mode hides system bars
 * - WakeLock keeps screen on
 * - Mark task as done on completion
 */
class FocusModeActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "FocusMode"
        const val EXTRA_TASK_ID = "task_id"
        const val EXTRA_TASK_TITLE = "task_title"
        const val EXTRA_TASK_DESC = "task_desc"
        const val EXTRA_DURATION_MINUTES = "duration_minutes"
        const val EXTRA_LANGUAGE = "language"
        private const val VOLUME_EXIT_THRESHOLD = 3
        private const val VOLUME_EXIT_WINDOW_MS = 1500L
    }

    private lateinit var taskId: String
    private lateinit var taskTitle: String
    private var taskDesc: String = ""
    private var durationMinutes: Int = 25
    private var isArabic: Boolean = false
    private var savedRingerMode: Int = AudioManager.RINGER_MODE_NORMAL
    private var wasDndEnabled: Boolean = false
    private var countDownTimer: CountDownTimer? = null
    private var pulseAnimator: ObjectAnimator? = null

    // Emergency exit: volume up 3 times
    private val volumeUpTimes = mutableListOf<Long>()
    private var totalDurationMs: Long = 0

    private lateinit var wakeLock: PowerManager.WakeLock

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: ""
        taskTitle = intent.getStringExtra(EXTRA_TASK_TITLE) ?: "Focus Mode"
        taskDesc = intent.getStringExtra(EXTRA_TASK_DESC) ?: ""
        durationMinutes = intent.getIntExtra(EXTRA_DURATION_MINUTES, 25)
        isArabic = intent.getStringExtra(EXTRA_LANGUAGE) == "ar"

        totalDurationMs = durationMinutes.toLong() * 60 * 1000

        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "🎯 [FOCUS] Starting focus mode for: $taskTitle")
        Log.d(TAG, "📱 [FOCUS] Duration: $durationMinutes min, Arabic: $isArabic")
        Log.d(TAG, "📱 [FOCUS] Android SDK: ${Build.VERSION.SDK_INT}")

        // Acquire WakeLock
        acquireWakeLock()

        // Setup full screen
        setupFullScreen()

        // Enable silent/DND mode
        enableSilentMode()

        // Set layout
        setContentView(R.layout.activity_focus_mode)
        setupUI()

        // Start countdown
        startCountdown()

        // Immersive sticky mode
        setupImmersiveMode()

        Log.d(TAG, "✅ [FOCUS] Focus mode active")
    }

    // ─── Full Screen Setup ────────────────────────────────────────────────

    private fun setupFullScreen() {
        // Turn screen on and show over lock screen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            try {
                setTurnScreenOn(true)
                setShowWhenLocked(true)
                Log.d(TAG, "✅ [FOCUS] Using O_MR1+ APIs")
            } catch (e: Exception) {
                Log.w(TAG, "⚠️ [FOCUS] O_MR1+ APIs failed: ${e.message}")
                setupWindowFlags()
            }
        } else {
            setupWindowFlags()
        }

        // Keep screen on
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Max brightness
        val params = window.attributes
        params.screenBrightness = 1.0f
        window.attributes = params
    }

    @Suppress("DEPRECATION")
    private fun setupWindowFlags() {
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )
    }

    private fun setupImmersiveMode() {
        // Sticky immersive mode — hides status bar and navigation bar
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            or View.SYSTEM_UI_FLAG_FULLSCREEN
            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        )

        // Re-apply on any UI visibility change
        window.decorView.setOnSystemUiVisibilityChangeListener {
            if (it and View.SYSTEM_UI_FLAG_FULLSCREEN == 0) {
                window.decorView.systemUiVisibility = (
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    or View.SYSTEM_UI_FLAG_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                )
            }
        }
    }

    // ─── WakeLock ─────────────────────────────────────────────────────────

    @Suppress("DEPRECATION")
    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "aura:FocusModeWakeLock"
        )
        wakeLock.acquire((durationMinutes + 5).toLong() * 60 * 1000L)
        Log.d(TAG, "✅ [FOCUS] WakeLock acquired")
    }

    // ─── Silent Mode ──────────────────────────────────────────────────────

    private fun enableSilentMode() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        // Save current ringer mode
        savedRingerMode = audioManager.ringerMode

        // Try DND first (API 23+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (notificationManager.isNotificationPolicyAccessGranted) {
                wasDndEnabled = true
                try {
                    // Save current interruption filter
                    notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                    Log.d(TAG, "✅ [FOCUS] DND enabled via NotificationManager")
                } catch (e: Exception) {
                    Log.w(TAG, "⚠️ [FOCUS] DND failed, falling back to ringer mode: ${e.message}")
                    fallbackToRingerSilent(audioManager)
                }
            } else {
                Log.w(TAG, "⚠️ [FOCUS] DND policy access not granted, falling back to ringer mode")
                fallbackToRingerSilent(audioManager)
            }
        } else {
            // Pre-Marshmallow: use AudioManager
            fallbackToRingerSilent(audioManager)
        }
    }

    private fun fallbackToRingerSilent(audioManager: AudioManager) {
        try {
            audioManager.ringerMode = AudioManager.RINGER_MODE_VIBRATE
            Log.d(TAG, "✅ [FOCUS] Ringer mode set to vibrate")
        } catch (e: Exception) {
            try {
                audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
                Log.d(TAG, "✅ [FOCUS] Ringer mode set to silent")
            } catch (e2: Exception) {
                Log.e(TAG, "❌ [FOCUS] Could not change ringer mode: ${e2.message}")
            }
        }
    }

    private fun restoreSoundMode() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (wasDndEnabled && notificationManager.isNotificationPolicyAccessGranted) {
                try {
                    notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                    Log.d(TAG, "✅ [FOCUS] DND disabled")
                } catch (e: Exception) {
                    Log.w(TAG, "⚠️ [FOCUS] Could not disable DND: ${e.message}")
                }
            }
        }

        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        try {
            audioManager.ringerMode = savedRingerMode
            Log.d(TAG, "✅ [FOCUS] Ringer mode restored to $savedRingerMode")
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ [FOCUS] Could not restore ringer mode: ${e.message}")
        }
    }

    // ─── Countdown Timer ──────────────────────────────────────────────────

    private fun startCountdown() {
        countDownTimer = object : CountDownTimer(totalDurationMs, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                updateTimerDisplay(millisUntilFinished)
            }

            override fun onFinish() {
                onCountdownComplete()
            }
        }.start()
    }

    private fun updateTimerDisplay(millisRemaining: Long) {
        val minutes = TimeUnit.MILLISECONDS.toMinutes(millisRemaining)
        val seconds = TimeUnit.MILLISECONDS.toSeconds(millisRemaining) % 60

        val timeText = if (isArabic) {
            val arMin = toArabicNumerals(minutes.toString())
            val arSec = toArabicNumerals(String.format("%02d", seconds))
            "$arMin:$arSec"
        } else {
            String.format("%02d:%02d", minutes, seconds)
        }

        try {
            val timerTextView = findViewById<TextView>(R.id.focusTimerText)
            timerTextView?.text = timeText

            // Update progress bar
            val progressBar = findViewById<ProgressBar>(R.id.focusProgressBar)
            if (progressBar != null) {
                val progress = ((totalDurationMs - millisRemaining).toFloat() / totalDurationMs.toFloat() * 100).toInt()
                progressBar.progress = progress
            }

            // Update remaining label
            val remainingLabel = findViewById<TextView>(R.id.focusRemainingLabel)
            if (remainingLabel != null) {
                remainingLabel.text = if (isArabic) {
                    "${toArabicNumerals(minutes.toString())} ${if (minutes == 1L) "دقيقة" else "دقائق"} ${if (isArabic) "متبقي" else ""}"
                } else {
                    "$minutes min remaining"
                }
            }
        } catch (e: Exception) {
            // Views might not be ready
        }
    }

    private fun onCountdownComplete() {
        Log.d(TAG, "✅ [FOCUS] Countdown complete!")

        // Mark task as done via broadcast
        val completeIntent = Intent(this, FocusModeReceiver::class.java).apply {
            action = "com.aura.hala.FOCUS_TASK_COMPLETE"
            putExtra(EXTRA_TASK_ID, taskId)
        }
        sendBroadcast(completeIntent)

        // Show completion UI
        try {
            val timerTextView = findViewById<TextView>(R.id.focusTimerText)
            timerTextView?.text = if (isArabic) "!تم" else "Done!"

            val titleLabel = findViewById<TextView>(R.id.focusTaskTitle)
            titleLabel?.text = if (isArabic) "انتهت جلسة التركيز!" else "Focus Session Complete!"

            val subtitleLabel = findViewById<TextView>(R.id.focusTaskDesc)
            val minStr = if (isArabic) toArabicNumerals(durationMinutes.toString()) else durationMinutes.toString()
            subtitleLabel?.text = if (isArabic) {
                "أحسنت! بقيت مركزاً لمدة $minStr دقيقة."
            } else {
                "Great job! You stayed focused for $durationMinutes minutes."
            }

            val progressBar = findViewById<ProgressBar>(R.id.focusProgressBar)
            progressBar?.progress = 100

            // Change close button text
            val closeBtn = findViewById<Button>(R.id.focusCloseBtn)
            closeBtn?.text = if (isArabic) "إغلاق" else "Close"

            stopPulseAnimation()
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ [FOCUS] Error updating completion UI: ${e.message}")
        }

        // Auto-close after 5 seconds
        Handler(Looper.getMainLooper()).postDelayed({
            finishFocusMode()
        }, 5000)
    }

    // ─── UI Setup ─────────────────────────────────────────────────────────

    private fun setupUI() {
        // Task title
        val titleLabel = findViewById<TextView>(R.id.focusTaskTitle)
        titleLabel?.text = taskTitle

        // Task description
        val descLabel = findViewById<TextView>(R.id.focusTaskDesc)
        descLabel?.text = if (taskDesc.isNotEmpty()) taskDesc else {
            if (isArabic) "ابقَ مركزاً على مهمتك" else "Stay focused on your task"
        }

        // Focus mode label
        val modeLabel = findViewById<TextView>(R.id.focusModeLabel)
        modeLabel?.text = if (isArabic) "وضع التركيز نشط" else "Focus Mode Active"

        // Duration label
        val durationLabel = findViewById<TextView>(R.id.focusDurationLabel)
        val durStr = if (isArabic) toArabicNumerals(durationMinutes.toString()) else durationMinutes.toString()
        durationLabel?.text = if (isArabic) "$durStr دقيقة" else "$durationMinutes min"

        // Exit hint
        val exitHint = findViewById<TextView>(R.id.focusExitHint)
        exitHint?.text = if (isArabic) "اضغط على زر رفع الصوت 3 مرات للخروج" else "Press volume up 3x to exit"

        // Close / Mark Done button
        val closeBtn = findViewById<Button>(R.id.focusCloseBtn)
        closeBtn?.text = if (isArabic) "إتمام المهمة والخروج" else "Mark Done & Exit"
        closeBtn?.setOnClickListener {
            // Mark task as done
            val completeIntent = Intent(this, FocusModeReceiver::class.java).apply {
                action = "com.aura.hala.FOCUS_TASK_COMPLETE"
                putExtra(EXTRA_TASK_ID, taskId)
            }
            sendBroadcast(completeIntent)
            finishFocusMode()
        }

        // Start pulse animation on progress bar
        startPulseAnimation()
    }

    private fun startPulseAnimation() {
        try {
            val progressBar = findViewById<ProgressBar>(R.id.focusProgressBar)
            if (progressBar != null) {
                pulseAnimator = ObjectAnimator.ofPropertyValuesHolder(
                    progressBar,
                    PropertyValuesHolder.ofFloat("alpha", 1f, 0.7f, 1f)
                ).apply {
                    duration = 3000
                    repeatCount = ValueAnimator.INFINITE
                    start()
                }
            }
        } catch (e: Exception) {
            // Not critical
        }
    }

    private fun stopPulseAnimation() {
        pulseAnimator?.cancel()
        pulseAnimator = null
    }

    // ─── Volume Button Emergency Exit ────────────────────────────────────

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            val now = System.currentTimeMillis()
            volumeUpTimes.add(now)

            // Remove presses older than threshold
            volumeUpTimes.removeAll { it < now - VOLUME_EXIT_WINDOW_MS }

            if (volumeUpTimes.size >= VOLUME_EXIT_THRESHOLD) {
                Log.d(TAG, "🚪 [FOCUS] Emergency exit triggered (volume up 3x)")
                volumeUpTimes.clear()
                finishFocusMode()
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    // ─── Back Button Blocked ──────────────────────────────────────────────

    @Suppress("DEPRECATION")
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Blocked - do nothing
        Log.d(TAG, "🚫 [FOCUS] Back button pressed — blocked")
    }

    // ─── Finish ───────────────────────────────────────────────────────────

    private fun finishFocusMode() {
        countDownTimer?.cancel()
        countDownTimer = null
        restoreSoundMode()
        stopPulseAnimation()

        if (wakeLock.isHeld) {
            wakeLock.release()
            Log.d(TAG, "✅ [FOCUS] WakeLock released")
        }

        finish()
        Log.d(TAG, "✅ [FOCUS] Focus mode ended")
    }

    override fun onDestroy() {
        countDownTimer?.cancel()
        restoreSoundMode()
        stopPulseAnimation()
        if (wakeLock.isHeld) {
            try { wakeLock.release() } catch (_: Exception) {}
        }
        super.onDestroy()
        Log.d(TAG, "📱 [FOCUS] Activity destroyed")
    }

    // ─── Arabic Numerals ──────────────────────────────────────────────────

    private fun toArabicNumerals(input: String): String {
        val easternDigits = charArrayOf('٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩')
        return input.map { c ->
            if (c in '0'..'9') easternDigits[c - '0'] else c
        }.joinToString("")
    }
}
