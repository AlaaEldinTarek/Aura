package com.aura.hala

import android.app.Service
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.IBinder
import android.util.Log

/**
 * Service that updates prayer widgets on demand
 * Called from Flutter when prayer times are updated
 */
class WidgetUpdateService : Service() {

    companion object {
        private const val TAG = "WidgetUpdateService"
        const val ACTION_UPDATE_NEXT_PRAYER = "com.aura.hala.UPDATE_NEXT_PRAYER"
        const val ACTION_UPDATE_ALL_PRAYERS = "com.aura.hala.UPDATE_ALL_PRAYERS"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        Log.d(TAG, "Widget update service started: $action")

        Thread {
            try {
                when (action) {
                    ACTION_UPDATE_NEXT_PRAYER -> updateNextPrayerWidget()
                    ACTION_UPDATE_ALL_PRAYERS -> updateAllPrayersWidget()
                    else -> {
                        updateNextPrayerWidget()
                        updateAllPrayersWidget()
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in widget update thread", e)
            } finally {
                stopSelf()
            }
        }.start()

        return START_NOT_STICKY
    }

    private fun updateNextPrayerWidget() {
        try {
            val appWidgetManager = AppWidgetManager.getInstance(this)
            val componentName = ComponentName(this, NextPrayerWidget::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

            if (appWidgetIds.isNotEmpty()) {
                for (appWidgetId in appWidgetIds) {
                    NextPrayerWidget().updateAppWidget(this, appWidgetManager, appWidgetId)
                }
                Log.d(TAG, "Updated ${appWidgetIds.size} NextPrayerWidget instances")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error updating NextPrayerWidget", e)
        }
    }

    private fun updateAllPrayersWidget() {
        try {
            val appWidgetManager = AppWidgetManager.getInstance(this)
            val componentName = ComponentName(this, AllPrayersWidget::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

            if (appWidgetIds.isNotEmpty()) {
                for (appWidgetId in appWidgetIds) {
                    AllPrayersWidget().updateAppWidget(this, appWidgetManager, appWidgetId)
                }
                Log.d(TAG, "Updated ${appWidgetIds.size} AllPrayersWidget instances")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error updating AllPrayersWidget", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Widget update service destroyed")
    }
}
