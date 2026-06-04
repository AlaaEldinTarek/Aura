package com.aura.hala

import android.content.Context
import android.text.format.DateFormat
import android.util.Log
import java.util.Calendar
import java.util.Date
import java.util.TimeZone
import kotlin.math.*

/**
 * Pure-Kotlin prayer time calculator — no external libraries.
 * Implements the standard astronomical algorithm used by the adhan library.
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
        val methodName = prefs.getString("prayer_calc_method", "muslimWorldLeague") ?: "muslimWorldLeague"
        val madhabName = prefs.getString("prayer_asr_madhab", "shafi") ?: "shafi"

        return try {
            val now = System.currentTimeMillis()

            // Compute TODAY's times first, then decide if we need tomorrow's.
            // (Don't trust the stored isha_time — in the morning it's still yesterday's,
            // which would wrongly push the calculation to tomorrow.)
            val todayCal = Calendar.getInstance()
            var times = calculate(lat, lng, todayCal, methodName, madhabName)

            // If today's Isha has already passed (late night), calculate for tomorrow
            if (times.isha < now) {
                val tomorrowCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
                times = calculate(lat, lng, tomorrowCal, methodName, madhabName)
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

    private data class PrayerResult(
        val fajr: Long, val sunrise: Long, val dhuhr: Long,
        val asr: Long, val maghrib: Long, val isha: Long
    )
    private data class NextPrayer(val name: String, val nameAr: String, val timeMs: Long)

    private fun calculate(
        lat: Double, lng: Double, cal: Calendar,
        methodName: String, madhabName: String
    ): PrayerResult {
        val year  = cal.get(Calendar.YEAR)
        val month = cal.get(Calendar.MONTH) + 1
        val day   = cal.get(Calendar.DAY_OF_MONTH)
        val tz    = cal.timeZone.getOffset(cal.timeInMillis) / 3_600_000.0

        val jd = julianDay(year, month, day)
        val (decl, eot) = sunPosition(jd)

        // Dhuhr (solar noon in local time hours)
        val dhuhrH = 12.0 + tz - lng / 15.0 - eot

        // Half-day (sunrise/sunset offset from Dhuhr)
        val halfDay = hourAngle(lat, decl, -0.8333) // standard horizon dip

        val sunriseH  = dhuhrH - halfDay
        val sunsetH   = dhuhrH + halfDay
        val maghribH  = sunsetH  // Maghrib = sunset (all methods here)

        // Fajr / Isha angles by method
        val (fajrAngle, ishaAngle, ishaIsFixed) = methodAngles(methodName)

        // High-latitude fallback: when sun doesn't rise/set, hourAngle returns 0.
        // Use 1/7 of the half-day as a minimum offset so Fajr/Isha are never at solar noon.
        val fallback = if (halfDay > 0.0) halfDay / 7.0 else 1.0

        val fajrH: Double
        val ishaH: Double
        if (ishaIsFixed) {
            // Isha = Maghrib + fixed offset (UmmAlQura: 90 min)
            ishaH  = maghribH + ishaAngle / 60.0
            val fajrHA = hourAngle(lat, decl, fajrAngle).let { if (it == 0.0) fallback else it }
            fajrH  = dhuhrH - fajrHA
        } else {
            val fajrHA = hourAngle(lat, decl, fajrAngle).let { if (it == 0.0) fallback else it }
            val ishaHA = hourAngle(lat, decl, ishaAngle).let { if (it == 0.0) fallback else it }
            fajrH  = dhuhrH - fajrHA
            ishaH  = dhuhrH + ishaHA
        }

        // Asr (shadow ratio: Shafi = 1, Hanafi = 2)
        val shadowFactor = if (madhabName == "hanafi") 2.0 else 1.0
        val asrH = dhuhrH + asrHourAngle(lat, decl, shadowFactor)

        // Makkah (UmmAlQura): Dhuhr +3 min
        val dhuhrAdj = if (methodName == "makkah") dhuhrH + 3.0 / 60.0 else dhuhrH

        return PrayerResult(
            fajr    = toEpoch(cal, fajrH),
            sunrise = toEpoch(cal, sunriseH),
            dhuhr   = toEpoch(cal, dhuhrAdj),
            asr     = toEpoch(cal, asrH),
            maghrib = toEpoch(cal, maghribH),
            isha    = toEpoch(cal, ishaH),
        )
    }

    // ── Astronomical helpers ──────────────────────────────────────────────────

    private fun julianDay(year: Int, month: Int, day: Int): Double {
        var y = year; var m = month
        if (m <= 2) { y--; m += 12 }
        val a = floor(y / 100.0)
        val b = 2 - a + floor(a / 4.0)
        return floor(365.25 * (y + 4716)) + floor(30.6001 * (m + 1)) + day + b - 1524.5
    }

    /** Returns (declination°, equationOfTime in hours) */
    private fun sunPosition(jd: Double): Pair<Double, Double> {
        val d = jd - 2451545.0
        val g = (357.529 + 0.98560028 * d) % 360.0
        val q = (280.459 + 0.98564736 * d) % 360.0
        val l = (q + 1.915 * sin(rad(g)) + 0.020 * sin(rad(2 * g))) % 360.0
        val e = 23.439 - 0.00000036 * d
        val ra = deg(atan2(cos(rad(e)) * sin(rad(l)), cos(rad(l)))) / 15.0
        val decl = deg(asin(sin(rad(e)) * sin(rad(l))))
        val eot = q / 15.0 - normalizeHours(ra)
        return Pair(decl, eot)
    }

    /** Hour angle for a given altitude angle (negative below horizon) */
    private fun hourAngle(lat: Double, decl: Double, alt: Double): Double {
        val cosH = (sin(rad(alt)) - sin(rad(lat)) * sin(rad(decl))) /
                   (cos(rad(lat)) * cos(rad(decl)))
        if (cosH < -1.0 || cosH > 1.0) return 0.0
        return deg(acos(cosH)) / 15.0
    }

    /** Asr hour angle based on shadow factor (1=Shafi, 2=Hanafi) */
    private fun asrHourAngle(lat: Double, decl: Double, factor: Double): Double {
        val target = deg(atan(1.0 / (factor + tan(rad(abs(lat - decl))))))
        return hourAngle(lat, decl, target)
    }

    /** (fajrAngle, ishaAngle, ishaIsFixed) — positive angles = degrees below horizon */
    private fun methodAngles(method: String): Triple<Double, Double, Boolean> = when (method) {
        "makkah"       -> Triple(18.5,  90.0, true)  // Isha = Maghrib + 90 min
        "isna"         -> Triple(15.0,  15.0, false)
        "egyptian"     -> Triple(19.5,  17.5, false)
        "karachi"      -> Triple(18.0,  18.0, false)
        "tehran"       -> Triple(17.7,  14.0, false)
        "kuwait"       -> Triple(18.0,  17.5, false)
        "fixedAngle"   -> Triple(19.5,  17.5, false)
        "proportional" -> Triple(15.0,  15.0, false)
        else           -> Triple(18.0,  17.0, false)  // MWL
    }

    // ── Utilities ─────────────────────────────────────────────────────────────

    private fun rad(d: Double) = d * PI / 180.0
    private fun deg(r: Double) = r * 180.0 / PI
    private fun normalizeHours(h: Double): Double {
        var v = h % 24.0; if (v < 0) v += 24.0; return v
    }

    /** Convert fractional local hours to epoch milliseconds for the given day */
    private fun toEpoch(baseCal: Calendar, hours: Double): Long {
        val h = normalizeHours(hours)
        val c = Calendar.getInstance(baseCal.timeZone).apply {
            set(baseCal.get(Calendar.YEAR), baseCal.get(Calendar.MONTH), baseCal.get(Calendar.DAY_OF_MONTH))
            set(Calendar.HOUR_OF_DAY, h.toInt())
            set(Calendar.MINUTE, ((h - h.toInt()) * 60).toInt())
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        return c.timeInMillis
    }

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
