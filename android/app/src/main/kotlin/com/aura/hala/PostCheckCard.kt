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
import android.os.Bundle
import android.util.Log
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
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

    /** P2b card: plain LinearLayout like notification_actions*.xml, all four buttons, same view collapsed and expanded. */
    fun cardLayoutId(dark: Boolean, isArabic: Boolean): Int = when {
        dark && isArabic -> R.layout.notification_post_check_card_dark_rtl
        dark -> R.layout.notification_post_check_card_dark
        isArabic -> R.layout.notification_post_check_card_rtl
        else -> R.layout.notification_post_check_card
    }

    private const val EXTRA_NAME = "aura_post_check_name"
    private const val EXTRA_NAME_AR = "aura_post_check_name_ar"
    private const val EXTRA_TIME = "aura_post_check_time"

    /**
     * Builds and posts the post-check card (id 6001-6006, channel post_prayer_check). P2b/P2c: ongoing, PRIORITY_MAX,
     * VISIBILITY_PUBLIC, plain LinearLayout (notification_actions style, shows on the EMUI lock screen), same view
     * collapsed and expanded, four buttons, auto-removed after [PostCheckActions.TIMEOUT_MS]. Category stays REMINDER
     * (ALARM would pass Do Not Disturb). Every button cancels the card (PrayerAlarmReceiver).
     *
     * [keepWhen] != null means a refresh of a card that is already showing: same id, no new sound or heads-up
     * (setOnlyAlertOnce), the original `when`, and only the REMAINING timeout.
     */
    fun show(context: Context, prayerName: String, prayerNameAr: String, prayerTime: Long, keepWhen: Long?) {
        val isArabic = isArabic(context)
        val prayerLabel = if (isArabic) prayerNameAr else prayerName
        val title = PostCheckActions.question(prayerLabel, isArabic)
        val body = PostCheckActions.subtitle(isArabic)
        val notificationId = PrayerAlarmReceiver.getPostCheckNotificationId(prayerName)
        val nowMs = System.currentTimeMillis()
        val whenMs = keepWhen ?: nowMs
        val timeout = PostCheckActions.remainingTimeoutMs(whenMs, nowMs)
        if (timeout <= 0L) {
            NotificationManagerCompat.from(context).cancel(notificationId)
            Log.d(TAG, "📋 [POST_CHECK] refresh skipped for $prayerName: timeout already over, card removed")
            return
        }

        val view = RemoteViews(context.packageName, cardLayoutId(isDark(context), isArabic))
        view.setTextViewText(R.id.post_check_title, title)
        view.setTextViewText(R.id.post_check_body, body)
        iconBitmap(context, prayerName)?.let { view.setImageViewBitmap(R.id.post_check_icon, it) }
        for (spec in PostCheckActions.ALL) {
            val viewId = when (spec.key) {
                "done" -> R.id.btn_done
                "late" -> R.id.btn_late
                "missed" -> R.id.btn_missed
                else -> R.id.btn_remind_later
            }
            view.setTextViewText(viewId, PostCheckActions.label(spec, isArabic))
            view.setOnClickPendingIntent(viewId, actionPending(context, spec, prayerName, prayerNameAr, prayerTime))
        }

        val extras = Bundle().apply {
            putString(EXTRA_NAME, prayerName)
            putString(EXTRA_NAME_AR, prayerNameAr)
            putLong(EXTRA_TIME, prayerTime)
        }
        val builder = NotificationCompat.Builder(context, PostCheckActions.CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setCustomContentView(view)
            .setCustomBigContentView(view)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setWhen(whenMs)
            .setTimeoutAfter(timeout)
            .addExtras(extras)
            .setContentIntent(popupPending(context, prayerName, prayerNameAr, prayerTime))

        try {
            NotificationManagerCompat.from(context).notify(notificationId, builder.build())
            Log.d(TAG, "📋 [POST_CHECK] Notification ${if (keepWhen == null) "shown" else "refreshed"} for $prayerName")
        } catch (e: Exception) {
            Log.e(TAG, "❌ [POST_CHECK] Error showing notification: ${e.message}")
        }
    }

    /**
     * Theme or language changed in the app (the Dart side calls updatePrayerWidgets, which ends here): re-post every
     * post-check card that is on screen and has a different look from what the current theme/language would pick.
     * No new prefs key, channel or method. Cards that already look right are left alone.
     */
    fun refreshShowing(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val wanted = cardLayoutId(isDark(context), isArabic(context))
            for (sbn in nm.activeNotifications) {
                if (sbn.packageName != context.packageName || !PostCheckActions.isPostCheckId(sbn.id)) continue
                val n = sbn.notification
                if (n.contentView?.layoutId == wanted) continue
                val name = n.extras.getString(EXTRA_NAME) ?: continue
                val nameAr = n.extras.getString(EXTRA_NAME_AR) ?: name
                val time = n.extras.getLong(EXTRA_TIME)
                Log.d(TAG, "📋 [POST_CHECK] look changed, refreshing card ${sbn.id}")
                show(context, name, nameAr, time, n.`when`)
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ [POST_CHECK] refreshShowing failed: ${e.message}")
        }
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
