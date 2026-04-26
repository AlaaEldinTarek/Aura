import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_time.dart';
import '../models/prayer_settings.dart';

/// Service for calculating Islamic prayer times
/// Uses the Adhan library for accurate calculations
class PrayerTimesService {
  PrayerTimesService();

  // SharedPreferences key for iqama settings
  static const String _iqamaPrefsKey = 'iqama_minutes';

  /// Load iqama minutes from SharedPreferences
  static Future<Map<String, int>> loadIqamaMinutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString(_iqamaPrefsKey);

      if (savedData != null) {
        final Map<String, int> iqamaMap = {};
        savedData.split(',').forEach((pair) {
          final parts = pair.split(':');
          if (parts.length == 2) {
            final key = parts[0].trim();
            final value = int.tryParse(parts[1].trim());
            if (value != null) {
              iqamaMap[key] = value;
            }
          }
        });

        debugPrint('✅ [IQAMA] Loaded from prefs: $iqamaMap');
        return iqamaMap;
      }
    } catch (e) {
      debugPrint('❌ [IQAMA] Error loading: $e');
    }

    // Return default values if nothing saved
    final defaults = {
      'Fajr': 15,
      'Zuhr': 15,
      'Asr': 15,
      'Maghrib': 5,
      'Isha': 15,
    };
    debugPrint('📋 [IQAMA] Using defaults: $defaults');
    return defaults;
  }

  /// Calculate prayer times for a specific date and location
  Future<List<PrayerTime>> getPrayerTimes({
    required DateTime date,
    required double latitude,
    required double longitude,
    CalculationMethod calculationMethod = CalculationMethod.muslimWorldLeague,
    AsrMadhab asrMadhab = AsrMadhab.shafi,
    Map<String, int>? iqamaMinutes, // Custom iqama minutes per prayer
  }) async {
    // Create coordinates
    final coordinates = adhan.Coordinates(latitude, longitude);

    // Map custom CalculationMethod enum to Adhan library's CalculationMethod
    final adhanCalculationMethod = _mapToAdhanCalculationMethod(calculationMethod);
    final params = adhanCalculationMethod.getParameters();

    // Map custom AsrMadhab enum to Adhan library's Madhab
    params.madhab = _mapToAdhanMadhab(asrMadhab);

    // Calculate prayer times for today
    final prayerTimesForDate = adhan.PrayerTimes.today(coordinates, params);

    // Calculate the difference in days between the requested date and today
    final today = DateTime.now();
    final requestedDate = DateTime(date.year, date.month, date.day);
    final todayDate = DateTime(today.year, today.month, today.day);
    final daysDifference = requestedDate.difference(todayDate).inDays;

    // Debug logging
    debugPrint('PRAYER TIMES: Calculating for date: $requestedDate (days from today: $daysDifference)');
    debugPrint('PRAYER TIMES: Calculation method: ${calculationMethod.name}, Madhab: ${asrMadhab.name}');
    debugPrint('PRAYER TIMES: Location: $latitude, $longitude');

    // Adjust prayer times by the day difference and convert to local
    DateTime adjustByDays(DateTime time, int days) {
      return time.add(Duration(days: days));
    }

    // Convert each prayer time to local time if it's in UTC
    DateTime toLocalTime(DateTime utcTime) {
      if (utcTime.isUtc) {
        return utcTime.toLocal();
      }
      return utcTime;
    }

    // Adjust prayer times by the day difference and convert to local
    final fajrLocal = toLocalTime(adjustByDays(prayerTimesForDate.fajr, daysDifference));
    final dhuhrLocal = toLocalTime(adjustByDays(prayerTimesForDate.dhuhr, daysDifference));
    final asrLocal = toLocalTime(adjustByDays(prayerTimesForDate.asr, daysDifference));
    final maghribLocal = toLocalTime(adjustByDays(prayerTimesForDate.maghrib, daysDifference));
    final ishaLocal = toLocalTime(adjustByDays(prayerTimesForDate.isha, daysDifference));
    final sunriseLocal = toLocalTime(adjustByDays(prayerTimesForDate.sunrise, daysDifference));

    debugPrint('PRAYER TIMES: Local times for $requestedDate:');
    debugPrint('  - Fajr: $fajrLocal');
    debugPrint('  - Sunrise: $sunriseLocal');
    debugPrint('  - Zuhr: $dhuhrLocal');
    debugPrint('  - Asr: $asrLocal');
    debugPrint('  - Maghrib: $maghribLocal');
    debugPrint('  - Isha: $ishaLocal');

    // Default iqama minutes (can be customized)
    final defaultIqamaMinutes = {
      'Fajr': 15,
      'Zuhr': 15,
      'Maghrib': 5, // Usually shorter after maghrib
      'Isha': 15,
    };

    // Use custom iqama minutes if provided, otherwise use defaults
    final iqama = iqamaMinutes ?? defaultIqamaMinutes;

    return [
      PrayerTime(
        name: 'Fajr',
        nameAr: 'الفجر',
        time: fajrLocal,
        iqamaTime: fajrLocal.add(Duration(minutes: iqama['Fajr'] ?? 15)),
      ),
      PrayerTime(
        name: 'Sunrise',
        nameAr: 'الشروق',
        time: sunriseLocal,
        iqamaTime: null, // No iqama for sunrise
      ),
      PrayerTime(
        name: 'Zuhr',
        nameAr: 'الظهر',
        time: dhuhrLocal,
        iqamaTime: dhuhrLocal.add(Duration(minutes: iqama['Zuhr'] ?? 15)),
      ),
      PrayerTime(
        name: 'Asr',
        nameAr: 'العصر',
        time: asrLocal,
        iqamaTime: asrLocal.add(Duration(minutes: iqama['Asr'] ?? 15)),
      ),
      PrayerTime(
        name: 'Maghrib',
        nameAr: 'المغرب',
        time: maghribLocal,
        iqamaTime: maghribLocal.add(Duration(minutes: iqama['Maghrib'] ?? 5)),
      ),
      PrayerTime(
        name: 'Isha',
        nameAr: 'العشاء',
        time: ishaLocal,
        iqamaTime: ishaLocal.add(Duration(minutes: iqama['Isha'] ?? 15)),
      ),
    ];
  }

  /// Get the next prayer time from a list of prayer times
  PrayerTime? getNextPrayer(List<PrayerTime> prayerTimes) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    debugPrint('🔍 [GET_NEXT_PRAYER] Current time: $now, Today: $today');
    debugPrint('🔍 [GET_NEXT_PRAYER] Checking ${prayerTimes.length} prayer times...');

    // Sort by time
    final sortedPrayers = List<PrayerTime>.from(prayerTimes);
    sortedPrayers.sort((a, b) => a.time.compareTo(b.time));

    // Find the next prayer that is actually in the future
    for (final prayer in sortedPrayers) {
      final isAfter = prayer.time.isAfter(now);
      debugPrint('  - ${prayer.name}: ${prayer.time} (isAfter: $isAfter)');

      // Only return prayers that are actually in the future
      if (isAfter) {
        debugPrint('✅ [GET_NEXT_PRAYER] Found next prayer: ${prayer.name} at ${prayer.time}');
        return prayer;
      }
    }

    // If all prayers in the list have passed, next prayer is Fajr tomorrow
    if (sortedPrayers.isNotEmpty) {
      final fajr = sortedPrayers.firstWhere(
        (p) => p.name == 'Fajr',
        orElse: () => sortedPrayers.first,
      );

      // IMPORTANT: Use NOW (current time) to calculate tomorrow's Fajr
      // NOT the stored fajr.time which could be from a previous day
      final tomorrow = today.add(const Duration(days: 1));
      final fajrTimeTomorrow = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        fajr.time.hour,
        fajr.time.minute,
      );

      debugPrint('⚠️ [GET_NEXT_PRAYER] All prayers passed. Next: Fajr tomorrow at $fajrTimeTomorrow');

      return PrayerTime(
        name: fajr.name,
        nameAr: fajr.nameAr,
        time: fajrTimeTomorrow,
      );
    }

    debugPrint('❌ [GET_NEXT_PRAYER] No prayer times available');
    return null;
  }

  /// Get the current prayer (the one that just passed or is currently happening)
  /// Current means: between adhan and iqama time
  PrayerTime? getCurrentPrayer(List<PrayerTime> prayerTimes) {
    final now = DateTime.now();

    for (final prayer in prayerTimes) {
      if (prayer.name == 'Sunrise') continue; // Skip Sunrise for current prayer

      // Check if current time is between adhan and iqama
      // If iqama is not set, use 15 minutes after adhan as default
      final iqamaEnd = prayer.iqamaTime ?? prayer.time.add(const Duration(minutes: 15));

      if (now.isAfter(prayer.time) && now.isBefore(iqamaEnd)) {
        return prayer; // Currently in prayer window
      } else if (prayer.time.isAfter(now)) {
        // Prayer time is in the future, stop checking
        break;
      }
    }

    // No prayer is currently in its window (all iqama times have passed)
    return null;
  }

  /// Maps custom CalculationMethod enum to Adhan library's CalculationMethod
  adhan.CalculationMethod _mapToAdhanCalculationMethod(CalculationMethod method) {
    switch (method) {
      case CalculationMethod.muslimWorldLeague:
        return adhan.CalculationMethod.muslim_world_league;
      case CalculationMethod.isna:
        return adhan.CalculationMethod.north_america;
      case CalculationMethod.egyptian:
        return adhan.CalculationMethod.egyptian;
      case CalculationMethod.makkah:
        return adhan.CalculationMethod.umm_al_qura;
      case CalculationMethod.karachi:
        return adhan.CalculationMethod.karachi;
      case CalculationMethod.tehran:
        return adhan.CalculationMethod.tehran;
      case CalculationMethod.kuwait:
        return adhan.CalculationMethod.kuwait;
      case CalculationMethod.fixedAngle:
        // Fixed angle - use Egyptian with custom params
        return adhan.CalculationMethod.egyptian;
      case CalculationMethod.proportional:
        // Proportional - use MWL
        return adhan.CalculationMethod.muslim_world_league;
    }
  }

  /// Maps custom AsrMadhab enum to Adhan library's Madhab
  adhan.Madhab _mapToAdhanMadhab(AsrMadhab madhab) {
    switch (madhab) {
      case AsrMadhab.shafi:
        return adhan.Madhab.shafi;
      case AsrMadhab.hanafi:
        return adhan.Madhab.hanafi;
    }
  }

  /// Calculate time remaining until a prayer
  String getTimeRemaining(DateTime prayerTime) {
    final now = DateTime.now();
    final difference = prayerTime.difference(now);

    if (difference.isNegative) {
      return 'Passed';
    }

    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
