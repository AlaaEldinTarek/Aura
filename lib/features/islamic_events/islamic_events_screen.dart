import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/islamic_event.dart';
import '../../core/providers/islamic_events_provider.dart';
import '../../core/utils/hijri_date.dart';
import '../../core/utils/number_formatter.dart';

class IslamicEventsScreen extends ConsumerWidget {
  const IslamicEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(islamicEventsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final primary = AppConstants.getPrimary(isDark);

    return Scaffold(
      appBar: AppBar(title: Text('events_title'.tr())),
      body: events.isEmpty
          ? Center(child: Text('events_no_events'.tr()))
          : ListView.separated(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final e = events[index];
                return _EventCard(
                  item: e,
                  isDark: isDark,
                  isArabic: isArabic,
                  primary: primary,
                );
              },
            ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final IslamicEventWithDate item;
  final bool isDark;
  final bool isArabic;
  final Color primary;

  const _EventCard({
    required this.item,
    required this.isDark,
    required this.isArabic,
    required this.primary,
  });

  Color _badgeColor() {
    if (item.daysUntil == 0) return Colors.green;
    if (item.daysUntil <= 7) return const Color(0xFFFF8F00);
    if (item.daysUntil <= 30) return primary;
    return Colors.grey;
  }

  String _countdownText() {
    if (item.daysUntil == 0) return isArabic ? 'اليوم!' : 'Today!';
    if (item.daysUntil == 1) return isArabic ? 'غداً' : 'Tomorrow';
    final n = NumberFormatter.withArabicNumeralsByLanguage(
      item.daysUntil.toString(),
      isArabic ? 'ar' : 'en',
    );
    return isArabic ? 'بعد $n يوم' : 'in $n days';
  }

  String _hijriLabel() {
    final h = HijriDate.toHijri(item.date);
    return isArabic ? HijriDate.formatAr(h) : HijriDate.formatEn(h);
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = _badgeColor();
    final secondary = isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: item.daysUntil <= 7
              ? badgeColor.withOpacity(0.35)
              : (isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
        ),
        boxShadow: item.daysUntil <= 7
            ? [BoxShadow(color: badgeColor.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Emoji
                Text(item.event.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                // Name + Hijri date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? item.event.nameAr : item.event.nameEn,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: isArabic ? 'Cairo' : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _hijriLabel(),
                        style: TextStyle(fontSize: 12, color: secondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Countdown badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    _countdownText(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Description
            Text(
              isArabic ? item.event.descriptionAr : item.event.descriptionEn,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: secondary,
                fontFamily: isArabic ? 'Cairo' : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
