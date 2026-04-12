import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class SharedPreferencesService {
  SharedPreferencesService._();

  static SharedPreferencesService? _instance;
  static SharedPreferences? _prefs;
  static Completer<SharedPreferencesService>? _initCompleter;

  static SharedPreferencesService get instance {
    if (_instance == null) {
      throw Exception(
        'SharedPreferencesService not initialized. '
        'Call getInstance() first.'
      );
    }
    return _instance!;
  }

  static Future<SharedPreferencesService> getInstance() async {
    // Return existing instance if already initialized
    if (_instance != null) {
      return _instance!;
    }

    // If initialization is in progress, wait for it
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      return _initCompleter!.future;
    }

    // Start initialization
    _initCompleter = Completer<SharedPreferencesService>();

    try {
      _instance = SharedPreferencesService._();
      _prefs = await SharedPreferences.getInstance();
      _initCompleter!.complete(_instance!);
      return _instance!;
    } catch (e, st) {
      _initCompleter!.completeError(e, st);
      rethrow;
    }
  }

  Future<bool> ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
    return true;
  }

  // Ensure prefs is initialized before any operation
  SharedPreferences get _prefsInstance {
    if (_prefs == null) {
      throw Exception('SharedPreferences not initialized. Call ensureInitialized() first.');
    }
    return _prefs!;
  }

  // Theme Mode
  Future<String> getThemeMode() async {
    return _prefsInstance.getString(AppConstants.keyThemeMode) ?? 'system';
  }

  Future<bool> setThemeMode(String value) async {
    return await _prefsInstance.setString(AppConstants.keyThemeMode, value);
  }

  // Dynamic Color
  bool getDynamicColor() {
    return _prefsInstance.getBool(AppConstants.keyDynamicColor) ?? false;
  }

  Future<bool> setDynamicColor(bool value) async {
    return await _prefsInstance.setBool(AppConstants.keyDynamicColor, value);
  }

  // Language
  Future<String> getLanguage() async {
    return _prefsInstance.getString(AppConstants.keyLanguage) ?? 'en';
  }

  Future<bool> setLanguage(String value) async {
    return await _prefsInstance.setString(AppConstants.keyLanguage, value);
  }

  // First Launch
  Future<bool> isFirstLaunch() async {
    return _prefsInstance.getBool(AppConstants.keyFirstLaunch) ?? true;
  }

  Future<bool> setFirstLaunch(bool value) async {
    return await _prefsInstance.setBool(AppConstants.keyFirstLaunch, value);
  }

  // Guest Mode
  Future<bool> isGuest() async {
    return _prefsInstance.getBool(AppConstants.keyIsGuest) ?? false;
  }

  Future<bool> setGuest(bool value) async {
    return await _prefsInstance.setBool(AppConstants.keyIsGuest, value);
  }

  // Vibration enabled preference
  Future<bool> isVibrationEnabled() async {
    return _prefsInstance.getBool('vibration_enabled') ?? false;
  }

  Future<bool> setVibrationEnabled(bool value) async {
    return await _prefsInstance.setBool('vibration_enabled', value);
  }

  // Vibration simplified mode (only important vibrations)
  Future<bool> isVibrationSimplifiedMode() async {
    return _prefsInstance.getBool('vibration_simplified') ?? true;
  }

  Future<bool> setVibrationSimplifiedMode(bool value) async {
    return await _prefsInstance.setBool('vibration_simplified', value);
  }

  // Silent Mode Automation
  Future<bool> isSilentModeEnabled() async {
    return _prefsInstance.getBool('silent_mode_enabled') ?? true;
  }

  Future<bool> setSilentModeEnabled(bool value) async {
    return await _prefsInstance.setBool('silent_mode_enabled', value);
  }

  Future<int> getSilentModeDuration() async {
    return _prefsInstance.getInt('silent_mode_duration') ?? 20;
  }

  Future<bool> setSilentModeDuration(int value) async {
    return await _prefsInstance.setInt('silent_mode_duration', value);
  }

  // Clear all (except guest mode and first launch)
  Future<bool> clearUserData() async {
    await _prefsInstance.remove(AppConstants.keyThemeMode);
    await _prefsInstance.remove(AppConstants.keyLanguage);
    return true;
  }

  // Clear all
  Future<bool> clearAll() async {
    return await _prefsInstance.clear();
  }

  // Google Maps API Key for Geocoding
  Future<String> getGoogleMapsApiKey() async {
    return _prefsInstance.getString('google_maps_api_key') ?? '';
  }

  Future<bool> setGoogleMapsApiKey(String value) async {
    return await _prefsInstance.setString('google_maps_api_key', value);
  }

  /// Get all user preferences as a map (useful for guest migration)
  Future<Map<String, dynamic>> getAllPreferences() async {
    return {
      AppConstants.keyThemeMode: await getThemeMode(),
      AppConstants.keyLanguage: await getLanguage(),
    };
  }

  /// Restore preferences from a map (useful for guest migration)
  Future<bool> restorePreferences(Map<String, dynamic> prefs) async {
    try {
      if (prefs.containsKey(AppConstants.keyThemeMode)) {
        await setThemeMode(prefs[AppConstants.keyThemeMode] as String);
      }
      if (prefs.containsKey(AppConstants.keyLanguage)) {
        await setLanguage(prefs[AppConstants.keyLanguage] as String);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
