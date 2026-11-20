package com.aura.hala

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Daily prayer summary (id 7001, channel `prayer_tracking`) as a themed card: logo, title, body; tap opens Prayer
 * Tracking (unchanged). Follows the APP theme and language, and re-applies both live because the text is built here
 * from the stored count. Spec: docs/designs/fix-themed-notifications.md (T3).
 */
object DailySummaryCard {
    private const val TAG = "DailySummaryReceiver"
    const val NOTIFICATION_ID = 7001
    const val CHANNEL_ID = "prayer_tracking"

    private const val EXTRA_MARK = "aura_daily_summary_card"
    private const val EXTRA_COUNT = "aura_daily_summary_count"

    fun tapRequestCode(): Int = NOTIFICATION_ID

    fun title(isArabic: Boolean): String = if (isArabic) "تذكير الصلاة اليومي" else "Daily Prayer Reminder"

    /** Lock-screen version: no count, only that a reminder exists. */
    fun publicTitle(isArabic: Boolean): String =
        if (isArabic) "هالة - تذكير الصلاة اليومي" else "Aura - Daily Prayer Reminder"

    /** Arabic count goes through the Arabic numerals rule (CLAUDE.md); wording is unchanged from before T3. */
    fun body(count: Int, isArabic: Boolean): String =
        if (isArabic) {
            "لديك ${ThemedNotification.withArabicNumerals(count.toString())} ${if (count == 1) "صلاة" else "صلوات"} لم تُسجَّل اليوم"
        } else {
            "You have $count untracked ${if (count == 1) "prayer" else "prayers"} today"
        }

    fun layoutId(dark: Boolean, isArabic: Boolean): Int = ThemedNotification.pickLayout(
        dark, isArabic,
        R.layout.notification_daily_summary, R.layout.notification_daily_summary_dark,
        R.layout.notification_daily_summary_rtl, R.layout.notification_daily_summary_dark_rtl
    )

    /** [keepWhen] != null: refresh of a card that is showing (same id, no new sound, original `when`). */
    fun show(context: Context, count: Int, keepWhen: Long?) {
        val isArabic = ThemedNotification.isArabic(context)
        val dark = ThemedNotification.isDark(context)
        val titleText = title(isArabic)
        val bodyText = body(count, isArabic)

        val tapIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("route", "/prayer_tracking")
        }
        val tapPending = PendingIntent.getActivity(
            context, tapRequestCode(), tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        fun buildCard(publicVersion: Boolean): RemoteViews {
            val view = RemoteViews(context.packageName, layoutId(dark, isArabic))
            view.setTextViewText(R.id.daily_summary_title, if (publicVersion) publicTitle(isArabic) else titleText)
            view.setTextViewText(R.id.daily_summary_body, bodyText)
            view.setViewVisibility(R.id.daily_summary_body, if (publicVersion) View.GONE else View.VISIBLE)
            return view
        }

        val view = buildCard(false)
        val publicView = buildCard(true)
        val publicNotification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(publicTitle(isArabic))
            .setCustomContentView(publicView)
            .setCustomBigContentView(publicView)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        val extras = Bundle().apply {
            putBoolean(EXTRA_MARK, true)
            putInt(EXTRA_COUNT, count)
        }
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(titleText)
            .setContentText(bodyText)
            .setCustomContentView(view)
            .setCustomBigContentView(view)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(publicNotification)
            .setAutoCancel(true)
            .setOnlyAlertOnce(keepWhen != null)
            .addExtras(extras)
            .setContentIntent(tapPending)
        if (keepWhen != null) builder.setWhen(keepWhen)

        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, builder.build())
            Log.d(TAG, "📅 Daily summary ${if (keepWhen == null) "shown" else "refreshed"}: $count untracked prayers")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to show daily summary: ${e.message}")
        }
    }

    /** Theme or language changed in the app (ThemedNotification.refreshAll): re-post the card if it is showing. */
    fun refreshShowing(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            val wanted = layoutId(ThemedNotification.isDark(context), ThemedNotification.isArabic(context))
            for (sbn in nm.activeNotifications) {
                if (sbn.packageName != context.packageName || sbn.id != NOTIFICATION_ID) continue
                val n = sbn.notification
                if (!n.extras.getBoolean(EXTRA_MARK, false)) continue
                if (n.contentView?.layoutId == wanted) continue
                Log.d(TAG, "📅 look changed, refreshing daily summary")
                show(context, n.extras.getInt(EXTRA_COUNT, 1), n.`when`)
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ refreshShowing failed: ${e.message}")
        }
    }
}
