import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  // Brand Colors
  static const Color primaryColor = Color(0xFFF5A623);
  static const Color primaryDark = Color(0xFFD4890A);
  static const Color primaryLight = Color(0xFFFFD37A);

  // Accent Colors
  static const Color accentCyan = Color(0xFFE8A849);
  static const Color accentPurple = Color(0xFF9D4EDD);
  static const Color accentOrange = Color(0xFFFF9F1C);

  // Neutral Colors - Light Mode
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF5F5F5);
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF757575);
  static const Color lightBorder = Color(0xFFE0E0E0);

  // Neutral Colors - Dark Mode
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2C2C2C);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkBorder = Color(0xFF3A3A3A);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // SharedPreferences Keys
  static const String keyThemeMode = 'theme_mode';
  static const String keyDynamicColor = 'dynamic_color';
  static const String keyLanguage = 'language';
  static const String keyFirstLaunch = 'first_launch';
  static const String keyIsGuest = 'is_guest';
  static const String keyCalculationMethod = 'calculation_method';
  static const String keyAsrMadhab = 'asr_madhab';
  static const String keyPrayerNotificationsEnabled = 'prayer_notifications_enabled';
  static const String keyBackgroundNotificationEnabled = 'background_notification_enabled';
  static const String keyAdhanEnabled = 'adhan_enabled';
  static const String keySilentModeEnabled = 'silent_mode_enabled';
  static const String keySilentModeDuration = 'silent_mode_duration';
  static const String keyNotificationReminderMinutes = 'notification_reminder_minutes';
  static const String keyVibrationEnabled = 'vibration_enabled';
  static const String keyVibrationSimplified = 'vibration_simplified';

  // Animation Durations
  static const Duration animationDurationShort = Duration(milliseconds: 200);
  static const Duration animationDurationMedium = Duration(milliseconds: 350);
  static const Duration animationDurationLong = Duration(milliseconds: 500);
  static const Duration splashDuration = Duration(milliseconds: 2500);

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;

  // Spacing
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  // Font Sizes
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeLarge = 16.0;
  static const double fontSizeXLarge = 20.0;
  static const double fontSizeXXLarge = 24.0;

  // Supported Languages
  static const List<String> supportedLanguages = ['en', 'ar'];

  // Minimum Password Length
  static const int minPasswordLength = 6;
}
