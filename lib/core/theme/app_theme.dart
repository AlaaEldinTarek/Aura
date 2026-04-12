import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

class AppTheme {
  // Font families
  static const String primaryFont = 'Roboto';
  static const String arabicFont = 'Cairo'; // You need to add Cairo font to assets

  // Primary color palette
  static const Color primary = Color(0xFF007DFF);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainerLight = Color(0xFFD9E6FF);
  static const Color onPrimaryContainerLight = Color(0xFF001C3B);
  static const Color primaryContainerDark = Color(0xFF0052B3);
  static const Color onPrimaryContainerDark = Color(0xFFD9E6FF);

  // Secondary/Accent colors
  static const Color secondary = Color(0xFF00BCD4);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // Surface colors
  static const Color surfaceLight = Color(0xFFFDFCFF);
  static const Color onSurfaceLight = Color(0xFF1A1B1E);
  static const Color surfaceDark = Color(0xFF1A1B1E);
  static const Color onSurfaceDark = Color(0xFFE3E2E6);

  // AMOLED surface colors (pure black)
  static const Color surfaceAmoled = Color(0xFF000000);
  static const Color onSurfaceAmoled = Color(0xFFE3E2E6);

  // Background colors
  static const Color backgroundLight = Color(0xFFFDFCFF);
  static const Color onBackgroundLight = Color(0xFF1A1B1E);
  static const Color backgroundDark = Color(0xFF111317);
  static const Color onBackgroundDark = Color(0xFFE3E2E6);

  // AMOLED background colors
  static const Color backgroundAmoled = Color(0xFF000000);
  static const Color onBackgroundAmoled = Color(0xFFE3E2E6);

  // Outline colors
  static const Color outlineLight = Color(0xFFC7C5D0);
  static const Color outlineDark = Color(0xFF47474F);
  static const Color outlineAmoled = Color(0xFF333333);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);

  // Light theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainerLight,
      onPrimaryContainer: onPrimaryContainerLight,
      secondary: secondary,
      onSecondary: onSecondary,
      surface: surfaceLight,
      onSurface: onSurfaceLight,
      outline: outlineLight,
      error: error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceLight,
      foregroundColor: onSurfaceLight,
      elevation: 0,
      centerTitle: true,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: 6,
    ),
    cardTheme: CardThemeData(
      color: surfaceLight,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: outlineLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: outlineLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: onBackgroundLight,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: onBackgroundLight,
      ),
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: onBackgroundLight,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onBackgroundLight,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: onBackgroundLight,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: onBackgroundLight,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: onBackgroundLight,
      ),
    ),
    // Make keyboard background transparent
    scaffoldBackgroundColor: backgroundLight,
    // Set the system UI overlay style for transparent keyboard
    extensions: const [
      // Note: This requires flutter_statusbarcolor or similar package for full transparency
    ],
  );

  // Dark theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainerDark,
      onPrimaryContainer: onPrimaryContainerDark,
      secondary: secondary,
      onSecondary: onSecondary,
      surface: surfaceDark,
      onSurface: onSurfaceDark,
      outline: outlineDark,
      error: error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceDark,
      foregroundColor: onSurfaceDark,
      elevation: 0,
      centerTitle: true,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: 6,
    ),
    cardTheme: CardThemeData(
      color: surfaceDark,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: outlineDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: outlineDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: onBackgroundDark,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: onBackgroundDark,
      ),
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: onBackgroundDark,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onBackgroundDark,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: onBackgroundDark,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: onBackgroundDark,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: onBackgroundDark,
      ),
    ),
    // Make keyboard background transparent
    scaffoldBackgroundColor: backgroundDark,
    // Set the system UI overlay style for transparent keyboard
    extensions: const [
      // Note: This requires flutter_statusbarcolor or similar package for full transparency
    ],
  );

  // AMOLED Black theme (pure black backgrounds for OLED devices)
  static ThemeData amoledTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainerDark,
      onPrimaryContainer: onPrimaryContainerDark,
      secondary: secondary,
      onSecondary: onSecondary,
      surface: surfaceAmoled,
      onSurface: onSurfaceAmoled,
      outline: outlineAmoled,
      error: error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceAmoled,
      foregroundColor: onSurfaceAmoled,
      elevation: 0,
      centerTitle: true,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: 6,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF111111),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceAmoled,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: outlineAmoled),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: outlineAmoled),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: onBackgroundAmoled,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: onBackgroundAmoled,
      ),
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: onBackgroundAmoled,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onBackgroundAmoled,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: onBackgroundAmoled,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: onBackgroundAmoled,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: onBackgroundAmoled,
      ),
    ),
    scaffoldBackgroundColor: backgroundAmoled,
    extensions: const [],
  );

  /// Build a dynamic light theme from the system's Material You color scheme
  static ThemeData buildDynamicLightTheme(ColorScheme dynamicColorScheme) {
    return _buildThemeFromColorScheme(
      colorScheme: dynamicColorScheme,
      brightness: Brightness.light,
      backgroundColor: backgroundLight,
    );
  }

  /// Build a dynamic dark theme from the system's Material You color scheme
  static ThemeData buildDynamicDarkTheme(ColorScheme dynamicColorScheme) {
    return _buildThemeFromColorScheme(
      colorScheme: dynamicColorScheme,
      brightness: Brightness.dark,
      backgroundColor: backgroundDark,
    );
  }

  static ThemeData _buildThemeFromColorScheme({
    required ColorScheme colorScheme,
    required Brightness brightness,
    required Color backgroundColor,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 6,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      scaffoldBackgroundColor: backgroundColor,
    );
  }

}
