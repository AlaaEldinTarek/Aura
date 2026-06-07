package com.aura.hala

import android.content.Context
import android.util.Log
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.Worker
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * Backup periodic recalculation of prayer times — a third reliability layer
 * behind the 00:05 [DailyRecalcReceiver] exact alarm and the foreground
 * service's stale-time loop. WorkManager is OS-managed and survives process
 * death + reboot, so it keeps prayer times fresh even on aggressive OEMs
 * (Huawei/Xiaomi/Oppo) that cancel exact alarms and freeze the app overnight.
 *
 * Runs in the background, so it must NOT start a foreground service (that throws
 * on Android 12+). It only recomputes + reschedules alarms via
 * NativePrayerCalculator; the foreground service reads the refreshed times on
 * its next tick, and the rescheduled alarms wake the service if it was killed.
 */
class PrayerRecalcWorker(context: Context, params: WorkerParameters) :
    Worker(context, params) {

    override fun doWork(): Result {
        return try {
            val ok = NativePrayerCalculator.calculateAndSave(applicationContext)
            Log.d(TAG, if (ok) "✅ Periodic recalc done" else "⚠️ Skipped (no stored coordinates)")
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "❌ Periodic recalc failed: ${e.message}")
            Result.success() // don't retry-storm — the next period will try again
        }
    }

    companion object {
        private const val TAG = "PrayerRecalcWorker"
        private const val WORK_NAME = "aura_periodic_prayer_recalc"

        /** Enqueue the 6-hourly recalc. Idempotent (KEEP) — safe to call on every app start/boot. */
        fun schedule(context: Context) {
            try {
                val request = PeriodicWorkRequestBuilder<PrayerRecalcWorker>(
                    6, TimeUnit.HOURS
                ).build()
                WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                    WORK_NAME,
                    ExistingPeriodicWorkPolicy.KEEP,
                    request
                )
                Log.d(TAG, "⏰ Scheduled periodic prayer recalc (6h)")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to schedule periodic recalc: ${e.message}")
            }
        }
    }
}
