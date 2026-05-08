package com.aura.hala

import android.content.Context
import android.content.Intent
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

/**
 * Full-screen post-prayer azkar activity.
 * Shows سبحان الله ×33, الحمد لله ×33, الله أكبر ×34.
 * Tap each row to increment its counter; green checkmark appears when done.
 * "بارك الله فيك" banner shows when all three are complete.
 */
class AzkarFullScreenActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "AzkarFullScreen"
        const val EXTRA_PRAYER_NAME    = "prayer_name"
        const val EXTRA_PRAYER_NAME_AR = "prayer_name_ar"

        fun getIntent(context: Context, prayerName: String, prayerNameAr: String): Intent {
            return Intent(context, AzkarFullScreenActivity::class.java).apply {
                putExtra(EXTRA_PRAYER_NAME, prayerName)
                putExtra(EXTRA_PRAYER_NAME_AR, prayerNameAr)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS or
                        Intent.FLAG_ACTIVITY_NO_HISTORY
            }
        }
    }

    private val counts = intArrayOf(0, 0, 0)
    private val targets = intArrayOf(33, 33, 34)

    private lateinit var prayerName: String
    private lateinit var prayerNameAr: String
    private var isArabic = false
    private var vibrator: Vibrator? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        prayerName   = intent.getStringExtra(EXTRA_PRAYER_NAME)    ?: "Fajr"
        prayerNameAr = intent.getStringExtra(EXTRA_PRAYER_NAME_AR) ?: "الفجر"

        Log.d(TAG, "🤲 [AZKAR] Launched for $prayerName")

        val prefs = getSharedPreferences("aura_prayer_times", MODE_PRIVATE)
        isArabic = prefs.getString("language", "en") == "ar"

        setupFullScreen()
        setContentView(R.layout.activity_azkar_fullscreen)

        @Suppress("DEPRECATION")
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator

        setupUI()
    }

    private fun setupFullScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                setTurnScreenOn(true)
                setShowWhenLocked(true)
            } catch (e: Exception) {
                setupWindowFlags()
            }
        } else {
            setupWindowFlags()
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    @Suppress("DEPRECATION")
    private fun setupWindowFlags() {
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD  or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON    or
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )
    }

    private fun setupUI() {
        // Header
        val titleTv = findViewById<TextView>(R.id.azkarTitle)
        val prayerNameTv = findViewById<TextView>(R.id.azkarPrayerName)

        titleTv.text = if (isArabic) "أذكار بعد الصلاة" else "Post-Prayer Azkar"
        prayerNameTv.text = if (isArabic) "بعد صلاة $prayerNameAr" else "After $prayerName prayer"

        // Item rows
        val items = listOf(
            Triple(R.id.azkarItem1, R.id.azkarCount1, R.id.azkarCheck1),
            Triple(R.id.azkarItem2, R.id.azkarCount2, R.id.azkarCheck2),
            Triple(R.id.azkarItem3, R.id.azkarCount3, R.id.azkarCheck3),
        )

        items.forEachIndexed { idx, (itemId, countId, checkId) ->
            val itemView  = findViewById<LinearLayout>(itemId)
            val countTv   = findViewById<TextView>(countId)
            val checkTv   = findViewById<TextView>(checkId)

            // Style the card background
            itemView.background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 16f
                setColor(0x22FFFFFF)
            }

            countTv.text = "0 / ${targets[idx]}"

            itemView.setOnClickListener {
                if (counts[idx] < targets[idx]) {
                    counts[idx]++
                    countTv.text = "${counts[idx]} / ${targets[idx]}"
                    vibrate()

                    if (counts[idx] == targets[idx]) {
                        checkTv.visibility = View.VISIBLE
                        checkAllComplete()
                    }
                }
            }
        }

        // Dismiss button
        findViewById<Button>(R.id.btnAzkarDismiss).setOnClickListener {
            finish()
        }
    }

    private fun checkAllComplete() {
        if (counts[0] >= targets[0] && counts[1] >= targets[1] && counts[2] >= targets[2]) {
            val completeTv = findViewById<TextView>(R.id.azkarComplete)
            completeTv.text = if (isArabic) "بارك الله فيك ✨" else "Barak Allah feek ✨"
            completeTv.visibility = View.VISIBLE
            Log.d(TAG, "✅ [AZKAR] All azkar completed for $prayerName")
        }
    }

    private fun vibrate() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createOneShot(40, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(40)
            }
        } catch (e: Exception) {
            // Ignore vibration failures
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "📱 [AZKAR] Activity destroyed")
    }
}
