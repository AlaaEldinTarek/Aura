package com.aura.hala

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Look of the weekly Jumu'ah reminder (id 8001, channel `jumuah_reminder`): a themed card with the app logo, a title,
 * and a live countdown to Zuhr (30:00 down to 0, ticked by the system UI) or, when today's Zuhr time is unknown, a calm
 * text. Follows the APP theme and language (text built here), re-applies both live while it shows, and the system
 * removes it at Zuhr (the azan takes over). Tap opens the Prayer tab. Spec: docs/designs/fix-themed-notifications.md (T7).
 */
object JumuahCard {
    private const val TAG = "JumuahReminder"
    const val NOTIFICATION_ID = 8001
    const val CHANNEL_ID = "jumuah_reminder"
    private const val TAP_REQUEST_CODE = 8003
    private const val PRAYER_TAB = 1

    /** Full text on the lock screen (nothing private on this card). */
    const val VISIBILITY = NotificationCompat.VISIBILITY_PUBLIC

    private const val MIN_MS = 60_000L
    /** The reminder fires 30 min before Zuhr; without a countdown the card goes away after the same half hour. */
    private const val NO_COUNTDOWN_TIMEOUT_MS = 30 * MIN_MS
    /** A Zuhr time further away than this is a stale value from another day: no countdown. */
    private const val MAX_COUNTDOWN_MS = 90 * MIN_MS

    private const val EXTRA_MARK = "aura_jumuah_card"
    private const val EXTRA_ZUHR = "aura_jumuah_card_zuhr"

    enum class Mode { COUNTDOWN, TEXT }

    fun title(isArabic: Boolean): String = if (isArabic) "جمعة مباركة 🕌" else "Jumu'ah Mubarak 🕌"

    fun fallbackBody(isArabic: Boolean): String =
        if (isArabic) "اقترب وقت صلاة الجمعة، لا تفوّتها" else "Friday prayer time is approaching. Don't miss it!"

    /** One timer slot (%s). The digits are the phone's own (Chronometer limit, same as the task card). */
    fun countdownFormat(isArabic: Boolean): String = if (isArabic) "الجمعة بعد %s" else "Jumu'ah in %s"

    fun countdownAvailable(zuhrMs: Long, nowMs: Long): Boolean =
        zuhrMs > nowMs && zuhrMs - nowMs <= MAX_COUNTDOWN_MS

    /** Chronometer base (SystemClock.elapsedRealtime timebase) for the Zuhr moment. */
    fun countdownBase(zuhrMs: Long, nowMs: Long, elapsedNowMs: Long): Long = elapsedNowMs + (zuhrMs - nowMs)

    /** The system removes the card at Zuhr (at least one second out), or after half an hour when there is no countdown. */
    fun timeoutAfterMs(zuhrMs: Long, nowMs: Long, countdown: Boolean): Long =
        if (countdown) maxOf(1_000L, zuhrMs - nowMs) else NO_COUNTDOWN_TIMEOUT_MS

    fun modeFor(countdown: Boolean): Mode = if (countdown) Mode.COUNTDOWN else Mode.TEXT

    /** Dev tile: a fake Zuhr half an hour ahead, so the card shows 30:00 on any day of the week. */
    fun testZuhrMs(nowMs: Long): Long = nowMs + 30 * MIN_MS

    fun layoutId(dark: Boolean, isArabic: Boolean): Int = ThemedNotification.pickLayout(
        dark, isArabic,
        R.layout.notification_jumuah, R.layout.notification_jumuah_dark,
        R.layout.notification_jumuah_rtl, R.layout.notification_jumuah_dark_rtl
    )

    /** Creates the channel (same id, name, importance and description as before) if missing. */
    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Jumu'ah Reminder", NotificationManager.IMPORTANCE_HIGH)
                .apply { description = "Weekly Friday prayer reminder" }
        )
    }

    /** [zuhrMs] = today's Zuhr (0 = unknown). [keepWhen] != null: refresh of a card that is showing (no new sound, same `when`). */
    fun show(context: Context, zuhrMs: Long, keepWhen: Long?) {
        val isArabic = ThemedNotification.isArabic(context)
        val nowMs = System.currentTimeMillis()
        val countdown = countdownAvailable(zuhrMs, nowMs)
        val titleText = title(isArabic)
        val bodyText = fallbackBody(isArabic)

        val tapIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("widget_target_tab", PRAYER_TAB)
        }
        val tapPending = PendingIntent.getActivity(
            context, TAP_REQUEST_CODE, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val view = RemoteViews(context.packageName, layoutId(ThemedNotification.isDark(context), isArabic))
        view.setTextViewText(R.id.jumuah_title, titleText)
        view.setTextViewText(R.id.jumuah_body, bodyText)
        // Both views are set explicitly in both modes (see TaskReminderCard): a re-post only touches what it sets.
        when (modeFor(countdown)) {
            Mode.COUNTDOWN -> {
                view.setViewVisibility(R.id.jumuah_body, View.GONE)
                view.setViewVisibility(R.id.jumuah_countdown, View.VISIBLE)
                view.setChronometerCountDown(R.id.jumuah_countdown, true)
                view.setChronometer(
                    R.id.jumuah_countdown,
                    countdownBase(zuhrMs, nowMs, SystemClock.elapsedRealtime()),
                    countdownFormat(isArabic), true
                )
            }
            Mode.TEXT -> {
                view.setViewVisibility(R.id.jumuah_countdown, View.GONE)
                view.setChronometer(R.id.jumuah_countdown, SystemClock.elapsedRealtime(), null, false)
                view.setViewVisibility(R.id.jumuah_body, View.VISIBLE)
            }
        }

        val extras = Bundle().apply {
            putBoolean(EXTRA_MARK, true)
            putLong(EXTRA_ZUHR, zuhrMs)
        }
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(titleText)
            .setContentText(bodyText)
            .setCustomContentView(view)
            .setCustomBigContentView(view)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(VISIBILITY)
            .setOngoing(true)
            .setAutoCancel(true)
            .setOnlyAlertOnce(keepWhen != null)
            .setTimeoutAfter(timeoutAfterMs(zuhrMs, nowMs, countdown))
            .addExtras(extras)
            .setContentIntent(tapPending)
        if (keepWhen != null) builder.setWhen(keepWhen)

        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, builder.build())
            Log.d(TAG, "✅ Jumu'ah card ${if (keepWhen == null) "shown" else "refreshed"} (${modeFor(countdown)})")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to show Jumu'ah card: ${e.message}")
        }
    }

    /** Theme or language changed in the app (ThemedNotification.refreshAll): re-post the card if it is showing. */
    fun refreshShowing(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val wanted = layoutId(ThemedNotification.isDark(context), ThemedNotification.isArabic(context))
            for (sbn in nm.activeNotifications) {
                if (sbn.packageName != context.packageName || sbn.id != NOTIFICATION_ID) continue
                val n = sbn.notification
                if (!n.extras.getBoolean(EXTRA_MARK, false)) continue
                if (n.contentView?.layoutId == wanted) continue
                Log.d(TAG, "🕌 look changed, refreshing Jumu'ah card")
                show(context, n.extras.getLong(EXTRA_ZUHR, 0L), n.`when`)
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ refreshShowing failed: ${e.message}")
        }
    }
}
