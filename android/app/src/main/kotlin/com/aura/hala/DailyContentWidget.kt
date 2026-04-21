package com.aura.hala

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import java.util.Calendar

class DailyContentWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) updateAppWidget(context, appWidgetManager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, DailyContentWidget::class.java))
            for (id in ids) updateAppWidget(context, manager, id)
        }
    }

    companion object {
        private const val TAG = "DailyContentWidget"

        data class ContentItem(
            val type: String,    // "ayah" or "hadith"
            val arabic: String,
            val translation: String,
            val source: String
        )

        private val CONTENT = listOf(
            ContentItem("ayah",   "إِنَّ مَعَ الْعُسْرِ يُسْرًا",                                          "Indeed, with hardship comes ease.",                                         "Ash-Sharh 94:6"),
            ContentItem("ayah",   "وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ",                      "Whoever relies upon Allah — He is sufficient for him.",                     "At-Talaq 65:3"),
            ContentItem("ayah",   "فَاذْكُرُونِي أَذْكُرْكُمْ",                                             "So remember Me; I will remember you.",                                      "Al-Baqarah 2:152"),
            ContentItem("ayah",   "وَلَا تَهِنُوا وَلَا تَحْزَنُوا وَأَنتُمُ الْأَعْلَوْنَ",              "Do not weaken and do not grieve — you will be superior.",                   "Aal-e-Imran 3:139"),
            ContentItem("ayah",   "اسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ",                                 "Seek help through patience and prayer.",                                    "Al-Baqarah 2:153"),
            ContentItem("ayah",   "وَإِذَا سَأَلَكَ عِبَادِي عَنِّي فَإِنِّي قَرِيبٌ",                    "When My servants ask about Me — indeed I am near.",                         "Al-Baqarah 2:186"),
            ContentItem("ayah",   "حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ",                                  "Allah is sufficient for us, and He is the best Disposer.",                  "Aal-e-Imran 3:173"),
            ContentItem("ayah",   "إِنَّ اللَّهَ مَعَ الصَّابِرِينَ",                                       "Indeed, Allah is with the patient.",                                        "Al-Baqarah 2:153"),
            ContentItem("ayah",   "وَقُل رَّبِّ زِدْنِي عِلْمًا",                                           "My Lord, increase me in knowledge.",                                        "Ta-Ha 20:114"),
            ContentItem("ayah",   "رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً",    "Our Lord, give us good in this world and in the Hereafter.",                "Al-Baqarah 2:201"),
            ContentItem("hadith", "إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ",                                     "Actions are judged by intentions.",                                         "Bukhari & Muslim"),
            ContentItem("hadith", "خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ",                     "The best of you learn the Quran and teach it.",                             "Bukhari"),
            ContentItem("hadith", "الْمُسْلِمُ مَنْ سَلِمَ الْمُسْلِمُونَ مِنْ لِسَانِهِ وَيَدِهِ",       "A Muslim is one from whose tongue and hand others are safe.",               "Bukhari & Muslim"),
            ContentItem("hadith", "لَا يُؤْمِنُ أَحَدُكُمْ حَتَّى يُحِبَّ لِأَخِيهِ مَا يُحِبُّ لِنَفْسِهِ", "None truly believes until he loves for his brother what he loves for himself.", "Bukhari & Muslim"),
            ContentItem("hadith", "أَحَبُّ الأَعْمَالِ إِلَى اللَّهِ أَدْوَمُهَا وَإِنْ قَلَّ",           "The most beloved deeds are those done consistently, even if small.",        "Bukhari & Muslim"),
            ContentItem("hadith", "مَنْ صَلَّى الصُّبْحَ فَهُوَ فِي ذِمَّةِ اللَّهِ",                     "Whoever prays Fajr is under the protection of Allah.",                      "Muslim"),
            ContentItem("hadith", "تَبَسُّمُكَ فِي وَجْهِ أَخِيكَ صَدَقَةٌ",                              "Your smile in the face of your brother is charity.",                        "Tirmidhi"),
            ContentItem("hadith", "مَنْ كَانَ يُؤْمِنُ بِاللَّهِ فَلْيَقُلْ خَيْرًا أَوْ لِيَصْمُتْ",   "Whoever believes in Allah, let him speak good or remain silent.",           "Bukhari & Muslim"),
            ContentItem("hadith", "إِنَّ اللَّهَ جَمِيلٌ يُحِبُّ الْجَمَالَ",                              "Indeed Allah is beautiful and loves beauty.",                               "Muslim"),
            ContentItem("hadith", "الدُّنْيَا سِجْنُ الْمُؤْمِنِ وَجَنَّةُ الْكَافِرِ",                   "The world is a prison for the believer and paradise for the disbeliever.", "Muslim")
        )

        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, id: Int) {
            val prefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)
            val language = prefs.getString("language", "en") ?: "en"
            val isArabic = language == "ar"

            val themePrefs = context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)
            val theme = themePrefs.getString("theme_mode", "system") ?: "system"
            val isDark = theme == "dark" || theme == "amoled"

            val layoutId = if (isDark) R.layout.daily_content_widget_dark else R.layout.daily_content_widget
            val views = RemoteViews(context.packageName, layoutId)

            // Rotate daily by day of year
            val dayOfYear = Calendar.getInstance().get(Calendar.DAY_OF_YEAR)
            val item = CONTENT[dayOfYear % CONTENT.size]

            val typeEmoji = if (item.type == "ayah") "\uD83D\uDCD6" else "\uD83D\uDCDC"
            val typeLabel = if (item.type == "ayah") {
                if (isArabic) "آية اليوم" else "Verse of the Day"
            } else {
                if (isArabic) "حديث اليوم" else "Hadith of the Day"
            }

            views.setTextViewText(R.id.widget_type_emoji, typeEmoji)
            views.setTextViewText(R.id.widget_type_label, typeLabel)
            views.setTextViewText(R.id.widget_source, item.source)
            views.setTextViewText(R.id.widget_arabic, item.arabic)
            views.setTextViewText(R.id.widget_translation, item.translation)

            // Tap opens app
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pi = PendingIntent.getActivity(
                    context, 0, launchIntent,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
                views.setOnClickPendingIntent(R.id.widget_root, pi)
            }

            appWidgetManager.updateAppWidget(id, views)
            Log.d(TAG, "Updated: ${item.type} | day=$dayOfYear | ${item.source}")
        }
    }
}
