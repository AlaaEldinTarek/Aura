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
import '../services/task_service.dart';
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

  // Cached location to avoid GPS calls every minute
  LocationData? _cachedLocation;
  DateTime? _locationCacheTime;
  static const Duration _locationCacheTTL = Duration(minutes: 15);

  // Track last side effects day to avoid re-running on same day
  String? _lastSideEffectsDate;

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

  /// Get location (cached for 15 minutes to avoid GPS lag)
  Future<LocationData> _getCachedLocation() async {
    final now = DateTime.now();
    if (_cachedLocation != null && _locationCacheTime != null) {
      final age = now.difference(_locationCacheTime!);
      if (age < _locationCacheTTL) {
        debugPrint('📍 [CACHE] Using cached location (${age.inSeconds}s old)');
        return _cachedLocation!;
      }
    }
    debugPrint('📍 [CACHE] Cache expired or empty, fetching fresh location...');
    final location = await _locationService.getBestLocation();
    _cachedLocation = location;
    _locationCacheTime = now;
    return location;
  }

  /// Start periodic timer to update next prayer every minute
  void _startNextPrayerUpdateTimer() {
    _nextPrayerUpdateTimer?.cancel();
    _nextPrayerUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!state.isLoading && state.prayerTimes.isNotEmpty) {
        // Quick update: just recalculate next/current prayer without GPS
        _quickUpdateNextPrayer();
      }
    });
    debugPrint('⏰ [TIMER] Started next prayer update timer (every minute)');
  }

  /// Quick update that only recalculates next/current prayer (no GPS, no side effects)
  void _quickUpdateNextPrayer() {
    final nextPrayer = _prayerTimesService.getNextPrayer(state.prayerTimes);
    final currentPrayer = _prayerTimesService.getCurrentPrayer(state.prayerTimes);

    // Check if next prayer is tomorrow (day transition) - need full reload
    if (nextPrayer != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final nextPrayerDate = DateTime(nextPrayer.time.year, nextPrayer.time.month, nextPrayer.time.day);
      if (nextPrayerDate.isAfter(today)) {
        debugPrint('📅 [QUICK_UPDATE] Day transition detected, doing full reload');
        loadPrayerTimes(DateTime.now());
        return;
      }
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
      // Get location (uses cache to avoid GPS every time)
      final locationData = await _getCachedLocation();

      // Use provided or saved calculation method
      final method = calculationMethod ?? _getCalculationMethod();
      final madhab = asrMadhab ?? _getAsrMadhab();

      // Load iqama settings from preferences
      final iqamaMinutes = await PrayerTimesService.loadIqamaMinutes();

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

      // ---- SIDE EFFECTS in background (fire-and-forget) ----
      // Only run once per day to avoid wasting resources every minute
      final todayKey = '${date.year}-${date.month}-${date.day}';
      if (_lastSideEffectsDate == todayKey) return; // Guard before spawning async
      _lastSideEffectsDate = todayKey; // Set synchronously to prevent concurrent runs
      () async {

        // Schedule notifications for prayer times (5-minute reminders)
        try {
          await NotificationService.instance.scheduleDailyPrayers(updatedPrayerTimes);
        } catch (e) {
          debugPrint('PrayerTimesNotifier: Error scheduling notifications - $e');
        }

        // Schedule post-prayer check notifications (after prayer time, ask if user prayed)
        try {
          await NotificationService.instance.schedulePostPrayerCheck(updatedPrayerTimes);
        } catch (e) {
          debugPrint('PrayerTimesNotifier: Error scheduling post-prayer checks - $e');
        }

        // Schedule daily 8 AM task digest notification
        try {
          final userId = getCurrentUserId();
          if (userId.isNotEmpty) {
            final tasks = await TaskService.instance.getTasksOnce(userId: userId, limit: 500);
            final today = tasks.where((t) => t.isDueToday && !t.isCompleted).length;
            final overdue = tasks.where((t) => t.isOverdue && !t.isCompleted).length;
            await NotificationService.instance.scheduleDailyTaskDigest(
              todayCount: today,
              overdueCount: overdue,
            );
          }
        } catch (e) {
          debugPrint('PrayerTimesNotifier: Error scheduling task digest - $e');
        }

        // Schedule native alarms for adhan playback at exact prayer times
        try {
          await PrayerAlarmService.instance.scheduleDailyPrayerAlarms(updatedPrayerTimes);
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
        } catch (e) {
          debugPrint('PrayerTimesNotifier: Error updating foreground service - $e');
        }
      }();
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
