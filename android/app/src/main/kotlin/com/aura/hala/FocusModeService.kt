package com.aura.hala

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import android.view.View
import androidx.core.app.NotificationCompat

/**
 * Foreground service that monitors FocusModeActivity and relaunches it if escaped.
 * Uses a FULL-SCREEN overlay that blocks ALL touch input during countdown.
 * Stores start timestamp so timer continues correctly on relaunch.
 */
class FocusModeService : Service() {

    companion object {
        private const val TAG = "FocusModeService"
        const val CHANNEL_ID = "focus_mode_service"
        const val NOTIFICATION_ID = 5998
        private const val PREFS_NAME = "aura_focus_state"

        const val ACTION_START = "com.aura.hala.FOCUS_SERVICE_START"
        const val ACTION_STOP = "com.aura.hala.FOCUS_SERVICE_STOP"
        const val ACTION_BLOCK_TOUCH = "com.aura.hala.FOCUS_BLOCK_TOUCH"
        const val ACTION_ALLOW_TOUCH = "com.aura.hala.FOCUS_ALLOW_TOUCH"

        const val EXTRA_TASK_ID = "task_id"
        const val EXTRA_TASK_TITLE = "task_title"
        const val EXTRA_TASK_DESC = "task_desc"
        const val EXTRA_DURATION_MINUTES = "duration_minutes"
        const val EXTRA_LANGUAGE = "language"
        const val EXTRA_STARTED_AT = "started_at"

        const val ACTION_TASK_DONE = "com.aura.hala.FOCUS_TASK_DONE"
        const val ACTION_TASK_NOT_DONE = "com.aura.hala.FOCUS_TASK_NOT_DONE"
        const val ACTION_RESTART_FOCUS = "com.aura.hala.FOCUS_RESTART"

        var isRunning: Boolean = false
            private set

        fun start(context: Context, taskId: String, taskTitle: String, taskDesc: String, durationMinutes: Int, language: String) {
            val intent = Intent(context, FocusModeService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TASK_ID, taskId)
                putExtra(EXTRA_TASK_TITLE, taskTitle)
                putExtra(EXTRA_TASK_DESC, taskDesc)
                putExtra(EXTRA_DURATION_MINUTES, durationMinutes)
                putExtra(EXTRA_LANGUAGE, language)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent)
            else context.startService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, FocusModeService::class.java).apply { action = ACTION_STOP }
            context.startService(intent)
        }

        /** Called by activity to block ALL touch input on screen */
        fun blockTouch(context: Context) {
            val intent = Intent(context, FocusModeService::class.java).apply { action = ACTION_BLOCK_TOUCH }
            context.startService(intent)
        }

        /** Called by activity to allow touch input (after timer ends) */
        fun allowTouch(context: Context) {
            val intent = Intent(context, FocusModeService::class.java).apply { action = ACTION_ALLOW_TOUCH }
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
    private var savedRingerMode: Int = AudioManager.RINGER_MODE_NORMAL
    private var wasDndEnabled: Boolean = false
    private lateinit var wakeLock: PowerManager.WakeLock
    private lateinit var screenWakeLock: PowerManager.WakeLock

    // Start timestamp for accurate timer across relaunches
    private var focusStartedAt: Long = 0L

    // Full-screen touch blocker overlay
    private var touchBlocker: View? = null
    private lateinit var windowManager: WindowManager

    private val monitorHandler = Handler(Looper.getMainLooper())
    private val monitorInterval = 100L

    private val monitorRunnable = object : Runnable {
        override fun run() {
            if (!isTimerFinished && isRunning) {
                if (!FocusModeActivity.isActivityVisible) {
                    Log.w(TAG, "[FOCUS] Activity escaped! Relaunching immediately")
                    relaunchActivity()
                }
                // Re-add touch blocker if removed by system
                if (touchBlocker == null) addTouchBlocker()
                monitorHandler.postDelayed(this, monitorInterval)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
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

                focusStartedAt = intent.getLongExtra(EXTRA_STARTED_AT, 0L)
                if (focusStartedAt == 0L) {
                    focusStartedAt = System.currentTimeMillis()
                }
                saveFocusState()

                startForeground()
                acquireWakeLock()
                enableSilentMode()
                addTouchBlocker()
                startMonitoring()
                isRunning = true
                Log.d(TAG, "[FOCUS] Service started for: $taskTitle (${durationMinutes}min)")
            }

            ACTION_BLOCK_TOUCH -> {
                addTouchBlocker()
                return START_STICKY
            }

            ACTION_ALLOW_TOUCH -> {
                removeTouchBlocker()
                return START_STICKY
            }

            ACTION_STOP -> {
                stopFocusMode()
                return START_NOT_STICKY
            }

            ACTION_TASK_DONE -> {
                Log.d(TAG, "[FOCUS] User marked task as DONE")
                val prefs = getSharedPreferences("${packageName}_preferences", Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("focus_completed_task_id", taskId)
                    .putBoolean("focus_task_was_completed", true)
                    .apply()
                stopFocusMode()
                return START_NOT_STICKY
            }

            ACTION_TASK_NOT_DONE -> {
                Log.d(TAG, "[FOCUS] User said task NOT done")
                stopFocusMode()
                return START_NOT_STICKY
            }

            ACTION_RESTART_FOCUS -> {
                val minutes = intent.getIntExtra(EXTRA_DURATION_MINUTES, 25)
                Log.d(TAG, "[FOCUS] Restarting focus mode for $minutes min")
                durationMinutes = minutes
                focusStartedAt = intent.getLongExtra(EXTRA_STARTED_AT, System.currentTimeMillis())
                isTimerFinished = false
                saveFocusState()
                addTouchBlocker()
                startMonitoring()
                enableSilentMode()
                return START_STICKY
            }
        }
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (!isTimerFinished && isRunning) {
            try {
                val restartIntent = buildRestartIntent()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(restartIntent)
                else startService(restartIntent)
            } catch (_: Exception) {}
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        stopMonitoring()
        removeTouchBlocker()
        restoreSoundMode()
        releaseWakeLock()
        isRunning = false

        if (!isTimerFinished) {
            try {
                val restartIntent = buildRestartIntent()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(restartIntent)
                else startService(restartIntent)
            } catch (_: Exception) {}
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // --- State Persistence ---

    private fun saveFocusState() {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .putString("task_id", taskId)
            .putString("task_title", taskTitle)
            .putString("task_desc", taskDesc)
            .putInt("duration_minutes", durationMinutes)
            .putString("language", language)
            .putLong("started_at", focusStartedAt)
            .apply()
    }

    private fun clearFocusState() {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit().clear().apply()
    }

    private fun buildRestartIntent(): Intent {
        return Intent(this, FocusModeService::class.java).apply {
            action = ACTION_START
            putExtra(EXTRA_TASK_ID, taskId)
            putExtra(EXTRA_TASK_TITLE, taskTitle)
            putExtra(EXTRA_TASK_DESC, taskDesc)
            putExtra(EXTRA_DURATION_MINUTES, durationMinutes)
            putExtra(EXTRA_LANGUAGE, language)
            putExtra(EXTRA_STARTED_AT, focusStartedAt)
        }
    }

    // --- Full-Screen Touch Blocker ---

    /**
     * Creates a full-screen transparent overlay that consumes ALL touch events.
     * This prevents the user from doing ANYTHING on the phone during countdown.
     * - No notification shade pull-down
     * - No navigation gestures (home, recents, back)
     * - No touch input at all
     */
    private fun addTouchBlocker() {
        if (touchBlocker != null) return

        try {
            val overlay = View(this)
            // Fully transparent - the activity is visible behind it
            overlay.setBackgroundColor(0x00000000)
            // Consume ALL touch events
            overlay.setOnTouchListener { _, _ -> true }
            // Also block key events via focus
            overlay.isFocusable = false

            val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_SYSTEM_ERROR

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_FULLSCREEN,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
            }

            windowManager.addView(overlay, params)
            touchBlocker = overlay
            Log.d(TAG, "[FOCUS] Full-screen touch blocker added - ALL input blocked")
        } catch (e: Exception) {
            Log.w(TAG, "[FOCUS] Could not add touch blocker: ${e.message}")
        }
    }

    private fun removeTouchBlocker() {
        if (touchBlocker != null) {
            try {
                windowManager.removeView(touchBlocker)
            } catch (_: Exception) {}
            touchBlocker = null
            Log.d(TAG, "[FOCUS] Touch blocker removed - input allowed")
        }
    }

    // --- Monitoring ---

    private fun startMonitoring() {
        monitorHandler.removeCallbacks(monitorRunnable)
        monitorHandler.postDelayed(monitorRunnable, monitorInterval)
    }

    private fun stopMonitoring() {
        monitorHandler.removeCallbacks(monitorRunnable)
    }

    private fun relaunchActivity() {
        try {
            val intent = Intent(this, FocusModeActivity::class.java).apply {
                putExtra(FocusModeActivity.EXTRA_TASK_ID, taskId)
                putExtra(FocusModeActivity.EXTRA_TASK_TITLE, taskTitle)
                putExtra(FocusModeActivity.EXTRA_TASK_DESC, taskDesc)
                putExtra(FocusModeActivity.EXTRA_DURATION_MINUTES, durationMinutes)
                putExtra(FocusModeActivity.EXTRA_LANGUAGE, language)
                putExtra(FocusModeActivity.EXTRA_STARTED_AT, focusStartedAt)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }

            // Try direct start (works on some devices)
            try { startActivity(intent) } catch (_: Exception) {}

            // Full-screen intent notification — reliable on Android 10+ and Huawei/Xiaomi OEMs
            val pendingIntent = PendingIntent.getActivity(
                this, 5996, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(if (isArabic) "وضع التركيز نشط" else "Focus Mode Active")
                .setContentText(taskTitle)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setFullScreenIntent(pendingIntent, true)
                .setOngoing(true)
                .setAutoCancel(false)
                .build()
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(5996, notification)
            Log.w(TAG, "[FOCUS] Activity escaped — fired full-screen intent to relaunch")
        } catch (e: Exception) {
            Log.w(TAG, "[FOCUS] Relaunch failed: ${e.message}")
        }
    }

    // --- Foreground Notification ---

    private fun startForeground() {
        val contentIntent = Intent(this, FocusModeActivity::class.java).apply {
            putExtra(FocusModeActivity.EXTRA_TASK_ID, taskId)
            putExtra(FocusModeActivity.EXTRA_TASK_TITLE, taskTitle)
            putExtra(FocusModeActivity.EXTRA_TASK_DESC, taskDesc)
            putExtra(FocusModeActivity.EXTRA_DURATION_MINUTES, durationMinutes)
            putExtra(FocusModeActivity.EXTRA_LANGUAGE, language)
            putExtra(FocusModeActivity.EXTRA_STARTED_AT, focusStartedAt)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, NOTIFICATION_ID, contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(if (isArabic) "Focus Mode Active" else "Focus Mode Active")
            .setContentText(if (isArabic) taskTitle else taskTitle)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(pendingIntent)
            .build()
        startForeground(NOTIFICATION_ID, notification)
    }

    // --- Silent Mode ---

    private fun enableSilentMode() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        savedRingerMode = audioManager.ringerMode

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.isNotificationPolicyAccessGranted) {
                wasDndEnabled = true
                try { nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY) } catch (_: Exception) { fallbackToRingerSilent(audioManager) }
            } else { fallbackToRingerSilent(audioManager) }
        } else { fallbackToRingerSilent(audioManager) }
    }

    private fun fallbackToRingerSilent(audioManager: AudioManager) {
        try { audioManager.ringerMode = AudioManager.RINGER_MODE_VIBRATE } catch (_: Exception) {}
    }

    private fun restoreSoundMode() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.isNotificationPolicyAccessGranted) {
                try { nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL) } catch (_: Exception) {}
            }
        }
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        try { audioManager.ringerMode = savedRingerMode } catch (_: Exception) {
            try { audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL } catch (_: Exception) {}
        }
        Log.d(TAG, "[FOCUS] Sound mode restored")
    }

    // --- WakeLock ---

    @Suppress("DEPRECATION")
    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager

        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "aura:FocusModeServiceLock")
        wakeLock.acquire((durationMinutes + 10).toLong() * 60 * 1000L)

        screenWakeLock = powerManager.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
            "aura:FocusModeScreenLock"
        )
        screenWakeLock.acquire((durationMinutes + 5).toLong() * 60 * 1000L)
    }

    private fun releaseWakeLock() {
        if (::wakeLock.isInitialized && wakeLock.isHeld) {
            try { wakeLock.release() } catch (_: Exception) {}
        }
        if (::screenWakeLock.isInitialized && screenWakeLock.isHeld) {
            try { screenWakeLock.release() } catch (_: Exception) {}
        }
    }

    // --- Stop ---

    private fun stopFocusMode() {
        isTimerFinished = true
        isRunning = false
        stopMonitoring()
        removeTouchBlocker()
        clearFocusState()
        restoreSoundMode()
        releaseWakeLock()
        // Cancel the relaunch notification if it was shown
        try { (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(5996) } catch (_: Exception) {}
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    // --- Notification Channel ---

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
