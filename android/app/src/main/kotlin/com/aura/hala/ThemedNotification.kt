package com.aura.hala

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.util.Log
import androidx.core.content.res.ResourcesCompat

/**
 * Shared rules for notifications that follow the APP theme and language (not the phone's): the theme rule, the
 * app language, the 4-layout pick (light/dark x LTR/RTL), the per-prayer icon, and one entry point that
 * re-applies theme/language to everything that is showing. Spec: docs/designs/fix-themed-notifications.md (T0, T1).
 *
 * Theme comes from the Flutter pref `theme_mode` (FlutterPrefs), language from `language` in `aura_prayer_times`;
 * both are written by Dart before it calls the `updatePrayerWidgets` bridge, which ends in [refreshAll].
 */
object ThemedNotification {
    private const val TAG = "ThemedNotification"

    /** dark / amoled = dark, light = light, anything else (system) follows the phone. */
    fun isDark(themeMode: String, systemNight: Boolean): Boolean = when (themeMode) {
        "dark", "amoled" -> true
        "light" -> false
        else -> systemNight
    }

    fun isDark(context: Context): Boolean {
        val night = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        return isDark(FlutterPrefs.getString(context, "theme_mode", "system"), night)
    }

    fun isArabic(context: Context): Boolean =
        (context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE).getString("language", "en") ?: "en") == "ar"

    /** Western digits to Eastern Arabic numerals; every other character stays (CLAUDE.md: numbers in Arabic UI). */
    fun withArabicNumerals(input: String): String =
        input.map { c -> if (c in '0'..'9') ('\u0660' + (c - '0')) else c }.joinToString("")

    /** One of four layout ids for the current theme and language. */
    fun pickLayout(dark: Boolean, isArabic: Boolean, light: Int, darkLayout: Int, lightRtl: Int, darkRtl: Int): Int = when {
        dark && isArabic -> darkRtl
        dark -> darkLayout
        isArabic -> lightRtl
        else -> light
    }

    /** Per-prayer icon (mapping: [PostCheckActions.iconKey], same as the Next Prayer card), 128 px bitmap. */
    fun iconBitmap(context: Context, prayerName: String): Bitmap? {
        val iconRes = when (PostCheckActions.iconKey(prayerName)) {
            "fajr" -> R.drawable.ic_prayer_fajr
            "dhuhr" -> R.drawable.ic_prayer_dhuhr
            "afternoon" -> R.drawable.ic_prayer_afternoon
            "maghrib" -> R.drawable.ic_prayer_maghrib
            "isha" -> R.drawable.ic_prayer_isha
            else -> R.drawable.ic_mosque
        }
        return try {
            ResourcesCompat.getDrawable(context.resources, iconRes, null)?.let { d ->
                val bmp = Bitmap.createBitmap(128, 128, Bitmap.Config.ARGB_8888)
                d.setBounds(0, 0, 128, 128)
                d.draw(Canvas(bmp))
                bmp
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ icon load failed: ${e.message}")
            null
        }
    }

    /**
     * Theme or language changed in the app: re-post every themed notification that is showing. Each family adds one
     * line here. Called from the `updatePrayerWidgets` handler in MainActivity (Dart already calls it on change).
     */
    fun refreshAll(context: Context) {
        PostCheckCard.refreshShowing(context)
        TaskReminderCard.refreshShowing(context)
        DailySummaryCard.refreshShowing(context)
        NativeReminderCard.refreshShowing(context)
        PrayerForegroundService.getInstance()?.refreshNotification()
    }
}
