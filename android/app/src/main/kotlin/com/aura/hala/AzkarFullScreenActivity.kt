package com.aura.hala

import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

/**
 * Full-screen post-prayer azkar activity.
 * Shows the complete post-prayer remembrances from Hisn al-Muslim.
 * Items are dynamically built based on prayer name (Fajr/Maghrib get extra azkar).
 * Tap each card to increment its counter; green ✓ when done.
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

    private data class AzkarItem(
        val textAr: String,
        val target: Int,
        var count: Int = 0
    ) {
        val isDone get() = count >= target
    }

    private val items = mutableListOf<AzkarItem>()
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

        @Suppress("DEPRECATION")
        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator

        setupFullScreen()
        setContentView(R.layout.activity_azkar_fullscreen)
        buildAzkarList()
        setupUI()
    }

    // ── Azkar data ────────────────────────────────────────────────────────────

    private fun buildAzkarList() {
        items.clear()
        val isFajrOrMaghrib = prayerName == "Fajr" || prayerName == "Maghrib"
        val qulsCount = if (isFajrOrMaghrib) 3 else 1

        // 1. Istighfar × 3
        items.add(AzkarItem("أَسْتَغْفِرُ اللَّهَ", 3))

        // 2. Allahumma antas-Salam × 1
        items.add(AzkarItem(
            "اللَّهُمَّ أَنْتَ السَّلاَمُ، وَمِنْكَ السَّلاَمُ، تَبَارَكْتَ يَا ذَا الْجَلاَلِ وَالْإِكْرَامِ",
            1
        ))

        // 3. La ilaha illallah + Allahumma la mani'a × 1
        items.add(AzkarItem(
            "لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، اللَّهُمَّ لاَ مَانِعَ لِمَا أَعْطَيْتَ، وَلاَ مُعْطِيَ لِمَا مَنَعْتَ، وَلاَ يَنْفَعُ ذَا الْجَدِّ مِنْكَ الْجَدُّ",
            1
        ))

        // 4. La ilaha illallah + La hawla × 1
        items.add(AzkarItem(
            "لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، لاَ حَوْلَ وَلاَ قُوَّةَ إِلاَّ بِاللَّهِ، لاَ إِلَهَ إِلاَّ اللَّهُ، وَلاَ نَعْبُدُ إِلاَّ إِيَّاهُ، لَهُ النِّعْمَةُ وَلَهُ الْفَضْلُ وَلَهُ الثَّنَاءُ الحَسَنُ، لاَ إِلَهَ إِلاَّ اللَّهُ مُخْلِصِينَ لَهُ الدِّينَ وَلَوْ كَرِهَ الْكَافِرُونَ",
            1
        ))

        // 5–7. Tasbeeh × 33 each
        items.add(AzkarItem("سُبْحَانَ اللَّهِ", 33))
        items.add(AzkarItem("الْحَمْدُ لِلَّهِ", 33))
        items.add(AzkarItem("اللَّهُ أَكْبَرُ", 33))

        // 8. Complete 100: La ilaha illallah × 1
        items.add(AzkarItem(
            "لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ",
            1
        ))

        // 9. Ayat al-Kursi × 1
        items.add(AzkarItem(
            "اللَّهُ لاَ إِلَهَ إِلاَّ هُوَ الْحَيُّ الْقَيُّومُ، لاَ تَأْخُذُهُ سِنَةٌ وَلاَ نَوْمٌ، لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الأَرْضِ، مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلاَّ بِإِذْنِهِ، يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ، وَلاَ يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلاَّ بِمَا شَاءَ، وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالأَرْضَ، وَلاَ يَؤُودُهُ حِفْظُهُمَا، وَهُوَ الْعَلِيُّ الْعَظِيمُ",
            1
        ))

        // 10–12. 3 Quls — ×1 normally, ×3 after Fajr & Maghrib
        items.add(AzkarItem(
            "قُلْ هُوَ اللَّهُ أَحَدٌ ۞ اللَّهُ الصَّمَدُ ۞ لَمْ يَلِدْ وَلَمْ يُولَدْ ۞ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ",
            qulsCount
        ))
        items.add(AzkarItem(
            "قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۞ مِن شَرِّ مَا خَلَقَ ۞ وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ ۞ وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۞ وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ",
            qulsCount
        ))
        items.add(AzkarItem(
            "قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۞ مَلِكِ النَّاسِ ۞ إِلَهِ النَّاسِ ۞ مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۞ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۞ مِنَ الْجِنَّةِ وَالنَّاسِ",
            qulsCount
        ))

        // 13. After Fajr & Maghrib: La ilaha illallah + yuhyi wa yumit × 10
        if (isFajrOrMaghrib) {
            items.add(AzkarItem(
                "لاَ إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لاَ شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ يُحْيِي وَيُمِيتُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ",
                10
            ))
        }

        // 14. After Fajr only: Dua for beneficial knowledge × 1
        if (prayerName == "Fajr") {
            items.add(AzkarItem(
                "اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَرِزْقًا طَيِّبًا، وَعَمَلاً مُتَقَبَّلاً",
                1
            ))
        }
    }

    // ── UI ────────────────────────────────────────────────────────────────────

    private fun setupUI() {
        // Header text
        findViewById<TextView>(R.id.azkarTitle).text =
            if (isArabic) "أذكار بعد الصلاة" else "Post-Prayer Azkar"
        findViewById<TextView>(R.id.azkarPrayerName).text =
            if (isArabic) "بعد صلاة $prayerNameAr" else "After $prayerName prayer"

        // Dismiss
        findViewById<Button>(R.id.btnAzkarDismiss).setOnClickListener { finish() }

        // Build item cards
        val container = findViewById<LinearLayout>(R.id.azkarContainer)
        container.removeAllViews()
        items.forEachIndexed { idx, item -> container.addView(buildItemCard(idx, item)) }

        // Completion banner appended inside the scroll container
        val completeBanner = TextView(this).apply {
            id = View.generateViewId()
            text = if (isArabic) "بارك الله فيك ✨" else "Barak Allah feek ✨"
            textSize = 20f
            setTextColor(0xFF00C853.toInt())
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            visibility = View.GONE
            setPadding(0, dp(20), 0, dp(8))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            tag = "complete_banner"
        }
        container.addView(completeBanner)

        updateProgress()
    }

    private fun buildItemCard(idx: Int, item: AzkarItem): View {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(14), dp(12), dp(14), dp(12))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(14).toFloat()
                setColor(0x22FFFFFF)
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { setMargins(0, if (idx == 0) 0 else dp(10), 0, 0) }
        }

        // Arabic zikr text (right side, RTL)
        val textTv = TextView(this).apply {
            text = item.textAr
            textSize = 15f
            setTextColor(0xFFFFFFFF.toInt())
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            textDirection = View.TEXT_DIRECTION_RTL
            gravity = Gravity.END or Gravity.CENTER_VERTICAL
            setPadding(dp(8), 0, 0, 0)
            setLineSpacing(0f, 1.45f)
        }

        // Right badge: count or ✓
        val badgeTv = TextView(this).apply {
            updateBadge(this, item)
            gravity = Gravity.CENTER
            minWidth = dp(52)
        }

        card.addView(badgeTv)
        card.addView(textTv)

        card.setOnClickListener {
            if (!item.isDone) {
                item.count++
                vibrate()
                updateBadge(badgeTv, item)
                updateProgress()
                if (item.isDone) checkAllComplete()
            }
        }

        return card
    }

    private fun updateBadge(tv: TextView, item: AzkarItem) {
        if (item.isDone) {
            tv.text = "✓"
            tv.textSize = 20f
            tv.setTextColor(0xFF00C853.toInt())
            tv.typeface = Typeface.DEFAULT_BOLD
        } else if (item.target == 1) {
            tv.text = "اضغط"
            tv.textSize = 11f
            tv.setTextColor(0xFFF5B301.toInt())
            tv.typeface = Typeface.DEFAULT
        } else {
            tv.text = "${item.count}\n——\n${item.target}"
            tv.textSize = 13f
            tv.setTextColor(0xFFF5B301.toInt())
            tv.typeface = Typeface.DEFAULT_BOLD
        }
    }

    private fun updateProgress() {
        val done  = items.count { it.isDone }
        val total = items.size
        val tv = findViewById<TextView>(R.id.azkarProgressText)
        tv.text = if (isArabic) "$total / $done أذكار" else "$done / $total azkar"
    }

    private fun checkAllComplete() {
        if (items.all { it.isDone }) {
            val container = findViewById<LinearLayout>(R.id.azkarContainer)
            for (i in 0 until container.childCount) {
                val v = container.getChildAt(i)
                if (v.tag == "complete_banner") { v.visibility = View.VISIBLE; break }
            }
            Log.d(TAG, "✅ [AZKAR] All azkar completed for $prayerName")
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun vibrate() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createOneShot(35, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(35)
            }
        } catch (_: Exception) { }
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    private fun setupFullScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try { setTurnScreenOn(true); setShowWhenLocked(true) }
            catch (_: Exception) { setupWindowFlags() }
        } else setupWindowFlags()
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

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "📱 [AZKAR] Activity destroyed")
    }
}
