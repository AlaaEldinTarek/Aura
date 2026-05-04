import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/prayer_time.dart';
import '../models/prayer_record.dart';
import '../utils/number_formatter.dart';
import '../utils/date_formatter.dart';

/// A beautiful prayer time card with countdown indicator
class PrayerCard extends StatelessWidget {
  final PrayerTime prayer;
  final bool isNext;
  final bool isCurrent;
  final VoidCallback? onTap;
  final bool showIqamah;
  final String? iqamahTime;
  final bool isCompleted; // Track if prayer is completed
  final PrayerStatus? prayerStatus; // Actual status (onTime/late/missed)
  final bool wasExplicitlyMarked; // True if user actively chose a status (including missed)
  final VoidCallback? onMarkPrayed; // Callback for marking as prayed

  const PrayerCard({
    super.key,
    required this.prayer,
    this.isNext = false,
    this.isCurrent = false,
    this.onTap,
    this.showIqamah = false,
    this.iqamahTime,
    this.isCompleted = false,
    this.prayerStatus,
    this.wasExplicitlyMarked = false,
    this.onMarkPrayed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';

    // Determine colors based on state
    Color cardColor;
    Color borderColor;
    Color iconColor;
    double borderWidth;

    if (isCurrent) {
      cardColor = isDark
          ? AppConstants.getPrimary(isDark).withOpacity(0.15)
          : AppConstants.getPrimary(isDark).withOpacity(0.1);
      borderColor = AppConstants.getPrimary(isDark);
      iconColor = AppConstants.getPrimary(isDark);
      borderWidth = 2;
    } else if (isNext) {
      cardColor = isDark ? AppConstants.darkCard : AppConstants.lightCard;
      borderColor = AppConstants.getPrimary(isDark).withOpacity(0.5);
      iconColor = AppConstants.getPrimary(isDark);
      borderWidth = 1.5;
    } else {
      cardColor = isDark ? AppConstants.darkCard : AppConstants.lightCard;
      borderColor = isDark ? AppConstants.darkBorder : AppConstants.lightBorder;
      iconColor = isDark ? Colors.white54 : Colors.black54;
      borderWidth = 1;
    }

    return AnimatedContainer(
      duration: AppConstants.animationDurationMedium,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: isNext || isCurrent
            ? [
                BoxShadow(
                  color: borderColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          button: true,
          label: '${isArabic ? prayer.nameAr : prayer.name}, ${_formatPrayerTime(prayer, isArabic)}'
              '${isCompleted ? ", ${isArabic ? 'مُصلّاة' : 'prayed'}" : ""}'
              '${isCurrent ? ", ${isArabic ? 'الصلاة الحالية' : 'current prayer'}" : ""}',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Row(
              children: [
                // Prayer Icon with Indicator
                _buildPrayerIcon(context, isCurrent, isNext, iconColor),
                const SizedBox(width: AppConstants.paddingMedium),

                // Prayer Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Prayer Name with Badge
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              isArabic ? prayer.nameAr : prayer.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: isNext || isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isCurrent
                                        ? AppConstants.getPrimary(isDark)
                                        : null,
                                  ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: AppConstants.paddingSmall),
                            _buildCurrentBadge(context, isArabic),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Prayer Time
                      Text(
                        _formatPrayerTime(prayer, isArabic),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                      ),

                      // Iqamah Time
                      if (prayer.iqamaTime != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          isArabic
                              ? 'الإقامة: ${DateFormatter.formatTime(prayer.iqamaTime!, languageCode: 'ar')}'
                              : 'Iqamah: ${DateFormatter.formatTime(prayer.iqamaTime!)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppConstants.accentCyan,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Time / Countdown or Mark as Prayed button
                if (isCompleted || wasExplicitlyMarked)
                  _buildCompletedIndicator(context, isArabic, onMarkPrayed, prayerStatus)
                else if (onMarkPrayed != null)
                  _buildMarkPrayedButton(context, isArabic, isDark)
                else if (isNext)
                  _buildCountdown(context, prayer.time, isArabic, isDark)
                else
                  Icon(
                    Icons.chevron_right,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildPrayerIcon(
      BuildContext context, bool isCurrent, bool isNext, Color iconColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: isCurrent
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppConstants.getPrimary(isDark),
                  AppConstants.accentCyan,
                ],
              )
            : null,
        color: isNext ? null : iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Center(
        child: _buildPrayerIconChild(iconColor, isCurrent),
      ),
    );
  }

  Widget _buildPrayerIconChild(Color iconColor, bool isCurrent) {
    final assetPath = _getPrayerIconAsset();
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        width: 30,
        height: 30,
        color: isCurrent ? Colors.white : null,
      );
    }
    return Text(
      _getPrayerEmoji(),
      style: const TextStyle(fontSize: 28),
    );
  }

  Widget _buildCurrentBadge(BuildContext context, bool isArabic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppConstants.getPrimary(isDark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isArabic ? 'الآن' : 'NOW',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCountdown(
      BuildContext context, DateTime prayerTime, bool isArabic, bool isDark) {
    final now = DateTime.now();
    final difference = prayerTime.difference(now);

    if (difference.isNegative) {
      return const SizedBox.shrink();
    }

    String countdown;
    if (difference.inHours > 0) {
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      countdown = isArabic ? '$hours س $minutes د' : '${hours}h ${minutes}m';
    } else {
      countdown = isArabic ? '${difference.inMinutes} د' : '${difference.inMinutes}m';
    }

    // Convert to Arabic numerals if needed
    if (isArabic) {
      countdown = NumberFormatter.withArabicNumeralsByLanguage(countdown, 'ar');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppConstants.getPrimary(isDark).withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: AppConstants.getPrimary(isDark).withOpacity(0.3),
        ),
      ),
      child: Text(
        countdown,
        style: TextStyle(
          color: AppConstants.getPrimary(isDark),
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  String _formatPrayerTime(PrayerTime prayer, bool isArabic) {
    String time = prayer.time12h;
    if (isArabic) {
      time = time.replaceAll('AM', 'ص').replaceAll('PM', 'م');
      time = NumberFormatter.withArabicNumeralsByLanguage(time, 'ar');
    }
    return time;
  }

  String? _getPrayerIconAsset() {
    switch (prayer.name.toLowerCase()) {
      case 'fajr':
      case 'sunrise':
        return 'assets/images/ic_prayer_fajr.png';
      case 'dhuhr':
      case 'zuhr':
        return 'assets/images/ic_prayer_dhuhr.png';
      case 'asr':
        return 'assets/images/ic_prayer_asr.png';
      case 'maghrib':
        return 'assets/images/ic_prayer_maghrib.png';
      case 'isha':
        return 'assets/images/ic_prayer_isha.png';
      default:
        return null;
    }
  }

  String _getPrayerEmoji() {
    switch (prayer.name.toLowerCase()) {
      case 'fajr':
        return '🌙';
      case 'sunrise':
        return '🌅';
      case 'dhuhr':
      case 'zuhr':
        return '☀️';
      case 'asr':
        return '🌤️';
      case 'maghrib':
        return '🌇';
      case 'isha':
        return '🌃';
      default:
        return '🕌';
    }
  }

  /// Build completed indicator (green/orange/red badge) - clickable to uncheck
  Widget _buildCompletedIndicator(BuildContext context, bool isArabic, VoidCallback? onUncheck, PrayerStatus? status) {
    final isLate = status == PrayerStatus.late;
    final isMissed = status == PrayerStatus.excused || status == PrayerStatus.missed;
    final color = isMissed ? Colors.red : (isLate ? Colors.orange : Colors.green);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onUncheck,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isMissed ? Icons.cancel : (isLate ? Icons.schedule : Icons.check_circle),
                color: color,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                isMissed
                    ? (isArabic ? 'لم أصلّ' : 'Missed')
                    : isLate
                        ? (isArabic ? 'متأخر' : 'Late')
                        : (isArabic ? 'في الوقت' : 'On Time'),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build "Mark as Prayed" button
  Widget _buildMarkPrayedButton(BuildContext context, bool isArabic, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onMarkPrayed,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppConstants.getPrimary(isDark).withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(
              color: AppConstants.getPrimary(isDark).withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: AppConstants.getPrimary(isDark),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                isArabic ? 'أديت' : 'Prayed',
                style: TextStyle(
                  color: AppConstants.getPrimary(isDark),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
