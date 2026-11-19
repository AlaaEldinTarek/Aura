package com.aura.hala

import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewOutlineProvider
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

/**
 * Small popup opened by tapping the post-prayer check card (docs/designs/fix-post-check-remind-later.md, R1e).
 * A translucent activity with a bottom card in the notification's style (same theme and language layout), the
 * prayer icon, the question and the four buttons. A button sends the SAME PendingIntent as the notification
 * button (PrayerAlarmReceiver writes the status once and cancels the notification), then the popup closes.
 * Back or a tap outside closes the popup only (nothing recorded, the notification stays). Never starts MainActivity.
 */
class PostCheckPopupActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockScreen()

        val prayerName = intent.getStringExtra(PrayerAlarmReceiver.EXTRA_PRAYER_NAME)
        if (prayerName == null) {
            Log.e(TAG, "❌ [POST_CHECK_POPUP] no prayer name, closing")
            finish()
            return
        }
        val prayerNameAr = intent.getStringExtra(PrayerAlarmReceiver.EXTRA_PRAYER_NAME_AR) ?: prayerName
        val prayerTime = intent.getLongExtra(PrayerAlarmReceiver.EXTRA_PRAYER_TIME, 0L)
        val isArabic = PostCheckCard.isArabic(this)
        val dark = PostCheckCard.isDark(this)
        val density = resources.displayMetrics.density

        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#99000000"))
            setOnClickListener { finish() } // tap outside the card: close the popup only
        }
        val container = FrameLayout(this).apply {
            background = GradientDrawable().apply {
                setColor(Color.parseColor(if (dark) "#1A1B1E" else "#FFF8EB"))
                cornerRadius = 20 * density
            }
            outlineProvider = ViewOutlineProvider.BACKGROUND
            clipToOutline = true
            isClickable = true // swallow taps on the card
        }
        val card = layoutInflater.inflate(PostCheckCard.layoutId(dark, isArabic), container, false)
        container.addView(card)
        root.addView(
            container,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM
            ).apply {
                val m = (12 * density).toInt()
                setMargins(m, m, m, (24 * density).toInt())
            }
        )
        setContentView(root)

        val label = if (isArabic) prayerNameAr else prayerName
        card.findViewById<TextView>(R.id.post_check_title).text = PostCheckActions.question(label, isArabic)
        card.findViewById<TextView>(R.id.post_check_body).text = PostCheckActions.subtitle(isArabic)
        ThemedNotification.iconBitmap(this, prayerName)?.let { card.findViewById<ImageView>(R.id.post_check_icon).setImageBitmap(it) }
        card.findViewById<View>(R.id.post_check_hint).visibility = View.GONE // the hint is for the collapsed card only

        fun wire(viewId: Int, spec: PostCheckActions.Spec) {
            val v = card.findViewById<TextView>(viewId)
            v.text = PostCheckActions.label(spec, isArabic)
            v.setOnClickListener {
                try {
                    PostCheckCard.actionPending(this, spec, prayerName, prayerNameAr, prayerTime).send()
                    Log.d(TAG, "🪟 [POST_CHECK_POPUP] ${spec.key} sent for $prayerName")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ [POST_CHECK_POPUP] send failed: ${e.message}")
                }
                finish()
            }
        }
        for (spec in PostCheckActions.buttons()) {
            wire(
                when (spec.key) {
                    "done" -> R.id.btn_done
                    "late" -> R.id.btn_late
                    else -> R.id.btn_missed
                },
                spec
            )
        }
        wire(R.id.btn_remind_later, PostCheckActions.corner())
    }

    @Suppress("DEPRECATION")
    private fun showOverLockScreen() {
        // Same approach as AdhanFullScreenActivity: show over the lock screen and wake the screen.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    companion object {
        private const val TAG = "PostCheckPopup"
    }
}
