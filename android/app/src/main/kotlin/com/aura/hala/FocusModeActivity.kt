package com.aura.hala

import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.animation.ValueAnimator
import android.app.KeyguardManager
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
import java.util.concurrent.TimeUnit

/**
 * Focus Mode Activity - Full screen lock that cannot be dismissed until timer ends.
 *
 * Universal compatibility:
 * - Android 5.0+ (API 21+)
 * - All OEM devices: Huawei, Honor, Xiaomi, Samsung, Oppo, Vivo, Realme, etc.
 *
 * Features:
 * - Cannot be dismissed until timer finishes (no back, no home, no recents)
 * - Auto-wakes and unlocks phone when triggered
 * - Full-screen over lock screen and other apps
 * - DND / silent mode with fallback for restricted devices
 * - Countdown timer with circular progress
 * - Immersive sticky mode hides system bars
 * - WakeLock keeps screen on
 * - Mark task as done when timer completes
 */
class FocusModeActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "FocusMode"
        const val EXTRA_TASK_ID = "task_id"
        const val EXTRA_TASK_TITLE = "task_title"
        const val EXTRA_TASK_DESC = "task_desc"
        const val EXTRA_DURATION_MINUTES = "duration_minutes"
        const val EXTRA_LANGUAGE = "language"
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
    private var totalDurationMs: Long = 0
    private var isTimerFinished = false

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

        // Wake and unlock screen first
        wakeUpAndUnlockScreen()

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

        // Prevent activity from being killed
        moveTaskToBack(false)

        Log.d(TAG, "✅ [FOCUS] Focus mode active — CANNOT be dismissed until timer ends")
    }

    // ─── Wake Up & Unlock Screen ──────────────────────────────────────────

    @Suppress("DEPRECATION")
    private fun wakeUpAndUnlockScreen() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager

        // Wake up the screen
        @Suppress("DEPRECATION")
        val screenLock = powerManager.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
            PowerManager.ACQUIRE_CAUSES_WAKEUP or
            PowerManager.ON_AFTER_RELEASE,
            "aura:FocusScreenWake"
        )
        screenLock.acquire(5000L)
        screenLock.release()

        // Dismiss keyguard (unlock screen)
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // On O+ use requestDismissKeyguard
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            // On older versions, use window flags
            window.addFlags(
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
            )
        }

        Log.d(TAG, "✅ [FOCUS] Screen woken and keyguard dismissed")
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

    // ─── Block All Escape Attempts ────────────────────────────────────────

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        // Block all buttons while timer is running
        if (!isTimerFinished) {
            when (keyCode) {
                KeyEvent.KEYCODE_BACK,
                KeyEvent.KEYCODE_HOME,
                KeyEvent.KEYCODE_APP_SWITCH,
                KeyEvent.KEYCODE_RECENT_APPS -> {
                    Log.d(TAG, "🚫 [FOCUS] Blocked key: $keyCode")
                    return true
                }
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (!isTimerFinished) {
            when (keyCode) {
                KeyEvent.KEYCODE_BACK,
                KeyEvent.KEYCODE_HOME,
                KeyEvent.KEYCODE_APP_SWITCH,
                KeyEvent.KEYCODE_RECENT_APPS -> return true
            }
        }
        return super.onKeyUp(keyCode, event)
    }

    // Block back button
    @Suppress("DEPRECATION")
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (!isTimerFinished) {
            Log.d(TAG, "🚫 [FOCUS] Back button pressed — blocked")
            return
        }
        finishFocusMode()
    }

    // Re-launch if activity is somehow sent to background
    override fun onUserLeaveHint() {
        if (!isTimerFinished) {
            Log.d(TAG, "🚫 [FOCUS] User tried to leave — relaunching")
            Handler(Looper.getMainLooper()).postDelayed({
                if (!isTimerFinished) {
                    val relaunchIntent = Intent(this, FocusModeActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP
                        putExtra(EXTRA_TASK_ID, taskId)
                        putExtra(EXTRA_TASK_TITLE, taskTitle)
                        putExtra(EXTRA_TASK_DESC, taskDesc)
                        putExtra(EXTRA_DURATION_MINUTES, durationMinutes)
                        putExtra(EXTRA_LANGUAGE, if (isArabic) "ar" else "en")
                    }
                    startActivity(relaunchIntent)
                }
            }, 500)
        }
        super.onUserLeaveHint()
    }

    // Prevent being moved to back
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.putExtra(EXTRA_TASK_ID, taskId)
        intent.putExtra(EXTRA_TASK_TITLE, taskTitle)
        intent.putExtra(EXTRA_TASK_DESC, taskDesc)
        intent.putExtra(EXTRA_DURATION_MINUTES, durationMinutes)
        intent.putExtra(EXTRA_LANGUAGE, if (isArabic) "ar" else "en")
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
        savedRingerMode = audioManager.ringerMode

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (notificationManager.isNotificationPolicyAccessGranted) {
                wasDndEnabled = true
                try {
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

            val progressBar = findViewById<ProgressBar>(R.id.focusProgressBar)
            if (progressBar != null) {
                val progress = ((totalDurationMs - millisRemaining).toFloat() / totalDurationMs.toFloat() * 100).toInt()
                progressBar.progress = progress
            }

            val remainingLabel = findViewById<TextView>(R.id.focusRemainingLabel)
            if (remainingLabel != null) {
                remainingLabel.text = if (isArabic) {
                    "${toArabicNumerals(minutes.toString())} ${if (minutes == 1L) "دقيقة" else "دقائق"} متبقي"
                } else {
                    "$minutes min remaining"
                }
            }
        } catch (_: Exception) {}
    }

    private fun onCountdownComplete() {
        isTimerFinished = true
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
            timerTextView?.text = if (isArabic) "تم!" else "Done!"

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

            // Enable close button now
            val closeBtn = findViewById<Button>(R.id.focusCloseBtn)
            closeBtn?.apply {
                text = if (isArabic) "إغلاق" else "Close"
                isEnabled = true
                alpha = 1.0f
                setBackgroundColor(0xFF4CAF50.toInt()) // Green
            }

            stopPulseAnimation()
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ [FOCUS] Error updating completion UI: ${e.message}")
        }

        // Auto-close after 10 seconds
        Handler(Looper.getMainLooper()).postDelayed({
            finishFocusMode()
        }, 10000)
    }

    // ─── UI Setup ─────────────────────────────────────────────────────────

    private fun setupUI() {
        val titleLabel = findViewById<TextView>(R.id.focusTaskTitle)
        titleLabel?.text = taskTitle

        val descLabel = findViewById<TextView>(R.id.focusTaskDesc)
        descLabel?.text = if (taskDesc.isNotEmpty()) taskDesc else {
            if (isArabic) "ابقَ مركزاً على مهمتك" else "Stay focused on your task"
        }

        val modeLabel = findViewById<TextView>(R.id.focusModeLabel)
        modeLabel?.text = if (isArabic) "وضع التركيز نشط" else "Focus Mode Active"

        val durationLabel = findViewById<TextView>(R.id.focusDurationLabel)
        val durStr = if (isArabic) toArabicNumerals(durationMinutes.toString()) else durationMinutes.toString()
        durationLabel?.text = if (isArabic) "$durStr دقيقة" else "$durationMinutes min"

        // Lock icon hint — cannot exit
        val exitHint = findViewById<TextView>(R.id.focusExitHint)
        exitHint?.text = if (isArabic) "🔒 لن يمكنك الخروج حتى ينتهي المؤقت" else "🔒 You cannot exit until timer ends"

        // Close button — DISABLED until timer finishes
        val closeBtn = findViewById<Button>(R.id.focusCloseBtn)
        closeBtn?.apply {
            text = if (isArabic) "🔒 مقفل حتى انتهاء الوقت" else "🔒 Locked until timer ends"
            isEnabled = false
            alpha = 0.4f
            setOnClickListener {
                if (isTimerFinished) {
                    finishFocusMode()
                }
            }
        }

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
        } catch (_: Exception) {}
    }

    private fun stopPulseAnimation() {
        pulseAnimator?.cancel()
        pulseAnimator = null
    }

    // ─── Finish ───────────────────────────────────────────────────────────

    private fun finishFocusMode() {
        countDownTimer?.cancel()
        countDownTimer = null
        restoreSoundMode()
        stopPulseAnimation()

        if (wakeLock.isHeld) {
            try { wakeLock.release() } catch (_: Exception) {}
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
        // If destroyed before timer finished, relaunch
        if (!isTimerFinished) {
            Log.w(TAG, "⚠️ [FOCUS] Destroyed before timer — attempting relaunch")
            val relaunchIntent = Intent(this, FocusModeActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                putExtra(EXTRA_TASK_ID, taskId)
                putExtra(EXTRA_TASK_TITLE, taskTitle)
                putExtra(EXTRA_TASK_DESC, taskDesc)
                putExtra(EXTRA_DURATION_MINUTES, durationMinutes)
                putExtra(EXTRA_LANGUAGE, if (isArabic) "ar" else "en")
            }
            startActivity(relaunchIntent)
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
