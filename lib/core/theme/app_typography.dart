import 'package:flutter/material.dart';

/// Semantic typography tokens for Aura.
///
/// Colors are intentionally omitted — apply via Theme or copyWith so
/// styles work across light / dark / AMOLED themes automatically.
///
/// Usage:
///   Text('Hello', style: AppTypography.headingL)
///   Text('مرحبا', style: AppTypography.ar(AppTypography.headingL))
class AppTypography {
  AppTypography._();

  static const String _en = 'Roboto';
  static const String _ar = 'Cairo';

  // ── Display ──────────────────────────────────────────────────────────────
  static const TextStyle displayL = TextStyle(
    fontFamily: _en,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const TextStyle displayM = TextStyle(
    fontFamily: _en,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.3,
  );

  // ── Headings ─────────────────────────────────────────────────────────────
  static const TextStyle headingL = TextStyle(
    fontFamily: _en,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.2,
  );

  static const TextStyle headingM = TextStyle(
    fontFamily: _en,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.1,
  );

  static const TextStyle headingS = TextStyle(
    fontFamily: _en,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0,
  );

  // ── Body ─────────────────────────────────────────────────────────────────
  static const TextStyle bodyL = TextStyle(
    fontFamily: _en,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.55,
    letterSpacing: 0.1,
  );

  static const TextStyle bodyM = TextStyle(
    fontFamily: _en,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.55,
    letterSpacing: 0.1,
  );

  static const TextStyle bodyS = TextStyle(
    fontFamily: _en,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.1,
  );

  // ── Labels ───────────────────────────────────────────────────────────────
  static const TextStyle label = TextStyle(
    fontFamily: _en,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.1,
  );

  static const TextStyle labelS = TextStyle(
    fontFamily: _en,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.3,
  );

  // ── Caption ───────────────────────────────────────────────────────────────
  static const TextStyle caption = TextStyle(
    fontFamily: _en,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.2,
  );

  // ── Arabic variant ────────────────────────────────────────────────────────
  /// Returns the same style with Cairo font and Arabic-friendly line height.
  static TextStyle ar(TextStyle base) => base.copyWith(
        fontFamily: _ar,
        height: (base.height ?? 1.4) + 0.2,
      );
}
