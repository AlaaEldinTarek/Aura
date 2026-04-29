import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/shared_preferences_service.dart';
import '../services/firestore_service.dart';
import '../services/prayer_widget_service.dart';
import '../services/task_widget_service.dart';
import '../services/prayer_alarm_service.dart';
import 'auth_provider.dart';
import 'prayer_times_provider.dart';

// Theme Mode Provider
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AsyncValue<String>>((ref) {
  final prefsService = ref.watch(sharedPreferencesServiceProvider);
  final firestoreService = ref.watch(firestoreServiceProvider);
  return ThemeModeNotifier(prefsService, firestoreService, ref);
});

class ThemeModeNotifier extends StateNotifier<AsyncValue<String>> {
  final SharedPreferencesService _prefsService;
  final FirestoreService _firestoreService;
  final Ref _ref;

  ThemeModeNotifier(this._prefsService, this._firestoreService, this._ref)
      : super(const AsyncValue.data('system')) {
    _init();
  }

  Future<void> _init() async {
    try {
      final themeMode = await _prefsService.getThemeMode();
      state = AsyncValue.data(themeMode);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setThemeMode(String value) async {
    try {
      await _prefsService.setThemeMode(value);
      state = AsyncValue.data(value);

      // Update widgets with new theme immediately
      try {
        final prayerWidgetService = PrayerWidgetService.instance;
        final prayerTimesNotifier = _ref.read(prayerTimesProvider.notifier);

        // Get current prayer times
        final currentState = prayerTimesNotifier.state;
        if (currentState.prayerTimes.isNotEmpty) {
          // Get current language preference
          final language = await _prefsService.getLanguage();
          await prayerWidgetService.savePrayerTimes(
            prayerTimes: currentState.prayerTimes,
            nextPrayer: currentState.nextPrayer,
            currentPrayer: currentState.currentPrayer,
            language: language,
            locationName: currentState.location?.cityName,
          );
          debugPrint('📱 Widgets updated with new theme: $value');
        }
        try {
          await TaskWidgetService.instance.refreshWidget();
        } catch (_) {}
      } catch (e) {
        debugPrint('⚠️ Error updating widgets with new theme: $e');
      }

      // Sync to Firestore in background if user is logged in
      final user = _ref.read(currentUserProvider);
      if (user != null) {
        try {
          await _firestoreService.updateUserFields(
            user.uid,
            {'themeMode': value},
          ).timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              debugPrint('⏱️ Firestore sync timeout (3s) - continuing with local data only');
            },
          );
        } catch (e, st) {
          debugPrint('⚠️ Firestore sync failed: $e');
          debugPrint('📍 Stack trace: $st');
        }
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

// Language Provider
final languageProvider =
    StateNotifierProvider<LanguageNotifier, AsyncValue<String>>((ref) {
  final prefsService = ref.watch(sharedPreferencesServiceProvider);
  final firestoreService = ref.watch(firestoreServiceProvider);
  return LanguageNotifier(prefsService, firestoreService, ref);
});

class LanguageNotifier extends StateNotifier<AsyncValue<String>> {
  final SharedPreferencesService _prefsService;
  final FirestoreService _firestoreService;
  final Ref _ref;

  LanguageNotifier(this._prefsService, this._firestoreService, this._ref)
      : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final language = await _prefsService.getLanguage();
      state = AsyncValue.data(language);
      debugPrint('🌐 Language loaded from preferences: $language');
    } catch (e, st) {
      debugPrint('❌ Error loading language: $e');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setLanguage(String value) async {
    try {
      await _prefsService.setLanguage(value);
      state = AsyncValue.data(value);

      // Update widgets and notification with new language immediately
      try {
        // Import to avoid circular dependency
        final prayerWidgetService = PrayerWidgetService.instance;
        final prayerTimesNotifier = _ref.read(prayerTimesProvider.notifier);

        // Get current prayer times
        final currentState = prayerTimesNotifier.state;
        if (currentState.prayerTimes.isNotEmpty) {
          await prayerWidgetService.savePrayerTimes(
            prayerTimes: currentState.prayerTimes,
            nextPrayer: currentState.nextPrayer,
            currentPrayer: currentState.currentPrayer,
            language: value,
            locationName: currentState.location?.cityName,
          );
          debugPrint('📱 Widgets and notification updated with new language: $value');
        }
        try {
          await TaskWidgetService.instance.refreshWidget();
        } catch (_) {}
      } catch (e) {
        debugPrint('⚠️ Error updating widgets with new language: $e');
      }

      // Sync to Firestore in background if user is logged in
      final user = _ref.read(currentUserProvider);
      if (user != null) {
        try {
          await _firestoreService.updateUserFields(
            user.uid,
            {'language': value},
          ).timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              debugPrint('⏱️ Firestore sync timeout (3s) - continuing with local data only');
            },
          );
        } catch (e, st) {
          debugPrint('⚠️ Firestore sync failed: $e');
          debugPrint('📍 Stack trace: $st');
        }
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

// First Launch Provider
final firstLaunchProvider =
    StateNotifierProvider<FirstLaunchNotifier, AsyncValue<bool>>((ref) {
  final prefsService = ref.watch(sharedPreferencesServiceProvider);
  return FirstLaunchNotifier(prefsService);
});

// Guest Mode Provider
final guestModeProvider =
    StateNotifierProvider<GuestModeNotifier, AsyncValue<bool>>((ref) {
  final prefsService = ref.watch(sharedPreferencesServiceProvider);
  return GuestModeNotifier(prefsService);
});

class FirstLaunchNotifier extends StateNotifier<AsyncValue<bool>> {
  final SharedPreferencesService _prefsService;

  FirstLaunchNotifier(this._prefsService)
      : super(const AsyncValue.data(true)) {
    _init();
  }

  Future<void> _init() async {
    try {
      final isFirstLaunch = await _prefsService.isFirstLaunch();
      state = AsyncValue.data(isFirstLaunch);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setFirstLaunch(bool value) async {
    state = const AsyncValue.loading();
    try {
      await _prefsService.setFirstLaunch(value);
      state = AsyncValue.data(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

class GuestModeNotifier extends StateNotifier<AsyncValue<bool>> {
  final SharedPreferencesService _prefsService;

  GuestModeNotifier(this._prefsService)
      : super(const AsyncValue.data(false)) {
    _init();
  }

  Future<void> _init() async {
    try {
      final isGuest = await _prefsService.isGuest();
      state = AsyncValue.data(isGuest);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setGuest(bool value) async {
    state = const AsyncValue.loading();
    try {
      await _prefsService.setGuest(value);
      state = AsyncValue.data(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

// Vibration Enabled Provider
final vibrationEnabledProvider =
    StateNotifierProvider<VibrationEnabledNotifier, AsyncValue<bool>>((ref) {
  final prefsService = ref.watch(sharedPreferencesServiceProvider);
  return VibrationEnabledNotifier(prefsService);
});

class VibrationEnabledNotifier extends StateNotifier<AsyncValue<bool>> {
  final SharedPreferencesService _prefsService;

  VibrationEnabledNotifier(this._prefsService)
      : super(const AsyncValue.data(false)) {
    _init();
  }

  Future<void> _init() async {
    try {
      final isEnabled = await _prefsService.isVibrationEnabled();
      state = AsyncValue.data(isEnabled);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setVibrationEnabled(bool value) async {
    state = const AsyncValue.loading();
    try {
      await _prefsService.setVibrationEnabled(value);
      state = AsyncValue.data(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

// Vibration Simplified Mode Provider
final vibrationSimplifiedProvider =
    StateNotifierProvider<VibrationSimplifiedNotifier, AsyncValue<bool>>((ref) {
  final prefsService = ref.watch(sharedPreferencesServiceProvider);
  return VibrationSimplifiedNotifier(prefsService);
});

class VibrationSimplifiedNotifier extends StateNotifier<AsyncValue<bool>> {
  final SharedPreferencesService _prefsService;

  VibrationSimplifiedNotifier(this._prefsService)
      : super(const AsyncValue.data(true)) {
    _init();
  }

  Future<void> _init() async {
    try {
      final isSimplified = await _prefsService.isVibrationSimplifiedMode();
      state = AsyncValue.data(isSimplified);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setVibrationSimplified(bool value) async {
    state = const AsyncValue.loading();
    try {
      await _prefsService.setVibrationSimplifiedMode(value);
      state = AsyncValue.data(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

// Silent Mode Enabled Provider
final silentModeEnabledProvider =
    StateNotifierProvider<SilentModeEnabledNotifier, AsyncValue<bool>>((ref) {
  final prefsService = ref.watch(sharedPreferencesServiceProvider);
  return SilentModeEnabledNotifier(prefsService);
});

class SilentModeEnabledNotifier extends StateNotifier<AsyncValue<bool>> {
  final SharedPreferencesService _prefsService;

  SilentModeEnabledNotifier(this._prefsService)
      : super(const AsyncValue.data(true)) {
    _init();
  }

  Future<void> _init() async {
    try {
      final isEnabled = await _prefsService.isSilentModeEnabled();
      state = AsyncValue.data(isEnabled);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setSilentModeEnabled(bool value) async {
    state = const AsyncValue.loading();
    try {
      await _prefsService.setSilentModeEnabled(value);
      state = AsyncValue.data(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

// Silent Mode Duration Provider
final silentModeDurationProvider =
    StateNotifierProvider<SilentModeDurationNotifier, AsyncValue<int>>((ref) {
  final prefsService = ref.watch(sharedPreferencesServiceProvider);
  return SilentModeDurationNotifier(prefsService);
});

// Dynamic Color Provider
final dynamicColorProvider =
    StateNotifierProvider<DynamicColorNotifier, AsyncValue<bool>>((ref) {
  final prefsService = ref.watch(sharedPreferencesServiceProvider);
  return DynamicColorNotifier(prefsService);
});

class DynamicColorNotifier extends StateNotifier<AsyncValue<bool>> {
  final SharedPreferencesService _prefsService;

  DynamicColorNotifier(this._prefsService)
      : super(const AsyncValue.data(false)) {
    _init();
  }

  Future<void> _init() async {
    try {
      final enabled = _prefsService.getDynamicColor();
      state = AsyncValue.data(enabled);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setDynamicColor(bool value) async {
    try {
      await _prefsService.setDynamicColor(value);
      state = AsyncValue.data(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

class SilentModeDurationNotifier extends StateNotifier<AsyncValue<int>> {
  final SharedPreferencesService _prefsService;

  SilentModeDurationNotifier(this._prefsService)
      : super(const AsyncValue.data(20)) {
    _init();
  }

  Future<void> _init() async {
    try {
      final duration = await _prefsService.getSilentModeDuration();
      state = AsyncValue.data(duration);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setSilentModeDuration(int value) async {
    state = const AsyncValue.loading();
    try {
      await _prefsService.setSilentModeDuration(value);
      state = AsyncValue.data(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

// Task Notifications Provider
final taskNotificationsEnabledProvider =
    StateNotifierProvider<TaskNotificationsEnabledNotifier, AsyncValue<bool>>((ref) {
  final prefsService = ref.watch(sharedPreferencesServiceProvider);
  return TaskNotificationsEnabledNotifier(prefsService);
});

class TaskNotificationsEnabledNotifier extends StateNotifier<AsyncValue<bool>> {
  final SharedPreferencesService _prefsService;

  TaskNotificationsEnabledNotifier(this._prefsService)
      : super(const AsyncValue.data(true)) {
    _init();
  }

  Future<void> _init() async {
    try {
      final isEnabled = await _prefsService.isTaskNotificationsEnabled();
      state = AsyncValue.data(isEnabled);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setEnabled(bool value) async {
    state = const AsyncValue.loading();
    try {
      await _prefsService.setTaskNotificationsEnabled(value);
      state = AsyncValue.data(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// Tab navigation provider — allows child screens to request tab switches
final tabNavigationProvider = StateProvider<int>((ref) => -1);

// ─── Jumu'ah Reminder Provider ────────────────────────────────────────────────

const _jumuahReminderKey = 'jumua_reminder_enabled';

final jumuahReminderEnabledProvider =
    StateNotifierProvider<JumuahReminderNotifier, bool>((ref) {
  return JumuahReminderNotifier();
});

class JumuahReminderNotifier extends StateNotifier<bool> {
  JumuahReminderNotifier() : super(true) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_jumuahReminderKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_jumuahReminderKey, value);
    state = value;
  }
}

// Task Reminder Minutes Provider
final taskReminderMinutesProvider =
    StateNotifierProvider<TaskReminderMinutesNotifier, AsyncValue<int>>((ref) {
  final prefsService = ref.watch(sharedPreferencesServiceProvider);
  return TaskReminderMinutesNotifier(prefsService);
});

class TaskReminderMinutesNotifier extends StateNotifier<AsyncValue<int>> {
  final SharedPreferencesService _prefsService;

  TaskReminderMinutesNotifier(this._prefsService)
      : super(const AsyncValue.data(30)) {
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final minutes = prefs.getInt('task_reminder_minutes') ?? 30;
      state = AsyncValue.data(minutes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setMinutes(int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('task_reminder_minutes', value);
      state = AsyncValue.data(value);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

// ─── App Mode ─────────────────────────────────────────────────────────────────

enum AppMode { both, prayerOnly, tasksOnly }

const _appModeKey = 'app_mode';

final appModeProvider = StateNotifierProvider<AppModeNotifier, AppMode>((ref) {
  return AppModeNotifier();
});

class AppModeNotifier extends StateNotifier<AppMode> {
  AppModeNotifier() : super(AppMode.both) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_appModeKey) ?? 'both';
    state = _fromString(value);
  }

  Future<void> setMode(AppMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appModeKey, _toString(mode));
    state = mode;
  }

  static AppMode _fromString(String v) {
    switch (v) {
      case 'prayer_only': return AppMode.prayerOnly;
      case 'tasks_only': return AppMode.tasksOnly;
      default: return AppMode.both;
    }
  }

  static String _toString(AppMode m) {
    switch (m) {
      case AppMode.prayerOnly: return 'prayer_only';
      case AppMode.tasksOnly: return 'tasks_only';
      case AppMode.both: return 'both';
    }
  }
}

// ─── Prayer Tracking Notifications Provider ───────────────────────────────────

final prayerTrackingEnabledProvider =
    StateNotifierProvider<PrayerTrackingEnabledNotifier, bool>((ref) {
  final prefsService = ref.watch(sharedPreferencesServiceProvider);
  return PrayerTrackingEnabledNotifier(prefsService);
});

class PrayerTrackingEnabledNotifier extends StateNotifier<bool> {
  final SharedPreferencesService _prefs;
  PrayerTrackingEnabledNotifier(this._prefs) : super(true) { _init(); }

  Future<void> _init() async {
    state = await _prefs.isPrayerTrackingEnabled();
  }

  Future<void> setEnabled(bool value) async {
    await _prefs.setPrayerTrackingEnabled(value);
    state = value;
  }
}

// ─── Daily Summary Time Provider ─────────────────────────────────────────────

final dailySummaryTimeProvider =
    StateNotifierProvider<DailySummaryTimeNotifier, String>((ref) {
  final prefsService = ref.watch(sharedPreferencesServiceProvider);
  return DailySummaryTimeNotifier(prefsService);
});

class DailySummaryTimeNotifier extends StateNotifier<String> {
  final SharedPreferencesService _prefs;
  DailySummaryTimeNotifier(this._prefs) : super('21:00') { _init(); }

  Future<void> _init() async {
    state = await _prefs.getDailySummaryTime();
  }

  Future<void> setTime(String value) async {
    await _prefs.setDailySummaryTime(value);
    state = value;
    await PrayerAlarmService.instance.scheduleDailySummary(value);
  }
}
