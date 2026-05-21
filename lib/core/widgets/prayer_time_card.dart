import 'package:flutter/material.dart';
import '../../core/models/prayer_time.dart';
import '../../core/constants/app_constants.dart';

/// Widget for displaying a single prayer time card
class PrayerTimeCard extends StatelessWidget {
  final PrayerTime prayerTime;
  final bool isSelected;
  final bool isNext;
  final bool isCurrent;
  final VoidCallback? onTap;

  const PrayerTimeCard({
    super.key,
    required this.prayerTime,
    this.isSelected = false,
    this.isNext = false,
    this.isCurrent = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final ts = MediaQuery.textScalerOf(context);

    // Time formatting
    final hour = prayerTime.time.hour % 12 == 0 ? 12 : prayerTime.time.hour % 12;
    final minute = prayerTime.time.minute.toString().padLeft(2, '0');
    final period = prayerTime.time.hour < 12 ? 'AM' : 'PM';
    final timeFormat = '$hour:$minute $period';

    final timeRemaining = prayerTime.time.difference(DateTime.now());

    return Container(
      margin: EdgeInsets.symmetric(horizontal: ts.scale(4.0)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getGradientForPrayer(prayerTime.name, isDark),
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: [
          if (isNext || isCurrent)
            BoxShadow(
              color: _getPrayerColor(prayerTime.name, isDark).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: ts.scale(16.0), vertical: ts.scale(12.0)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Prayer emoji
                Container(
                  width: ts.scale(32.0),
                  height: ts.scale(32.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      prayerTime.emoji,
                      style: TextStyle(fontSize: ts.scale(18.0)),
                      textScaler: TextScaler.noScaling,
                    ),
                  ),
                ),
                SizedBox(height: ts.scale(8.0)),

                // Prayer name
                Text(
                  isArabic ? prayerTime.nameAr : prayerTime.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: ts.scale(4.0)),

                // Prayer time
                Text(
                  timeFormat,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),

                // Time remaining (if next prayer)
                if (isNext && timeRemaining.inSeconds > 0)
                  Padding(
                    padding: EdgeInsets.only(top: ts.scale(4.0)),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: ts.scale(6.0), vertical: ts.scale(2.0)),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatTimeRemaining(timeRemaining),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontSize: ts.scale(10.0),
                            ),
                        textScaler: TextScaler.noScaling,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeRemaining(Duration duration) {
    if (duration.isNegative) return 'Now';

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  List<Color> _getGradientForPrayer(String prayerName, bool isDark) {
    // Use Aura theme gradient (Primary Blue to Accent Cyan)
    if (isDark) {
      return [
        AppConstants.getPrimary(isDark).withOpacity(0.8),
        AppConstants.accentCyan.withOpacity(0.6),
      ];
    } else {
      return [
        AppConstants.getPrimary(isDark),
        AppConstants.accentCyan,
      ];
    }
  }

  Color _getPrayerColor(String prayerName, bool isDark) {
    // Use Aura theme colors for prayer-specific highlights
    switch (prayerName) {
      case 'Fajr':
        return AppConstants.getPrimary(isDark); // Blue
      case 'Sunrise':
        return AppConstants.accentOrange; // Orange
      case 'Zuhr':
        return AppConstants.getPrimary(isDark); // Blue
      case 'Asr':
        return AppConstants.accentPurple; // Purple
      case 'Maghrib':
        return AppConstants.accentOrange; // Orange
      case 'Isha':
        return AppConstants.accentPurple; // Purple
      default:
        return AppConstants.getPrimary(isDark);
    }
  }
}
