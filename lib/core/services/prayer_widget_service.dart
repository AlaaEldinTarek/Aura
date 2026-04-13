import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_time.dart';
import 'background_service_manager.dart';

/// Service for managing home screen widget data
/// Sends prayer times to Android widgets via MethodChannel
class PrayerWidgetService {
  PrayerWidgetService._();

  static PrayerWidgetService? _instance;
  SharedPreferences? _prefs;
  static const _widgetChannel = MethodChannel('com.aura.hala/widgets');

  static PrayerWidgetService get instance {
    _instance ??= PrayerWidgetService._();
    return _instance!;
  }

  /// Initialize the service
  static Future<PrayerWidgetService> init() async {
    _instance ??= PrayerWidgetService._();
    _instance!._prefs = await SharedPreferences.getInstance();
    return _instance!;
  }

  /// Save prayer times to Android widgets via MethodChannel
  Future<void> savePrayerTimes({
    required List<PrayerTime> prayerTimes,
    required PrayerTime? nextPrayer,
    PrayerTime? currentPrayer,
    required String language,
    String? locationName,
  }) async {
    try {
      // Build prayer times map
      final Map<String, String> prayerTimesMap = {};
      for (final prayer in prayerTimes) {
        final timeKey = _getTimeKey(prayer.name);
        prayerTimesMap[timeKey] = prayer.time.millisecondsSinceEpoch.toString();
      }

      // Get theme mode from SharedPreferences
      final themeMode = _prefs?.getString('theme_mode') ?? 'system';

      // Send to Android via MethodChannel for widgets
      final args = <String, dynamic>{
        'prayerTimes': prayerTimesMap,
        'nextPrayerName': nextPrayer?.name,
        'nextPrayerNameAr': nextPrayer?.nameAr,
        'nextPrayerTime': nextPrayer?.time.millisecondsSinceEpoch,
        'currentPrayerName': currentPrayer?.name,
        'currentPrayerNameAr': currentPrayer?.nameAr,
        'language': language,
        'locationName': locationName ?? 'Unknown',
        'themeMode': themeMode,
      };

      await _widgetChannel.invokeMethod('updatePrayerWidgets', args);

      debugPrint('📱 WidgetService: Sent ${prayerTimes.length} prayer times to Android widgets');
      debugPrint('  Next prayer: ${nextPrayer?.name} at ${nextPrayer?.time}');
      debugPrint('  Current prayer: ${currentPrayer?.name} at ${currentPrayer?.time}');
      debugPrint('  Location sent to widget: "$locationName"');
      debugPrint('  Theme mode: $themeMode');

      // Also update the background service notification
      await BackgroundServiceManager.instance.updatePrayerTimes(
        prayerTimes: prayerTimesMap,
        nextPrayerName: nextPrayer?.name,
        nextPrayerNameAr: nextPrayer?.nameAr,
        nextPrayerTime: nextPrayer?.time.millisecondsSinceEpoch,
        language: language,
      );
      debugPrint('📱 WidgetService: Also updated background service notification');
    } catch (e) {
      debugPrint('📱 WidgetService: Error sending prayer times - $e');
    }
  }

  /// Get the storage key for a prayer time
  String _getTimeKey(String prayerName) {
    switch (prayerName.toLowerCase()) {
      case 'fajr':
        return 'fajr_time';
      case 'sunrise':
        return 'sunrise_time';
      case 'dhuhr':
      case 'zuhr':
        return 'dhuhr_time';
      case 'asr':
        return 'asr_time';
      case 'maghrib':
        return 'maghrib_time';
      case 'isha':
        return 'isha_time';
      default:
        return '${prayerName.toLowerCase()}_time';
    }
  }
}
