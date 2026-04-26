package com.aura.hala

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.os.SystemClock
import android.text.format.DateFormat
import android.util.Log
import android.widget.RemoteViews
import com.aura.hala.R
import java.util.Calendar
import java.util.Date

/**
 * Combined Prayer Widget — ViewFlipper with Next Prayer + Day Timeline views
 */
class AllPrayersWidget : AppWidgetProvider() {

    companion object {
        private const val TAG = "CombinedPrayerWidget"
        const val ACTION_SWITCH_TAB = "com.aura.hala.ACTION_SWITCH_TAB"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widgets")
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
        scheduleWidgetUpdate(context)
    }

    override fun onEnabled(context: Context) {
        Log.d(TAG, "Widget enabled")
        scheduleWidgetUpdate(context)
    }

    override fun onDisabled(context: Context) {
        Log.d(TAG, "Widget disabled")
        cancelWidgetUpdate(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_SWITCH_TAB) {
            val tabIndex = intent.getIntExtra("tab_index", 0)
            val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                val prefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
                prefs.edit().putInt("combined_widget_tab_$widgetId", tabIndex).apply()
                Log.d(TAG, "Tab switch to $tabIndex for widget $widgetId")
            }
        }
        super.onReceive(context, intent)
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val componentName = ComponentName(context, AllPrayersWidget::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val prefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
        val themeMode = prefs.getString("themeMode", "system") ?: "system"
        val isDark = when (themeMode) {
            "dark" -> true
            "light" -> false
            else -> isSystemDarkTheme(context)
        }
        val language = prefs.getString("language", "en") ?: "en"
        val isArabic = language == "ar"

        val layoutId = when {
            isArabic && isDark -> R.layout.combined_prayer_widget_dark_rtl
            isArabic && !isDark -> R.layout.combined_prayer_widget_rtl
            !isArabic && isDark -> R.layout.combined_prayer_widget_dark
            else -> R.layout.combined_prayer_widget
        }
        val views = RemoteViews(context.packageName, layoutId)

        val now = System.currentTimeMillis()

        // ── Prayer data ──
        // RTL: reverse order so Isha is rightmost (slot 0) and Fajr leftmost (slot 5)
        val prayers = if (isArabic) listOf(
            PrayerInfo("isha_time", "Isha", "العشاء", R.id.timeline_dot_0, R.id.timeline_name_0, R.id.timeline_time_0),
            PrayerInfo("maghrib_time", "Maghrib", "المغرب", R.id.timeline_dot_1, R.id.timeline_name_1, R.id.timeline_time_1),
            PrayerInfo("asr_time", "Asr", "العصر", R.id.timeline_dot_2, R.id.timeline_name_2, R.id.timeline_time_2),
            PrayerInfo("dhuhr_time", "Zuhr", "الظهر", R.id.timeline_dot_3, R.id.timeline_name_3, R.id.timeline_time_3),
            PrayerInfo("sunrise_time", "Sunrise", "الشروق", R.id.timeline_dot_4, R.id.timeline_name_4, R.id.timeline_time_4),
            PrayerInfo("fajr_time", "Fajr", "الفجر", R.id.timeline_dot_5, R.id.timeline_name_5, R.id.timeline_time_5)
        ) else listOf(
            PrayerInfo("fajr_time", "Fajr", "الفجر", R.id.timeline_dot_0, R.id.timeline_name_0, R.id.timeline_time_0),
            PrayerInfo("sunrise_time", "Sunrise", "الشروق", R.id.timeline_dot_1, R.id.timeline_name_1, R.id.timeline_time_1),
            PrayerInfo("dhuhr_time", "Zuhr", "الظهر", R.id.timeline_dot_2, R.id.timeline_name_2, R.id.timeline_time_2),
            PrayerInfo("asr_time", "Asr", "العصر", R.id.timeline_dot_3, R.id.timeline_name_3, R.id.timeline_time_3),
            PrayerInfo("maghrib_time", "Maghrib", "المغرب", R.id.timeline_dot_4, R.id.timeline_name_4, R.id.timeline_time_4),
            PrayerInfo("isha_time", "Isha", "العشاء", R.id.timeline_dot_5, R.id.timeline_name_5, R.id.timeline_time_5)
        )

        val nextPrayerNameEn = prefs.getString("next_prayer_name", "Asr") ?: "Asr"
        val nextPrayerNameAr = prefs.getString("next_prayer_name_ar", "العصر") ?: "العصر"
        val nextPrayerTimeStr = prefs.getString("next_prayer_time", "0") ?: "0"
        val nextPrayerTime = nextPrayerTimeStr.toLongOrNull() ?: 0

        // Find current prayer (most recent past prayer)
        var currentPrayerNameEn: String? = null
        var currentPrayerNameAr: String? = null
        var mostRecentTime = 0L

        for (p in prayers) {
            val timeStr = prefs.getString(p.key, null)
            val time = timeStr?.toLongOrNull() ?: 0
            if (time > 0 && time <= now && time > mostRecentTime) {
                mostRecentTime = time
                currentPrayerNameEn = p.nameEn
                currentPrayerNameAr = p.nameAr
            }
        }

        // ── Tab state ──
        val currentTab = prefs.getInt("combined_widget_tab_$appWidgetId", 0)
        val activeTabBg = if (isDark) R.drawable.widget_tab_active_dark else R.drawable.widget_tab_active_light
        val inactiveTabBg = if (isDark) R.drawable.widget_tab_inactive_dark else R.drawable.widget_tab_inactive_light
        val activeColor = if (isDark) 0xFFF5B301.toInt() else 0xFFB5821B.toInt()
        val inactiveColor = if (isDark) 0xFF6B7180.toInt() else 0xFF9A8F78.toInt()

        val tabNextLabel = if (isArabic) "الصلاة القادمة" else "Next Prayer"
        val tabTimelineLabel = if (isArabic) "كل الصلوات" else "All Prayer"

        views.setTextViewText(R.id.tab_next_prayer, tabNextLabel)
        views.setTextViewText(R.id.tab_timeline, tabTimelineLabel)

        if (currentTab == 0) {
            views.setInt(R.id.tab_next_prayer, "setBackgroundResource", activeTabBg)
            views.setTextColor(R.id.tab_next_prayer, activeColor)
            views.setInt(R.id.tab_timeline, "setBackgroundResource", inactiveTabBg)
            views.setTextColor(R.id.tab_timeline, inactiveColor)
        } else {
            views.setInt(R.id.tab_next_prayer, "setBackgroundResource", inactiveTabBg)
            views.setTextColor(R.id.tab_next_prayer, inactiveColor)
            views.setInt(R.id.tab_timeline, "setBackgroundResource", activeTabBg)
            views.setTextColor(R.id.tab_timeline, activeColor)
        }

        // Tab click PendingIntents
        val tab0Intent = Intent(context, AllPrayersWidget::class.java).apply {
            action = ACTION_SWITCH_TAB
            putExtra("tab_index", 0)
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        views.setOnClickPendingIntent(R.id.tab_next_prayer,
            PendingIntent.getBroadcast(context, appWidgetId * 10, tab0Intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))

        val tab1Intent = Intent(context, AllPrayersWidget::class.java).apply {
            action = ACTION_SWITCH_TAB
            putExtra("tab_index", 1)
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        views.setOnClickPendingIntent(R.id.tab_timeline,
            PendingIntent.getBroadcast(context, appWidgetId * 10 + 1, tab1Intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))

        // ── Location ──
        val locationName = prefs.getString("location_name", null)
        views.setTextViewText(R.id.widget_location_small,
            if (!locationName.isNullOrEmpty()) locationName else if (isArabic) "الموقع" else "Location")

        // ══════════════════════════════════════════
        // VIEW 0: Next Prayer
        // ══════════════════════════════════════════

        val isFriday = Calendar.getInstance().get(Calendar.DAY_OF_WEEK) == Calendar.FRIDAY
        val isZuhrNext = nextPrayerNameEn == "Zuhr" || nextPrayerNameEn == "Dhuhr"
        val nextPrayerDisplay = when {
            isFriday && isZuhrNext -> if (isArabic) "الجمعة" else "Jumu'ah"
            isArabic -> nextPrayerNameAr
            else -> nextPrayerNameEn
        }
        views.setTextViewText(R.id.widget_next_prayer_name, nextPrayerDisplay)

        // Next prayer time
        if (nextPrayerTime > 0) {
            val cal = Calendar.getInstance().apply { timeInMillis = nextPrayerTime }
            var hours = cal.get(Calendar.HOUR_OF_DAY)
            val minutes = cal.get(Calendar.MINUTE)
            val ampm = if (hours < 12) { if (isArabic) "صباحاً" else "AM" } else { if (isArabic) "مساءً" else "PM" }
            hours = if (hours == 0) 12 else if (hours > 12) hours - 12 else hours
            val timeText = if (isArabic) {
                "${toEasternArabic(String.format("%02d", hours))}:${toEasternArabic(String.format("%02d", minutes))}"
            } else {
                String.format("%02d:%02d", hours, minutes)
            }
            views.setTextViewText(R.id.widget_next_prayer_time, timeText)
            views.setTextViewText(R.id.widget_next_prayer_ampm, ampm)
        } else {
            views.setTextViewText(R.id.widget_next_prayer_time, "--:--")
            views.setTextViewText(R.id.widget_next_prayer_ampm, "")
        }

        // Countdown
        val timeRemainingMs = nextPrayerTime - now
        if (timeRemainingMs > 0) {
            views.setChronometer(R.id.widget_time_remaining,
                SystemClock.elapsedRealtime() + timeRemainingMs, null, true)
        } else {
            views.setChronometer(R.id.widget_time_remaining,
                SystemClock.elapsedRealtime(), null, false)
        }

        val untilLabel = if (isArabic) "حتى موعد الأذان" else "UNTIL AZAN"
        views.setTextViewText(R.id.widget_time_remaining_seconds, untilLabel)

        // Ring progress bitmap
        val maxMinutes = 180f
        val totalMinRem = (timeRemainingMs / 60000).toFloat()
        val progress = ((maxMinutes - totalMinRem) / maxMinutes).coerceIn(0f, 1f)
        val ringColor = if (isDark) 0xFFF5B301.toInt() else 0xFFB5821B.toInt()
        val trackColorAlpha = if (isDark) Color.argb(20, 255, 255, 255) else Color.argb(26, 60, 45, 20)
        val density = context.resources.displayMetrics.density
        val ringSize = (16 * density).toInt()
        val ringBitmap = createRingBitmap(progress, ringColor, trackColorAlpha, ringSize, 2f * density)
        views.setImageViewBitmap(R.id.widget_progress_bar, ringBitmap)

        // Date info
        val currentDate = Date(now)
        val dayOfWeek = DateFormat.format("EEEE", currentDate)
        val dayOfWeekAr = when (dayOfWeek.toString()) {
            "Monday" -> "الإثنين"; "Tuesday" -> "الثلاثاء"; "Wednesday" -> "الأربعاء"
            "Thursday" -> "الخميس"; "Friday" -> "الجمعة"; "Saturday" -> "السبت"
            "Sunday" -> "الأحد"; else -> dayOfWeek.toString()
        }

        val gregorianMonthEn = DateFormat.format("MMM", currentDate)
        val gregorianMonthAr = when (gregorianMonthEn.toString()) {
            "Jan" -> "يناير"; "Feb" -> "فبراير"; "Mar" -> "مارس"; "Apr" -> "أبريل"
            "May" -> "مايو"; "Jun" -> "يونيو"; "Jul" -> "يوليو"; "Aug" -> "أغسطس"
            "Sep" -> "سبتمبر"; "Oct" -> "أكتوبر"; "Nov" -> "نوفمبر"; "Dec" -> "ديسمبر"
            else -> gregorianMonthEn.toString()
        }
        val gregorianDay = DateFormat.format("d", currentDate).toString()
        val gregorianYear = DateFormat.format("yyyy", currentDate).toString()

        // Day of week (horizontal layout)
        views.setTextViewText(R.id.widget_day_of_week, if (isArabic) dayOfWeekAr else dayOfWeek.toString())

        views.setTextViewText(R.id.widget_gregorian_label, if (isArabic) "الميلادي" else "GREGORIAN")
        views.setTextViewText(R.id.widget_gregorian_day, if (isArabic) toEasternArabic(gregorianDay) else gregorianDay)
        views.setTextViewText(R.id.widget_gregorian_month, if (isArabic) gregorianMonthAr else gregorianMonthEn.toString())
        views.setTextViewText(R.id.widget_gregorian_year, if (isArabic) toEasternArabic(gregorianYear) else gregorianYear)

        val hijriDate = calculateHijriDate(currentDate)
        views.setTextViewText(R.id.widget_hijri_label, if (isArabic) "الهجري" else "HIJRI")
        views.setTextViewText(R.id.widget_hijri_day, if (isArabic) toEasternArabic(hijriDate["day"].toString()) else "${hijriDate["day"]}")
        views.setTextViewText(R.id.widget_hijri_month, if (isArabic) hijriDate["monthAr"] ?: "" else hijriDate["monthEn"] ?: "")
        val hijriYearStr = if (isArabic) "${toEasternArabic(hijriDate["year"].toString())} هـ" else "${hijriDate["year"]} AH"
        views.setTextViewText(R.id.widget_hijri_year, hijriYearStr)

        // ══════════════════════════════════════════
        // VIEW 1: Day Timeline
        // ══════════════════════════════════════════

        // Current prayer info
        val curDisplay = if (isArabic) (currentPrayerNameAr ?: "") else (currentPrayerNameEn ?: "")
        views.setTextViewText(R.id.timeline_current_name, curDisplay)

        if (mostRecentTime > 0) {
            val cal = Calendar.getInstance().apply { timeInMillis = mostRecentTime }
            var h = cal.get(Calendar.HOUR_OF_DAY)
            val m = cal.get(Calendar.MINUTE)
            val ampm = if (h < 12) { if (isArabic) "صباحاً" else "AM" } else { if (isArabic) "مساءً" else "PM" }
            h = if (h == 0) 12 else if (h > 12) h - 12 else h
            views.setTextViewText(R.id.timeline_current_time,
                if (isArabic) "${toEasternArabic(String.format("%02d", h))}:${toEasternArabic(String.format("%02d", m))}"
                else String.format("%02d:%02d", h, m))
            views.setTextViewText(R.id.timeline_current_ampm, ampm)
        } else {
            views.setTextViewText(R.id.timeline_current_time, "--:--")
            views.setTextViewText(R.id.timeline_current_ampm, "")
        }

        // Next countdown in timeline header
        val nextDisplayShort = if (isArabic) nextPrayerNameAr else nextPrayerNameEn
        if (timeRemainingMs > 0) {
            views.setTextViewText(R.id.timeline_next_label, if (isArabic) "التالي · " else "NEXT · ")
            views.setTextViewText(R.id.timeline_next_name, if (isArabic) nextDisplayShort else nextDisplayShort.uppercase())
            views.setTextViewText(R.id.timeline_next_suffix, if (isArabic) " بعد" else " IN")
            views.setChronometer(R.id.timeline_countdown_text, SystemClock.elapsedRealtime() + timeRemainingMs, null, true)
        } else {
            views.setTextViewText(R.id.timeline_next_label, if (isArabic) "التالي" else "NEXT")
            views.setTextViewText(R.id.timeline_next_name, "")
            views.setTextViewText(R.id.timeline_next_suffix, "")
            views.setChronometer(R.id.timeline_countdown_text, SystemClock.elapsedRealtime(), null, false)
        }

        // Secondary info line
        if (isArabic) {
            views.setTextViewText(R.id.timeline_secondary_info, "$dayOfWeekAr ${toEasternArabic(gregorianDay)} $gregorianMonthAr")
        } else {
            views.setTextViewText(R.id.timeline_secondary_info, "${dayOfWeek.toString().take(3).uppercase()} ${gregorianDay} ${gregorianMonthEn}")
        }

        // Timeline dots + names + times
        val dotNow = if (isDark) R.drawable.widget_timeline_dot_now_dark else R.drawable.widget_timeline_dot_now
        val dotNext = if (isDark) R.drawable.widget_timeline_dot_next_dark else R.drawable.widget_timeline_dot_next
        val dotPast = if (isDark) R.drawable.widget_timeline_dot_past_dark else R.drawable.widget_timeline_dot_past
        val dotFuture = if (isDark) R.drawable.widget_timeline_dot_future_dark else R.drawable.widget_timeline_dot_future

        val nameColorNow = if (isDark) 0xFFF4F5F7.toInt() else 0xFF2A2418.toInt()
        val nameColorNext = if (isDark) 0xFFFFD37A.toInt() else 0xFF8A6110.toInt()
        val nameColorPast = if (isDark) 0xFF6B7180.toInt() else 0xFF9A8F78.toInt()
        val nameColorFuture = if (isDark) 0xFF6B7180.toInt() else 0xFF9A8F78.toInt()

        for (i in prayers.indices) {
            val p = prayers[i]
            val timeStr = prefs.getString(p.key, null)
            val time = timeStr?.toLongOrNull() ?: 0

            val isCurrent = p.nameEn == currentPrayerNameEn
            val isNext = p.nameEn == nextPrayerNameEn
            val isPast = time > 0 && time <= now && !isCurrent

            // Dot
            val dotRes = when {
                isCurrent -> dotNow
                isNext -> dotNext
                isPast -> dotNow
                else -> dotFuture
            }
            views.setImageViewResource(p.dotId, dotRes)

            // Name — show Jumu'ah on Fridays for Zuhr
            val isZuhr = p.nameEn == "Zuhr" || p.nameEn == "Dhuhr"
            val displayName = when {
                isFriday && isZuhr -> if (isArabic) "الجمعة" else "Jumu'ah"
                isArabic -> p.nameAr
                else -> p.nameEn
            }
            views.setTextViewText(p.nameId, displayName)
            val nameColor = when {
                isCurrent -> nameColorNow
                isNext -> nameColorNext
                isPast -> nameColorPast
                else -> nameColorFuture
            }
            views.setTextColor(p.nameId, nameColor)

            // Time
            if (time > 0) {
                val cal = Calendar.getInstance().apply { timeInMillis = time }
                var h = cal.get(Calendar.HOUR_OF_DAY)
                val m = cal.get(Calendar.MINUTE)
                h = if (h == 0) 12 else if (h > 12) h - 12 else h
                val timeText = if (isArabic) {
                    "${toEasternArabic(String.format("%02d", h))}:${toEasternArabic(String.format("%02d", m))}"
                } else {
                    String.format("%02d:%02d", h, m)
                }
                views.setTextViewText(p.timeId, timeText)
            } else {
                views.setTextViewText(p.timeId, "--:--")
            }

            val timeColor = when {
                isCurrent -> nameColorNow
                isNext -> nameColorNext
                isPast -> nameColorPast
                else -> nameColorFuture
            }
            views.setTextColor(p.timeId, timeColor)
        }

        // Progress bar bitmap
        val progressWidth = (256 * density).toInt()
        val progressHeight = (4 * density).toInt()
        val fillColor = if (isDark) 0xFFF5B301.toInt() else 0xFFB5821B.toInt()
        val pTrackColor = if (isDark) Color.argb(20, 255, 255, 255) else Color.argb(26, 60, 45, 20)

        // For RTL: dots are visually reversed (slot 0 = RIGHT), so map array index to visual position
        val progressFraction = if (mostRecentTime > 0 && nextPrayerTime > mostRecentTime) {
            val elapsed = now - mostRecentTime
            val total = nextPrayerTime - mostRecentTime
            val curIndex = prayers.indexOfFirst { it.nameEn == currentPrayerNameEn }.coerceIn(0, prayers.size - 1)
            val segFraction = (elapsed.toFloat() / total.toFloat()).coerceIn(0f, 1f)
            if (isArabic) {
                ((prayers.size - 1 - curIndex) + 0.5f + segFraction) / prayers.size.toFloat()
            } else {
                (curIndex + 0.5f + segFraction) / prayers.size.toFloat()
            }
        } else if (mostRecentTime > 0) {
            val curIndex = prayers.indexOfFirst { it.nameEn == currentPrayerNameEn }.coerceIn(0, prayers.size - 1)
            if (isArabic) {
                (prayers.size - 0.5f - curIndex) / prayers.size.toFloat()
            } else {
                (curIndex + 0.5f) / prayers.size.toFloat()
            }
        } else 0f

        val progressBitmap = createProgressBitmap(progressFraction.coerceIn(0f, 1f), fillColor, pTrackColor, progressWidth, progressHeight, isArabic)
        views.setImageViewBitmap(R.id.timeline_progress_bar, progressBitmap)

        // ── ViewFlipper ──
        views.setDisplayedChild(R.id.view_flipper, currentTab)

        // ── Root click → open app ──
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        launchIntent?.let {
            views.setOnClickPendingIntent(R.id.view_flipper,
                PendingIntent.getActivity(context, appWidgetId * 10 + 5, it,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
        Log.d(TAG, "Updated combined widget $appWidgetId tab=$currentTab (${if(isDark) "dark" else "light"}, $language)")
    }

    private data class PrayerInfo(
        val key: String,
        val nameEn: String,
        val nameAr: String,
        val dotId: Int,
        val nameId: Int,
        val timeId: Int
    )

    private fun createRingBitmap(progress: Float, ringColor: Int, trackColor: Int, size: Int, strokeWidth: Float): Bitmap {
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val center = size / 2f
        val radius = (size - strokeWidth) / 2f
        val rect = RectF(center - radius, center - radius, center + radius, center + radius)
        canvas.drawCircle(center, center, radius, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; this.strokeWidth = strokeWidth; color = trackColor
        })
        if (progress > 0f) {
            canvas.drawArc(rect, -90f, 360f * progress, false, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE; this.strokeWidth = strokeWidth; color = ringColor; strokeCap = Paint.Cap.ROUND
            })
        }
        return bitmap
    }

    private fun createProgressBitmap(progress: Float, fillColor: Int, trackColor: Int, width: Int, height: Int, isRtl: Boolean = false): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val r = height / 2f
        canvas.drawRoundRect(RectF(0f, 0f, width.toFloat(), height.toFloat()), r, r,
            Paint(Paint.ANTI_ALIAS_FLAG).apply { color = trackColor; style = Paint.Style.FILL })
        if (progress > 0f) {
            val fillW = (width * progress.coerceIn(0f, 1f))
            canvas.drawRoundRect(RectF(0f, 0f, fillW, height.toFloat()), r, r,
                Paint(Paint.ANTI_ALIAS_FLAG).apply { color = fillColor; style = Paint.Style.FILL })
        }
        return bitmap
    }

    private fun isSystemDarkTheme(context: Context): Boolean {
        val nightMode = context.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK
        return nightMode == android.content.res.Configuration.UI_MODE_NIGHT_YES
    }

    private fun scheduleWidgetUpdate(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AllPrayersWidgetReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        alarmManager.setRepeating(AlarmManager.RTC_WAKEUP, System.currentTimeMillis(), 30000L, pendingIntent)
    }

    private fun cancelWidgetUpdate(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AllPrayersWidgetReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        alarmManager.cancel(pendingIntent)
    }

    private fun toEasternArabic(number: String): String {
        val western = "0123456789"
        val eastern = "٠١٢٣٤٥٦٧٨٩"
        return number.map { digit -> val i = western.indexOf(digit); if (i >= 0) eastern[i] else digit }.joinToString("")
    }

    private fun toEasternArabic(number: Int): String = toEasternArabic(number.toString())

    private fun calculateHijriDate(date: Date): Map<String, String> {
        val d = date.date
        val m = date.month + 1
        val y = date.year + 1900
        val a = (14 - m) / 12
        val y1 = y + 4800 - a
        val m1 = m + 12 * a - 3
        val jd = d + ((153 * m1 + 2) / 5) + 365 * y1 + (y1 / 4) - (y1 / 100) + (y1 / 400) - 32045
        val hijriEpoch = 1948439
        val daysSinceEpoch = jd - hijriEpoch
        val yearLength = 354.36667
        var hYear = (daysSinceEpoch / yearLength).toInt() + 1
        var remainingDays = daysSinceEpoch - ((hYear - 1) * yearLength).toInt()
        val cyclePosition = hYear % 30
        val isLeapYear = listOf(2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29).contains(cyclePosition)
        val monthLengths = mutableListOf(30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29)
        if (isLeapYear) monthLengths[11] = 30
        var hMonth = 1; var hDay = remainingDays
        for (i in 0 until 12) { if (hDay <= monthLengths[i]) { hMonth = i + 1; break }; hDay -= monthLengths[i] }
        val monthNamesAr = listOf("محرم","صفر","ربيع I","ربيع II","جمادى I","جمادى II","رجب","شعبان","رمضان","شوال","ذو قعدة","ذو حجة")
        val monthNamesEn = listOf("Muh.","Saf.","Rabi I","Rabi II","Jum. I","Jum. II","Raj.","Sha.","Ram.","Shaw.","Dhu Q.","Dhu H.")
        return mapOf("year" to hYear.toString(), "month" to hMonth.toString(), "day" to hDay.toString(),
            "monthAr" to monthNamesAr[hMonth - 1], "monthEn" to monthNamesEn[hMonth - 1])
    }
}

/**
 * BroadcastReceiver for Combined Prayer Widget updates + tab switching
 */
class AllPrayersWidgetReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("AllPrayersWidget", "Broadcast received, action=${intent.action}")
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val componentName = ComponentName(context, AllPrayersWidget::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

        for (appWidgetId in appWidgetIds) {
            AllPrayersWidget().updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }
}
