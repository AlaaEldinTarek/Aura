package com.aura.hala

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BroadcastReceiver for stopping Adhan playback
 * Triggered when user taps the "Stop" button on the prayer notification
 *
 * IMPORTANT: This ONLY stops the adhan audio - the notification remains visible
 * The notification will be automatically cancelled after 20 minutes by SilentOffReceiver
 * Or user can dismiss it by swiping or using the trash icon
 */
class StopAdhanReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "StopAdhanReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "🛑 [STOP] Stop Adhan action received")

        val prayerName = intent.getStringExtra(PrayerAlarmReceiver.EXTRA_PRAYER_NAME) ?: "Unknown"

        // Stop the Adhan playback ONLY - do NOT cancel notification
        if (AdhanPlayer.isPlaying()) {
            AdhanPlayer.stop()
            Log.d(TAG, "✅ [STOP] Stopped Adhan audio for $prayerName")
        } else {
            Log.d(TAG, "ℹ️ [STOP] No Adhan currently playing")
        }

        // DO NOT cancel the notification - let it stay for 20 minutes
        // Notification will be cancelled by SilentOffReceiver after 20 minutes
        // Or user can dismiss by swiping or using trash icon
        Log.d(TAG, "📱 [STOP] Notification KEPT VISIBLE - user can dismiss by swipe/trash icon")

        // Update the notification to show adhan is stopped (remove Stop button, show remaining buttons)
        updateNotificationAfterStop(context, prayerName)

        Log.d(TAG, "═══════════════════════════════════════")
    }

    /**
     * Update notification after stopping adhan
     * Remove Stop button, keep Dismiss/Vibrate Always buttons
     */
    private fun updateNotificationAfterStop(context: Context, prayerName: String) {
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val notificationId = PrayerAlarmReceiver.getNotificationId(prayerName)

            val defaultPrefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
            val language = defaultPrefs.getString("language", "en") ?: "en"
            val isArabic = language == "ar"

            val prayerNameAr = when (prayerName) {
                "Fajr" -> "الفجر"
                "Dhuhr", "Zuhr" -> "الظهر"
                "Asr" -> "العصر"
                "Maghrib" -> "المغرب"
                "Isha" -> "العشاء"
                else -> prayerName
            }

            val title = if (isArabic) prayerNameAr else prayerName
            val message = if (isArabic) {
                "تم إيقاف الأذان - $prayerNameAr"
            } else {
                "Azan stopped - $prayerName"
            }

            val builder = androidx.core.app.NotificationCompat.Builder(context, "prayer_times")
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(title)
                .setContentText(message)
                .setPriority(androidx.core.app.NotificationCompat.PRIORITY_HIGH)
                .setCategory(androidx.core.app.NotificationCompat.CATEGORY_ALARM)
                .setAutoCancel(false)
                .setOngoing(false)
                .setShowWhen(true)
                .setVisibility(androidx.core.app.NotificationCompat.VISIBILITY_PUBLIC)
                .setStyle(
                    androidx.core.app.NotificationCompat.BigTextStyle()
                        .bigText(message)
                        .setBigContentTitle(title)
                )

            notificationManager.notify(notificationId, builder.build())
            Log.d(TAG, "📱 [STOP] Notification updated - shows 'Adhan stopped', Stop button removed")
        } catch (e: Exception) {
            Log.e(TAG, "❌ [STOP] Error updating notification: ${e.message}")
        }
    }
}
