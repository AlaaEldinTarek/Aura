package com.aura.hala

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar

/**
 * Fires every day at 00:05 to recalculate the new day's prayer times natively,
 * so the foreground-service countdown is ready before Fajr without the user
 * having to open the app. Reschedules itself for the next day after firing.
 *
 * Uses the cached coordinates stored in `aura_prayer_times` — no GPS or internet
 * needed, just the standard astronomical math in NativePrayerCalculator.
 */
class DailyRecalcReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "DailyRecalcReceiver"
        const val ACTION_DAILY_RECALC = "com.aura.hala.DAILY_RECALC"
        private const val REQUEST_CODE = 9100

        /** Schedule the next 00:05 daily recalculation. */
        fun schedule(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            val cal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 5)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                // If 00:05 today already passed, schedule for tomorrow
                if (timeInMillis <= System.currentTimeMillis()) {
                    add(Calendar.DAY_OF_YEAR, 1)
                }
            }

            val intent = Intent(context, DailyRecalcReceiver::class.java).apply {
                action = ACTION_DAILY_RECALC
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context, REQUEST_CODE, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, cal.timeInMillis, pendingIntent
                    )
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, cal.timeInMillis, pendingIntent)
                }
                Log.d(TAG, "⏰ Daily recalc scheduled for ${cal.time}")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to schedule daily recalc: ${e.message}")
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_DAILY_RECALC) return
        Log.d(TAG, "🔄 Daily recalc fired — computing new day's prayer times")

        val ok = NativePrayerCalculator.calculateAndSave(context)
        if (ok) {
            Log.d(TAG, "✅ New day's prayer times computed natively")
            // Refresh the foreground-service notification immediately
            PrayerForegroundService.startService(context)
        } else {
            Log.w(TAG, "⚠️ Recalc skipped (no cached coordinates) — will refresh on next app open")
        }

        // Always reschedule for the next day
        schedule(context)
    }
}
