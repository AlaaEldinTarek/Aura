package com.aura.hala

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.text.format.DateFormat
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.aura.hala.R
import java.util.Date

/**
 * Generic native delivery for Flutter-scheduled notifications (10-min
 * pre-prayer reminders, Wird reminders, daily task digest).
 *
 * Same rationale as TaskReminderReceiver: Huawei/EMUI silently drops
 * broadcasts to flutter_local_notifications' receiver, but delivers to
 * receivers in our own package. Dart computes the text and timing; this
 * receiver just posts what it is given, optionally re-arming itself every
 * 24h (the native equivalent of matchDateTimeComponents.time).
 *
 * When a prayer name is attached, the notification gets the two pre-prayer
 * actions: "Mark as Prayed" (writes prayer_status_{name}_{date} — synced to
 * Firestore on next app open, same mechanism as PrayerAlarmReceiver) and
 * "Remind Me Again" (re-posts 5 minutes before the prayer time).
 */
class NativeNotificationReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "NativeNotifReceiver"

        const val ACTION_MARK_PRAYED = "com.aura.hala.NATIVE_NOTIF_MARK_PRAYED"
        const val ACTION_REMIND_AGAIN = "com.aura.hala.NATIVE_NOTIF_REMIND_AGAIN"

        const val EXTRA_NOTIFICATION_ID = "notification_id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_CHANNEL_ID = "channel_id"
        const val EXTRA_CHANNEL_NAME = "channel_name"
        const val EXTRA_TAP_TAB = "tap_tab"
        const val EXTRA_REPEAT_DAILY = "repeat_daily"
        const val EXTRA_IS_ARABIC = "is_arabic"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_PRAYER_TIME_MS = "prayer_time_ms"

        fun schedule(
            context: Context,
            notificationId: Int,
            title: String,
            body: String,
            channelId: String,
            channelName: String,
            triggerAtMs: Long,
            tapTab: Int,
            repeatDaily: Boolean,
            isArabic: Boolean,
            prayerName: String?,
            prayerTimeMs: Long
        ) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, NativeNotificationReceiver::class.java).apply {
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_CHANNEL_ID, channelId)
                putExtra(EXTRA_CHANNEL_NAME, channelName)
                putExtra(EXTRA_TAP_TAB, tapTab)
                putExtra(EXTRA_REPEAT_DAILY, repeatDaily)
                putExtra(EXTRA_IS_ARABIC, isArabic)
                if (prayerName != null) putExtra(EXTRA_PRAYER_NAME, prayerName)
                putExtra(EXTRA_PRAYER_TIME_MS, prayerTimeMs)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context, notificationId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
            }
            Log.d(TAG, "⏰ Scheduled id=$notificationId ch=$channelId at ${DateFormat.format("MM-dd HH:mm", Date(triggerAtMs))} repeatDaily=$repeatDaily")
        }

        fun cancel(context: Context, notificationId: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, NativeNotificationReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context, notificationId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
            NotificationManagerCompat.from(context).cancel(notificationId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)
        val title = intent.getStringExtra(EXTRA_TITLE) ?: return
        val body = intent.getStringExtra(EXTRA_BODY) ?: ""
        val channelId = intent.getStringExtra(EXTRA_CHANNEL_ID) ?: "task_reminders"
        val channelName = intent.getStringExtra(EXTRA_CHANNEL_NAME) ?: "Reminders"
        val tapTab = intent.getIntExtra(EXTRA_TAP_TAB, 0)
        val repeatDaily = intent.getBooleanExtra(EXTRA_REPEAT_DAILY, false)
        val isArabic = intent.getBooleanExtra(EXTRA_IS_ARABIC, false)
        val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME)
        val prayerTimeMs = intent.getLongExtra(EXTRA_PRAYER_TIME_MS, 0L)

        when (intent.action) {
            ACTION_MARK_PRAYED -> {
                if (prayerName != null) {
                    val prefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
                    val today = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(Date())
                    prefs.edit().putString("prayer_status_${prayerName}_${today}", "on_time").apply()
                    Log.d(TAG, "✅ Marked $prayerName as prayed (syncs on next app open)")
                }
                NotificationManagerCompat.from(context).cancel(notificationId)
                return
            }
            ACTION_REMIND_AGAIN -> {
                NotificationManagerCompat.from(context).cancel(notificationId)
                val fiveMinBefore = prayerTimeMs - 5 * 60 * 1000L
                if (fiveMinBefore > System.currentTimeMillis()) {
                    schedule(
                        context, notificationId + 5000, title,
                        if (isArabic) "الصلاة بعد ٥ دقائق" else "Prayer in 5 minutes",
                        channelId, channelName, fiveMinBefore, tapTab,
                        repeatDaily = false, isArabic = isArabic,
                        prayerName = null, prayerTimeMs = 0L
                    )
                    Log.d(TAG, "🔁 Remind-again armed for $prayerName 5 min before prayer")
                } else {
                    Log.d(TAG, "⏭️ Remind-again skipped — less than 5 min to prayer")
                }
                return
            }
        }

        Log.d(TAG, "🔔 Fired id=$notificationId ch=$channelId")
        ensureChannel(context, channelId, channelName)

        val tapIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("widget_target_tab", tapTab)
        }
        val tapPending = PendingIntent.getActivity(
            context, notificationId + 1, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(tapPending)

        if (prayerName != null) {
            val prayedIntent = Intent(context, NativeNotificationReceiver::class.java).apply {
                action = ACTION_MARK_PRAYED
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
                putExtra(EXTRA_PRAYER_NAME, prayerName)
            }
            val prayedPending = PendingIntent.getBroadcast(
                context, notificationId + 2, prayedIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val againIntent = Intent(context, NativeNotificationReceiver::class.java).apply {
                action = ACTION_REMIND_AGAIN
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_CHANNEL_ID, channelId)
                putExtra(EXTRA_CHANNEL_NAME, channelName)
                putExtra(EXTRA_TAP_TAB, tapTab)
                putExtra(EXTRA_IS_ARABIC, isArabic)
                putExtra(EXTRA_PRAYER_TIME_MS, prayerTimeMs)
                putExtra(EXTRA_PRAYER_NAME, prayerName)
            }
            val againPending = PendingIntent.getBroadcast(
                context, notificationId + 3, againIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.addAction(0, if (isArabic) "أديت الصلاة" else "Mark as Prayed", prayedPending)
            builder.addAction(0, if (isArabic) "ذكرني مرة أخرى" else "Remind Me Again", againPending)
        }

        try {
            NotificationManagerCompat.from(context).notify(notificationId, builder.build())
            Log.d(TAG, "✅ Posted id=$notificationId")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error posting notification: ${e.message}")
        }

        // Native equivalent of matchDateTimeComponents.time — re-arm for tomorrow
        // with the same payload. Flutter refreshes text/times on each app open.
        if (repeatDaily) {
            schedule(
                context, notificationId, title, body, channelId, channelName,
                System.currentTimeMillis() + 24 * 60 * 60 * 1000L,
                tapTab, repeatDaily = true, isArabic = isArabic,
                prayerName = prayerName, prayerTimeMs = prayerTimeMs + 24 * 60 * 60 * 1000L
            )
        }
    }

    private fun ensureChannel(context: Context, channelId: String, channelName: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(channelId) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_HIGH)
                )
            }
        }
    }
}
