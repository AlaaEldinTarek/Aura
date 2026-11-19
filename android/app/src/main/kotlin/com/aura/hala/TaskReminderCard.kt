package com.aura.hala

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * The task reminder as a card that follows the app theme and language (spec docs/designs/fix-themed-notifications.md, T2):
 * plain LinearLayout (notification_task_reminder*.xml, 4 layouts), app icon, title, body and a custom Remind Later
 * button. Same notification id, same channel `task_reminders`, same snooze action and request codes as before
 * (tap id+1, snooze id+2). Dismissible, not ongoing. VISIBILITY_PRIVATE with a public version (same themed layout,
 * only "Aura - Task reminder", no task title, no button) so a locked phone never shows the task. Title and body
 * arrive ready-made from Dart (language at schedule time); only the layout and the button label follow a later
 * theme/language change.
 */
object TaskReminderCard {
    private const val TAG = "TaskReminderCard"

    // Kept in the notification's own extras so a live refresh can rebuild the card (no prefs key).
    private const val EXTRA_MARK = "aura_task_card"
    private const val EXTRA_TASK_ID = "aura_task_card_task_id"
    private const val EXTRA_TITLE = "aura_task_card_title"
    private const val EXTRA_BODY = "aura_task_card_body"

    fun tapRequestCode(notificationId: Int): Int = notificationId + 1

    fun snoozeRequestCode(notificationId: Int): Int = notificationId + 2

    fun snoozeLabel(isArabic: Boolean): String = if (isArabic) "ذكرني لاحقاً" else "Remind Later"

    /** The only text the locked screen shows (public version): no task title. */
    fun publicTitle(isArabic: Boolean): String = if (isArabic) "هالة - تذكير بمهمة" else "Aura - Task reminder"

    fun layoutId(dark: Boolean, isArabic: Boolean): Int = ThemedNotification.pickLayout(
        dark, isArabic,
        R.layout.notification_task_reminder, R.layout.notification_task_reminder_dark,
        R.layout.notification_task_reminder_rtl, R.layout.notification_task_reminder_dark_rtl
    )

    /**
     * Posts the card. [keepWhen] != null means a refresh of a card that is already showing: same id, no new sound
     * (setOnlyAlertOnce) and the original `when`.
     */
    fun show(context: Context, notificationId: Int, taskId: String, title: String, body: String, keepWhen: Long?) {
        val isArabic = ThemedNotification.isArabic(context)

        // Tap -> open the app on the Tasks tab (handleWidgetTabIntent reads this extra); unchanged
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("widget_target_tab", 3)
        }
        val tapPending = PendingIntent.getActivity(
            context, tapRequestCode(notificationId), tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Remind Later: the same broadcast the system action sent (action, extras, request code id+2); unchanged
        val snoozeIntent = Intent(context, TaskReminderReceiver::class.java).apply {
            action = TaskReminderReceiver.ACTION_SNOOZE
            putExtra(TaskReminderReceiver.EXTRA_NOTIFICATION_ID, notificationId)
            putExtra(TaskReminderReceiver.EXTRA_TASK_ID, taskId)
            putExtra(TaskReminderReceiver.EXTRA_TITLE, title)
            putExtra(TaskReminderReceiver.EXTRA_IS_ARABIC, isArabic)
        }
        val snoozePending = PendingIntent.getBroadcast(
            context, snoozeRequestCode(notificationId), snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val view = RemoteViews(context.packageName, layoutId(ThemedNotification.isDark(context), isArabic))
        view.setTextViewText(R.id.task_reminder_title, title)
        view.setTextViewText(R.id.task_reminder_body, body)
        view.setTextViewText(R.id.btn_task_remind_later, snoozeLabel(isArabic))
        view.setOnClickPendingIntent(R.id.btn_task_remind_later, snoozePending)

        // What the locked screen shows: the same themed card with only the generic title (no task, no button)
        val publicTitleText = publicTitle(isArabic)
        val publicView = RemoteViews(context.packageName, layoutId(ThemedNotification.isDark(context), isArabic))
        publicView.setTextViewText(R.id.task_reminder_title, publicTitleText)
        publicView.setViewVisibility(R.id.task_reminder_body, android.view.View.GONE)
        publicView.setViewVisibility(R.id.btn_task_remind_later, android.view.View.GONE)
        val publicNotification = NotificationCompat.Builder(context, TaskReminderReceiver.CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(publicTitleText)
            .setCustomContentView(publicView)
            .setCustomBigContentView(publicView)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        val extras = Bundle().apply {
            putBoolean(EXTRA_MARK, true)
            putString(EXTRA_TASK_ID, taskId)
            putString(EXTRA_TITLE, title)
            putString(EXTRA_BODY, body)
        }
        val builder = NotificationCompat.Builder(context, TaskReminderReceiver.CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setCustomContentView(view)
            .setCustomBigContentView(view)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(publicNotification)
            .setAutoCancel(true)
            .setOnlyAlertOnce(keepWhen != null)
            .addExtras(extras)
            .setContentIntent(tapPending)
        if (keepWhen != null) builder.setWhen(keepWhen)

        try {
            NotificationManagerCompat.from(context).notify(notificationId, builder.build())
            Log.d(TAG, "✅ Task reminder ${if (keepWhen == null) "posted" else "refreshed"} id=$notificationId")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error posting task reminder: ${e.message}")
        }
    }

    /**
     * Theme or language changed in the app (ThemedNotification.refreshAll): re-post every task reminder card that is
     * showing with a different look than the current theme/language would pick.
     */
    fun refreshShowing(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            val wanted = layoutId(ThemedNotification.isDark(context), ThemedNotification.isArabic(context))
            for (sbn in nm.activeNotifications) {
                if (sbn.packageName != context.packageName) continue
                val n = sbn.notification
                if (!n.extras.getBoolean(EXTRA_MARK, false)) continue
                if (n.contentView?.layoutId == wanted) continue
                val title = n.extras.getString(EXTRA_TITLE) ?: continue
                Log.d(TAG, "📋 look changed, refreshing task reminder ${sbn.id}")
                show(context, sbn.id, n.extras.getString(EXTRA_TASK_ID) ?: "", title, n.extras.getString(EXTRA_BODY) ?: "", n.`when`)
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ refreshShowing failed: ${e.message}")
        }
    }
}
