package com.aura.hala

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.util.Log
import android.view.View
import android.widget.RemoteViews

class TasksWidget : AppWidgetProvider() {

    companion object {
        private const val TAG = "TasksWidget"
        private const val PREFS_NAME = "aura_tasks_widget"
        private const val MAX_TASKS = 5
        private const val ACTION_COMPLETE_TASK = "com.aura.hala.COMPLETE_TASK"
        private const val ACTION_ADD_TASK = "com.aura.hala.ADD_TASK"
        private const val EXTRA_TASK_ID = "task_id"

        private val CATEGORY_EMOJI = mapOf(
            "work" to "\uD83C\uDFE2",       // 🏢
            "personal" to "\uD83D\uDC64",    // 👤
            "shopping" to "\uD83D\uDED2",    // 🛒
            "health" to "\uD83D\uDCAA",      // 💪
            "study" to "\uD83D\uDCDA",       // 📚
            "prayer" to "\uD83D\uDD4C",      // 🕌
            "other" to "\uD83D\uDCCC"        // 📌
        )
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) updateAppWidget(context, appWidgetManager, id)
        scheduleWidgetUpdate(context)
    }

    override fun onEnabled(context: Context) { scheduleWidgetUpdate(context) }
    override fun onDisabled(context: Context) { cancelWidgetUpdate(context) }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_COMPLETE_TASK -> {
                val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: return
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit().putString("pending_complete_task_id", taskId).apply()
                // Also write to Flutter's SharedPreferences
                val flutterPrefs = context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)
                flutterPrefs.edit().putString("pending_complete_task_id", taskId).apply()
                // Launch app to process completion
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    launchIntent.putExtra("complete_task_id", taskId)
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    context.startActivity(launchIntent)
                }
            }
            ACTION_ADD_TASK -> {
                // Write flag to Flutter's SharedPreferences
                val flutterPrefs = context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)
                flutterPrefs.edit().putBoolean("widget_open_task_form", true).apply()
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    launchIntent.putExtra("open_task_form", true)
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    context.startActivity(launchIntent)
                }
            }
        }
    }

    fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isDark = resolveDark(prefs, context)
        val isArabic = resolveArabic(prefs)

        val layoutId = when {
            isArabic && isDark -> R.layout.tasks_widget_dark_rtl
            isArabic && !isDark -> R.layout.tasks_widget_rtl
            !isArabic && isDark -> R.layout.tasks_widget_dark
            else -> R.layout.tasks_widget
        }
        val views = RemoteViews(context.packageName, layoutId)

        val taskCount = prefs.getInt("task_count", 0)
        val tasksDone = prefs.getInt("tasks_done", 0)
        val tasksTotal = prefs.getInt("tasks_total", 0)
        val streak = prefs.getInt("streak", 0)

        val allDone = tasksTotal > 0 && tasksDone >= tasksTotal

        // Celebration state
        if (allDone) {
            val celebColor = Color.parseColor("#4CAF50")
            views.setInt(R.id.widget_root, "setBackgroundColor", celebColor)
            views.setTextViewText(R.id.widget_tasks_label,
                if (isArabic) "\uD83C\uDF89 تم الكل!" else "\uD83C\uDF89 All done!")
            views.setTextColor(R.id.widget_tasks_label, Color.WHITE)
        } else {
            views.setTextViewText(R.id.widget_tasks_label,
                if (isArabic) "مهام اليوم" else "Today's Tasks")
        }

        // Streak badge
        if (streak > 0) {
            views.setViewVisibility(R.id.widget_streak, View.VISIBLE)
            val streakText = if (isArabic) "\uD83D\uDD25 ${toEA(streak)}" else "\uD83D\uDD25 $streak"
            views.setTextViewText(R.id.widget_streak, streakText)
        } else {
            views.setViewVisibility(R.id.widget_streak, View.GONE)
        }

        // Tasks count
        views.setTextViewText(R.id.widget_tasks_count, if (isArabic)
            "${toEA(tasksDone)}/${toEA(tasksTotal)}" else "$tasksDone/$tasksTotal")

        // Progress bar
        val progress = if (tasksTotal > 0) ((tasksDone.toFloat() / tasksTotal) * 100).toInt() else 0
        try { views.setProgressBar(R.id.widget_tasks_progress, 100, progress, false) } catch (_: Exception) {}

        // Task rows
        val rowIds = intArrayOf(R.id.task_row_0, R.id.task_row_1, R.id.task_row_2, R.id.task_row_3, R.id.task_row_4)
        val titleIds = intArrayOf(R.id.task_title_0, R.id.task_title_1, R.id.task_title_2, R.id.task_title_3, R.id.task_title_4)
        val checkIds = intArrayOf(R.id.task_check_0, R.id.task_check_1, R.id.task_check_2, R.id.task_check_3, R.id.task_check_4)
        val timeIds = intArrayOf(R.id.task_time_0, R.id.task_time_1, R.id.task_time_2, R.id.task_time_3, R.id.task_time_4)
        val subtaskIds = intArrayOf(R.id.task_subtask_0, R.id.task_subtask_1, R.id.task_subtask_2, R.id.task_subtask_3, R.id.task_subtask_4)

        val normalTitleColor = if (isDark) Color.parseColor("#E0E0E0") else Color.parseColor("#333333")

        for (i in 0 until MAX_TASKS) {
            if (i < taskCount) {
                views.setViewVisibility(rowIds[i], View.VISIBLE)
                val title = prefs.getString("task_${i}_title", "") ?: ""
                val priority = prefs.getString("task_${i}_priority", "medium") ?: "medium"
                val overdue = prefs.getBoolean("task_${i}_overdue", false)
                val time = prefs.getString("task_${i}_time", "") ?: ""
                val category = prefs.getString("task_${i}_category", "other") ?: "other"
                val subtaskDone = prefs.getInt("task_${i}_subtaskDone", 0)
                val subtaskTotal = prefs.getInt("task_${i}_subtaskTotal", 0)
                val taskId = prefs.getString("task_${i}_id", "") ?: ""

                // Priority colored dot
                val indicatorColor = when (priority) {
                    "high" -> Color.parseColor("#FF5252")
                    "low" -> Color.parseColor("#4CAF50")
                    else -> Color.parseColor("#FF9F1C")
                }
                views.setTextViewText(checkIds[i], "\u25CF") // ●
                views.setTextColor(checkIds[i], indicatorColor)

                // Category emoji + title
                val emoji = CATEGORY_EMOJI[category] ?: CATEGORY_EMOJI["other"]!!
                views.setTextViewText(titleIds[i], "$emoji $title")
                views.setTextColor(titleIds[i], if (overdue) Color.parseColor("#FF5252") else normalTitleColor)

                // Time
                if (time.isNotEmpty()) {
                    views.setViewVisibility(timeIds[i], View.VISIBLE)
                    views.setTextViewText(timeIds[i], if (overdue) "\u26A0 $time" else time)
                    views.setTextColor(timeIds[i], if (overdue) Color.parseColor("#FF5252") else Color.parseColor("#888888"))
                } else {
                    views.setViewVisibility(timeIds[i], View.GONE)
                }

                // Subtask progress
                if (subtaskTotal > 0) {
                    views.setViewVisibility(subtaskIds[i], View.VISIBLE)
                    val stDone = if (isArabic) toEA(subtaskDone) else subtaskDone.toString()
                    val stTotal = if (isArabic) toEA(subtaskTotal) else subtaskTotal.toString()
                    views.setTextViewText(subtaskIds[i], "$stDone/$stTotal")
                } else {
                    views.setViewVisibility(subtaskIds[i], View.GONE)
                }

                // Tap-to-complete on task row
                if (taskId.isNotEmpty()) {
                    val completeIntent = Intent(context, TasksWidget::class.java).apply {
                        action = ACTION_COMPLETE_TASK
                        putExtra(EXTRA_TASK_ID, taskId)
                    }
                    views.setOnClickPendingIntent(rowIds[i], PendingIntent.getBroadcast(
                        context, appWidgetId * 10 + i, completeIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                }
            } else {
                views.setViewVisibility(rowIds[i], View.GONE)
            }
        }

        // Empty state
        if (taskCount == 0 && !allDone) {
            views.setViewVisibility(R.id.widget_empty_state, View.VISIBLE)
            views.setTextViewText(R.id.widget_empty_state,
                if (isArabic) "لا توجد مهام اليوم" else "No tasks today")
        } else {
            views.setViewVisibility(R.id.widget_empty_state, View.GONE)
        }

        // Quick-add button
        val addIntent = Intent(context, TasksWidget::class.java).apply {
            action = ACTION_ADD_TASK
        }
        views.setOnClickPendingIntent(R.id.widget_add_button, PendingIntent.getBroadcast(
            context, appWidgetId + 5000, addIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))

        // Root click → open app
        context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
            views.setOnClickPendingIntent(R.id.widget_root, PendingIntent.getActivity(
                context, appWidgetId, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
        Log.d(TAG, "Updated tasks widget $appWidgetId ($taskCount tasks, $progress%)")
    }

    private fun resolveDark(prefs: android.content.SharedPreferences, context: Context): Boolean {
        return when (prefs.getString("themeMode", "system") ?: "system") {
            "dark" -> true; "light" -> false; else -> isSystemDarkTheme(context)
        }
    }
    private fun resolveArabic(prefs: android.content.SharedPreferences): Boolean =
        (prefs.getString("language", "en") ?: "en") == "ar"
    private fun isSystemDarkTheme(context: Context): Boolean =
        (context.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
                android.content.res.Configuration.UI_MODE_NIGHT_YES

    private fun scheduleWidgetUpdate(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = PendingIntent.getBroadcast(context, 0, Intent(context, TasksWidgetReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        am.setRepeating(AlarmManager.RTC, System.currentTimeMillis(), 1800000L, pi)
    }
    private fun cancelWidgetUpdate(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(PendingIntent.getBroadcast(context, 0, Intent(context, TasksWidgetReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
    }
    private fun toEA(n: String): String = n.map { val i = "0123456789".indexOf(it); if (i >= 0) "٠١٢٣٤٥٦٧٨٩"[i] else it }.joinToString("")
    private fun toEA(n: Int): String = toEA(n.toString())
}

class TasksWidgetReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val am = AppWidgetManager.getInstance(context)
        for (id in am.getAppWidgetIds(ComponentName(context, TasksWidget::class.java)))
            TasksWidget().updateAppWidget(context, am, id)
    }
}

/**
 * Next Task Widget - 4x1 compact
 */
class NextTaskWidget : AppWidgetProvider() {

    companion object {
        private const val TAG = "NextTaskWidget"
        private const val PREFS = "aura_tasks_widget"
        private const val ACTION_COMPLETE_TASK = "com.aura.hala.NEXT_COMPLETE_TASK"
        private const val EXTRA_TASK_ID = "task_id"

        private val CATEGORY_EMOJI = mapOf(
            "work" to "\uD83C\uDFE2",
            "personal" to "\uD83D\uDC64",
            "shopping" to "\uD83D\uDED2",
            "health" to "\uD83D\uDCAA",
            "study" to "\uD83D\uDCDA",
            "prayer" to "\uD83D\uDD4C",
            "other" to "\uD83D\uDCCC"
        )
    }

    override fun onUpdate(context: Context, am: AppWidgetManager, ids: IntArray) {
        for (id in ids) updateAppWidget(context, am, id)
        scheduleUpdate(context)
    }
    override fun onEnabled(context: Context) { scheduleUpdate(context) }
    override fun onDisabled(context: Context) { cancelUpdate(context) }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_COMPLETE_TASK) {
            val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: return
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            prefs.edit().putString("pending_complete_task_id", taskId).apply()
            // Also write to Flutter's SharedPreferences
            val flutterPrefs = context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)
            flutterPrefs.edit().putString("pending_complete_task_id", taskId).apply()
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                launchIntent.putExtra("complete_task_id", taskId)
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                context.startActivity(launchIntent)
            }
        }
    }

    fun updateAppWidget(context: Context, am: AppWidgetManager, appWidgetId: Int) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val isDark = when (prefs.getString("themeMode", "system") ?: "system") {
            "dark" -> true; "light" -> false; else -> isSystemDark(context)
        }
        val isArabic = (prefs.getString("language", "en") ?: "en") == "ar"

        val layoutId = when {
            isArabic && isDark -> R.layout.next_task_widget_dark_rtl
            isArabic && !isDark -> R.layout.next_task_widget_rtl
            !isArabic && isDark -> R.layout.next_task_widget_dark
            else -> R.layout.next_task_widget
        }
        val views = RemoteViews(context.packageName, layoutId)

        val taskCount = prefs.getInt("task_count", 0)
        val tasksDone = prefs.getInt("tasks_done", 0)
        val tasksTotal = prefs.getInt("tasks_total", 0)
        val streak = prefs.getInt("streak", 0)

        views.setTextViewText(R.id.widget_tasks_label,
            if (isArabic) "المهمة القادمة" else "Next Task")

        // Streak
        if (streak > 0) {
            views.setViewVisibility(R.id.widget_streak, View.VISIBLE)
            views.setTextViewText(R.id.widget_streak,
                if (isArabic) "\uD83D\uDD25 ${toEA(streak)}" else "\uD83D\uDD25 $streak")
        } else {
            views.setViewVisibility(R.id.widget_streak, View.GONE)
        }

        if (taskCount > 0) {
            val title = prefs.getString("task_0_title", "") ?: ""
            val time = prefs.getString("task_0_time", "") ?: ""
            val priority = prefs.getString("task_0_priority", "medium") ?: "medium"
            val overdue = prefs.getBoolean("task_0_overdue", false)
            val category = prefs.getString("task_0_category", "other") ?: "other"
            val taskId = prefs.getString("task_0_id", "") ?: ""

            val emoji = CATEGORY_EMOJI[category] ?: CATEGORY_EMOJI["other"]!!
            val dotColor = when (priority) {
                "high" -> Color.parseColor("#FF5252")
                "low" -> Color.parseColor("#4CAF50")
                else -> Color.parseColor("#FF9F1C")
            }
            val titleColor = if (overdue) Color.parseColor("#FF5252") else dotColor

            views.setTextViewText(R.id.widget_task_title, "$emoji $title")
            views.setTextColor(R.id.widget_task_title, titleColor)

            if (time.isNotEmpty()) {
                views.setViewVisibility(R.id.widget_task_time, View.VISIBLE)
                views.setTextViewText(R.id.widget_task_time, if (overdue) "\u26A0 $time" else time)
                views.setTextColor(R.id.widget_task_time, if (overdue) Color.parseColor("#FF5252") else Color.parseColor("#888888"))
            } else {
                views.setViewVisibility(R.id.widget_task_time, View.GONE)
            }

            // Tap-to-complete
            if (taskId.isNotEmpty()) {
                val completeIntent = Intent(context, NextTaskWidget::class.java).apply {
                    action = ACTION_COMPLETE_TASK
                    putExtra(EXTRA_TASK_ID, taskId)
                }
                views.setOnClickPendingIntent(R.id.widget_root, PendingIntent.getBroadcast(
                    context, appWidgetId + 2000, completeIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            }
        } else {
            views.setTextViewText(R.id.widget_task_title,
                if (isArabic) "لا توجد مهام" else "No tasks today")
            views.setTextColor(R.id.widget_task_title,
                if (isDark) Color.parseColor("#E0E0E0") else Color.parseColor("#333333"))
            views.setViewVisibility(R.id.widget_task_time, View.GONE)

            // Fallback click → open app
            context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
                views.setOnClickPendingIntent(R.id.widget_root, PendingIntent.getActivity(
                    context, appWidgetId + 1000, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            }
        }

        // Count badge
        views.setTextViewText(R.id.widget_tasks_done,
            if (isArabic) toEA(tasksDone) else tasksDone.toString())
        views.setTextViewText(R.id.widget_tasks_total_label,
            if (isArabic) "\u0645\u0646 ${toEA(tasksTotal)}" else "of $tasksTotal")

        am.updateAppWidget(appWidgetId, views)
        Log.d(TAG, "Updated next task widget $appWidgetId")
    }

    private fun isSystemDark(c: Context): Boolean =
        (c.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
                android.content.res.Configuration.UI_MODE_NIGHT_YES
    private fun toEA(n: String): String = n.map { val i = "0123456789".indexOf(it); if (i >= 0) "٠١٢٣٤٥٦٧٨٩"[i] else it }.joinToString("")
    private fun toEA(n: Int): String = toEA(n.toString())

    private fun scheduleUpdate(c: Context) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.setRepeating(AlarmManager.RTC, System.currentTimeMillis(), 1800000L,
            PendingIntent.getBroadcast(c, 1, Intent(c, NextTaskWidgetReceiver::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
    }
    private fun cancelUpdate(c: Context) {
        (c.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(
            PendingIntent.getBroadcast(c, 1, Intent(c, NextTaskWidgetReceiver::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
    }
}

class NextTaskWidgetReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val am = AppWidgetManager.getInstance(context)
        for (id in am.getAppWidgetIds(ComponentName(context, NextTaskWidget::class.java)))
            NextTaskWidget().updateAppWidget(context, am, id)
    }
}
