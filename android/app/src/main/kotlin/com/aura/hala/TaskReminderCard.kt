package com.aura.hala

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
 * The task reminder as a card that follows the app theme and language (spec docs/designs/fix-themed-notifications.md,
 * T2 / T2b): plain LinearLayout (notification_task_reminder*.xml, 4 layouts), the transparent Aura logo, title, body,
 * and two custom buttons, Done and Remind Later. Same notification id, same channel `task_reminders`; request codes
 * tap id+1, Remind Later id+2 (both unchanged), Done id+3 (new, same family). Dismissible, not ongoing.
 * VISIBILITY_PRIVATE with a public version (same themed layout, only "Aura - Task reminder", no task title, no
 * buttons) so a locked phone never shows the task.
 *
 * The title is the user's task title (from Dart). The body is built here from a kind (+ minutes) so it follows the
 * app language, with Arabic numerals, and changes on a live language refresh.
 */
object TaskReminderCard {
    private const val TAG = "TaskReminderCard"

    // Body kinds sent by Dart (scheduleNativeTaskReminder `bodyKind`) and by the Remind Later re-arm.
    const val BODY_DUE_NOW = "due_now"
    const val BODY_BEFORE = "before"
    const val BODY_TODAY = "today"
    const val BODY_PENDING = "pending"

    // Kept in the notification's own extras so a live refresh can rebuild the card (no prefs key).
    private const val EXTRA_MARK = "aura_task_card"
    private const val EXTRA_TASK_ID = "aura_task_card_task_id"
    private const val EXTRA_TITLE = "aura_task_card_title"
    private const val EXTRA_BODY = "aura_task_card_body"
    private const val EXTRA_BODY_KIND = "aura_task_card_body_kind"
    private const val EXTRA_BODY_MINUTES = "aura_task_card_body_minutes"
    private const val EXTRA_DUE_AT = "aura_task_card_due_at"

    /** Default of the user's "remind X minutes before" setting (`task_reminder_minutes`), also used when it is invalid. */
    const val DEFAULT_REMINDER_MINUTES = 30

    /** Remind Later waits as long as the user's task reminder setting says (read at the moment the button is pressed). */
    fun snoozeDelayMinutes(stored: Int): Int = if (stored < 1) DEFAULT_REMINDER_MINUTES else stored

    fun tapRequestCode(notificationId: Int): Int = notificationId + 1

    fun snoozeRequestCode(notificationId: Int): Int = notificationId + 2

    fun doneRequestCode(notificationId: Int): Int = notificationId + 3

    // Same wording as the post-check card (with shadda)
    /** The silent "due now" re-post at the due time (TC1): action TASK_DUE_NOW, same family as tap/snooze/done. */
    fun dueNowRequestCode(notificationId: Int): Int = notificationId + 4

    /** Live countdown (Chronometer) only for the "before" reminder and only while the due time is still ahead. */
    fun showsCountdown(kind: String?, dueAtMs: Long, nowMs: Long): Boolean =
        kind == BODY_BEFORE && dueAtMs > nowMs

    /** A "before" card whose due time has passed reads as "due now" (e.g. a theme refresh after the due time). */
    fun effectiveKind(kind: String?, dueAtMs: Long, nowMs: Long): String? =
        if (kind == BODY_BEFORE && dueAtMs in 1..nowMs) BODY_DUE_NOW else kind

    /**
     * Chronometer base (SystemClock.elapsedRealtime timebase) for the due moment. Recomputed from the absolute due
     * time on every (re)post, so a live theme/language refresh keeps the timer correct.
     */
    fun countdownBase(dueAtMs: Long, nowMs: Long, elapsedNowMs: Long): Long = elapsedNowMs + (dueAtMs - nowMs)

    /** One timer slot (%s): "Due in 04:32". The digits are the phone's own (Chronometer limit, see spec TC.3). */
    fun countdownFormat(isArabic: Boolean): String = if (isArabic) "موعد المهمة بعد %s" else "Due in %s"

    /**
     * The countdown card is removed by the system this long after the due time if the due-now repost never came, so
     * the card can never keep a negative time. The repost (normally within ~50 ms of the due time) replaces it.
     */
    const val COUNTDOWN_GRACE_MS = 2_000L

    /** An ongoing card that is already "due now" goes away this long after the due time (the in-app list keeps the task). */
    const val DUE_NOW_TIMEOUT_MS = 30L * 60 * 1000

    /**
     * Every post sets a timeout, because the card is ongoing (stays on the EMUI lock screen, cannot be swiped) and
     * must still go away: countdown = just after the due time (safety net), due now = [DUE_NOW_TIMEOUT_MS] after the
     * repost (so 30 min after the due time), today / pending / an alarm armed before TC1 = until the end of the day
     * ([endOfDayMs], at least one minute). A post without a timeout may not clear an earlier one (UNKNOWN), so each
     * post replaces it.
     */
    fun timeoutAfterMs(kind: String?, dueAtMs: Long, nowMs: Long, endOfDayMs: Long): Long = when (kind) {
        BODY_BEFORE -> maxOf(1_000L, dueAtMs - nowMs + COUNTDOWN_GRACE_MS)
        BODY_DUE_NOW -> DUE_NOW_TIMEOUT_MS
        else -> maxOf(60_000L, endOfDayMs - nowMs)
    }

    private fun endOfToday(): Long = java.util.Calendar.getInstance().apply {
        set(java.util.Calendar.HOUR_OF_DAY, 23); set(java.util.Calendar.MINUTE, 59)
        set(java.util.Calendar.SECOND, 59); set(java.util.Calendar.MILLISECOND, 999)
    }.timeInMillis

    enum class Mode { COUNTDOWN, TEXT }

    fun modeFor(countdown: Boolean): Mode = if (countdown) Mode.COUNTDOWN else Mode.TEXT

    fun snoozeLabel(isArabic: Boolean): String = if (isArabic) "ذكّرني لاحقاً" else "Remind Later"

    /** Arabic grammar: "دقائق" for 3-10, "دقيقة" for 1, 2 and 11+ (5 دقائق، 10 دقائق، 15 دقيقة، 60 دقيقة). */
    fun arabicMinutesUnit(minutes: Int): String = if (minutes in 3..10) "دقائق" else "دقيقة"

    fun doneLabel(isArabic: Boolean): String = if (isArabic) "إتمام" else "Done"

    /** The only text the locked screen shows (public version): no task title. */
    fun publicTitle(isArabic: Boolean): String = if (isArabic) "هالة - تذكير بمهمة" else "Aura - Task reminder"

    /**
     * Body text in the app language (wording of the old Dart notification). [kind] null or empty = an alarm scheduled
     * before this change: keep its ready-made [fallback] text.
     */
    fun bodyText(kind: String?, minutes: Int, isArabic: Boolean, fallback: String): String = when (kind) {
        BODY_DUE_NOW -> if (isArabic) "حان موعد المهمة الآن" else "Task is due now"
        BODY_BEFORE ->
            if (isArabic) "موعد المهمة بعد ${ThemedNotification.withArabicNumerals(minutes.toString())} ${arabicMinutesUnit(minutes)}"
            else "Task due in $minutes minutes"
        BODY_TODAY -> if (isArabic) "لديك مهمة مستحقة اليوم" else "You have a task due today"
        BODY_PENDING -> if (isArabic) "لا تزال المهمة معلقة" else "Your task is still pending"
        else -> fallback
    }

    /** `pending_complete_task_id` can hold several ids (comma separated) so a second Done does not overwrite the first. */
    fun addPendingDoneId(existing: String, taskId: String): String {
        val ids = existing.split(",").map { it.trim() }.filter { it.isNotEmpty() }.toMutableList()
        if (taskId.isNotBlank() && !ids.contains(taskId)) ids.add(taskId)
        return ids.joinToString(",")
    }

    fun layoutId(dark: Boolean, isArabic: Boolean): Int = ThemedNotification.pickLayout(
        dark, isArabic,
        R.layout.notification_task_reminder, R.layout.notification_task_reminder_dark,
        R.layout.notification_task_reminder_rtl, R.layout.notification_task_reminder_dark_rtl
    )

    /**
     * Posts the card. [keepWhen] != null means a refresh of a card that is already showing: same id, no new sound
     * (setOnlyAlertOnce) and the original `when`.
     */
    fun show(
        context: Context,
        notificationId: Int,
        taskId: String,
        title: String,
        body: String,
        bodyKind: String?,
        bodyMinutes: Int,
        dueAtMs: Long,
        keepWhen: Long?
    ) {
        val isArabic = ThemedNotification.isArabic(context)
        val dark = ThemedNotification.isDark(context)
        val nowMs = System.currentTimeMillis()
        val kind = effectiveKind(bodyKind, dueAtMs, nowMs)
        val countdown = showsCountdown(kind, dueAtMs, nowMs)
        val bodyShown = bodyText(kind, bodyMinutes, isArabic, body)

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

        // Done: completes the task (applied by the app on its next open, see TaskReminderReceiver) and removes the card
        val doneIntent = Intent(context, TaskReminderReceiver::class.java).apply {
            action = TaskReminderReceiver.ACTION_DONE
            putExtra(TaskReminderReceiver.EXTRA_NOTIFICATION_ID, notificationId)
            putExtra(TaskReminderReceiver.EXTRA_TASK_ID, taskId)
        }
        val donePending = PendingIntent.getBroadcast(
            context, doneRequestCode(notificationId), doneIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val view = RemoteViews(context.packageName, layoutId(dark, isArabic))
        view.setTextViewText(R.id.task_reminder_title, title)
        view.setTextViewText(R.id.task_reminder_body, bodyShown)
        // Both views are set explicitly in both modes: when the card is updated, SystemUI re-applies the new
        // RemoteViews on the view that is already showing and only touches what it sets, so a due-now repost that
        // only set the body text left the old state (countdown visible, body hidden) and the timer went negative.
        when (modeFor(countdown)) {
            Mode.COUNTDOWN -> {
                // Ticks every second in the system UI process, no app wakeups (API 24+, minSdk 24)
                view.setViewVisibility(R.id.task_reminder_body, View.GONE)
                view.setViewVisibility(R.id.task_reminder_countdown, View.VISIBLE)
                view.setChronometerCountDown(R.id.task_reminder_countdown, true)
                view.setChronometer(
                    R.id.task_reminder_countdown,
                    countdownBase(dueAtMs, nowMs, SystemClock.elapsedRealtime()),
                    countdownFormat(isArabic), true
                )
            }
            Mode.TEXT -> {
                view.setViewVisibility(R.id.task_reminder_countdown, View.GONE)
                view.setChronometer(R.id.task_reminder_countdown, SystemClock.elapsedRealtime(), null, false)
                view.setViewVisibility(R.id.task_reminder_body, View.VISIBLE)
            }
        }
        view.setTextViewText(R.id.btn_task_remind_later, snoozeLabel(isArabic))
        view.setOnClickPendingIntent(R.id.btn_task_remind_later, snoozePending)
        view.setTextViewText(R.id.btn_task_done, doneLabel(isArabic))
        view.setOnClickPendingIntent(R.id.btn_task_done, donePending)

        // What the locked screen shows: the same themed card with only the generic title (no task, no buttons)
        val publicTitleText = publicTitle(isArabic)
        val publicView = RemoteViews(context.packageName, layoutId(dark, isArabic))
        publicView.setTextViewText(R.id.task_reminder_title, publicTitleText)
        publicView.setViewVisibility(R.id.task_reminder_body, View.GONE)
        publicView.setViewVisibility(R.id.task_reminder_countdown, View.GONE)
        publicView.setViewVisibility(R.id.btn_task_remind_later, View.GONE)
        publicView.setViewVisibility(R.id.btn_task_done, View.GONE)
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
            putString(EXTRA_BODY_KIND, bodyKind ?: "")
            putInt(EXTRA_BODY_MINUTES, bodyMinutes)
            putLong(EXTRA_DUE_AT, dueAtMs)
        }
        val builder = NotificationCompat.Builder(context, TaskReminderReceiver.CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(bodyShown)
            .setCustomContentView(view)
            .setCustomBigContentView(view)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(publicNotification)
            // Ongoing, like the post-check card: EMUI hid a dismissible card from the lock screen once the phone had
            // been unlocked. Removed by Done, Remind Later, a tap (opens Tasks) or the timeout below.
            .setOngoing(true)
            .setAutoCancel(true)
            .setTimeoutAfter(timeoutAfterMs(if (countdown) BODY_BEFORE else kind, dueAtMs, nowMs, endOfToday()))
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

    /** `when` of this task card if it is still showing, else null (a dismissed card is not brought back). */
    fun shownWhen(context: Context, notificationId: Int): Long? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
        return try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            nm.activeNotifications
                .firstOrNull {
                    it.packageName == context.packageName && it.id == notificationId &&
                        it.notification.extras.getBoolean(EXTRA_MARK, false)
                }
                ?.notification?.`when`
        } catch (e: Exception) {
            Log.e(TAG, "❌ shownWhen failed: ${e.message}")
            null
        }
    }

    /**
     * Theme or language changed in the app (ThemedNotification.refreshAll): re-post every task reminder card that is
     * showing with a different look than the current theme/language would pick (layout, button labels and the body
     * text in the new language).
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
                show(
                    context, sbn.id, n.extras.getString(EXTRA_TASK_ID) ?: "", title,
                    n.extras.getString(EXTRA_BODY) ?: "",
                    n.extras.getString(EXTRA_BODY_KIND)?.takeIf { it.isNotEmpty() },
                    n.extras.getInt(EXTRA_BODY_MINUTES, 0),
                    n.extras.getLong(EXTRA_DUE_AT, 0L),
                    n.`when`
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ refreshShowing failed: ${e.message}")
        }
    }
}
