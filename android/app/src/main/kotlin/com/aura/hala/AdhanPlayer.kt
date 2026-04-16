package com.aura.hala

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import android.util.Log
import java.io.IOException

/**
 * Native Adhan Player using Android MediaPlayer
 * Plays adhan audio for prayer times
 * Catches volume button presses via ContentObserver to stop adhan on lock screen
 */
object AdhanPlayer {
    private const val TAG = "AdhanPlayer"
    private var mediaPlayer: MediaPlayer? = null
    private var currentPrayer: String? = null
    private var volumeReceiver: BroadcastReceiver? = null
    private var lastVolumeIndex: Int = -1

    // Synchronization lock to prevent double adhan playback
    private val playbackLock = Any()

    // Adhan audio file names (should be in assets/audio/ or res/raw/)
    private val adhanFiles = mapOf(
        "Fajr" to "adhan_fajr.mp3",
        "Dhuhr" to "adhan_dhuhr.mp3",
        "Zuhr" to "adhan_dhuhr.mp3",
        "Asr" to "adhan_asr.mp3",
        "Maghrib" to "adhan_maghrib.mp3",
        "Isha" to "adhan_isha.mp3"
    )

    private val defaultAdhan = "adhan_default.mp3"

    // Custom adhan file path (set by user selection)
    private var customAdhanPath: String? = null

    /**
     * Set a custom adhan file path
     * @param path Full path to the adhan file
     */
    fun setCustomAdhan(path: String?) {
        customAdhanPath = path
        if (path != null) {
            Log.d(TAG, "✅ [CUSTOM ADHAN] Set to: $path")
        } else {
            Log.d(TAG, "🔄 [CUSTOM ADHAN] Cleared - using built-in")
        }
    }

    /**
     * Get the current custom adhan path
     */
    fun getCustomAdhan(): String? = customAdhanPath

    /**
     * Register volume change receiver to catch volume button presses on lock screen
     */
    private fun registerVolumeReceiver(context: Context) {
        unregisterVolumeReceiver()

        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        lastVolumeIndex = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)

        volumeReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                if (intent.action == "android.media.VOLUME_CHANGED_ACTION") {
                    val streamType = intent.getIntExtra("android.media.EXTRA_VOLUME_STREAM_TYPE", -1)
                    if (streamType == AudioManager.STREAM_MUSIC) {
                        val newVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                        if (newVolume != lastVolumeIndex) {
                            lastVolumeIndex = newVolume
                            Log.d(TAG, "🔊 [VOLUME] Volume changed to $newVolume — stopping adhan")
                            stop()
                        }
                    }
                }
            }
        }

        val filter = IntentFilter("android.media.VOLUME_CHANGED_ACTION")
        context.registerReceiver(volumeReceiver, filter)
        Log.d(TAG, "✅ [VOLUME RECEIVER] Registered — volume keys will stop adhan")
    }

    /**
     * Unregister volume change receiver
     */
    private fun unregisterVolumeReceiver() {
        volumeReceiver?.let {
            try {
                // We need an application context to unregister
                // This is handled in releasePlayer()
            } catch (e: Exception) {
                Log.e(TAG, "❌ [VOLUME RECEIVER] Unregister error: ${e.message}")
            }
        }
    }

    private var appContext: Context? = null

    /**
     * Play adhan for the specified prayer
     * @param context Application context
     * @param prayerName Name of the prayer (Fajr, Dhuhr, Asr, Maghrib, Isha)
     */
    @Synchronized
    fun play(context: Context, prayerName: String) {
        Log.d(TAG, "═════════════════════════════════════")
        Log.d(TAG, "🎵 [ADHAN PLAY] Requested for: $prayerName")
        Log.d(TAG, "🔒 [LOCK] Acquired playback lock")

        // Check if adhan is enabled
        val prefs = context.getSharedPreferences("aura_prefs", Context.MODE_PRIVATE)
        val adhanEnabled = prefs.getBoolean("adhan_enabled", true)

        if (!adhanEnabled) {
            Log.w(TAG, "❌ [ADHAN] DISABLED - Not playing for $prayerName")
            return
        }
        Log.d(TAG, "✅ [ADHAN] Enabled - Proceeding with playback")

        // Stop any currently playing adhan
        stop()

        // Save context for cleanup
        appContext = context.applicationContext

        // Register volume receiver to catch volume button presses
        registerVolumeReceiver(context.applicationContext)

        // Check for custom adhan
        if (customAdhanPath != null) {
            Log.d(TAG, "📁 [CUSTOM ADHAN] Path: $customAdhanPath")
            vibrate(context)
            if (playCustomAdhan(context, customAdhanPath!!, prayerName)) {
                Log.d(TAG, "✅ [ADHAN] Custom adhan playing successfully")
                return
            }
            Log.w(TAG, "⚠️ [CUSTOM ADHAN] Failed, falling back to built-in")
        } else {
            Log.d(TAG, "📦 [BUILT-IN ADHAN] No custom adhan set")
        }

        // Vibrate before playing adhan
        vibrate(context)

        // Try to play adhan - first specific, then default
        val filesToTry = listOf(
            adhanFiles[prayerName] ?: defaultAdhan,  // Prayer-specific file
            defaultAdhan  // Default adhan as fallback
        ).distinct()  // Remove duplicates if they're the same

        Log.d(TAG, "📋 [FILES] Trying: ${filesToTry.joinToString(", ")}")

        var playedSuccessfully = false

        for (fileName in filesToTry) {
            if (playAdhanFile(context, fileName, prayerName)) {
                playedSuccessfully = true
                break
            }
        }

        // If all files failed, play default notification sound
        if (!playedSuccessfully) {
            Log.e(TAG, "❌ [ADHAN] All files failed - using default notification")
            playDefaultSound(context)
        }

        Log.d(TAG, "✅ [ADHAN PLAY] play() method COMPLETED for $prayerName - playedSuccessfully=$playedSuccessfully")
        Log.d(TAG, "🔓 [LOCK] Releasing playback lock")
        Log.d(TAG, "═════════════════════════════════════")
    }

    /**
     * Play a custom adhan file from storage
     * @return true if successful, false otherwise
     */
    private fun playCustomAdhan(context: Context, filePath: String, prayerName: String): Boolean {
        Log.d(TAG, "📂 [CUSTOM] Attempting: $filePath")

        return try {
            mediaPlayer = MediaPlayer()
            mediaPlayer?.setOnCompletionListener {
                Log.d(TAG, "✅ [CUSTOM] Playback completed for $prayerName")
                releasePlayer()
            }
            mediaPlayer?.setOnErrorListener { _, what, extra ->
                Log.e(TAG, "❌ [CUSTOM] Error - what=$what, extra=$extra")
                releasePlayer()
                true
            }

            mediaPlayer?.setDataSource(filePath)
            mediaPlayer?.prepare()
            mediaPlayer?.start()

            currentPrayer = prayerName
            Log.d(TAG, "✅ [CUSTOM] NOW PLAYING for $prayerName")
            true

        } catch (e: IOException) {
            Log.e(TAG, "❌ [CUSTOM] IO Error: ${e.message}")
            releasePlayer()
            false
        } catch (e: Exception) {
            Log.e(TAG, "❌ [CUSTOM] Error: ${e.message}")
            releasePlayer()
            false
        }
    }

    /**
     * Try to play a specific adhan file
     * @return true if successful, false otherwise
     */
    private fun playAdhanFile(context: Context, fileName: String, prayerName: String): Boolean {
        Log.d(TAG, "📂 [BUILT-IN] Trying: $fileName for $prayerName")

        try {
            mediaPlayer = MediaPlayer()
            mediaPlayer?.setOnCompletionListener {
                Log.d(TAG, "✅ [BUILT-IN] Playback completed for $prayerName")
                releasePlayer()
            }
            mediaPlayer?.setOnErrorListener { _, what, extra ->
                Log.e(TAG, "❌ [BUILT-IN] Error - what=$what, extra=$extra")
                releasePlayer()
                true
            }

            // Try to load from resources (res/raw folder) first
            val resourceName = fileName.substringBeforeLast('.')
            val resourceId = context.resources.getIdentifier(
                resourceName,
                "raw",
                context.packageName
            )

            if (resourceId != 0) {
                // File found in res/raw
                Log.d(TAG, "✅ [BUILT-IN] Found in res/raw/$fileName")
                val assetFileDescriptor = context.resources.openRawResourceFd(resourceId)
                mediaPlayer?.setDataSource(assetFileDescriptor.fileDescriptor, assetFileDescriptor.startOffset, assetFileDescriptor.declaredLength)
                assetFileDescriptor.close()

                mediaPlayer?.prepare()
                mediaPlayer?.start()

                currentPrayer = prayerName
                Log.d(TAG, "✅ [BUILT-IN] NOW PLAYING for $prayerName from $fileName")
                return true
            } else {
                Log.w(TAG, "❌ [BUILT-IN] NOT FOUND in res/raw: $fileName")
                return false
            }

        } catch (e: IOException) {
            Log.e(TAG, "❌ [BUILT-IN] IO Error loading $fileName: ${e.message}")
            releasePlayer()
            return false
        } catch (e: Exception) {
            Log.e(TAG, "❌ [BUILT-IN] Error playing $fileName: ${e.message}")
            releasePlayer()
            return false
        }
    }

    /**
     * Stop the currently playing adhan
     */
    fun stop() {
        if (mediaPlayer?.isPlaying == true) {
            Log.d(TAG, "⏹️ [ADHAN] STOPPING playback for $currentPrayer")
            mediaPlayer?.stop()
        }
        releasePlayer()
    }

    /**
     * Release the MediaPlayer and volume receiver
     */
    private fun releasePlayer() {
        mediaPlayer?.release()
        mediaPlayer = null
        currentPrayer = null

        // Unregister volume receiver
        try {
            volumeReceiver?.let {
                appContext?.unregisterReceiver(it)
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ [VOLUME RECEIVER] Unregister error: ${e.message}")
        }
        volumeReceiver = null
        appContext = null
    }

    /**
     * Vibrate device before playing adhan
     */
    private fun vibrate(context: Context) {
        try {
            val vibrator = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as android.os.VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                vibrator.vibrate(
                    VibrationEffect.createWaveform(longArrayOf(0, 500, 200, 500), -1)
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(longArrayOf(0, 500, 200, 500), -1)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error vibrating", e)
        }
    }

    /**
     * Play default notification sound as fallback
     */
    private fun playDefaultSound(context: Context) {
        try {
            val player = MediaPlayer()
            player.setDataSource(context, android.provider.Settings.System.DEFAULT_NOTIFICATION_URI)
            player.prepare()
            player.start()
            player.setOnCompletionListener { player.release() }
            Log.d(TAG, "Played default notification sound as fallback")
        } catch (e: Exception) {
            Log.e(TAG, "Error playing default sound", e)
        }
    }

    /**
     * Check if adhan is currently playing
     */
    fun isPlaying(): Boolean {
        return mediaPlayer?.isPlaying == true
    }

    /**
     * Get the current prayer name being played
     */
    fun getCurrentPrayer(): String? {
        return currentPrayer
    }
}
