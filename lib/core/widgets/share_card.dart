import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_typography.dart';
import '../utils/number_formatter.dart';

enum ShareCardType { prayerStreak, taskStreak, wirdStreak, khatm }

/// Renders a branded shareable card inside a RepaintBoundary.
/// Use [captureAndShare(key, filename)] from share_util.dart to export it.
class ShareCard extends StatelessWidget {
  final GlobalKey repaintKey;
  final ShareCardType type;
  final int count;
  final String lang;

  const ShareCard({
    super.key,
    required this.repaintKey,
    required this.type,
    required this.count,
    required this.lang,
  });

  bool get _isAr => lang == 'ar';

  String get _emoji {
    switch (type) {
      case ShareCardType.prayerStreak: return '🕌';
      case ShareCardType.taskStreak:   return '✅';
      case ShareCardType.wirdStreak:   return '📖';
      case ShareCardType.khatm:        return '🌙✨';
    }
  }

  String get _titleEn {
    switch (type) {
      case ShareCardType.prayerStreak: return 'Prayer Streak';
      case ShareCardType.taskStreak:   return 'Task Streak';
      case ShareCardType.wirdStreak:   return 'Wird Streak';
      case ShareCardType.khatm:        return 'Quran Khatm';
    }
  }

  String get _titleAr {
    switch (type) {
      case ShareCardType.prayerStreak: return 'سلسلة الصلاة';
      case ShareCardType.taskStreak:   return 'سلسلة المهام';
      case ShareCardType.wirdStreak:   return 'سلسلة الورد';
      case ShareCardType.khatm:        return 'ختمة القرآن';
    }
  }

  String get _subtitleEn {
    if (type == ShareCardType.khatm) return 'Khatm #$count completed';
    return '$count day${count == 1 ? '' : 's'} in a row!';
  }

  String get _subtitleAr {
    final n = NumberFormatter.withArabicNumerals('$count');
    if (type == ShareCardType.khatm) return 'ختمة رقم $n مكتملة';
    return '$n ${count == 1 ? 'يوم' : 'أيام'} متواصلة!';
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFFF5B301);
    final countStr = NumberFormatter.withArabicNumeralsByLanguage('$count', lang);

    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        width: 320,
        height: 320,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1500), Color(0xFF111317), Color(0xFF1A1200)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            // Gold circle decoration
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withOpacity(0.06),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App brand
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: primary.withOpacity(0.4)),
                        ),
                        child: Center(
                          child: Text('A', style: AppTypography.bodyM.copyWith(
                            color: primary,
                            fontWeight: FontWeight.bold,
                          )),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Aura | هالة',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Emoji
                  Text(_emoji, style: const TextStyle(fontSize: 52)),
                  const SizedBox(height: 8),

                  // Count
                  Text(
                    countStr,
                    style: AppTypography.displayL.copyWith(
                      color: primary,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Title
                  Text(
                    _isAr ? _titleAr : _titleEn,
                    style: AppTypography.headingS.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Subtitle
                  Text(
                    _isAr ? _subtitleAr : _subtitleEn,
                    style: AppTypography.bodyS.copyWith(
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
