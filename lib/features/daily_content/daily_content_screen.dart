import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/daily_content.dart';
import '../../core/services/daily_content_service.dart';

class DailyContentScreen extends StatelessWidget {
  const DailyContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Accent icon circle
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 2),
                ),
                child: Center(
                  child: Text(
                    isAyah ? '📖' : '📜',
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 500.ms).scale(curve: Curves.elasticOut),

            const SizedBox(height: 24),

            // Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
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
                    style: TextStyle(
                      fontSize: 22,
                      fontFamily: 'Cairo',
                      color: isDark ? Colors.white : Colors.black87,
                      height: 2.0,
                    ),
                    textAlign: TextAlign.right,
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 16),

                  Divider(color: accentColor.withValues(alpha: 0.2)),

                  const SizedBox(height: 16),

                  // Translation
                  Text(
                    content.translation,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.7,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 16),

                  // Source badge
                  Align(
                    alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        content.source,
                        style: TextStyle(
                          fontSize: 13,
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
