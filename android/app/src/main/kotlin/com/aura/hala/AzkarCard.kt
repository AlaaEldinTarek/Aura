package com.aura.hala

import android.app.PendingIntent
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Look of the post-prayer azkar notification (ids 9001-9006, channel `azkar_reminder`): a themed card with the prayer
 * icon, a title naming the prayer just finished, a calm body, the first dhikr, and one gold "Start azkar" button.
 * Follows the APP theme and language, text built here with Arabic digits, and re-applies both live while it shows.
 *
 * LOOK ONLY. The launch is untouched: [AzkarAlarmReceiver] still sets the full-screen intent, starts the activity
 * directly and keeps the content intent; the button here uses that same PendingIntent. Spec:
 * docs/designs/fix-themed-notifications.md (T6).
 */
object AzkarCard {
    private const val TAG = "AzkarAlarmReceiver"
    const val CHANNEL_ID = "azkar_reminder"

    /** Same value the receiver passes to setTimeoutAfter on the first post. */
    const val INITIAL_TIMEOUT_MS = 60_000L

    /** Full text on the lock screen (nothing private on this card). */
    const val VISIBILITY = NotificationCompat.VISIBILITY_PUBLIC

    /** The first item of the azkar screen for every prayer (see AzkarFullScreenActivity.buildAzkarList; a test guards drift). */
    const val FIRST_DHIKR_AR = "أَسْتَغْفِرُ اللَّهَ"
    const val FIRST_DHIKR_COUNT = 3

    private const val EXTRA_MARK = "aura_azkar_card"
    private const val EXTRA_PRAYER = "aura_azkar_card_prayer"
    private const val EXTRA_PRAYER_AR = "aura_azkar_card_prayer_ar"
    private const val EXTRA_POSTED_AT = "aura_azkar_card_posted_at"

    private val NOTIFICATION_IDS = 9001..9006

    private fun isZuhr(prayerName: String) = prayerName == "Dhuhr" || prayerName == "Zuhr"

    /** Prayer name as the app shows it: Zuhr on Fridays is Jumu'ah (CLAUDE.md display-name rule). */
    private fun prayerLabel(prayerName: String, prayerNameAr: String, isArabic: Boolean, isFriday: Boolean): String = when {
        isFriday && isZuhr(prayerName) -> if (isArabic) "الجمعة" else "Jumu'ah"
        isArabic -> prayerNameAr
        isZuhr(prayerName) -> "Zuhr"
        else -> prayerName
    }

    fun title(prayerName: String, prayerNameAr: String, isArabic: Boolean, isFriday: Boolean): String {
        val label = prayerLabel(prayerName, prayerNameAr, isArabic, isFriday)
        return if (isArabic) "أذكار بعد صلاة $label" else "Azkar after $label"
    }

    fun body(isArabic: Boolean): String =
        if (isArabic) "دقيقتان من الذكر بعد الصلاة 🤲" else "Two minutes of dhikr after prayer 🤲"

    fun startLabel(isArabic: Boolean): String = if (isArabic) "ابدأ الأذكار" else "Start azkar"

    fun firstDhikr(isArabic: Boolean): String {
        val count = if (isArabic) ThemedNotification.withArabicNumerals(FIRST_DHIKR_COUNT.toString()) else FIRST_DHIKR_COUNT.toString()
        return "$FIRST_DHIKR_AR ×$count"
    }

    /** A refresh keeps the original 60 s deadline: what is left of it, at least one second. */
    fun remainingTimeoutMs(postedAtMs: Long, nowMs: Long): Long = maxOf(1_000L, INITIAL_TIMEOUT_MS - (nowMs - postedAtMs))

    fun layoutId(dark: Boolean, isArabic: Boolean): Int = ThemedNotification.pickLayout(
        dark, isArabic,
        R.layout.notification_azkar, R.layout.notification_azkar_dark,
        R.layout.notification_azkar_rtl, R.layout.notification_azkar_dark_rtl
    )

    private fun isFriday(): Boolean =
        java.util.Calendar.getInstance().get(java.util.Calendar.DAY_OF_WEEK) == java.util.Calendar.FRIDAY

    /** The card's views. [startPending] is the receiver's own full-screen/content PendingIntent: no new action. */
    fun contentView(context: Context, prayerName: String, prayerNameAr: String, startPending: PendingIntent): RemoteViews {
        val isArabic = ThemedNotification.isArabic(context)
        val view = RemoteViews(context.packageName, layoutId(ThemedNotification.isDark(context), isArabic))
        view.setTextViewText(R.id.azkar_title, title(prayerName, prayerNameAr, isArabic, isFriday()))
        view.setTextViewText(R.id.azkar_body, body(isArabic))
        view.setTextViewText(R.id.azkar_dhikr, firstDhikr(isArabic))
        view.setTextViewText(R.id.btn_azkar_start, startLabel(isArabic))
        ThemedNotification.iconBitmap(context, prayerName)?.let { view.setImageViewBitmap(R.id.azkar_icon, it) }
        view.setOnClickPendingIntent(R.id.btn_azkar_start, startPending)
        return view
    }

    /** Extras that let a theme/language refresh rebuild the card. */
    fun extras(prayerName: String, prayerNameAr: String, postedAtMs: Long): Bundle = Bundle().apply {
        putBoolean(EXTRA_MARK, true)
        putString(EXTRA_PRAYER, prayerName)
        putString(EXTRA_PRAYER_AR, prayerNameAr)
        putLong(EXTRA_POSTED_AT, postedAtMs)
    }

    /**
     * Theme or language changed in the app (ThemedNotification.refreshAll): re-post the azkar card if it is showing.
     * A refresh never sets the full-screen intent and never starts the activity: it only re-skins what is on screen
     * (same id, no new sound, original `when`, what is left of the 60 s timeout).
     */
    fun refreshShowing(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            val wanted = layoutId(ThemedNotification.isDark(context), ThemedNotification.isArabic(context))
            for (sbn in nm.activeNotifications) {
                if (sbn.packageName != context.packageName || sbn.id !in NOTIFICATION_IDS) continue
                val n = sbn.notification
                if (!n.extras.getBoolean(EXTRA_MARK, false)) continue
                if (n.contentView?.layoutId == wanted) continue
                val prayerName = n.extras.getString(EXTRA_PRAYER) ?: continue
                val prayerNameAr = n.extras.getString(EXTRA_PRAYER_AR) ?: prayerName
                val postedAt = n.extras.getLong(EXTRA_POSTED_AT, System.currentTimeMillis())
                Log.d(TAG, "🤲 [AZKAR] look changed, refreshing azkar card ${sbn.id}")
                // Same target and request code as the receiver, so this is the very same PendingIntent
                val pi = PendingIntent.getActivity(
                    context,
                    AzkarAlarmReceiver.getAzkarRequestCode(prayerName),
                    AzkarFullScreenActivity.getIntent(context, prayerName, prayerNameAr),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val view = contentView(context, prayerName, prayerNameAr, pi)
                val isArabic = ThemedNotification.isArabic(context)
                val notif = NotificationCompat.Builder(context, CHANNEL_ID)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle(title(prayerName, prayerNameAr, isArabic, isFriday()))
                    .setContentText(body(isArabic))
                    .setCustomContentView(view)
                    .setCustomBigContentView(view)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .setVisibility(VISIBILITY)
                    .setAutoCancel(true)
                    .setContentIntent(pi)
                    .setOnlyAlertOnce(true)
                    .setWhen(n.`when`)
                    .setTimeoutAfter(remainingTimeoutMs(postedAt, System.currentTimeMillis()))
                    .addExtras(extras(prayerName, prayerNameAr, postedAt))
                    .build()
                NotificationManagerCompat.from(context).notify(sbn.id, notif)
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ [AZKAR] refreshShowing failed: ${e.message}")
        }
    }
}
