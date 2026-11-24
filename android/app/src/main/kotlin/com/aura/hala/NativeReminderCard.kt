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
 * Themed card for the Flutter-scheduled notifications that [NativeNotificationReceiver] posts: Wird reminders, the
 * daily task digest and the legacy prayer reminder (two buttons, only when a prayer name is attached). Follows the
 * APP theme; button labels follow the app language. The title and body are built by Dart when it schedules, so they
 * follow a language change only when Dart reschedules (spec limit). Spec: docs/designs/fix-themed-notifications.md (T4).
 */
object NativeReminderCard {
    private const val TAG = "NativeNotifReceiver"

    private const val EXTRA_MARK = "aura_native_card"
    private const val EXTRA_TITLE = "aura_native_card_title"
    private const val EXTRA_BODY = "aura_native_card_body"
    private const val EXTRA_CHANNEL_ID = "aura_native_card_channel"
    private const val EXTRA_CHANNEL_NAME = "aura_native_card_channel_name"
    private const val EXTRA_TAP_TAB = "aura_native_card_tab"
    private const val EXTRA_PRAYER_NAME = "aura_native_card_prayer"
    private const val EXTRA_PRAYER_TIME = "aura_native_card_prayer_time"
    private const val EXTRA_KIND = "aura_native_card_kind"
    private const val EXTRA_COUNT_A = "aura_native_card_count_a"
    private const val EXTRA_COUNT_B = "aura_native_card_count_b"

    /** Text kinds Dart can send instead of finished text (Kotlin then builds both languages, live). */
    const val KIND_WIRD = "wird"
    const val KIND_DIGEST = "digest"

    /** Full text on the lock screen (same decision as the daily summary card). */
    const val VISIBILITY = NotificationCompat.VISIBILITY_PUBLIC

    // Request codes and ids are unchanged from before T4
    fun tapRequestCode(notificationId: Int): Int = notificationId + 1
    fun prayedRequestCode(notificationId: Int): Int = notificationId + 2
    fun againRequestCode(notificationId: Int): Int = notificationId + 3
    fun remindAgainNotificationId(notificationId: Int): Int = notificationId + 5000

    /** Creates the channel if it does not exist yet (the receiver and the dev "Test digest" fire without Dart). */
    fun ensureChannel(context: Context, channelId: String, channelName: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            if (nm.getNotificationChannel(channelId) == null) {
                nm.createNotificationChannel(
                    android.app.NotificationChannel(channelId, channelName, android.app.NotificationManager.IMPORTANCE_HIGH)
                )
            }
        }
    }

    fun hasButtons(prayerName: String?): Boolean = !prayerName.isNullOrBlank()

    fun markPrayedLabel(isArabic: Boolean): String = if (isArabic) "أديت الصلاة" else "Mark as Prayed"
    fun remindAgainLabel(isArabic: Boolean): String = if (isArabic) "ذكرني مرة أخرى" else "Remind Me Again"

    /** Title for a kind; any other kind (or none: alarms armed before T4) keeps the text Dart sent. */
    fun titleFor(kind: String?, fallback: String, isArabic: Boolean): String = when (kind) {
        KIND_WIRD -> if (isArabic) "تذكير الورد" else "Wird Reminder"
        KIND_DIGEST -> if (isArabic) "ملخص مهامك اليوم" else "Today's Tasks"
        else -> fallback
    }

    private fun pages(a: Int, isArabic: Boolean): String =
        if (isArabic) ArabicCount.pages(a) else "$a ${if (a == 1) "page" else "pages"}"

    private fun tasks(a: Int, isArabic: Boolean): String =
        if (isArabic) ArabicCount.tasks(a) else "$a ${if (a == 1) "task" else "tasks"}"

    /** Body for a kind: wird = [a] pages; digest = [a] tasks today and [b] overdue. */
    fun bodyFor(kind: String?, a: Int, b: Int, fallback: String, isArabic: Boolean): String = when (kind) {
        KIND_WIRD ->
            if (isArabic) "اقرأ وردك اليومي — ${ArabicCount.pages(a)} اليوم" else "Read your daily Wird — ${pages(a, false)} today"
        KIND_DIGEST -> when {
            a > 0 && b > 0 ->
                if (isArabic) "${ArabicCount.tasks(a)} اليوم · ${ArabicCount.overdueTasks(b)}" else "${tasks(a, false)} today · $b overdue"
            a > 0 ->
                if (isArabic) "لديك ${ArabicCount.tasks(a)} اليوم — ابدأ يومك!" else "You have ${tasks(a, false)} today — let's go!"
            else ->
                if (isArabic) "يوم نظيف! لا مهام اليوم 🎉" else "Clean day! No tasks due today 🎉"
        }
        else -> fallback
    }

    /** Body of the "Remind Me Again" re-post; the Arabic digit goes through the Arabic numerals rule. */
    fun remindAgainBody(isArabic: Boolean): String =
        if (isArabic) "الصلاة بعد ${ThemedNotification.withArabicNumerals("5")} دقائق" else "Prayer in 5 minutes"

    /**
     * Ongoing (EMUI hides a dismissible card from the lock screen after an unlock), so it goes away by itself at the
     * end of the day, at least one minute from now; a tap or a button also removes it.
     */
    fun timeoutAfterMs(nowMs: Long, endOfDayMs: Long): Long = maxOf(60_000L, endOfDayMs - nowMs)

    private fun endOfToday(): Long = java.util.Calendar.getInstance().apply {
        set(java.util.Calendar.HOUR_OF_DAY, 23); set(java.util.Calendar.MINUTE, 59)
        set(java.util.Calendar.SECOND, 59); set(java.util.Calendar.MILLISECOND, 999)
    }.timeInMillis

    fun layoutId(dark: Boolean, isArabic: Boolean): Int = ThemedNotification.pickLayout(
        dark, isArabic,
        R.layout.notification_native_reminder, R.layout.notification_native_reminder_dark,
        R.layout.notification_native_reminder_rtl, R.layout.notification_native_reminder_dark_rtl
    )

    /** [keepWhen] != null: refresh of a card that is showing (same id, no new sound, original `when`). */
    fun show(
        context: Context,
        notificationId: Int,
        title: String,
        body: String,
        channelId: String,
        channelName: String,
        tapTab: Int,
        isArabic: Boolean,
        prayerName: String?,
        prayerTimeMs: Long,
        kind: String?,
        countA: Int,
        countB: Int,
        keepWhen: Long?
    ) {
        val appArabic = ThemedNotification.isArabic(context)
        val dark = ThemedNotification.isDark(context)

        val tapIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("widget_target_tab", tapTab)
        }
        val tapPending = PendingIntent.getActivity(
            context, tapRequestCode(notificationId), tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val view = RemoteViews(context.packageName, layoutId(dark, appArabic))
        // A kind means the text is built here in the app language (live); no kind = the text Dart sent
        val titleShown = titleFor(kind, title, appArabic)
        val bodyShown = bodyFor(kind, countA, countB, body, appArabic)
        view.setTextViewText(R.id.native_reminder_title, titleShown)
        view.setTextViewText(R.id.native_reminder_body, bodyShown)
        // Explicit in both cases: a refresh re-applies on the view that is showing (see TaskReminderCard)
        if (hasButtons(prayerName)) {
            val prayedIntent = Intent(context, NativeNotificationReceiver::class.java).apply {
                action = NativeNotificationReceiver.ACTION_MARK_PRAYED
                putExtra(NativeNotificationReceiver.EXTRA_NOTIFICATION_ID, notificationId)
                putExtra(NativeNotificationReceiver.EXTRA_PRAYER_NAME, prayerName)
            }
            val prayedPending = PendingIntent.getBroadcast(
                context, prayedRequestCode(notificationId), prayedIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val againIntent = Intent(context, NativeNotificationReceiver::class.java).apply {
                action = NativeNotificationReceiver.ACTION_REMIND_AGAIN
                putExtra(NativeNotificationReceiver.EXTRA_NOTIFICATION_ID, notificationId)
                putExtra(NativeNotificationReceiver.EXTRA_TITLE, title)
                putExtra(NativeNotificationReceiver.EXTRA_CHANNEL_ID, channelId)
                putExtra(NativeNotificationReceiver.EXTRA_CHANNEL_NAME, channelName)
                putExtra(NativeNotificationReceiver.EXTRA_TAP_TAB, tapTab)
                putExtra(NativeNotificationReceiver.EXTRA_IS_ARABIC, isArabic)
                putExtra(NativeNotificationReceiver.EXTRA_PRAYER_TIME_MS, prayerTimeMs)
                putExtra(NativeNotificationReceiver.EXTRA_PRAYER_NAME, prayerName)
            }
            val againPending = PendingIntent.getBroadcast(
                context, againRequestCode(notificationId), againIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            view.setViewVisibility(R.id.native_reminder_buttons, View.VISIBLE)
            view.setTextViewText(R.id.btn_native_primary, markPrayedLabel(appArabic))
            view.setOnClickPendingIntent(R.id.btn_native_primary, prayedPending)
            view.setTextViewText(R.id.btn_native_secondary, remindAgainLabel(appArabic))
            view.setOnClickPendingIntent(R.id.btn_native_secondary, againPending)
        } else {
            view.setViewVisibility(R.id.native_reminder_buttons, View.GONE)
        }

        val extras = Bundle().apply {
            putBoolean(EXTRA_MARK, true)
            putString(EXTRA_TITLE, title)
            putString(EXTRA_BODY, body)
            putString(EXTRA_CHANNEL_ID, channelId)
            putString(EXTRA_CHANNEL_NAME, channelName)
            putInt(EXTRA_TAP_TAB, tapTab)
            putString(EXTRA_PRAYER_NAME, prayerName ?: "")
            putLong(EXTRA_PRAYER_TIME, prayerTimeMs)
            putString(EXTRA_KIND, kind ?: "")
            putInt(EXTRA_COUNT_A, countA)
            putInt(EXTRA_COUNT_B, countB)
        }
        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(titleShown)
            .setContentText(bodyShown)
            .setCustomContentView(view)
            .setCustomBigContentView(view)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(VISIBILITY)
            .setOngoing(true)
            .setAutoCancel(true)
            .setTimeoutAfter(timeoutAfterMs(System.currentTimeMillis(), endOfToday()))
            .setOnlyAlertOnce(keepWhen != null)
            .addExtras(extras)
            .setContentIntent(tapPending)
        if (keepWhen != null) builder.setWhen(keepWhen)

        try {
            NotificationManagerCompat.from(context).notify(notificationId, builder.build())
            Log.d(TAG, "✅ Posted id=$notificationId${if (keepWhen != null) " (refreshed)" else ""}")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error posting notification: ${e.message}")
        }
    }

    /** Theme or language changed in the app (ThemedNotification.refreshAll): re-post every native card that is showing. */
    fun refreshShowing(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            val wanted = layoutId(ThemedNotification.isDark(context), ThemedNotification.isArabic(context))
            for (sbn in nm.activeNotifications) {
                if (sbn.packageName != context.packageName) continue
                val n = sbn.notification
                if (!n.extras.getBoolean(EXTRA_MARK, false)) continue
                Log.d(TAG, "📋 native card ${sbn.id}: layout=${n.contentView?.layoutId} wanted=$wanted")
                if (n.contentView?.layoutId == wanted) continue
                val title = n.extras.getString(EXTRA_TITLE) ?: continue
                Log.d(TAG, "📋 look changed, refreshing native card ${sbn.id}")
                show(
                    context, sbn.id, title, n.extras.getString(EXTRA_BODY) ?: "",
                    n.extras.getString(EXTRA_CHANNEL_ID) ?: "task_reminders",
                    n.extras.getString(EXTRA_CHANNEL_NAME) ?: "Reminders",
                    n.extras.getInt(EXTRA_TAP_TAB, 0),
                    ThemedNotification.isArabic(context),
                    n.extras.getString(EXTRA_PRAYER_NAME)?.takeIf { it.isNotEmpty() },
                    n.extras.getLong(EXTRA_PRAYER_TIME, 0L),
                    n.extras.getString(EXTRA_KIND)?.takeIf { it.isNotEmpty() },
                    n.extras.getInt(EXTRA_COUNT_A, 0), n.extras.getInt(EXTRA_COUNT_B, 0),
                    n.`when`
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ refreshShowing failed: ${e.message}")
        }
    }
}
