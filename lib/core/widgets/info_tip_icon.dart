import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/app_constants.dart';
import '../theme/app_typography.dart';

class InfoTipIcon extends StatelessWidget {
  final String titleKey;
  final String bodyKey;

  const InfoTipIcon({
    super.key,
    required this.titleKey,
    required this.bodyKey,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showTipDialog(context, isDark),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.info_outline,
          size: 18,
          color: AppConstants.getPrimary(isDark).withOpacity(0.7),
        ),
      ),
    );
  }

  void _showTipDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppConstants.darkSurface : AppConstants.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppConstants.getPrimary(isDark), size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                titleKey.tr(),
                style: AppTypography.bodyL.copyWith(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          bodyKey.tr(),
          style: AppTypography.label.copyWith(
            color: isDark ? Colors.white70 : Colors.black54,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.getPrimary(isDark),
            ),
            child: Text('banner_got_it'.tr()),
          ),
        ],
      ),
    );
  }
}
