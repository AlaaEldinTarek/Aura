package com.aura.hala

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log

internal enum class CancelKind { BROADCAST, SERVICE }

/**
 * One alarm to cancel: the receiver class, action and request code EXACTLY as the arming code builds them
 * (Android matches a PendingIntent by request code + Intent.filterEquals, so a different class or action matches
 * nothing). Each receiver owns its own specs next to its arming code; this file only runs them.
 */
internal data class CancelSpec(
    val receiver: Class<*>,
    val action: String?,
    val requestCode: Int,
    val kind: CancelKind = CancelKind.BROADCAST
)

/**
 * F70: logout cancels every Aura alarm, scheduled notification and the background service, in one place.
 * Spec: docs/designs/fix-f70-logout-alarms.md (hard rules R1-R3). Called through the `prayer_alarms` channel method
 * `cancelAllAppAlarms` after a successful sign-out. Lookups use FLAG_NO_CREATE, so nothing is created while cancelling.
 */
object AlarmCleanup {
    private const val TAG = "AlarmCleanup"

    /** Every cancel target of the inventory (spec sections A-C), each owned by the receiver that arms it. */
    internal fun specs(): List<CancelSpec> = (
        PrayerAlarmReceiver.cancelSpecs() +
            AzkarAlarmReceiver.cancelSpecs() +
            DailyRecalcReceiver.cancelSpecs() +
            DailySummaryReceiver.cancelSpecs() +
            JumuahReminderReceiver.cancelSpecs() +
            TaskReminderReceiver.cancelSpecs() +
            NativeNotificationReceiver.cancelSpecs() +
            FocusModeReceiver.cancelSpecs() +
            PrayerForegroundService.cancelSpecs()
        ).distinct()

    /** Returns the number of armed alarms that were found and cancelled. Never throws: each step has its own try-catch. */
    fun cancelAll(context: Context): Int {
        val app = context.applicationContext
        var cancelled = 0
        Log.d(TAG, "🧹 [F70] logout cleanup start")

        // The service first: the flag set by stopService keeps its onDestroy from arming a restart alarm
        step("service") { PrayerForegroundService.stopService(app) }
        step("alarms") { cancelled = cancelAlarms(app) }
        step("worker") { PrayerRecalcWorker.cancel(app) }
        step("notifications") {
            (app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancelAll()
        }

        Log.d(TAG, "🧹 [F70] logout cleanup done, $cancelled armed alarms cancelled")
        return cancelled
    }

    private inline fun step(name: String, block: () -> Unit) {
        try {
            block()
        } catch (e: Exception) {
            Log.e(TAG, "❌ [F70] step '$name' failed: ${e.message}")
        }
    }

    private fun cancelAlarms(context: Context): Int {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val all = specs()
        var cancelled = 0
        var errors = 0
        for (spec in all) {
            try {
                val intent = Intent(context, spec.receiver).apply { if (spec.action != null) action = spec.action }
                val flags = PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                val pending = when (spec.kind) {
                    CancelKind.BROADCAST -> PendingIntent.getBroadcast(context, spec.requestCode, intent, flags)
                    CancelKind.SERVICE -> PendingIntent.getService(context, spec.requestCode, intent, flags)
                }
                if (pending != null) {
                    alarmManager.cancel(pending)
                    pending.cancel()
                    cancelled++
                }
            } catch (e: Exception) {
                errors++
                Log.e(TAG, "❌ [F70] cancel failed for ${spec.receiver.simpleName} code=${spec.requestCode}: ${e.message}")
            }
        }
        Log.d(TAG, "🧹 [F70] ${all.size} lookups, $cancelled armed alarms cancelled, $errors errors")
        return cancelled
    }
}
