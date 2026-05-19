import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:aura_app/core/constants/app_constants.dart';
import 'package:aura_app/core/theme/app_typography.dart';
import 'package:aura_app/core/widgets/aura_button.dart';
import 'package:aura_app/core/utils/number_formatter.dart';
import 'khatma_dua_screen.dart';

class KhatmaCelebrationScreen extends StatelessWidget {
  final int khatmCount;
  final DateTime date;

  const KhatmaCelebrationScreen({
    super.key,
    required this.khatmCount,
    required this.date,
  });

  static const _starPositions = [
    (0.05, 0.08, 14.0),
    (0.90, 0.06, 10.0),
    (0.15, 0.20, 8.0),
    (0.82, 0.18, 12.0),
    (0.02, 0.44, 10.0),
    (0.94, 0.40, 8.0),
    (0.10, 0.74, 12.0),
    (0.86, 0.72, 10.0),
    (0.48, 0.02, 14.0),
    (0.58, 0.94, 8.0),
    (0.24, 0.88, 10.0),
    (0.73, 0.84, 12.0),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppConstants.getPrimary(isDark);
    final dateStr = DateFormat('d MMM yyyy', lang == 'ar' ? 'ar' : 'en').format(date);
    final countStr = NumberFormatter.withArabicNumeralsByLanguage(khatmCount.toString(), lang);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A1500), const Color(0xFF111317), const Color(0xFF1A1500)]
                : [const Color(0xFFFFF3D6), const Color(0xFFFFF8EB), const Color(0xFFFFF3D6)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              return Stack(
                children: [
                  // Background stars
                  ..._starPositions.asMap().entries.map((e) {
                    final i = e.key;
                    final (lf, tf, sz) = e.value;
                    return Positioned(
                      left: w * lf,
                      top: h * tf,
                      child: Icon(
                        Icons.star,
                        size: sz,
                        color: primary.withValues(alpha: 0.25),
                      )
                          .animate(
                            onPlay: (c) => c.repeat(reverse: true),
                            delay: Duration(milliseconds: i * 120),
                          )
                          .scale(
                            begin: const Offset(0.7, 0.7),
                            end: const Offset(1.3, 1.3),
                            duration: Duration(milliseconds: 1400 + i * 100),
                            curve: Curves.easeInOut,
                          ),
                    );
                  }),

                  // Main content
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animated moon+sparkle
                          const Text('🌙✨', style: TextStyle(fontSize: 64))
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .scale(
                                begin: const Offset(0.93, 0.93),
                                end: const Offset(1.07, 1.07),
                                duration: 1400.ms,
                                curve: Curves.easeInOut,
                              ),

                          const SizedBox(height: 24),

                          // Arabic Quran completion title
                          Text(
                            'ختم القرآن الكريم',
                            style: AppTypography.ar(AppTypography.displayM).copyWith(
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                            textAlign: TextAlign.center,
                          )
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .slideY(begin: -0.3, end: 0, curve: Curves.easeOut),

                          const SizedBox(height: 8),

                          Text(
                            'khatma_celebration_title'.tr(),
                            style: AppTypography.headingM.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppConstants.textPrimary(isDark),
                            ),
                            textAlign: TextAlign.center,
                          )
                              .animate()
                              .fadeIn(duration: 600.ms, delay: 200.ms),

                          const SizedBox(height: 10),

                          Text(
                            'khatma_celebration_subtitle'.tr(),
                            style: AppTypography.bodyL.copyWith(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          )
                              .animate()
                              .fadeIn(duration: 600.ms, delay: 350.ms),

                          const SizedBox(height: 32),

                          // Khatm count + date badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: primary.withValues(alpha: 0.4), width: 1.5),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'khatma_count_label'.tr().replaceAll('%d', countStr),
                                  style: AppTypography.headingL.copyWith(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: primary,
                                    fontFamily: lang == 'ar' ? 'Cairo' : null,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'khatma_date_completed'.tr().replaceAll('%s', dateStr),
                                  style: AppTypography.bodyS.copyWith(
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 700.ms, delay: 500.ms)
                              .scale(
                                begin: const Offset(0.8, 0.8),
                                end: const Offset(1.0, 1.0),
                                delay: 500.ms,
                                duration: 500.ms,
                                curve: Curves.elasticOut,
                              ),

                          const SizedBox(height: 40),

                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const KhatmaDuaScreen()),
                              ),
                              icon: const Icon(Icons.menu_book_rounded),
                              label: Text(
                                'khatma_read_dua_btn'.tr(),
                                style: AppTypography.bodyL.copyWith(fontWeight: FontWeight.bold),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 500.ms, delay: 800.ms)
                              .slideY(begin: 0.3, end: 0, delay: 800.ms, duration: 400.ms),

                          const SizedBox(height: 12),

                          AuraButton.secondary(
                            label: 'khatma_done_btn'.tr(),
                            onPressed: () => Navigator.of(context).pop(),
                            expanded: true,
                            verticalPadding: 14,
                          )
                              .animate()
                              .fadeIn(duration: 500.ms, delay: 950.ms),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
