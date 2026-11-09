import 'dart:async';
import 'dart:io' show Platform;
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
import '../services/desktop_adhan_service.dart';
import '../services/desktop_prayer_scheduler.dart';
import '../services/desktop_tray_service.dart';
import '../services/desktop_notification_service.dart';
import '../utils/prayer_refresh.dart';
import '../utils/prayer_time_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

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

  // Input fingerprint of the last side-effects run: prayer-derived effects
  // (alarms, post-checks, widgets, native data, cache) run only when it changes.
  String? _lastFingerprint;

  // Wall-clock date (yyyy-M-d) of the last daily effects run (task digest,
  // future-record cleanup): these stay once per day.
  String? _lastDailyEffectsDate;

  // Latest side-effects run, shared by all notifier instances so a run of a
  // disposed notifier also loses to a newer notifier's run after resume.
  static int _generation = 0;

  @visibleForTesting
  static void resetGenerationForTest() => _generation = 0;

  // Wall-clock of the previous minute tick — a large gap means the machine
  // slept, which freezes Dart timers (desktop adhan timers fire late)
  DateTime _lastTickWallClock = DateTime.now();

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
      final now = DateTime.now();
      final gap = now.difference(_lastTickWallClock);
      _lastTickWallClock = now;

      // Desktop: Dart timers freeze during system sleep, so the adhan timers
      // scheduled by DesktopPrayerScheduler drift by the sleep duration.
      // A tick gap well beyond 1 minute means the machine slept — reschedule.
      if (_isDesktop && gap > const Duration(minutes: 3)) {
        debugPrint('💤 [DESKTOP] Wall-clock jump ${gap.inMinutes} min (system sleep?) — rescheduling prayer timers');
        if (state.prayerTimes.isNotEmpty) {
          DesktopPrayerScheduler.instance
              .schedulePrayerTimers(state.prayerTimes)
              .catchError((e) => debugPrint('⚠️ [DESKTOP] Reschedule after wake failed: $e'));
        }
      }

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

    if (_isDesktop) {
      DesktopTrayService.instance.updateNextPrayer(nextPrayer);
    }
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

      // Update system tray next-prayer label (desktop only, fire-and-forget)
      if (_isDesktop) {
        DesktopTrayService.instance.updateNextPrayer(nextPrayer);
      }

      // ---- SIDE EFFECTS in background (fire-and-forget) ----
      // Prayer-derived effects run only when the inputs changed (fingerprint:
      // wall-clock date, method, madhab, iqama, calculated times). Compared and
      // stored synchronously, before the async block, to prevent concurrent runs.
      final wallNow = DateTime.now();
      final todayKey = '${wallNow.year}-${wallNow.month}-${wallNow.day}';

      // Seven calendar days from the wall-clock date (today … +6), each
      // calculated for its own date. They feed the fingerprint, the native
      // cache and tomorrow's alarms. Day 0 reuses prayerTimes when it was
      // calculated for the wall-clock date (every live caller).
      final cacheDates = cacheDays(wallNow);
      final days = <List<PrayerTime>>[];
      for (final d in cacheDates) {
        if (days.isEmpty && normalizedDate == d) {
          days.add(prayerTimes);
          continue;
        }
        days.add(await _prayerTimesService.getPrayerTimes(
          date: d,
          latitude: locationData.latitude,
          longitude: locationData.longitude,
          calculationMethod: method,
          asrMadhab: madhab,
          iqamaMinutes: iqamaMinutes,
        ));
      }

      final fingerprint = sideEffectsFingerprint(
        today: cacheDates[0],
        method: method,
        madhab: madhab,
        iqama: iqamaMinutes,
        days: days,
      );
      if (fingerprint == _lastFingerprint) return; // Guard before spawning async
      _lastFingerprint = fingerprint;
      final run = ++_generation;
      // Daily effects (task digest, record cleanup) keep the once-per-day guard.
      final runDailyEffects = _lastDailyEffectsDate != todayKey;
      _lastDailyEffectsDate = todayKey;

      // Checked before each platform write: a newer run owns the writes.
      bool stale() => !isLatest(run, _generation);

      // Prayer-derived effects, in this order, each in its own try/catch:
      // widgets and desktop timers, native data (updatePrayerTimes), the cache,
      // then adhan alarms and post-checks — so a native recalculation that runs
      // in between already reads the new data.
      Future<void> prayerEffects() async {
        // Save to widget service for home screen widgets
        if (stale()) return;
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

        // Desktop: schedule timer-based adhan + notifications
        if (stale()) return;
        if (_isDesktop) {
          try {
            await DesktopAdhanService.instance.initialize();
            await DesktopPrayerScheduler.instance.schedulePrayerTimers(updatedPrayerTimes);
            debugPrint('✅ [DESKTOP] Prayer timers scheduled');
          } catch (e) {
            debugPrint('⚠️ [DESKTOP] Error scheduling prayer timers: $e');
          }
        }

        // Update foreground service notification with fresh prayer times
        if (stale()) return;
        try {
          final language = await _prefs?.getString('language') ?? 'en';
          final prayerTimesMap = <String, String>{};
          for (final p in updatedPrayerTimes) {
            final key = '${nativePrayerKey(p.name)}_time';
            prayerTimesMap[key] = p.time.millisecondsSinceEpoch.toString();
            if (p.iqamaTime != null && p.name != 'Sunrise') {
              final iqamaKey = '${nativePrayerKey(p.name)}_iqama_time';
              prayerTimesMap[iqamaKey] = p.iqamaTime!.millisecondsSinceEpoch.toString();
            }
          }
          await BackgroundServiceManager.instance.updatePrayerTimes(
            prayerTimes: prayerTimesMap,
            nextPrayerName: nextPrayer?.name,
            nextPrayerNameAr: nextPrayer?.nameAr,
            nextPrayerTime: nextPrayer?.time.millisecondsSinceEpoch,
            language: language,
            latitude: locationData.latitude,
            longitude: locationData.longitude,
            calculationMethod: method.name,
            asrMadhab: madhab.name,
          );
        } catch (e) {
          debugPrint('PrayerTimesNotifier: Error updating foreground service - $e');
        }

        // Cache seven days (today … +6) of adhan-accurate times so the native
        // recalc (00:05 alarm / foreground stale-check / WorkManager backup /
        // post-Fajr/Isha refresh) uses the exact library values instead of its
        // approximate astronomy. TODAY must be included: the post-fire recalc
        // in PrayerAlarmReceiver compares "isha < now" against these values —
        // without today's cache its own astronomy can place Isha a few minutes
        // later than the alarm that just fired, re-arming it (double adhan).
        if (stale()) return;
        if (!_isDesktop) try {
          final cache = buildNativeCache([
            for (var i = 0; i < days.length; i++) (cacheDates[i], days[i]),
          ]);
          await BackgroundServiceManager.instance.cacheAccuratePrayerTimes(cache);
        } catch (e) {
          debugPrint('PrayerTimesNotifier: Error caching future prayer times - $e');
        }

        // Schedule native alarms for adhan playback (Android only). Each prayer
        // at its next occurrence (today if ahead, else tomorrow): the new alarm
        // replaces the old one with the same request code, so no stale alarm
        // stays armed after a change and no cancel is needed.
        if (stale()) return;
        if (!_isDesktop) try {
          await PrayerAlarmService.instance.scheduleDailyPrayerAlarms(
              nextOccurrences(days[0], days[1], DateTime.now()));
        } catch (e) {
          debugPrint('PrayerTimesNotifier: Error scheduling adhan alarms - $e');
        }

        // Schedule post-prayer check alarms (Android only). Never cancelled: a
        // check whose new time + 30 min is already past keeps its old alarm.
        if (!_isDesktop) try {
          const notificationIds = {
            'Fajr': 1001, 'Sunrise': 1002, 'Zuhr': 1003,
            'Asr': 1004, 'Maghrib': 1005, 'Isha': 1006,
          };
          for (final prayer in postChecksToSchedule(days[0], DateTime.now())) {
            if (stale()) return;
            final requestCode = notificationIds[prayer.name] ?? 1000;
            await PrayerAlarmService.instance.schedulePostPrayerCheck(
              prayerName: prayer.name,
              prayerNameAr: prayer.nameAr,
              prayerTime: prayer.time,
              requestCode: requestCode,
            );
          }
        } catch (e) {
          debugPrint('PrayerTimesNotifier: Error scheduling post-prayer checks - $e');
        }
      }

      () async {
        await prayerEffects();
        if (!runDailyEffects) return;

        // Schedule daily task digest notification
        try {
          if (_isDesktop) {
            // Counts are fetched when the 8 AM timer fires — fetching here at
            // startup crashes the process (Defender blocks new exe network access)
            // and would be stale by digest time anyway.
            await DesktopNotificationService.instance.scheduleDailyTaskDigest(
              0,
              0,
              fetchCounts: () async {
                final userId = getCurrentUserId();
                if (userId.isEmpty) return const [0, 0];
                final tasks = await TaskService.instance
                    .getTasksOnce(userId: userId, limit: 500);
                final today =
                    tasks.where((t) => t.isDueToday && !t.isCompleted).length;
                final overdue =
                    tasks.where((t) => t.isOverdue && !t.isCompleted).length;
                return [today, overdue];
              },
            );
          } else {
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
          }
        } catch (e) {
          debugPrint('PrayerTimesNotifier: Error scheduling task digest - $e');
        }

        // Remove any prayer records created before the prayer's Adhan+20-min window.
        // These can only exist due to bugs — the 20-min rule blocks legitimate early marking.
        try {
          final userId = getCurrentUserId();
          if (userId.isNotEmpty) {
            await PrayerTrackingService.instance.cleanupFuturePrayerRecords(
              userId: userId,
              prayerTimes: updatedPrayerTimes,
            );
          }
        } catch (e) {
          debugPrint('PrayerTimesNotifier: Error in prayer record cleanup - $e');
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
        locationName: getLocalizedCityName(state.location?.cityName ?? '', language),
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
        final key = '${nativePrayerKey(p.name)}_time';
        prayerTimesMap[key] = p.time.millisecondsSinceEpoch.toString();
      }
      await BackgroundServiceManager.instance.updatePrayerTimes(
        prayerTimes: prayerTimesMap,
        nextPrayerName: nextPrayer?.name,
        nextPrayerNameAr: nextPrayer?.nameAr,
        nextPrayerTime: nextPrayer?.time.millisecondsSinceEpoch,
        language: language,
        // Persist coordinates + method on every refresh (not just the once-daily
        // side-effects block) so the native NativePrayerCalculator always has
        // them — without these, the morning recalc bails with "No stored
        // coordinates" and the notification sticks on "Loading prayer times...".
        latitude: state.location?.latitude,
        longitude: state.location?.longitude,
        calculationMethod: _getCalculationMethod().name,
        asrMadhab: _getAsrMadhab().name,
      );
      debugPrint('📱 [UPDATE] Foreground service updated with next prayer: ${nextPrayer?.name}');
    } catch (e) {
      debugPrint('⚠️ [UPDATE] Error updating foreground service: $e');
    }
  }

  /// Get calculation method from preferences.
  /// Handles both CalculationMethod.name format ('makkah') and
  /// AdhanCalculationMethod.value format ('UmmAlQura').
  CalculationMethod _getCalculationMethod() {
    if (_prefs == null) return CalculationMethod.muslimWorldLeague;
    return calculationMethodFromPref(_prefs!.getString('calculation_method'));
  }

  /// Get Asr Madhab from preferences ('Shafi' / 'Hanafi', any case).
  AsrMadhab _getAsrMadhab() {
    if (_prefs == null) return AsrMadhab.shafi;
    return asrMadhabFromPref(_prefs!.getString('asr_madhab'));
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
