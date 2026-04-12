package com.aura.hala

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.text.format.DateFormat
import android.util.Log
import android.widget.RemoteViews
import com.aura.hala.R
import java.util.Calendar
import java.util.Date

/**
 * Next Prayer Widget - Shows the next upcoming prayer time
 */
class NextPrayerWidget : AppWidgetProvider() {

    companion object {
        private const val TAG = "NextPrayerWidget"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "=== onUpdate called for ${appWidgetIds.size} widgets ===")
        Log.d(TAG, "Called from: ${Thread.currentThread().stackTrace[3].className}")
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }

        // Schedule periodic updates using AlarmManager
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

    fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        Log.d(TAG, "=== updateAppWidget START for widget $appWidgetId ===")
        Log.d(TAG, "Time: ${Date(System.currentTimeMillis())}")

        // Get prayer times from shared preferences
        val prefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)

        // Get theme mode
        val themeMode = prefs.getString("themeMode", "system") ?: "system"
        Log.d(TAG, "ThemeMode from prefs: $themeMode")

        val isDark = when (themeMode) {
            "dark" -> true
            "light" -> false
            else -> isSystemDarkTheme(context)
        }
        Log.d(TAG, "isDark result: $isDark (system=${isSystemDarkTheme(context)})")

        // Get language preference
        val language = prefs.getString("language", "en") ?: "en"
        val isArabic = language == "ar"
        Log.d(TAG, "Language: $language, isArabic: $isArabic")

        // Use appropriate layout based on theme and language (RTL for Arabic)
        val layoutId = when {
            isArabic && isDark -> R.layout.next_prayer_widget_dark_rtl
            isArabic && !isDark -> R.layout.next_prayer_widget_rtl
            !isArabic && isDark -> R.layout.next_prayer_widget_dark
            else -> R.layout.next_prayer_widget
        }
        Log.d(TAG, "Selected layout: ${context.resources.getResourceName(layoutId)}")
        val views = RemoteViews(context.packageName, layoutId)

        val nextPrayerName = prefs.getString("next_prayer_name", "Asr") ?: "Asr"
        val nextPrayerNameAr = prefs.getString("next_prayer_name_ar", "العصر") ?: "العصر"
        val nextPrayerTimeStr = prefs.getString("next_prayer_time", "0") ?: "0"
        val nextPrayerTime = nextPrayerTimeStr.toLongOrNull() ?: 0

        // Set next prayer name
        val nextPrayerDisplay = if (isArabic) nextPrayerNameAr else nextPrayerName
        views.setTextViewText(R.id.widget_next_prayer_name, nextPrayerDisplay)

        // Set next prayer time (separate time and AM/PM)
        if (nextPrayerTime > 0) {
            val date = Date(nextPrayerTime)
            val cal = Calendar.getInstance().apply { timeInMillis = nextPrayerTime }
            var hours = cal.get(Calendar.HOUR_OF_DAY)
            val minutes = cal.get(Calendar.MINUTE)
            val ampm = if (hours < 12) {
                if (isArabic) "صباحاً" else "AM"
            } else {
                if (isArabic) "مساءً" else "PM"
            }
            hours = if (hours == 0) 12 else if (hours > 12) hours - 12 else hours

            // Set time
            if (isArabic) {
                views.setTextViewText(R.id.widget_next_prayer_time, "${toEasternArabic(String.format("%02d", hours))}:${toEasternArabic(String.format("%02d", minutes))}")
            } else {
                views.setTextViewText(R.id.widget_next_prayer_time, String.format("%02d:%02d", hours, minutes))
            }

            // Set AM/PM with smaller text
            views.setTextViewText(R.id.widget_next_prayer_ampm, ampm)
        } else {
            views.setTextViewText(R.id.widget_next_prayer_time, "--:--")
            views.setTextViewText(R.id.widget_next_prayer_ampm, "")
        }

        // Set location
        val locationName = prefs.getString("location_name", null)
        if (!locationName.isNullOrEmpty()) {
            views.setTextViewText(R.id.widget_location_small, locationName)
        } else {
            views.setTextViewText(R.id.widget_location_small, "Location")
        }

        // Calculate and set time remaining
        val now = System.currentTimeMillis()
        val timeRemainingMs = nextPrayerTime - now
        val timeRemainingText = if (timeRemainingMs > 0) {
            val totalMinutes = (timeRemainingMs / 60000).toInt()
            val hours = totalMinutes / 60
            val minutes = totalMinutes % 60
            if (hours > 0) {
                if (isArabic) {
                    "${toEasternArabic(hours)} س ${toEasternArabic(minutes)} د"
                } else {
                    "$hours h $minutes m"
                }
            } else {
                if (isArabic) {
                    "${toEasternArabic(minutes)} د"
                } else {
                    "$minutes m"
                }
            }
        } else {
            if (isArabic) "الآن" else "now"
        }
        views.setTextViewText(R.id.widget_time_remaining, timeRemainingText)

        // Set seconds countdown
        val secondsText = if (timeRemainingMs > 0) {
            val seconds = (timeRemainingMs / 1000).toInt() % 60
            if (isArabic) {
                "${toEasternArabic(seconds)} ثانية"
            } else {
                "$seconds seconds"
            }
        } else {
            ""
        }
        views.setTextViewText(R.id.widget_time_remaining_seconds, secondsText)

        // Set "Next Prayer" label
        val nextPrayerLabel = if (isArabic) "الصلاة القادمة" else "Next Prayer"
        views.setTextViewText(R.id.widget_next_prayer_label, nextPrayerLabel)

        // Calculate progress bar based on time remaining
        // More time remaining = less progress (bar fills up as prayer approaches)
        val totalMinutesRemaining = (timeRemainingMs / 60000).toInt()
        val maxMinutes = 180 // 3 hours in minutes
        val progress = when {
            totalMinutesRemaining >= 120 -> 10  // 2+ hours left
            totalMinutesRemaining >= 60 -> 30  // 1-2 hours left
            totalMinutesRemaining >= 30 -> 60  // 30-60 min left
            else -> 90  // Less than 30 min
        }
        views.setProgressBar(R.id.widget_progress_bar, 100, progress, false)

        // Set date info for combined date card
        val currentDate = Date(now)

        // Day of week
        val dayOfWeek = DateFormat.format("EEEE", currentDate)
        val dayOfWeekAr = when (dayOfWeek.toString()) {
            "Monday" -> "الإثنين"
            "Tuesday" -> "الثلاثاء"
            "Wednesday" -> "الأربعاء"
            "Thursday" -> "الخميس"
            "Friday" -> "الجمعة"
            "Saturday" -> "السبت"
            "Sunday" -> "الأحد"
            else -> dayOfWeek.toString()
        }
        views.setTextViewText(R.id.widget_day_of_week, if (isArabic) dayOfWeekAr else dayOfWeek.toString())

        // Gregorian date
        val gregorianMonthEn = DateFormat.format("MMM", currentDate)
        val gregorianMonthAr = when (gregorianMonthEn.toString()) {
            "Jan" -> "يناير"
            "Feb" -> "فبراير"
            "Mar" -> "مارس"
            "Apr" -> "أبريل"
            "May" -> "مايو"
            "Jun" -> "يونيو"
            "Jul" -> "يوليو"
            "Aug" -> "أغسطس"
            "Sep" -> "سبتمبر"
            "Oct" -> "أكتوبر"
            "Nov" -> "نوفمبر"
            "Dec" -> "ديسمبر"
            else -> gregorianMonthEn.toString()
        }
        val gregorianDayOfMonth = DateFormat.format("d", currentDate)
        val gregorianYear = DateFormat.format("yyyy", currentDate)

        val gregorianDateStr = if (isArabic) {
            "${toEasternArabic(gregorianDayOfMonth.toString())} $gregorianMonthAr ${toEasternArabic(gregorianYear.toString())}"
        } else {
            "$gregorianDayOfMonth $gregorianMonthEn $gregorianYear"
        }
        views.setTextViewText(R.id.widget_gregorian_date, gregorianDateStr)

        // Hijri date - calculated dynamically
        val hijriDate = calculateHijriDate(currentDate)
        val hijriDateStr = if (isArabic) {
            "${toEasternArabic(hijriDate["day"].toString())} ${hijriDate["monthAr"]} ${toEasternArabic(hijriDate["year"].toString())}"
        } else {
            "${hijriDate["day"]} ${hijriDate["monthEn"]} ${hijriDate["year"]}"
        }
        views.setTextViewText(R.id.widget_hijri_date, hijriDateStr)

        // Create click intent to open app - make entire widget clickable
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        intent?.let {
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
        }

        // Update widget
        appWidgetManager.updateAppWidget(appWidgetId, views)

        Log.d(TAG, "Updated widget $appWidgetId: Next prayer is $nextPrayerDisplay")
    }

    private fun isSystemDarkTheme(context: Context): Boolean {
        val nightMode = context.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK
        return nightMode == android.content.res.Configuration.UI_MODE_NIGHT_YES
    }

    private fun scheduleWidgetUpdate(context: Context) {
        Log.d(TAG, "=== scheduleWidgetUpdate called ===")
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, NextPrayerWidgetReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Update every 30 seconds for accurate seconds countdown
        val interval = 30000L
        alarmManager.setRepeating(
            AlarmManager.RTC_WAKEUP,
            System.currentTimeMillis(),
            interval,
            pendingIntent
        )

        Log.d(TAG, "Scheduled widget update every $interval ms")
    }

    private fun cancelWidgetUpdate(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, NextPrayerWidgetReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
    }

    // Convert Western Arabic numerals to Eastern Arabic numerals
    private fun toEasternArabic(number: String): String {
        val western = "0123456789"
        val eastern = "٠١٢٣٤٥٦٧٨٩"
        return number.map { digit ->
            val index = western.indexOf(digit)
            if (index >= 0) eastern[index] else digit
        }.joinToString("")
    }

    // Convert Western Arabic numerals to Eastern Arabic numerals (Int version)
    private fun toEasternArabic(number: Int): String {
        return toEasternArabic(number.toString())
    }

    // Calculate Hijri date from Gregorian date
    private fun calculateHijriDate(date: Date): Map<String, String> {
        val d = date.date
        val m = date.month + 1 // Java month is 0-based
        val y = date.year + 1900 // Java year is years since 1900

        // Calculate Julian Day Number for Gregorian date
        val a = (14 - m) / 12
        val y1 = y + 4800 - a
        val m1 = m + 12 * a - 3

        val jd = d + ((153 * m1 + 2) / 5) + 365 * y1 + (y1 / 4) - (y1 / 100) + (y1 / 400) - 32045

        // Convert Julian Day to Hijri
        // Hijri epoch: July 16, 622 CE (Julian) = JD 1948439.5
        val hijriEpoch = 1948439
        val daysSinceEpoch = jd - hijriEpoch

        // Calculate Hijri year, month, day
        val yearLength = 354.36667
        var hYear = (daysSinceEpoch / yearLength).toInt() + 1
        var remainingDays = daysSinceEpoch - ((hYear - 1) * yearLength).toInt()

        // Leap years in 30-year cycle: 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29
        val cyclePosition = hYear % 30
        val isLeapYear = listOf(2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29).contains(cyclePosition)

        // Month lengths
        val monthLengths = mutableListOf(30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29)
        if (isLeapYear) {
            monthLengths[11] = 30
        }

        var hMonth = 1
        var hDay = remainingDays

        for (i in 0 until 12) {
            if (hDay <= monthLengths[i]) {
                hMonth = i + 1
                break
            }
            hDay -= monthLengths[i]
        }

        // Month names
        val monthNamesAr = listOf(
            "محرم", "صفر", "ربيع الأول", "ربيع الآخر",
            "جمادى الأولى", "جمادى الآخرة", "رجب", "شعبان",
            "رمضان", "شوال", "ذو القعدة", "ذو الحجة"
        )
        val monthNamesEn = listOf(
            "Muharram", "Safar", "Rabi al-Awwal", "Rabi al-Thani",
            "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Shaban",
            "Ramadan", "Shawwal", "Dhu al-Qadah", "Dhu al-Hijjah"
        )

        return mapOf(
            "year" to hYear.toString(),
            "month" to hMonth.toString(),
            "day" to hDay.toString(),
            "monthAr" to monthNamesAr[hMonth - 1],
            "monthEn" to monthNamesEn[hMonth - 1]
        )
    }
}

/**
 * All Prayers Widget - Shows all 5 daily prayer times
 */
class AllPrayersWidget : AppWidgetProvider() {

    companion object {
        private const val TAG = "AllPrayersWidget"
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

        // Schedule periodic updates
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

    fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        // Get prayer times from shared preferences
        val prefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)

        // Get theme mode
        val themeMode = prefs.getString("themeMode", "system") ?: "system"
        val isDark = when (themeMode) {
            "dark" -> true
            "light" -> false
            else -> isSystemDarkTheme(context)
        }

        // Get language preference
        val language = prefs.getString("language", "en") ?: "en"
        val isArabic = language == "ar"

        // Use appropriate layout based on theme and language (RTL for Arabic)
        val layoutId = when {
            isArabic && isDark -> R.layout.all_prayers_widget_dark_rtl
            isArabic && !isDark -> R.layout.all_prayers_widget_rtl
            !isArabic && isDark -> R.layout.all_prayers_widget_dark
            else -> R.layout.all_prayers_widget
        }
        val views = RemoteViews(context.packageName, layoutId)

        // Define prayers with their Arabic and English names
        val prayers = listOf(
            mapOf(
                "key" to "fajr_time",
                "nameEn" to "Fajr",
                "nameAr" to "الفجر",
                "emoji" to "🌙",
                "timeId" to R.id.widget_fajr_time,
                "nameId" to R.id.widget_fajr_name
            ),
            mapOf(
                "key" to "sunrise_time",
                "nameEn" to "Sunrise",
                "nameAr" to "الشروق",
                "emoji" to "🌅",
                "timeId" to R.id.widget_sunrise_time,
                "nameId" to R.id.widget_sunrise_name
            ),
            mapOf(
                "key" to "dhuhr_time",
                "nameEn" to "Zuhr",
                "nameAr" to "الظهر",
                "emoji" to "☀️",
                "timeId" to R.id.widget_dhuhr_time,
                "nameId" to R.id.widget_dhuhr_name
            ),
            mapOf(
                "key" to "asr_time",
                "nameEn" to "Asr",
                "nameAr" to "العصر",
                "emoji" to "🌤️",
                "timeId" to R.id.widget_asr_time,
                "nameId" to R.id.widget_asr_name
            ),
            mapOf(
                "key" to "maghrib_time",
                "nameEn" to "Maghrib",
                "nameAr" to "المغرب",
                "emoji" to "🌆",
                "timeId" to R.id.widget_maghrib_time,
                "nameId" to R.id.widget_maghrib_name
            ),
            mapOf(
                "key" to "isha_time",
                "nameEn" to "Isha",
                "nameAr" to "العشاء",
                "emoji" to "🌙",
                "timeId" to R.id.widget_isha_time,
                "nameId" to R.id.widget_isha_name
            )
        )

        // Get next prayer name and calculate current prayer (most recent that passed)
        val nextPrayerNameEn = prefs.getString("next_prayer_name", "Maghrib") ?: "Maghrib"
        val now = System.currentTimeMillis()
        val nextPrayerTimeStr = prefs.getString("next_prayer_time", "0") ?: "0"
        val nextPrayerTime = nextPrayerTimeStr.toLongOrNull() ?: 0

        // Find the most recent prayer that has passed (before the next prayer)
        var currentPrayerNameEn: String? = null
        var mostRecentTime = 0L

        for (prayer in prayers) {
            val timeStr = prefs.getString(prayer["key"] as String?, null)
            val time = timeStr?.toLongOrNull() ?: 0
            // Check if this prayer has passed and is more recent than others
            if (time > 0 && time < now && time <= nextPrayerTime && time > mostRecentTime) {
                mostRecentTime = time
                currentPrayerNameEn = prayer["nameEn"] as String
            }
        }

        // Set prayer names and times
        for (prayer in prayers) {
            val timeStr = prefs.getString(prayer["key"] as String?, null)
            val displayTime = if (!timeStr.isNullOrEmpty()) {
                val time = timeStr.toLongOrNull() ?: 0
                if (time > 0) {
                    if (isArabic) {
                        // Format time in Arabic with Eastern Arabic numerals and 12-hour format
                        val date = Date(time)
                        val cal = Calendar.getInstance().apply { timeInMillis = time }
                        var hours = cal.get(Calendar.HOUR_OF_DAY)
                        val minutes = cal.get(Calendar.MINUTE)
                        val ampm = if (hours < 12) "صباحاً" else "مساءً"
                        hours = if (hours == 0) 12 else if (hours > 12) hours - 12 else hours
                        "${toEasternArabic(String.format("%02d", hours))}:${toEasternArabic(String.format("%02d", minutes))} $ampm"
                    } else {
                        DateFormat.format("hh:mm aa", Date(time))
                    }
                } else {
                    "--:--"
                }
            } else {
                "--:--"
            }
            views.setTextViewText(prayer["timeId"] as Int, displayTime)

            // Set prayer name
            val prayerName = if (isArabic) prayer["nameAr"] else prayer["nameEn"]
            views.setTextViewText(prayer["nameId"] as Int, prayerName as String)

            // Check if this is the current prayer (most recent that passed) or next prayer
            val isCurrentPrayer = (prayer["nameEn"] as String) == currentPrayerNameEn
            val isNextPrayer = (prayer["nameEn"] as String) == nextPrayerNameEn

            // Set time color - only next prayer is blue, others are gray/inactive
            val timeColor = if (isNextPrayer) {
                if (isDark) android.graphics.Color.parseColor("#4DA6FF") else android.graphics.Color.parseColor("#007DFF")
            } else {
                android.graphics.Color.parseColor("#888888")
            }
            views.setTextColor(prayer["timeId"] as Int, timeColor)

            // Get the card view ID for this prayer
            val cardViewId = when (prayer["nameEn"] as String) {
                "Fajr" -> R.id.widget_fajr_card
                "Sunrise" -> R.id.widget_sunrise_card
                "Dhuhr", "Zuhr" -> R.id.widget_dhuhr_card
                "Asr" -> R.id.widget_asr_card
                "Maghrib" -> R.id.widget_maghrib_card
                "Isha" -> R.id.widget_isha_card
                else -> null
            }

            // Set highlight background and "now" badge for CURRENT prayer
            if (isCurrentPrayer && cardViewId != null) {
                val highlightBg = if (isDark) R.drawable.widget_prayer_card_highlight_modern_dark else R.drawable.widget_prayer_card_highlight_modern
                views.setInt(cardViewId, "setBackgroundResource", highlightBg)

                // Show "now" badge
                val nowBadgeId = when (prayer["nameEn"] as String) {
                    "Fajr" -> R.id.widget_fajr_now
                    "Sunrise" -> R.id.widget_sunrise_now
                    "Dhuhr", "Zuhr" -> R.id.widget_dhuhr_now
                    "Asr" -> R.id.widget_asr_now
                    "Maghrib" -> R.id.widget_maghrib_now
                    "Isha" -> R.id.widget_isha_now
                    else -> null
                }
                if (nowBadgeId != null) {
                    views.setViewVisibility(nowBadgeId, android.view.View.VISIBLE)
                }
            } else if (cardViewId != null) {
                // Reset to normal background
                val normalBg = if (isDark) R.drawable.widget_prayer_card_modern_dark else R.drawable.widget_prayer_card_modern
                views.setInt(cardViewId, "setBackgroundResource", normalBg)

                // Hide "now" badge
                val nowBadgeId = when (prayer["nameEn"] as String) {
                    "Fajr" -> R.id.widget_fajr_now
                    "Sunrise" -> R.id.widget_sunrise_now
                    "Dhuhr", "Zuhr" -> R.id.widget_dhuhr_now
                    "Asr" -> R.id.widget_asr_now
                    "Maghrib" -> R.id.widget_maghrib_now
                    "Isha" -> R.id.widget_isha_now
                    else -> null
                }
                if (nowBadgeId != null) {
                    views.setViewVisibility(nowBadgeId, android.view.View.GONE)
                }
            }

            // Show "next" badge for NEXT prayer
            if (isNextPrayer) {
                val nextBadgeId = when (prayer["nameEn"] as String) {
                    "Fajr" -> R.id.widget_fajr_next
                    "Sunrise" -> R.id.widget_sunrise_next
                    "Dhuhr", "Zuhr" -> R.id.widget_dhuhr_next
                    "Asr" -> R.id.widget_asr_next
                    "Maghrib" -> R.id.widget_maghrib_next
                    "Isha" -> R.id.widget_isha_next
                    else -> null
                }
                if (nextBadgeId != null) {
                    views.setViewVisibility(nextBadgeId, android.view.View.VISIBLE)
                }
            } else {
                // Hide "next" badge for all other prayers
                val nextBadgeId = when (prayer["nameEn"] as String) {
                    "Fajr" -> R.id.widget_fajr_next
                    "Sunrise" -> R.id.widget_sunrise_next
                    "Dhuhr", "Zuhr" -> R.id.widget_dhuhr_next
                    "Asr" -> R.id.widget_asr_next
                    "Maghrib" -> R.id.widget_maghrib_next
                    "Isha" -> R.id.widget_isha_next
                    else -> null
                }
                if (nextBadgeId != null) {
                    views.setViewVisibility(nextBadgeId, android.view.View.GONE)
                }
            }
        }

        // Set widget label
        val widgetLabel = if (isArabic) "مواقيت الصلاة" else "Prayer Times"
        views.setTextViewText(R.id.widget_label, widgetLabel)

        // Set location in header
        val locationName = prefs.getString("location_name", null)
        if (!locationName.isNullOrEmpty()) {
            views.setTextViewText(R.id.widget_location_small, locationName)
        }

        // Create click intent to open app - make entire widget clickable
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        intent?.let {
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
        }

        // Update widget
        appWidgetManager.updateAppWidget(appWidgetId, views)

        Log.d(TAG, "Updated all prayers widget $appWidgetId (theme: ${if(isDark) "dark" else "light"}, language: $language)")
    }

    private fun isSystemDarkTheme(context: Context): Boolean {
        val nightMode = context.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK
        return nightMode == android.content.res.Configuration.UI_MODE_NIGHT_YES
    }

    private fun scheduleWidgetUpdate(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AllPrayersWidgetReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Update every 30 seconds for accurate countdown
        val interval = 30000L
        alarmManager.setRepeating(
            AlarmManager.RTC_WAKEUP,
            System.currentTimeMillis(),
            interval,
            pendingIntent
        )

        Log.d(TAG, "Scheduled widget update every $interval ms")
    }

    private fun cancelWidgetUpdate(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AllPrayersWidgetReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
    }

    // Convert Western Arabic numerals to Eastern Arabic numerals
    private fun toEasternArabic(number: String): String {
        val western = "0123456789"
        val eastern = "٠١٢٣٤٥٦٧٨٩"
        return number.map { digit ->
            val index = western.indexOf(digit)
            if (index >= 0) eastern[index] else digit
        }.joinToString("")
    }

    // Convert Western Arabic numerals to Eastern Arabic numerals (Int version)
    private fun toEasternArabic(number: Int): String {
        return toEasternArabic(number.toString())
    }
}

/**
 * BroadcastReceiver for Next Prayer Widget updates
 */
class NextPrayerWidgetReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("NextPrayerWidget", "Broadcast received, updating widget")
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val componentName = ComponentName(context, NextPrayerWidget::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

        for (appWidgetId in appWidgetIds) {
            NextPrayerWidget().updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }
}

/**
 * BroadcastReceiver for All Prayers Widget updates
 */
class AllPrayersWidgetReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("AllPrayersWidget", "Broadcast received, updating widget")
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val componentName = ComponentName(context, AllPrayersWidget::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

        for (appWidgetId in appWidgetIds) {
            AllPrayersWidget().updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }
}
