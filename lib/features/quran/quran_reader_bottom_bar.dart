import 'package:flutter/material.dart';
import 'package:aura_app/core/constants/app_constants.dart';
import 'package:aura_app/core/theme/app_typography.dart';
import 'package:aura_app/core/utils/number_formatter.dart';

/// Bottom bar of the Quran reader: previous / next page and the page counter,
/// with A− / A+ zoom buttons around the counter when zoom callbacks are given
/// (mobile; desktop has its own floating controls) (F58).
class QuranReaderBottomBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final String lang;
  final VoidCallback? onGoToPrevious;
  final VoidCallback? onGoToNext;
  final VoidCallback? onZoomOut;
  final VoidCallback? onZoomIn;

  /// English: puts Next on the left and Previous on the right (back arrow =
  /// next), so the bar matches the page direction of the reader. Arabic leaves
  /// this false because its right-to-left layout already does it.
  final bool reverseNav;

  const QuranReaderBottomBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.lang,
    this.onGoToPrevious,
    this.onGoToNext,
    this.onZoomOut,
    this.onZoomIn,
    this.reverseNav = false,
  });

  Widget _navButton(VoidCallback? onPressed, IconData icon, Color color) =>
      IconButton(onPressed: onPressed, icon: Icon(icon, color: color));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: (AppConstants.surface(isDark)).withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: AppConstants.divider(isDark)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (reverseNav)
              _navButton(onGoToNext, Icons.arrow_back,
                  currentPage < totalPages ? primary : Colors.grey)
            else
              _navButton(onGoToPrevious, Icons.arrow_back,
                  currentPage > 1 ? primary : Colors.grey),
            if (onZoomOut != null)
              _ZoomButton(
                  icon: Icons.remove, color: primary, onTap: onZoomOut!),
            Expanded(
              child: Text(
                '${NumberFormatter.withArabicNumeralsByLanguage(currentPage.toString(), lang)} / ${NumberFormatter.withArabicNumeralsByLanguage(totalPages.toString(), lang)}',
                textAlign: TextAlign.center,
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.hintColor,
                ),
              ),
            ),
            if (onZoomIn != null)
              _ZoomButton(icon: Icons.add, color: primary, onTap: onZoomIn!),
            if (reverseNav)
              _navButton(onGoToPrevious, Icons.arrow_forward,
                  currentPage > 1 ? primary : Colors.grey)
            else
              _navButton(onGoToNext, Icons.arrow_forward,
                  currentPage < totalPages ? primary : Colors.grey),
          ],
        ),
      ),
    );
  }
}

/// "A−" / "A+" zoom button (same look as the former floating overlay).
class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ZoomButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('A',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 2),
              Icon(icon, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
