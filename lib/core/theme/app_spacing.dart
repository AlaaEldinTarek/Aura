/// Spacing scale and semantic aliases for Aura.
///
/// Always use these instead of raw pixel values so the whole app
/// stays consistent and a single edit here propagates everywhere.
///
/// Usage:
///   Padding(padding: EdgeInsets.all(AppSpacing.md))
///   SizedBox(height: AppSpacing.sectionGap)
class AppSpacing {
  AppSpacing._();

  // ── Base scale ────────────────────────────────────────────────────────────
  static const double xs    = 4.0;
  static const double sm    = 8.0;
  static const double md    = 12.0;
  static const double base  = 16.0;
  static const double lg    = 20.0;
  static const double xl    = 24.0;
  static const double xxl   = 32.0;
  static const double xxxl  = 48.0;

  // ── Semantic aliases ──────────────────────────────────────────────────────

  /// Horizontal padding for screen edges.
  static const double screenH = base;

  /// Vertical padding for screen edges.
  static const double screenV = lg;

  /// Internal padding for cards.
  static const double cardPadding = base;

  /// Gap between major sections on a screen.
  static const double sectionGap = xl;

  /// Gap between list items / small cards.
  static const double itemGap = sm;

  /// Gap between a label and its content.
  static const double labelGap = xs;

  /// Standard icon size.
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
}
