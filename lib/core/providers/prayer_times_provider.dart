import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/prayer_time.dart';
import '../models/prayer_settings.dart';
import '../models/prayer_record.dart';
import '../services/prayer_times_service.dart';
import '../services/location_service.dart';
import '../services/prayer_widget_service.dart';
import '../services/notification_service.dart';
import '../services/prayer_alarm_service.dart';
import '../services/background_service_manager.dart';
import '../services/prayer_tracking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prayer times state
class PrayerTimesState {
  final List<PrayerTime> prayerTimes;
  final PrayerTime? nextPrayer;
  final PrayerTime? currentPrayer;
  final DateTime selectedDate;
  final bool isLoading;
  final String? errorMessage;
  final LocationData? location;

  const PrayerTimesState({
    this.prayerTimes = const [],
    this.nextPrayer,
    this.currentPrayer,
    required this.selectedDate,
    this.isLoading = false,
    this.errorMessage,
    this.location,
  });

  PrayerTimesState copyWith({
    List<PrayerTime>? prayerTimes,
    PrayerTime? nextPrayer,
    PrayerTime? currentPrayer,
    DateTime? selectedDate,
    bool? isLoading,
    String? errorMessage,
    LocationData? location,
  }) {
    return PrayerTimesState(
      prayerTimes: prayerTimes ?? this.prayerTimes,
      nextPrayer: nextPrayer ?? this.nextPrayer,
      currentPrayer: currentPrayer ?? this.currentPrayer,
      selectedDate: selectedDate ?? this.selectedDate,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      location: location ?? this.location,
    );
  }
}

/// Prayer times notifier
class PrayerTimesNotifier extends StateNotifier<PrayerTimesState> {
  final PrayerTimesService _prayerTimesService;
  final LocationService _locationService;
  SharedPreferences? _prefs;
  Timer? _nextPrayerUpdateTimer;

  PrayerTimesNotifier(this._prayerTimesService, this._locationService, [this._prefs])
      : super(PrayerTimesState(selectedDate: DateTime.now())) {
    // Wrap init in microtask to avoid modifying state during provider creation
    Future.microtask(() => _init());
    _startNextPrayerUpdateTimer();
  }

  @override
  void dispose() {
    _nextPrayerUpdateTimer?.cancel();
    super.dispose();
  }

  /// Start periodic timer to update next prayer every minute
  void _startNextPrayerUpdateTimer() {
    _nextPrayerUpdateTimer?.cancel();
    _nextPrayerUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!state.isLoading && state.prayerTimes.isNotEmpty) {
        // Use full refresh to handle day transitions properly
        loadPrayerTimes(DateTime.now());
      }
    });
    debugPrint('⏰ [TIMER] Started next prayer update timer (every minute)');
  }

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _loadSettingsAndPrayerTimes();
  }

  Future<void> _loadSettingsAndPrayerTimes() async {
    final calculationMethod = _getCalculationMethod();
    final asrMadhab = _getAsrMadhab();
    await loadPrayerTimes(
      DateTime.now(),
      calculationMethod: calculationMethod,
      asrMadhab: asrMadhab,
    );
  }

  Future<void> loadPrayerTimes(
    DateTime date, {
    CalculationMethod? calculationMethod,
    AsrMadhab? asrMadhab,
  }) async {
    final now = DateTime.now();
    debugPrint('🔄 [PRAYER_TIMES] Loading prayer times for ${DateTime(date.year, date.month, date.day)} (current time: $now)');

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Get location
      final locationData = await _locationService.getBestLocation();

      // Use provided or saved calculation method
      final method = calculationMethod ?? _getCalculationMethod();
      final madhab = asrMadhab ?? _getAsrMadhab();

      // Load iqama settings from preferences
      final iqamaMinutes = await PrayerTimesService.loadIqamaMinutes();
      debugPrint('🕌 [PRAYER] Using iqama minutes: $iqamaMinutes');

      // Get prayer times with iqama settings
      final prayerTimes = await _prayerTimesService.getPrayerTimes(
        date: date,
        latitude: locationData.latitude,
        longitude: locationData.longitude,
        calculationMethod: method,
        asrMadhab: madhab,
        iqamaMinutes: iqamaMinutes,
      );

      // Get next and current prayer
      final nextPrayer = _prayerTimesService.getNextPrayer(prayerTimes);
      final currentPrayer = _prayerTimesService.getCurrentPrayer(prayerTimes);

      debugPrint('🕌 [PRAYER_TIMES] Next prayer determined: ${nextPrayer?.name} at ${nextPrayer?.time}');
      debugPrint('🕌 [PRAYER_TIMES] Current prayer: ${currentPrayer?.name}');

      // Update next/current flags
      final updatedPrayerTimes = prayerTimes.map((p) {
        return p.copyWith(
          isNext: nextPrayer?.name == p.name,
          isCurrent: currentPrayer?.name == p.name,
        );
      }).toList();

      final normalizedDate = DateTime(date.year, date.month, date.day);

      state = PrayerTimesState(
        prayerTimes: updatedPrayerTimes,
        nextPrayer: nextPrayer,
        currentPrayer: currentPrayer,
        selectedDate: normalizedDate,
        isLoading: false,
        location: locationData,
      );

      debugPrint('PrayerTimesNotifier: Loaded ${prayerTimes.length} prayer times');
      debugPrint('  Location: ${locationData.cityName}');
      debugPrint('  Next prayer: ${nextPrayer?.name} at ${nextPrayer?.time}');
      debugPrint('  Current prayer: ${currentPrayer?.name} at ${currentPrayer?.time}');

      // Schedule notifications for prayer times (5-minute reminders)
      try {
        await NotificationService.instance.scheduleDailyPrayers(updatedPrayerTimes);
        debugPrint('PrayerTimesNotifier: Scheduled 5-minute reminder notifications');
      } catch (e) {
        debugPrint('PrayerTimesNotifier: Error scheduling notifications - $e');
      }

      // Schedule prayer check reminders (30 min before prayer, check if previous was done)
      try {
        await PrayerTrackingService.instance.initialize();
        final summary = await PrayerTrackingService.instance.getDailySummary(
          userId: getCurrentUserId(),
          date: DateTime.now(),
        );
        final completedPrayers = <String, bool>{};
        for (final entry in summary.prayers.entries) {
          completedPrayers[entry.key] = entry.value != PrayerStatus.missed;
        }
        await NotificationService.instance.schedulePrayerCheckReminders(
          updatedPrayerTimes,
          completedPrayers,
        );
        debugPrint('PrayerTimesNotifier: Scheduled prayer check reminders');
      } catch (e) {
        debugPrint('PrayerTimesNotifier: Error scheduling prayer check reminders - $e');
      }

      // Schedule native alarms for adhan playback at exact prayer times
      try {
        await PrayerAlarmService.instance.scheduleDailyPrayerAlarms(updatedPrayerTimes);
        debugPrint('PrayerTimesNotifier: Scheduled native adhan alarms');
      } catch (e) {
        debugPrint('PrayerTimesNotifier: Error scheduling adhan alarms - $e');
      }

      // Save to widget service for home screen widgets
      try {
        final language = await _prefs?.getString('language') ?? 'en';
        final localizedCityName = getLocalizedCityName(locationData.cityName, language);
        await PrayerWidgetService.instance.savePrayerTimes(
          prayerTimes: updatedPrayerTimes,
          nextPrayer: nextPrayer,
          currentPrayer: currentPrayer,
          language: language,
          locationName: localizedCityName,
        );
      } catch (e) {
        debugPrint('PrayerTimesNotifier: Error saving to widget service - $e');
      }

      // Update foreground service notification with fresh prayer times
      try {
        final language = await _prefs?.getString('language') ?? 'en';
        final prayerTimesMap = <String, String>{};
        for (final p in updatedPrayerTimes) {
          final key = '${p.name.toLowerCase()}_time';
          prayerTimesMap[key] = p.time.millisecondsSinceEpoch.toString();
        }
        await BackgroundServiceManager.instance.updatePrayerTimes(
          prayerTimes: prayerTimesMap,
          nextPrayerName: nextPrayer?.name,
          nextPrayerNameAr: nextPrayer?.nameAr,
          nextPrayerTime: nextPrayer?.time.millisecondsSinceEpoch,
          language: language,
        );
        debugPrint('PrayerTimesNotifier: Updated foreground service with next prayer: ${nextPrayer?.name}');
      } catch (e) {
        debugPrint('PrayerTimesNotifier: Error updating foreground service - $e');
      }
    } catch (e) {
      debugPrint('PrayerTimesNotifier: Error loading prayer times: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> updateNextPrayer() async {
    if (state.prayerTimes.isEmpty) return;

    final nextPrayer = _prayerTimesService.getNextPrayer(state.prayerTimes);
    final currentPrayer = _prayerTimesService.getCurrentPrayer(state.prayerTimes);

    // Check if next prayer is on a different day (tomorrow's Fajr)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextPrayerDate = nextPrayer != null
        ? DateTime(nextPrayer!.time.year, nextPrayer!.time.month, nextPrayer!.time.day)
        : today;

    // If next prayer is tomorrow, reload prayer times for the new day
    if (nextPrayerDate.isAfter(today)) {
      debugPrint('📅 [UPDATE] Next prayer is tomorrow, reloading prayer times for new day');
      await loadPrayerTimes(nextPrayer!.time);
      return;
    }

    final updatedPrayerTimes = state.prayerTimes.map((p) {
      return p.copyWith(
        isNext: nextPrayer?.name == p.name,
        isCurrent: currentPrayer?.name == p.name,
      );
    }).toList();

    state = state.copyWith(
      prayerTimes: updatedPrayerTimes,
      nextPrayer: nextPrayer,
      currentPrayer: currentPrayer,
    );

    // Update widgets with new next prayer
    try {
      final language = await _prefs?.getString('language') ?? 'en';
      await PrayerWidgetService.instance.savePrayerTimes(
        prayerTimes: updatedPrayerTimes,
        nextPrayer: nextPrayer,
        language: language,
        locationName: state.location?.cityName,
      );
      debugPrint('📱 [UPDATE] Widgets updated with next prayer: ${nextPrayer?.name}');
    } catch (e) {
      debugPrint('⚠️ [UPDATE] Error updating widgets: $e');
    }

    // Update foreground service with new next prayer
    try {
      final language = await _prefs?.getString('language') ?? 'en';
      final prayerTimesMap = <String, String>{};
      for (final p in updatedPrayerTimes) {
        final key = '${p.name.toLowerCase()}_time';
        prayerTimesMap[key] = p.time.millisecondsSinceEpoch.toString();
      }
      await BackgroundServiceManager.instance.updatePrayerTimes(
        prayerTimes: prayerTimesMap,
        nextPrayerName: nextPrayer?.name,
        nextPrayerNameAr: nextPrayer?.nameAr,
        nextPrayerTime: nextPrayer?.time.millisecondsSinceEpoch,
        language: language,
      );
      debugPrint('📱 [UPDATE] Foreground service updated with next prayer: ${nextPrayer?.name}');
    } catch (e) {
      debugPrint('⚠️ [UPDATE] Error updating foreground service: $e');
    }
  }

  /// Get calculation method from preferences
  CalculationMethod _getCalculationMethod() {
    if (_prefs == null) return CalculationMethod.muslimWorldLeague;
    final methodString = _prefs!.getString('calculation_method') ?? 'muslimWorldLeague';
    return CalculationMethod.values.firstWhere(
      (m) => m.name == methodString,
      orElse: () => CalculationMethod.muslimWorldLeague,
    );
  }

  /// Get Asr Madhab from preferences
  AsrMadhab _getAsrMadhab() {
    if (_prefs == null) return AsrMadhab.shafi;
    final madhabString = _prefs!.getString('asr_madhab') ?? 'shafi';
    return AsrMadhab.values.firstWhere(
      (m) => m.name == madhabString,
      orElse: () => AsrMadhab.shafi,
    );
  }

  /// Save calculation method
  Future<void> setCalculationMethod(CalculationMethod method) async {
    if (_prefs != null) {
      await _prefs!.setString('calculation_method', method.name);
      await _loadSettingsAndPrayerTimes();
    }
  }

  /// Save Asr Madhab
  Future<void> setAsrMadhab(AsrMadhab madhab) async {
    if (_prefs != null) {
      await _prefs!.setString('asr_madhab', madhab.name);
      await _loadSettingsAndPrayerTimes();
    }
  }
}

/// Provider for prayer times service
final prayerTimesServiceProvider = Provider<PrayerTimesService>((ref) {
  return PrayerTimesService();
});

/// Provider for location service
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService.instance;
});

/// Provider for prayer times state
final prayerTimesProvider = StateNotifierProvider<PrayerTimesNotifier, PrayerTimesState>((ref) {
  final prayerTimesService = ref.watch(prayerTimesServiceProvider);
  final locationService = ref.watch(locationServiceProvider);

  return PrayerTimesNotifier(prayerTimesService, locationService);
});
