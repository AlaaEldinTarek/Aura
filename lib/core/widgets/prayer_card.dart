import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/app_constants.dart';
import '../models/prayer_time.dart';
import '../models/prayer_record.dart';
import '../utils/number_formatter.dart';
import '../utils/date_formatter.dart';
import '../theme/app_typography.dart';
import 'info_tip_icon.dart';

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
  final bool isWindowOpen; // True when 20-min window has passed and prayer can be marked

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
    this.isWindowOpen = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';
    final ts = MediaQuery.textScalerOf(context);

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
      cardColor = AppConstants.card(isDark);
      borderColor = AppConstants.getPrimary(isDark).withOpacity(0.5);
      iconColor = AppConstants.getPrimary(isDark);
      borderWidth = 1.5;
    } else {
      cardColor = AppConstants.card(isDark);
      borderColor = AppConstants.border(isDark);
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
              padding: EdgeInsets.all(ts.scale(AppConstants.paddingMedium)),
              child: Row(
              children: [
                // Prayer Icon with Indicator
                _buildPrayerIcon(context, isCurrent, isNext, iconColor),
                SizedBox(width: ts.scale(AppConstants.paddingMedium)),

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
                            SizedBox(width: ts.scale(AppConstants.paddingSmall)),
                            _buildCurrentBadge(context, isArabic),
                          ],
                          if (!isWindowOpen && !isCompleted && !wasExplicitlyMarked) ...[
                            SizedBox(width: ts.scale(4.0)),
                            InfoTipIcon(
                              titleKey: 'twenty_min_rule_title',
                              bodyKey: 'twenty_min_rule_body',
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: ts.scale(4.0)),

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
                        SizedBox(height: ts.scale(2.0)),
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
                    color: AppConstants.textDisabled(isDark),
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
    final ts = MediaQuery.textScalerOf(context);
    final containerSize = ts.scale(52.0);
    final imageSize = ts.scale(30.0);
    return Container(
      width: containerSize,
      height: containerSize,
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
        child: _buildPrayerIconChild(context, iconColor, isCurrent, imageSize: imageSize),
      ),
    );
  }

  Widget _buildPrayerIconChild(BuildContext context, Color iconColor, bool isCurrent, {double imageSize = 30}) {
    final assetPath = _getPrayerIconAsset();
    if (assetPath != null) {
      return Image.asset(
        assetPath,
        width: imageSize,
        height: imageSize,
        color: isCurrent ? Colors.white : null,
      );
    }
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Text(
        _getPrayerEmoji(),
        style: TextStyle(fontSize: imageSize - 2),
      ),
    );
  }

  Widget _buildCurrentBadge(BuildContext context, bool isArabic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ts = MediaQuery.textScalerOf(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ts.scale(8.0), vertical: ts.scale(2.0)),
      decoration: BoxDecoration(
        color: AppConstants.getPrimary(isDark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isArabic ? 'الآن' : 'NOW',
        style: AppTypography.caption.copyWith(
          color: Colors.white,
          fontSize: ts.scale(10.0),
          fontWeight: FontWeight.bold,
        ),
        textScaler: TextScaler.noScaling,
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

    final ts = MediaQuery.textScalerOf(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ts.scale(10.0), vertical: ts.scale(6.0)),
      decoration: BoxDecoration(
        color: AppConstants.getPrimary(isDark).withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: AppConstants.getPrimary(isDark).withOpacity(0.3),
        ),
      ),
      child: Text(
        countdown,
        style: AppTypography.bodyS.copyWith(
          color: AppConstants.getPrimary(isDark),
          fontWeight: FontWeight.bold,
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
    final ts = MediaQuery.textScalerOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onUncheck,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: ts.scale(12.0), vertical: ts.scale(6.0)),
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
                size: ts.scale(18.0),
              ),
              SizedBox(width: ts.scale(6.0)),
              Text(
                isMissed
                    ? (isArabic ? 'لم أصلّ' : 'Missed')
                    : isLate
                        ? (isArabic ? 'متأخر' : 'Late')
                        : (isArabic ? 'في الوقت' : 'On Time'),
                style: AppTypography.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
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
    final ts = MediaQuery.textScalerOf(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onMarkPrayed,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: ts.scale(12.0), vertical: ts.scale(6.0)),
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
                size: ts.scale(18.0),
              ),
              SizedBox(width: ts.scale(6.0)),
              Text(
                isArabic ? 'أديت' : 'Prayed',
                style: AppTypography.caption.copyWith(
                  color: AppConstants.getPrimary(isDark),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
