import 'package:flutter/material.dart';
import 'package:aura_app/core/constants/app_constants.dart';
import 'package:aura_app/core/theme/app_typography.dart';
import 'package:aura_app/core/utils/number_formatter.dart';

/// Bottom bar of the Quran reader: previous / next page and the page counter.
class QuranReaderBottomBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final String lang;
  final VoidCallback? onGoToPrevious;
  final VoidCallback? onGoToNext;

  const QuranReaderBottomBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.lang,
    this.onGoToPrevious,
    this.onGoToNext,
  });

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
            IconButton(
              onPressed: onGoToPrevious,
              icon: Icon(
                Icons.arrow_back,
                color: currentPage > 1 ? primary : Colors.grey,
              ),
            ),
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
            IconButton(
              onPressed: onGoToNext,
              icon: Icon(
                Icons.arrow_forward,
                color: currentPage < totalPages ? primary : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
