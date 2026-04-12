import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Analytics Service for tracking user behavior and app events
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? _analytics;

  bool _isInitialized = false;

  /// Initialize the analytics service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _analytics = FirebaseAnalytics.instance;
      await _analytics?.setAnalyticsCollectionEnabled(true);
      _isInitialized = true;
      debugPrint('📊 Analytics service initialized');
    } catch (e) {
      debugPrint('❌ Analytics initialization failed: $e');
    }
  }

  /// Get the Firebase Analytics instance
  FirebaseAnalytics? get analytics => _analytics;

  /// Check if analytics is initialized
  bool get isInitialized => _isInitialized;

  /// Log a custom event
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (!_isInitialized || _analytics == null) {
      debugPrint('⚠️ Analytics not initialized, skipping event: $name');
      return;
    }

    try {
      await _analytics!.logEvent(
        name: name,
        parameters: parameters,
      );
      debugPrint('📊 Event logged: $name ${parameters != null ? parameters : ''}');
    } catch (e) {
      debugPrint('❌ Failed to log event $name: $e');
    }
  }

  /// Log screen view
  Future<void> logScreenView({
    required String screenName,
  }) async {
    if (!_isInitialized || _analytics == null) return;

    try {
      await _analytics!.logScreenView(
        screenName: screenName,
      );
      debugPrint('📊 Screen view logged: $screenName');
    } catch (e) {
      debugPrint('❌ Failed to log screen view: $e');
    }
  }

  /// Log authentication events
  Future<void> logLogin({String? loginMethod}) async {
    if (!_isInitialized || _analytics == null) return;

    try {
      await _analytics!.logLogin(loginMethod: loginMethod ?? 'unknown');
      debugPrint('📊 Login logged: $loginMethod');
    } catch (e) {
      debugPrint('❌ Failed to log login: $e');
    }
  }

  Future<void> logSignUp({String? signUpMethod}) async {
    if (!_isInitialized || _analytics == null) return;

    try {
      await _analytics!.logSignUp(signUpMethod: signUpMethod ?? 'unknown');
      debugPrint('📊 Sign up logged: $signUpMethod');
    } catch (e) {
      debugPrint('❌ Failed to log sign up: $e');
    }
  }

  /// Set user ID
  Future<void> setUserId(String? id) async {
    if (!_isInitialized || _analytics == null) return;

    try {
      await _analytics!.setUserId(id: id);
      debugPrint('📊 User ID set: $id');
    } catch (e) {
      debugPrint('❌ Failed to set user ID: $e');
    }
  }

  /// Set user property
  Future<void> setUserProperty({
    required String name,
    String? value,
  }) async {
    if (!_isInitialized || _analytics == null) return;

    try {
      await _analytics!.setUserProperty(name: name, value: value);
      debugPrint('📊 User property set: $name=$value');
    } catch (e) {
      debugPrint('❌ Failed to set user property: $e');
    }
  }

  /// Track language change
  Future<void> logLanguageChanged(String language) async {
    await logEvent(
      name: 'language_changed',
      parameters: {'language': language},
    );
  }

  /// Track theme change
  Future<void> logThemeChanged(String theme) async {
    await logEvent(
      name: 'theme_changed',
      parameters: {'theme': theme},
    );
  }

  /// Track onboarding completion
  Future<void> logOnboardingCompleted() async {
    await logEvent(name: 'onboarding_completed');
  }

  /// Track settings opened
  Future<void> logSettingsOpened() async {
    await logEvent(name: 'settings_opened');
  }
}
