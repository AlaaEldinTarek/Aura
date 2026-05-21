import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/daily_content.dart';
import '../../core/services/daily_content_service.dart';
import '../../core/theme/app_typography.dart';

class DailyContentScreen extends StatelessWidget {
  const DailyContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final content = DailyContentService.instance.getToday();
    final isAyah = content.type == DailyContentType.ayah;

    final Color accentColor = isAyah
        ? const Color(0xFF00897B)
        : const Color(0xFFD4A017);

    final String typeLabel = isAyah
        ? (isArabic ? '📖 آية اليوم' : '📖 Verse of the Day')
        : (isArabic ? '📜 حديث اليوم' : '📜 Hadith of the Day');

    return Scaffold(
      appBar: AppBar(
        title: Text(typeLabel),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(ts.scale(AppConstants.paddingLarge)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Accent icon circle
            Center(
              child: Container(
                width: ts.scale(80.0),
                height: ts.scale(80.0),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 2),
                ),
                child: Center(
                  child: Text(
                    isAyah ? '📖' : '📜',
                    style: TextStyle(fontSize: ts.scale(36.0)),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 500.ms).scale(curve: Curves.elasticOut),

            SizedBox(height: ts.scale(24.0)),

            // Card
            Container(
              padding: EdgeInsets.all(ts.scale(24.0)),
              decoration: BoxDecoration(
                color: AppConstants.card(isDark),
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Arabic text
                  Text(
                    content.arabic,
                    style: AppTypography.ar(AppTypography.headingM).copyWith(
                      fontSize: ts.scale(22.0),
                      color: AppConstants.textPrimary(isDark),
                      height: 2.0,
                    ),
                    textScaler: TextScaler.noScaling,
                    textAlign: TextAlign.right,
                  ).animate().fadeIn(delay: 200.ms),

                  SizedBox(height: ts.scale(16.0)),

                  Divider(color: accentColor.withValues(alpha: 0.2)),

                  SizedBox(height: ts.scale(16.0)),

                  // Translation
                  Text(
                    content.translation,
                    style: AppTypography.bodyL.copyWith(
                      height: 1.7,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  ).animate().fadeIn(delay: 300.ms),

                  SizedBox(height: ts.scale(16.0)),

                  // Source badge
                  Align(
                    alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: ts.scale(14.0), vertical: ts.scale(6.0)),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        content.source,
                        style: AppTypography.bodyS.copyWith(
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                ],
              ),
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
          ],
        ),
      ),
    );
  }
}
