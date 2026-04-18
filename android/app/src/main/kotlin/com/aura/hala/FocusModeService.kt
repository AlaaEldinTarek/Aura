package com.aura.hala

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.inputmethodservice.Keyboard
import android.inputmethodservice.KeyboardView
import android.os.Build
import android.os.CountDownTimer
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.text.InputType
import android.util.Log
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.app.NotificationCompat
import java.util.Locale
import java.util.concurrent.TimeUnit

/**
 * Foreground service that shows a SYSTEM OVERLAY for Focus Mode.
 * Overlay covers everything including notification shade and control panel.
 * After timer ends, asks user if task was completed.
 */
class FocusModeService : Service() {

    companion object {
        private const val TAG = "FocusModeService"
        const val CHANNEL_ID = "focus_mode_service"
        const val NOTIFICATION_ID = 5998

        const val ACTION_START = "com.aura.hala.FOCUS_SERVICE_START"
        const val ACTION_STOP = "com.aura.hala.FOCUS_SERVICE_STOP"

        const val EXTRA_TASK_ID = "task_id"
        const val EXTRA_TASK_TITLE = "task_title"
        const val EXTRA_TASK_DESC = "task_desc"
        const val EXTRA_DURATION_MINUTES = "duration_minutes"
        const val EXTRA_LANGUAGE = "language"

        const val ACTION_TASK_DONE = "com.aura.hala.FOCUS_TASK_DONE"
        const val ACTION_TASK_NOT_DONE = "com.aura.hala.FOCUS_TASK_NOT_DONE"
        const val ACTION_RESTART_FOCUS = "com.aura.hala.FOCUS_RESTART"

        var isRunning: Boolean = false
            private set

        fun start(
            context: Context,
            taskId: String,
            taskTitle: String,
            taskDesc: String,
            durationMinutes: Int,
            language: String
        ) {
            val intent = Intent(context, FocusModeService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TASK_ID, taskId)
                putExtra(EXTRA_TASK_TITLE, taskTitle)
                putExtra(EXTRA_TASK_DESC, taskDesc)
                putExtra(EXTRA_DURATION_MINUTES, durationMinutes)
                putExtra(EXTRA_LANGUAGE, language)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, FocusModeService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private var taskId: String = ""
    private var taskTitle: String = "Focus Mode"
    private var taskDesc: String = ""
    private var durationMinutes: Int = 25
    private var language: String = "en"
    private var isArabic: Boolean = false
    private var isTimerFinished: Boolean = false
    private var savedRingerMode: Int = android.media.AudioManager.RINGER_MODE_NORMAL
    private var wasDndEnabled: Boolean = false

    private lateinit var wakeLock: PowerManager.WakeLock
    private var countDownTimer: CountDownTimer? = null
    private var totalDurationMs: Long = 0
    private var overlayView: View? = null
    private var statusBarOverlay: View? = null
    private var windowManager: WindowManager? = null

    // UI elements
    private var timerText: TextView? = null
    private var titleText: TextView? = null
    private var descText: TextView? = null
    private var modeLabel: TextView? = null
    private var progressFill: View? = null
    private var closeBtn: Button? = null
    private var remainingText: TextView? = null
    private var exitHint: TextView? = null
    private var durationLabel: TextView? = null
    private var mainLayout: LinearLayout? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_STICKY

        when (intent.action) {
            ACTION_START -> {
                taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: ""
                taskTitle = intent.getStringExtra(EXTRA_TASK_TITLE) ?: "Focus Mode"
                taskDesc = intent.getStringExtra(EXTRA_TASK_DESC) ?: ""
                durationMinutes = intent.getIntExtra(EXTRA_DURATION_MINUTES, 25)
                language = intent.getStringExtra(EXTRA_LANGUAGE) ?: "en"
                isArabic = language == "ar"
                isTimerFinished = false
                totalDurationMs = durationMinutes.toLong() * 60 * 1000

                startForeground()
                acquireWakeLock()
                enableSilentMode()
                showOverlay()
                startCountdown()
                isRunning = true

                Log.d(TAG, "✅ [FOCUS] Service started for: $taskTitle (${durationMinutes}min)")
            }

            ACTION_STOP -> {
                stopFocusMode()
                return START_NOT_STICKY
            }

            ACTION_TASK_DONE -> {
                Log.d(TAG, "✅ [FOCUS] User marked task as DONE")

                // Save to SharedPreferences that Flutter can read
                val prefs = getSharedPreferences("${packageName}_preferences", Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("focus_completed_task_id", taskId)
                    .putBoolean("focus_task_was_completed", true)
                    .apply()

                stopFocusMode()
                return START_NOT_STICKY
            }

            ACTION_TASK_NOT_DONE -> {
                Log.d(TAG, "⚠️ [FOCUS] User said task NOT done — showing restart options")
                showRestartOptions()
                return START_STICKY
            }

            ACTION_RESTART_FOCUS -> {
                val minutes = intent.getIntExtra(EXTRA_DURATION_MINUTES, 25)
                Log.d(TAG, "🔄 [FOCUS] Restarting focus mode for $minutes min")
                durationMinutes = minutes
                totalDurationMs = minutes.toLong() * 60 * 1000
                isTimerFinished = false
                removeOverlay()
                showOverlay()
                startCountdown()
                enableSilentMode()
                return START_STICKY
            }
        }

        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (!isTimerFinished && isRunning) {
            val restartIntent = Intent(this, FocusModeService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TASK_ID, taskId)
                putExtra(EXTRA_TASK_TITLE, taskTitle)
                putExtra(EXTRA_TASK_DESC, taskDesc)
                putExtra(EXTRA_DURATION_MINUTES, durationMinutes)
                putExtra(EXTRA_LANGUAGE, language)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(restartIntent)
                else startService(restartIntent)
            } catch (_: Exception) {}
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        removeOverlay()
        cancelCountdown()
        restoreSoundMode()
        releaseWakeLock()
        isRunning = false

        if (!isTimerFinished) {
            val restartIntent = Intent(this, FocusModeService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TASK_ID, taskId)
                putExtra(EXTRA_TASK_TITLE, taskTitle)
                putExtra(EXTRA_TASK_DESC, taskDesc)
                putExtra(EXTRA_DURATION_MINUTES, durationMinutes)
                putExtra(EXTRA_LANGUAGE, language)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(restartIntent)
                else startService(restartIntent)
            } catch (_: Exception) {}
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ─── System Overlay ───────────────────────────────────────────────────

    @SuppressLint("ClickableViewAccessibility")
    private fun showOverlay() {
        removeOverlay()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        overlayView = createOverlayView()

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_SYSTEM_ALERT,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
            screenBrightness = 1.0f
        }

        try {
            windowManager?.addView(overlayView, params)
            Log.d(TAG, "✅ [FOCUS] System overlay shown")
        } catch (e: Exception) {
            Log.e(TAG, "❌ [FOCUS] Overlay failed: ${e.message}")
        }

        // Status bar blocker overlay — sits on top and blocks notification shade
        showStatusBarBlocker()

        // Re-add if removed
        val handler = Handler(Looper.getMainLooper())
        val checkRunnable = object : Runnable {
            override fun run() {
                if (!isTimerFinished && isRunning) {
                    if (overlayView?.isAttachedToWindow != true) {
                        try {
                            windowManager?.addView(overlayView, params)
                        } catch (_: Exception) {}
                    }
                    if (statusBarOverlay?.isAttachedToWindow != true) {
                        showStatusBarBlocker()
                    }
                    handler.postDelayed(this, 300)
                }
            }
        }
        handler.postDelayed(checkRunnable, 300)
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun showStatusBarBlocker() {
        if (statusBarOverlay != null) {
            try { windowManager?.removeView(statusBarOverlay) } catch (_: Exception) {}
        }

        // Small overlay at the very top that intercepts status bar pull-down
        statusBarOverlay = View(this).apply {
            setBackgroundColor(Color.TRANSPARENT)
            setOnTouchListener { _, _ -> true }
        }

        val statusBarHeight = getStatusBarHeight()
        val statusParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            statusBarHeight + 20, // Extra to fully block
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_SYSTEM_ALERT,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = -10 // Slightly above screen edge
        }

        try {
            windowManager?.addView(statusBarOverlay, statusParams)
        } catch (_: Exception) {}
    }

    private fun getStatusBarHeight(): Int {
        var result = 72 // default
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        if (resourceId > 0) {
            result = resources.getDimensionPixelSize(resourceId)
        }
        return result
    }

    private fun removeOverlay() {
        try {
            overlayView?.let { windowManager?.removeView(it) }
        } catch (_: Exception) {}
        try {
            statusBarOverlay?.let { windowManager?.removeView(it) }
        } catch (_: Exception) {}
        overlayView = null
        statusBarOverlay = null
    }

    @SuppressLint("SetTextI18n", "ClickableViewAccessibility")
    private fun createOverlayView(): View {
        val context = this
        val bgColor = Color.parseColor("#0D1117")
        val accentColor = Color.parseColor("#007DFF")
        val white = Color.WHITE
        val grayColor = Color.parseColor("#B0B0B0")
        val dimGray = Color.parseColor("#666666")

        val rootLayout = FrameLayout(context).apply {
            setBackgroundColor(bgColor)
        }

        val scroll = ScrollView(context)
        mainLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 100, 48, 48) // Extra top padding to push below status bar
        }

        // Mode label
        modeLabel = TextView(context).apply {
            text = if (isArabic) "🔒 وضع التركيز نشط" else "🔒 Focus Mode Active"
            setTextColor(accentColor)
            textSize = 18f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 24)
        }
        mainLayout!!.addView(modeLabel)

        // Task title
        titleText = TextView(context).apply {
            text = taskTitle
            setTextColor(white)
            textSize = 28f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 12)
        }
        mainLayout!!.addView(titleText)

        // Task description
        descText = TextView(context).apply {
            text = if (taskDesc.isNotEmpty()) taskDesc else {
                if (isArabic) "ابقَ مركزاً على مهمتك" else "Stay focused on your task"
            }
            setTextColor(grayColor)
            textSize = 16f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 32)
        }
        mainLayout!!.addView(descText)

        // Timer
        timerText = TextView(context).apply {
            text = formatTime(totalDurationMs)
            setTextColor(white)
            textSize = 72f
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 8)
        }
        mainLayout!!.addView(timerText)

        // Remaining label
        remainingText = TextView(context).apply {
            val mins = durationMinutes.toLong()
            text = if (isArabic) {
                "${toArabicNumerals(mins.toString())} ${if (mins == 1L) "دقيقة" else "دقائق"} متبقي"
            } else "$mins min remaining"
            setTextColor(grayColor)
            textSize = 16f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 24)
        }
        mainLayout!!.addView(remainingText)

        // Progress bar
        val progressContainer = FrameLayout(context).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 8
            ).apply { setMargins(0, 0, 0, 32) }
            setBackgroundColor(Color.parseColor("#1AFFFFFF"))
        }
        progressFill = View(context).apply {
            setBackgroundColor(accentColor)
            layoutParams = FrameLayout.LayoutParams(0, FrameLayout.LayoutParams.MATCH_PARENT)
        }
        progressContainer.addView(progressFill)
        mainLayout!!.addView(progressContainer)

        // Duration label
        durationLabel = TextView(context).apply {
            val durStr = if (isArabic) toArabicNumerals(durationMinutes.toString()) else durationMinutes.toString()
            text = if (isArabic) "$durStr دقيقة" else "$durationMinutes min"
            setTextColor(grayColor)
            textSize = 14f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 16)
        }
        mainLayout!!.addView(durationLabel)

        // Exit hint
        exitHint = TextView(context).apply {
            text = if (isArabic) "🔒 لن يمكنك الخروج حتى ينتهي المؤقت" else "🔒 You cannot exit until timer ends"
            setTextColor(dimGray)
            textSize = 13f
            gravity = Gravity.CENTER
            setPadding(0, 16, 0, 16)
        }
        mainLayout!!.addView(exitHint)

        // Close button (disabled)
        closeBtn = Button(context).apply {
            text = if (isArabic) "🔒 مقفل" else "🔒 Locked"
            setTextColor(Color.parseColor("#888888"))
            textSize = 16f
            setBackgroundColor(Color.parseColor("#1A1A2E"))
            isEnabled = false
            alpha = 0.4f
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { gravity = Gravity.CENTER; topMargin = 16 }
            setPadding(48, 16, 48, 16)
        }
        mainLayout!!.addView(closeBtn)

        scroll.addView(mainLayout)
        rootLayout.addView(scroll)
        return rootLayout
    }

    private fun formatTime(millis: Long): String {
        val minutes = TimeUnit.MILLISECONDS.toMinutes(millis)
        val seconds = TimeUnit.MILLISECONDS.toSeconds(millis) % 60
        val timeStr = String.format(Locale.US, "%02d:%02d", minutes, seconds)
        return if (isArabic) toArabicNumerals(timeStr) else timeStr
    }

    private fun toArabicNumerals(input: String): String {
        val easternDigits = charArrayOf('٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩')
        return input.map { c -> if (c in '0'..'9') easternDigits[c - '0'] else c }.joinToString("")
    }

    // ─── Countdown ─────────────────────────────────────────────────────────

    private fun startCountdown() {
        cancelCountdown()
        countDownTimer = object : CountDownTimer(totalDurationMs, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                updateOverlayTimer(millisUntilFinished)
            }
            override fun onFinish() {
                onCountdownComplete()
            }
        }.start()
    }

    private fun cancelCountdown() {
        countDownTimer?.cancel()
        countDownTimer = null
    }

    @SuppressLint("SetTextI18n")
    private fun updateOverlayTimer(millisRemaining: Long) {
        try {
            timerText?.text = formatTime(millisRemaining)
            val minutes = TimeUnit.MILLISECONDS.toMinutes(millisRemaining)
            remainingText?.text = if (isArabic) {
                "${toArabicNumerals(minutes.toString())} ${if (minutes == 1L) "دقيقة" else "دقائق"} متبقي"
            } else "$minutes min remaining"

            val progress = ((totalDurationMs - millisRemaining).toFloat() / totalDurationMs)
            val containerWidth = (progressFill?.parent as? View)?.width ?: return
            (progressFill?.layoutParams as? FrameLayout.LayoutParams)?.let {
                it.width = (containerWidth * progress).toInt()
                progressFill?.layoutParams = it
            }
        } catch (_: Exception) {}
    }

    // ─── Timer Complete — Show Task Done Prompt ────────────────────────────

    @SuppressLint("SetTextI18n", "ClickableViewAccessibility")
    private fun onCountdownComplete() {
        isTimerFinished = true
        restoreSoundMode()
        cancelCountdown()
        Log.d(TAG, "✅ [FOCUS] Countdown complete!")

        // Update the overlay to show completion + buttons
        val context = this
        val greenColor = Color.parseColor("#4CAF50")
        val redColor = Color.parseColor("#F44336")
        val accentColor = Color.parseColor("#007DFF")
        val white = Color.WHITE
        val grayColor = Color.parseColor("#B0B0B0")

        try {
            timerText?.text = if (isArabic) "تم!" else "Done!"
            timerText?.setTextColor(greenColor)

            titleText?.text = if (isArabic) "انتهت جلسة التركيز!" else "Focus Session Complete!"
            titleText?.setTextColor(greenColor)

            val minStr = if (isArabic) toArabicNumerals(durationMinutes.toString()) else durationMinutes.toString()
            descText?.text = if (isArabic) {
                "أحسنت! بقيت مركزاً لمدة $minStr دقيقة."
            } else {
                "Great job! You stayed focused for $durationMinutes minutes."
            }
            descText?.setTextColor(greenColor)

            // Progress to 100%
            val containerWidth = (progressFill?.parent as? View)?.width ?: 0
            (progressFill?.layoutParams as? FrameLayout.LayoutParams)?.let {
                it.width = containerWidth
                progressFill?.layoutParams = it
            }
            progressFill?.setBackgroundColor(greenColor)

            // Hide timer elements, show completion question
            remainingText?.visibility = View.GONE
            durationLabel?.visibility = View.GONE
            exitHint?.visibility = View.GONE
            closeBtn?.visibility = View.GONE

            // "Did you complete your task?" label
            val questionLabel = TextView(context).apply {
                text = if (isArabic) "هل أنجزت مهمتك؟" else "Did you complete your task?"
                setTextColor(white)
                textSize = 22f
                gravity = Gravity.CENTER
                setPadding(0, 24, 0, 24)
                id = View.generateViewId()
            }
            mainLayout?.addView(questionLabel)

            // Buttons row
            val btnRow = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
                setPadding(0, 8, 0, 16)
            }

            // Yes button
            val yesBtn = Button(context).apply {
                text = if (isArabic) "✅ نعم، أنجزتها" else "✅ Yes, I did it"
                setTextColor(white)
                setBackgroundColor(greenColor)
                textSize = 16f
                setPadding(24, 12, 24, 12)
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                    marginEnd = 8
                }
                setOnClickListener {
                    // Mark task as done
                    startService(Intent(this@FocusModeService, FocusModeService::class.java).apply {
                        action = ACTION_TASK_DONE
                    })
                }
            }
            btnRow.addView(yesBtn)

            // No button
            val noBtn = Button(context).apply {
                text = if (isArabic) "❌ لا، لم أنجزها" else "❌ No, not yet"
                setTextColor(white)
                setBackgroundColor(redColor)
                textSize = 16f
                setPadding(24, 12, 24, 12)
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                    marginStart = 8
                }
                setOnClickListener {
                    startService(Intent(this@FocusModeService, FocusModeService::class.java).apply {
                        action = ACTION_TASK_NOT_DONE
                    })
                }
            }
            btnRow.addView(noBtn)

            mainLayout?.addView(btnRow)

            // Now make overlay touchable so buttons work
            updateOverlayTouchable(true)

        } catch (e: Exception) {
            Log.e(TAG, "❌ [FOCUS] Error showing completion UI: ${e.message}")
            stopFocusMode()
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun updateOverlayTouchable(touchable: Boolean) {
        try {
            val view = overlayView ?: return
            val wm = windowManager ?: return

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_SYSTEM_ALERT,
                if (touchable) 0 else (WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE),
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.CENTER
                screenBrightness = 1.0f
                flags = flags or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                        WindowManager.LayoutParams.FLAG_FULLSCREEN or
                        WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
            }

            wm.updateViewLayout(view, params)

            // Remove status bar blocker when touchable (timer done)
            if (touchable) {
                try { statusBarOverlay?.let { wm.removeView(it) }; statusBarOverlay = null } catch (_: Exception) {}
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ [FOCUS] updateOverlayTouchable failed: ${e.message}")
        }
    }

    // ─── Restart Options (when user says "No, not done") ───────────────────

    @SuppressLint("SetTextI18n", "ClickableViewAccessibility")
    private fun showRestartOptions() {
        val context = this
        val accentColor = Color.parseColor("#007DFF")
        val orangeColor = Color.parseColor("#FF9800")
        val redColor = Color.parseColor("#F44336")
        val grayColor = Color.parseColor("#B0B0B0")
        val white = Color.WHITE

        try {
            // Clear existing main layout children
            mainLayout?.removeAllViews()

            // Title
            val title = TextView(context).apply {
                text = if (isArabic) "ماذا تريد أن تفعل؟" else "What would you like to do?"
                setTextColor(white)
                textSize = 24f
                gravity = Gravity.CENTER
                setPadding(0, 24, 0, 32)
            }
            mainLayout?.addView(title)

            // "Start focus again?" label
            val restartLabel = TextView(context).apply {
                text = if (isArabic) "هل تريد بدء وضع التركيز مرة أخرى؟" else "Start Focus Mode again?"
                setTextColor(grayColor)
                textSize = 18f
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, 16)
            }
            mainLayout?.addView(restartLabel)

            // Duration presets
            val presetLabel = TextView(context).apply {
                text = if (isArabic) "اختر المدة:" else "Choose duration:"
                setTextColor(white)
                textSize = 16f
                gravity = Gravity.CENTER
                setPadding(0, 16, 0, 12)
            }
            mainLayout?.addView(presetLabel)

            // Duration chips row
            val chipsRow = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, 16)
            }

            val durations = listOf(5, 10, 15, 25, 45, 60)
            var selectedDuration = 25

            val chips = mutableListOf<Button>()
            for (dur in durations) {
                val chip = Button(context).apply {
                    text = if (isArabic) toArabicNumerals(dur.toString()) else dur.toString()
                    setTextColor(white)
                    textSize = 14f
                    setBackgroundColor(if (dur == 25) accentColor else Color.parseColor("#1A1A2E"))
                    setPadding(16, 8, 16, 8)
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply { marginEnd = 8; marginStart = 8 }
                    setOnClickListener {
                        selectedDuration = dur
                        chips.forEach { c ->
                            c.setBackgroundColor(Color.parseColor("#1A1A2E"))
                        }
                        setBackgroundColor(accentColor)
                    }
                }
                chips.add(chip)
                chipsRow.addView(chip)
            }
            mainLayout?.addView(chipsRow)

            // Custom minutes input
            val customLabel = TextView(context).apply {
                text = if (isArabic) "أو أدخل دقائق مخصصة:" else "Or enter custom minutes:"
                setTextColor(grayColor)
                textSize = 14f
                gravity = Gravity.CENTER
                setPadding(0, 8, 0, 8)
            }
            mainLayout?.addView(customLabel)

            val customInput = EditText(context).apply {
                hint = if (isArabic) "دقائق..." else "minutes..."
                setHintTextColor(Color.parseColor("#666666"))
                setTextColor(white)
                inputType = InputType.TYPE_CLASS_NUMBER
                gravity = Gravity.CENTER
                setBackgroundColor(Color.parseColor("#1A1A2E"))
                setPadding(24, 16, 24, 16)
                layoutParams = LinearLayout.LayoutParams(200, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                    gravity = Gravity.CENTER
                    bottomMargin = 16
                }
            }
            mainLayout?.addView(customInput)

            // Restart button
            val restartBtn = Button(context).apply {
                text = if (isArabic) "🔄 بدء التركيز" else "🔄 Start Focus"
                setTextColor(white)
                setBackgroundColor(accentColor)
                textSize = 18f
                setPadding(48, 16, 48, 16)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = 16 }
                setOnClickListener {
                    val mins = customInput.text.toString().toIntOrNull() ?: selectedDuration
                    startService(Intent(this@FocusModeService, FocusModeService::class.java).apply {
                        action = ACTION_RESTART_FOCUS
                        putExtra(EXTRA_DURATION_MINUTES, mins.coerceIn(1, 180))
                    })
                }
            }
            mainLayout?.addView(restartBtn)

            // Skip / close button
            val skipBtn = Button(context).apply {
                text = if (isArabic) "⏭️ تخطي وإغلاق" else "⏭️ Skip & Close"
                setTextColor(white)
                setBackgroundColor(Color.parseColor("#444444"))
                textSize = 16f
                setPadding(48, 12, 48, 12)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = 8 }
                setOnClickListener {
                    stopFocusMode()
                }
            }
            mainLayout?.addView(skipBtn)

        } catch (e: Exception) {
            Log.e(TAG, "❌ [FOCUS] showRestartOptions failed: ${e.message}")
            stopFocusMode()
        }
    }

    // ─── Foreground Notification ──────────────────────────────────────────

    private fun startForeground() {
        val contentIntent = Intent(this, FocusModeActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            this, NOTIFICATION_ID, contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(if (isArabic) "وضع التركيز نشط" else "Focus Mode Active")
            .setContentText(if (isArabic) taskTitle else taskTitle)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(pendingIntent)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    // ─── Silent Mode ──────────────────────────────────────────────────────

    private fun enableSilentMode() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
        savedRingerMode = audioManager.ringerMode

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.isNotificationPolicyAccessGranted) {
                wasDndEnabled = true
                try {
                    nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
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

    private fun fallbackToRingerSilent(audioManager: android.media.AudioManager) {
        try { audioManager.ringerMode = android.media.AudioManager.RINGER_MODE_VIBRATE } catch (_: Exception) {}
    }

    private fun restoreSoundMode() {
        Log.d(TAG, "✅ [FOCUS] Restoring sound mode to: $savedRingerMode")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.isNotificationPolicyAccessGranted) {
                try { nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL) } catch (_: Exception) {}
            }
        }
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
        try {
            audioManager.ringerMode = savedRingerMode
        } catch (_: Exception) {
            try { audioManager.ringerMode = android.media.AudioManager.RINGER_MODE_NORMAL } catch (_: Exception) {}
        }
    }

    // ─── WakeLock ─────────────────────────────────────────────────────────

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "aura:FocusModeServiceLock")
        wakeLock.acquire((durationMinutes + 10).toLong() * 60 * 1000L)
    }

    private fun releaseWakeLock() {
        if (::wakeLock.isInitialized && wakeLock.isHeld) {
            try { wakeLock.release() } catch (_: Exception) {}
        }
    }

    // ─── Stop ──────────────────────────────────────────────────────────────

    private fun stopFocusMode() {
        isTimerFinished = true
        isRunning = false
        cancelCountdown()
        removeOverlay()
        restoreSoundMode()
        releaseWakeLock()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        Log.d(TAG, "✅ [FOCUS] Service stopped")
    }

    // ─── Notification Channel ──────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Focus Mode Service", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Keeps focus mode active"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
