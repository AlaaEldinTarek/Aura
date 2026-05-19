import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/islamic_event.dart';
import '../../core/providers/islamic_events_provider.dart';
import '../../core/utils/hijri_date.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/theme/app_typography.dart';

class IslamicEventsScreen extends ConsumerWidget {
  const IslamicEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(islamicEventsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final primary = AppConstants.getPrimary(isDark);
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    Widget buildCard(IslamicEventWithDate e) => _EventCard(
      item: e, isDark: isDark, isArabic: isArabic, primary: primary,
    );

    return Scaffold(
      appBar: AppBar(title: Text('events_title'.tr())),
      body: events.isEmpty
          ? Center(child: Text('events_no_events'.tr()))
          : ListView.separated(
                  padding: const EdgeInsets.all(AppConstants.paddingMedium),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => buildCard(events[index]),
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
            Builder(builder: (ctx) {
              final ts = MediaQuery.textScalerOf(ctx);
              final chipSz = ts.scale(48.0);
              final emojiFz = (chipSz * 0.50).clamp(16.0, 40.0);
              return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Col 1: emoji chip
                Container(
                  width: chipSz,
                  height: chipSz,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  ),
                  child: Text(
                    item.event.emoji,
                    style: TextStyle(fontSize: emojiFz, height: 1.0),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                // Col 2: 2-line text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? item.event.nameAr : item.event.nameEn,
                        style: (isArabic
                            ? AppTypography.ar(AppTypography.headingS)
                            : AppTypography.headingS).copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _hijriLabel(),
                        style: AppTypography.caption.copyWith(color: secondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Col 3: countdown badge chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    _countdownText(),
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            );
            }),
            const SizedBox(height: 10),
            // Description
            Text(
              isArabic ? item.event.descriptionAr : item.event.descriptionEn,
              style: (isArabic
                  ? AppTypography.ar(AppTypography.caption)
                  : AppTypography.caption).copyWith(
                height: 1.5,
                color: secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
