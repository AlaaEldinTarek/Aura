package com.aura.hala

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.util.Log
import androidx.core.content.res.ResourcesCompat

/**
 * Android-side helpers shared by the post-prayer check notification (PrayerAlarmReceiver) and the tap popup
 * (PostCheckPopupActivity): same theme / language / layout / icon pick and the same action PendingIntents
 * (request codes notificationId+1..+4), so a popup button is exactly a notification button.
 * Spec: docs/designs/fix-post-check-remind-later.md (R1c, R1e).
 */
object PostCheckCard {
    private const val TAG = "PostCheckCard"

    /** Creates the post-check channel (IMPORTANCE_HIGH) if missing; safe to call every time. Importance cannot be raised later. */
    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(PostCheckActions.CHANNEL_ID) != null) return
            val ch = NotificationChannel(
                PostCheckActions.CHANNEL_ID, "Prayer Check", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Asks if you prayed after prayer time passes"
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            nm.createNotificationChannel(ch)
            Log.d(TAG, "✅ [CHANNEL] ${PostCheckActions.CHANNEL_ID} created (importance high)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ [CHANNEL] ${PostCheckActions.CHANNEL_ID} create failed: ${e.message}")
        }
    }

    fun isArabic(context: Context): Boolean =
        (context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE).getString("language", "en") ?: "en") == "ar"

    /** App theme pick (the same rule as the foreground Next Prayer card); system follows the phone. */
    fun isDark(context: Context): Boolean {
        val night = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        return PostCheckActions.isDark(FlutterPrefs.getString(context, "theme_mode", "system"), night)
    }

    fun layoutId(dark: Boolean, isArabic: Boolean): Int = when {
        dark && isArabic -> R.layout.notification_post_check_dark_rtl
        dark -> R.layout.notification_post_check_dark
        isArabic -> R.layout.notification_post_check_rtl
        else -> R.layout.notification_post_check
    }

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
            Log.e(TAG, "❌ [POST_CHECK] icon load failed: ${e.message}")
            null
        }
    }

    /** The action PendingIntent: broadcast to PrayerAlarmReceiver, request code notificationId + spec offset. */
    fun actionPending(
        context: Context,
        spec: PostCheckActions.Spec,
        prayerName: String,
        prayerNameAr: String,
        prayerTime: Long
    ): PendingIntent {
        val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            action = spec.action
            putExtra(PrayerAlarmReceiver.EXTRA_PRAYER_NAME, prayerName)
            putExtra(PrayerAlarmReceiver.EXTRA_PRAYER_NAME_AR, prayerNameAr)
            putExtra(PrayerAlarmReceiver.EXTRA_PRAYER_TIME, prayerTime)
        }
        return PendingIntent.getBroadcast(
            context,
            PostCheckActions.requestCode(PrayerAlarmReceiver.getPostCheckNotificationId(prayerName), spec),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** Tapping the card body opens the small popup (not MainActivity); request code notificationId + 5. */
    fun popupPending(context: Context, prayerName: String, prayerNameAr: String, prayerTime: Long): PendingIntent {
        val intent = Intent(context, PostCheckPopupActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra(PrayerAlarmReceiver.EXTRA_PRAYER_NAME, prayerName)
            putExtra(PrayerAlarmReceiver.EXTRA_PRAYER_NAME_AR, prayerNameAr)
            putExtra(PrayerAlarmReceiver.EXTRA_PRAYER_TIME, prayerTime)
        }
        return PendingIntent.getActivity(
            context,
            PostCheckActions.contentRequestCode(PrayerAlarmReceiver.getPostCheckNotificationId(prayerName)),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
