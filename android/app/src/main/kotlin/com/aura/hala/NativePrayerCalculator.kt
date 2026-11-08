package com.aura.hala

import android.content.Context
import android.text.format.DateFormat
import android.util.Log
import com.aura.hala.adhan.CalculationMethod
import com.aura.hala.adhan.CalculationParameters
import com.aura.hala.adhan.Coordinates
import com.aura.hala.adhan.Madhab
import com.aura.hala.adhan.PrayerTimes
import com.aura.hala.adhan.data.DateComponents
import com.aura.hala.adhan.getParameters
import java.time.ZoneId
import java.util.Calendar
import java.util.Date
import java.util.TimeZone

/**
 * Pure-Kotlin prayer time calculator — no external libraries.
 * Prefers the 7 days Flutter caches (`cached_{date}_*`); otherwise calculates
 * with a line-by-line port of the adhan package (`adhan/`, FX-0).
 *
 * Called by PrayerForegroundService when it detects stale prayer times,
 * so alarms stay accurate even if the user never opens the app.
 */
object NativePrayerCalculator {

    private const val TAG = "NativePrayerCalc"

    // ── Public entry point ────────────────────────────────────────────────────

    /**
     * Calculate today's prayer times, save to aura_prayer_times, and reschedule alarms.
     * Returns true on success.
     */
    fun calculateAndSave(context: Context): Boolean {
        val prefs = context.getSharedPreferences("aura_prayer_times", Context.MODE_PRIVATE)

        val latF = prefs.getFloat("prayer_latitude", Float.MIN_VALUE)
        val lngF = prefs.getFloat("prayer_longitude", Float.MIN_VALUE)
        if (latF == Float.MIN_VALUE || lngF == Float.MIN_VALUE) {
            Log.w(TAG, "⚠️ No stored coordinates — skipping native recalculation")
            return false
        }

        val lat = latF.toDouble()
        val lng = lngF.toDouble()
        val storedMethod = prefs.getString("prayer_calc_method", "muslimWorldLeague") ?: "muslimWorldLeague"
        val methodName = if (methodParams(storedMethod) != null) storedMethod else {
            Log.w(TAG, "⚠️ Unknown method '$storedMethod' — using MWL")
            "muslimWorldLeague"
        }
        val madhabName = prefs.getString("prayer_asr_madhab", "shafi") ?: "shafi"

        return try {
            val now = System.currentTimeMillis()

            // Compute TODAY's times first, then decide if we need tomorrow's.
            // (Don't trust the stored isha_time — in the morning it's still yesterday's,
            // which would wrongly push the calculation to tomorrow.)
            // Prefer the adhan-accurate values cached by Flutter; fall back to our
            // own astronomy only when the cache is missing for that date.
            val todayCal = Calendar.getInstance()
            var times = cachedOrComputed(prefs, lat, lng, todayCal, methodName, madhabName)

            // If today's Isha has already passed (late night), calculate for tomorrow
            if (times.isha < now) {
                val tomorrowCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
                times = cachedOrComputed(prefs, lat, lng, tomorrowCal, methodName, madhabName)
            }

            val editor = prefs.edit()
            editor.putString("fajr_time",    times.fajr.toString())
            editor.putString("sunrise_time", times.sunrise.toString())
            editor.putString("dhuhr_time",   times.dhuhr.toString())
            editor.putString("asr_time",     times.asr.toString())
            editor.putString("maghrib_time", times.maghrib.toString())
            editor.putString("isha_time",    times.isha.toString())

            val next = findNext(times)
            if (next != null) {
                editor.putString("next_prayer_name",    next.name)
                editor.putString("next_prayer_name_ar", next.nameAr)
                editor.putString("next_prayer_time",    next.timeMs.toString())
            }
            editor.apply()

            Log.d(TAG, "✅ Saved: Fajr=${fmt(times.fajr)} Dhuhr=${fmt(times.dhuhr)} Isha=${fmt(times.isha)}")
            reschedule(context, times)
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ Calculation failed: ${e.message}")
            false
        }
    }

    // ── Core calculation ──────────────────────────────────────────────────────

    /** Prayer times as epoch milliseconds. */
    internal data class PrayerResult(
        val fajr: Long, val sunrise: Long, val dhuhr: Long,
        val asr: Long, val maghrib: Long, val isha: Long
    )
    private data class NextPrayer(val name: String, val nameAr: String, val timeMs: Long)

    /**
     * Prayer times for [year]-[month]-[day] with the adhan package logic, ported
     * line by line in `adhan/` (FX-0): equals the package (plus the documented
     * Umm al-Qura Dhuhr +3 min) within ±1 min, verified by
     * NativePrayerCalculatorParityTest. Times are computed in UTC and converted
     * with [zone] per instant. Makes no android.* calls (unit-tested on the JVM).
     * An unknown [method] falls back to MWL; [madhab] "hanafi" → shadow 2, else Shafi.
     */
    internal fun calculate(
        lat: Double, lng: Double, year: Int, month: Int, day: Int,
        zone: TimeZone, method: String, madhab: String
    ): PrayerResult {
        val params = methodParams(method) ?: methodParams("muslimWorldLeague")!!
        params.madhab = if (madhab == "hanafi") Madhab.hanafi else Madhab.shafi
        val times = PrayerTimes(
            Coordinates(lat, lng), DateComponents(year, month, day), params,
            ZoneId.of(zone.id)
        )
        return PrayerResult(
            fajr    = times.fajr.toInstant().toEpochMilli(),
            sunrise = times.sunrise.toInstant().toEpochMilli(),
            dhuhr   = times.dhuhr.toInstant().toEpochMilli(),
            asr     = times.asr.toInstant().toEpochMilli(),
            maghrib = times.maghrib.toInstant().toEpochMilli(),
            isha    = times.isha.toInstant().toEpochMilli(),
        )
    }

    /**
     * Package parameters for a `prayer_calc_method` contract string (the Dart
     * `CalculationMethod.name`, contracts/prefs-keys.md), or null if unknown.
     * `fixedAngle` = Egyptian parameters, `proportional` = MWL parameters, as in
     * Dart. App adjustment: Umm al-Qura (`makkah`) Dhuhr +3 min.
     */
    private fun methodParams(name: String): CalculationParameters? = when (name) {
        "muslimWorldLeague"     -> CalculationMethod.muslim_world_league.getParameters()
        "isna"                  -> CalculationMethod.north_america.getParameters()
        "egyptian"              -> CalculationMethod.egyptian.getParameters()
        "makkah"                -> CalculationMethod.umm_al_qura.getParameters()
            .also { it.adjustments.dhuhr = 3 }
        "karachi"               -> CalculationMethod.karachi.getParameters()
        "tehran"                -> CalculationMethod.tehran.getParameters()
        "kuwait"                -> CalculationMethod.kuwait.getParameters()
        "fixedAngle"            -> CalculationMethod.egyptian.getParameters()
        "proportional"          -> CalculationMethod.muslim_world_league.getParameters()
        "qatar"                 -> CalculationMethod.qatar.getParameters()
        "dubai"                 -> CalculationMethod.dubai.getParameters()
        "turkey"                -> CalculationMethod.turkey.getParameters()
        "singapore"             -> CalculationMethod.singapore.getParameters()
        "moonsightingCommittee" -> CalculationMethod.moon_sighting_committee.getParameters()
        else                    -> null
    }

    /** Prefer Flutter-cached adhan-accurate times for this date; else compute. */
    private fun cachedOrComputed(
        prefs: android.content.SharedPreferences,
        lat: Double, lng: Double, cal: Calendar,
        methodName: String, madhabName: String
    ): PrayerResult {
        readCached(prefs, cal)?.let { return it }
        val y = cal.get(Calendar.YEAR)
        val m = cal.get(Calendar.MONTH) + 1
        val d = cal.get(Calendar.DAY_OF_MONTH)
        Log.w(
            TAG, "⚠️ No cached times for $y-${m.toString().padStart(2, '0')}-" +
                "${d.toString().padStart(2, '0')} — using native fallback"
        )
        return calculate(lat, lng, y, m, d, cal.timeZone, methodName, madhabName)
    }

    /** Read cached "cached_{yyyy-MM-dd}_{name}" times for [cal]'s date, or null. */
    private fun readCached(prefs: android.content.SharedPreferences, cal: Calendar): PrayerResult? {
        val y = cal.get(Calendar.YEAR)
        val m = (cal.get(Calendar.MONTH) + 1).toString().padStart(2, '0')
        val d = cal.get(Calendar.DAY_OF_MONTH).toString().padStart(2, '0')
        val prefix = "cached_$y-$m-$d"
        val fajr = prefs.getString("${prefix}_fajr", null)?.toLongOrNull() ?: return null
        val sunrise = prefs.getString("${prefix}_sunrise", null)?.toLongOrNull() ?: return null
        val dhuhr = prefs.getString("${prefix}_dhuhr", null)?.toLongOrNull() ?: return null
        val asr = prefs.getString("${prefix}_asr", null)?.toLongOrNull() ?: return null
        val maghrib = prefs.getString("${prefix}_maghrib", null)?.toLongOrNull() ?: return null
        val isha = prefs.getString("${prefix}_isha", null)?.toLongOrNull() ?: return null
        Log.d(TAG, "✅ Using cached adhan-accurate times for $prefix")
        return PrayerResult(fajr, sunrise, dhuhr, asr, maghrib, isha)
    }

    // ── Utilities ─────────────────────────────────────────────────────────────

    private fun findNext(t: PrayerResult): NextPrayer? {
        val now = System.currentTimeMillis()
        return listOf(
            NextPrayer("Fajr",    "الفجر",  t.fajr),
            NextPrayer("Sunrise", "الشروق", t.sunrise),
            NextPrayer("Zuhr",    "الظهر",  t.dhuhr),
            NextPrayer("Asr",     "العصر",  t.asr),
            NextPrayer("Maghrib", "المغرب", t.maghrib),
            NextPrayer("Isha",    "العشاء", t.isha),
        ).firstOrNull { it.timeMs > now }
    }

    private fun reschedule(context: Context, t: PrayerResult) {
        val now = System.currentTimeMillis()
        listOf(
            Triple("Fajr",    "الفجر",  t.fajr),
            Triple("Zuhr",    "الظهر",  t.dhuhr),
            Triple("Asr",     "العصر",  t.asr),
            Triple("Maghrib", "المغرب", t.maghrib),
            Triple("Isha",    "العشاء", t.isha),
        ).forEach { (name, ar, ms) ->
            if (ms > now) {
                PrayerAlarmReceiver.schedulePrayerAlarm(
                    context, name, ar, ms,
                    PrayerAlarmReceiver.getNotificationId(name)
                )
                Log.d(TAG, "⏰ Rescheduled $name → ${fmt(ms)}")
            }
        }
    }

    private fun fmt(ms: Long) = DateFormat.format("HH:mm", Date(ms)).toString()
}
