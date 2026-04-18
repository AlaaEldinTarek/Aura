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
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import java.util.concurrent.TimeUnit

/**
 * Focus Mode Activity - Full screen lock that cannot be dismissed until timer ends.
 *
 * Flow:
 * 1. Timer countdown with ring progress (inescapable)
 * 2. Timer ends -> restore sound immediately -> show "Did you complete?" (Yes/No)
 * 3. Yes -> mark task done -> close
 * 4. No -> show restart options (5/10/15/25/45/60 min + custom + skip)
 */
class FocusModeActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "FocusMode"
        const val EXTRA_TASK_ID = "task_id"
        const val EXTRA_TASK_TITLE = "task_title"
        const val EXTRA_TASK_DESC = "task_desc"
        const val EXTRA_DURATION_MINUTES = "duration_minutes"
        const val EXTRA_LANGUAGE = "language"
        const val EXTRA_STARTED_AT = "started_at"

        var isActivityVisible: Boolean = false
            private set
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
    private var startedAtMs: Long = 0

    private lateinit var wakeLock: PowerManager.WakeLock

    // UI sections
    private var timerSection: LinearLayout? = null
    private var completionSection: LinearLayout? = null
    private var restartSection: ScrollView? = null
    private var exitHint: TextView? = null
    private var closeBtn: Button? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: ""
        taskTitle = intent.getStringExtra(EXTRA_TASK_TITLE) ?: "Focus Mode"
        taskDesc = intent.getStringExtra(EXTRA_TASK_DESC) ?: ""
        durationMinutes = intent.getIntExtra(EXTRA_DURATION_MINUTES, 25)
        isArabic = intent.getStringExtra(EXTRA_LANGUAGE) == "ar"

        totalDurationMs = durationMinutes.toLong() * 60 * 1000
        // Use the original start time passed from service so timer continues on relaunch
        startedAtMs = intent.getLongExtra(EXTRA_STARTED_AT, 0L)
        if (startedAtMs == 0L) startedAtMs = System.currentTimeMillis()

        Log.d(TAG, "[FOCUS] Starting focus mode for: $taskTitle (${durationMinutes}min)")

        isActivityVisible = true

        wakeUpAndUnlockScreen()
        acquireWakeLock()
        setupFullScreen()
        enableSilentMode()

        setContentView(R.layout.activity_focus_mode)
        bindViews()
        setupUI()
        setupCompletionButtons()
        setupRestartButtons()

        // Block ALL touch input during countdown
        FocusModeService.blockTouch(this)

        startCountdown()
        setupImmersiveMode()

        Log.d(TAG, "[FOCUS] Focus mode active - cannot be dismissed until timer ends")
    }

    override fun onResume() {
        super.onResume()
        isActivityVisible = true
        if (!isTimerFinished) {
            try { startLockTask() } catch (_: Exception) {}
        }
    }

    override fun onPause() {
        super.onPause()
        if (!isTimerFinished) isActivityVisible = false
    }

    // --- View Binding ---

    private fun bindViews() {
        timerSection = findViewById(R.id.timerSection)
        completionSection = findViewById(R.id.completionSection)
        restartSection = findViewById(R.id.restartSection)
        exitHint = findViewById(R.id.focusExitHint)
        closeBtn = findViewById(R.id.focusCloseBtn)
    }

    // --- Wake Up & Unlock ---

    @Suppress("DEPRECATION")
    private fun wakeUpAndUnlockScreen() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager

        val screenLock = powerManager.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
            PowerManager.ACQUIRE_CAUSES_WAKEUP or
            PowerManager.ON_AFTER_RELEASE,
            "aura:FocusScreenWake"
        )
        screenLock.acquire(5000L)
        screenLock.release()

        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
            )
        }
    }

    // --- Full Screen ---

    private fun setupFullScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            try {
                setTurnScreenOn(true)
                setShowWhenLocked(true)
            } catch (_: Exception) {
                setupWindowFlags()
            }
        } else {
            setupWindowFlags()
        }

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

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
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            or View.SYSTEM_UI_FLAG_FULLSCREEN
            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        )

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

    // --- Block Escape ---

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (!isTimerFinished) {
            when (keyCode) {
                KeyEvent.KEYCODE_BACK,
                KeyEvent.KEYCODE_HOME,
                KeyEvent.KEYCODE_APP_SWITCH,
                KeyEvent.KEYCODE_RECENT_APPS -> return true
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

    @Suppress("DEPRECATION")
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (!isTimerFinished) return
        finishFocusMode()
    }

    override fun onUserLeaveHint() {
        if (!isTimerFinished) {
            // FocusModeService will detect and relaunch
        }
        super.onUserLeaveHint()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.putExtra(EXTRA_TASK_ID, taskId)
        intent.putExtra(EXTRA_TASK_TITLE, taskTitle)
        intent.putExtra(EXTRA_TASK_DESC, taskDesc)
        intent.putExtra(EXTRA_DURATION_MINUTES, durationMinutes)
        intent.putExtra(EXTRA_LANGUAGE, if (isArabic) "ar" else "en")
        intent.putExtra(EXTRA_STARTED_AT, startedAtMs)
    }

    // --- WakeLock ---

    @Suppress("DEPRECATION")
    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "aura:FocusModeWakeLock"
        )
        wakeLock.acquire((durationMinutes + 5).toLong() * 60 * 1000L)
    }

    // --- Silent Mode ---

    private fun enableSilentMode() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        savedRingerMode = audioManager.ringerMode

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (notificationManager.isNotificationPolicyAccessGranted) {
                wasDndEnabled = true
                try {
                    notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                } catch (_: Exception) {
                    fallbackToRingerSilent(audioManager)
                }
            } else {
                fallbackToRingerSilent(audioManager)
            }
        } else {
            fallbackToRingerSilent(audioManager)
        }
    }

    private fun fallbackToRingerSilent(audioManager: AudioManager) {
        try { audioManager.ringerMode = AudioManager.RINGER_MODE_VIBRATE } catch (_: Exception) {
            try { audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT } catch (_: Exception) {}
        }
    }

    private fun restoreSoundMode() {
        Log.d(TAG, "[FOCUS] Restoring sound mode IMMEDIATELY")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (notificationManager.isNotificationPolicyAccessGranted) {
                try { notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL) } catch (_: Exception) {}
            }
        }
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        try { audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL } catch (_: Exception) {}
    }

    // --- Countdown Timer ---

    private fun startCountdown() {
        val elapsedMs = System.currentTimeMillis() - startedAtMs
        val remainingMs = if (elapsedMs > 0 && elapsedMs < totalDurationMs) {
            totalDurationMs - elapsedMs
        } else {
            totalDurationMs
        }

        Log.d(TAG, "[FOCUS] Starting countdown: ${remainingMs / 1000}s remaining")

        countDownTimer = object : CountDownTimer(remainingMs, 1000) {
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
            "${toArabicNumerals(minutes.toString())}:${toArabicNumerals(String.format("%02d", seconds))}"
        } else {
            String.format("%02d:%02d", minutes, seconds)
        }

        try {
            findViewById<TextView>(R.id.focusTimerText)?.text = timeText

            val progressBar = findViewById<ProgressBar>(R.id.focusProgressBar)
            progressBar?.let {
                val progress = ((totalDurationMs - millisRemaining).toFloat() / totalDurationMs * 100).toInt()
                it.progress = progress
            }

            val remainingLabel = findViewById<TextView>(R.id.focusRemainingLabel)
            remainingLabel?.text = if (isArabic) {
                "${toArabicNumerals(minutes.toString())} ${if (minutes == 1L) "دقيقة" else "دقائق"} متبقي"
            } else {
                "$minutes min remaining"
            }
        } catch (_: Exception) {}
    }

    private fun onCountdownComplete() {
        isTimerFinished = true
        isActivityVisible = true

        Log.d(TAG, "[FOCUS] Countdown complete!")


        try { stopLockTask() } catch (_: Exception) {}
        // Allow touch input so user can interact with buttons
        FocusModeService.allowTouch(this)

        // 3. Restore sound IMMEDIATELY
        restoreSoundMode()

        // 2. Stop the monitoring service (no more relaunch)
        FocusModeService.stop(this)

        // 3. Update timer display to show completion
        try {
            findViewById<TextView>(R.id.focusTimerText)?.text = if (isArabic) "تم!" else "Done!"
            findViewById<ProgressBar>(R.id.focusProgressBar)?.progress = 100
        } catch (_: Exception) {}

        // 4. Show completion prompt after brief delay
        Handler(Looper.getMainLooper()).postDelayed({
            showCompletionPrompt()
        }, 800)

        stopPulseAnimation()
    }

    // --- Completion Prompt ---

    private fun showCompletionPrompt() {
        // Hide timer section, exit hint, close button
        timerSection?.visibility = View.GONE
        exitHint?.visibility = View.GONE
        closeBtn?.visibility = View.GONE

        // Update completion texts
        val completionTitle = findViewById<TextView>(R.id.completionTitle)
        completionTitle?.text = if (isArabic) "انتهت جلسة التركيز!" else "Focus Session Complete!"

        val completionSubtitle = findViewById<TextView>(R.id.completionSubtitle)
        val minStr = if (isArabic) toArabicNumerals(durationMinutes.toString()) else durationMinutes.toString()
        completionSubtitle?.text = if (isArabic) {
            "أحسنت! بقيت مركزاً لمدة $minStr دقيقة."
        } else {
            "Great job! You stayed focused for $durationMinutes minutes."
        }

        val completionQuestion = findViewById<TextView>(R.id.completionQuestion)
        completionQuestion?.text = if (isArabic) "هل أكملت مهمتك؟" else "Did you complete your task?"

        val btnYes = findViewById<Button>(R.id.btnYes)
        btnYes?.text = if (isArabic) "نعم" else "Yes"

        val btnNo = findViewById<Button>(R.id.btnNo)
        btnNo?.text = if (isArabic) "لا" else "No"

        // Show completion section
        completionSection?.visibility = View.VISIBLE
    }

    // --- Completion Button Handlers ---

    private fun setupCompletionButtons() {
        // Yes button - mark task as done
        findViewById<Button>(R.id.btnYes)?.setOnClickListener {
            Log.d(TAG, "[FOCUS] User marked task as DONE")
            markTaskDone()
            finishFocusMode()
        }

        // No button - show restart options
        findViewById<Button>(R.id.btnNo)?.setOnClickListener {
            Log.d(TAG, "[FOCUS] User said NOT done - showing restart options")
            showRestartOptions()
        }
    }

    private fun markTaskDone() {
        val prefs = getSharedPreferences("${packageName}_preferences", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("focus_completed_task_id", taskId)
            .putBoolean("focus_task_was_completed", true)
            .apply()
        Log.d(TAG, "[FOCUS] Task $taskId marked done in SharedPreferences")
    }

    // --- Restart Options ---

    private fun showRestartOptions() {
        completionSection?.visibility = View.GONE

        // Update restart button labels for Arabic
        if (isArabic) {
            findViewById<Button>(R.id.btnRestart5)?.text = "${toArabicNumerals("5")} دقيقة"
            findViewById<Button>(R.id.btnRestart10)?.text = "${toArabicNumerals("10")} دقيقة"
            findViewById<Button>(R.id.btnRestart15)?.text = "${toArabicNumerals("15")} دقيقة"
            findViewById<Button>(R.id.btnRestart25)?.text = "${toArabicNumerals("25")} دقيقة"
            findViewById<Button>(R.id.btnRestart45)?.text = "${toArabicNumerals("45")} دقيقة"
            findViewById<Button>(R.id.btnRestart60)?.text = "${toArabicNumerals("60")} دقيقة"
            findViewById<Button>(R.id.btnRestartCustom)?.text = "ابدأ"
            findViewById<Button>(R.id.btnSkipClose)?.text = "تخطي وإغلاق"
            findViewById<EditText>(R.id.customDurationInput)?.hint = "مخصص (دقائق)"
        }

        restartSection?.visibility = View.VISIBLE
    }

    private fun setupRestartButtons() {
        val presetButtons = mapOf(
            R.id.btnRestart5 to 5,
            R.id.btnRestart10 to 10,
            R.id.btnRestart15 to 15,
            R.id.btnRestart25 to 25,
            R.id.btnRestart45 to 45,
            R.id.btnRestart60 to 60,
        )

        for ((id, minutes) in presetButtons) {
            findViewById<Button>(id)?.setOnClickListener {
                restartFocusMode(minutes)
            }
        }

        // Custom duration
        findViewById<Button>(R.id.btnRestartCustom)?.setOnClickListener {
            val input = findViewById<EditText>(R.id.customDurationInput)
            val text = input?.text?.toString()?.trim() ?: ""
            val minutes = text.toIntOrNull()
            if (minutes != null && minutes in 1..240) {
                restartFocusMode(minutes)
            }
        }

        // Skip & Close
        findViewById<Button>(R.id.btnSkipClose)?.setOnClickListener {
            Log.d(TAG, "[FOCUS] User skipped restart - closing")
            finishFocusMode()
        }
    }

    private fun restartFocusMode(minutes: Int) {
        Log.d(TAG, "[FOCUS] Restarting focus mode for $minutes min")

        // Reset state with new start time
        isTimerFinished = false
        durationMinutes = minutes
        totalDurationMs = minutes.toLong() * 60 * 1000
        startedAtMs = System.currentTimeMillis() // Fresh start for restart

        // Hide restart/completion, show timer
        restartSection?.visibility = View.GONE
        completionSection?.visibility = View.GONE
        timerSection?.visibility = View.VISIBLE
        exitHint?.visibility = View.VISIBLE
        closeBtn?.visibility = View.VISIBLE

        // Re-enable silent mode
        enableSilentMode()

        // Re-block all touch input during new countdown
        FocusModeService.blockTouch(this)

        // Re-pin screen for new countdown
        try { startLockTask() } catch (_: Exception) {}
        // Restart the foreground service for monitoring with new start time
        val serviceIntent = Intent(this, FocusModeService::class.java).apply {
            action = FocusModeService.ACTION_RESTART_FOCUS
            putExtra(FocusModeService.EXTRA_DURATION_MINUTES, minutes)
            putExtra(FocusModeService.EXTRA_STARTED_AT, startedAtMs)
        }
        startService(serviceIntent)

        // Reset UI
        setupUI()
        startCountdown()
        startPulseAnimation()
    }

    // --- UI Setup ---

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

        exitHint?.text = if (isArabic) "لن يمكنك الخروج حتى ينتهي المؤقت" else "You cannot exit until timer ends"

        closeBtn?.apply {
            text = if (isArabic) "مقفل حتى انتهاء الوقت" else "Locked until timer ends"
            isEnabled = false
            alpha = 0.4f
            setOnClickListener {
                if (isTimerFinished) finishFocusMode()
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

    // --- Finish ---

    private fun finishFocusMode() {
        isActivityVisible = false
        try { stopLockTask() } catch (_: Exception) {}
        countDownTimer?.cancel()
        countDownTimer = null
        stopPulseAnimation()

        // Stop the foreground service
        FocusModeService.stop(this)

        if (::wakeLock.isInitialized && wakeLock.isHeld) {
            try { wakeLock.release() } catch (_: Exception) {}
        }

        finish()
        Log.d(TAG, "[FOCUS] Focus mode ended")
    }

    override fun onDestroy() {
        countDownTimer?.cancel()
        stopPulseAnimation()
        if (::wakeLock.isInitialized && wakeLock.isHeld) {
            try { wakeLock.release() } catch (_: Exception) {}
        }

        if (!isTimerFinished) {
            isActivityVisible = false
            Log.w(TAG, "[FOCUS] Destroyed before timer - service will handle relaunch")
        } else {
            isActivityVisible = false
        }

        super.onDestroy()
    }

    // --- Arabic Numerals ---

    private fun toArabicNumerals(input: String): String {
        val easternDigits = charArrayOf('\u0660', '\u0661', '\u0662', '\u0663', '\u0664', '\u0665', '\u0666', '\u0667', '\u0668', '\u0669')
        return input.map { c ->
            if (c in '0'..'9') easternDigits[c - '0'] else c
        }.joinToString("")
    }
}
