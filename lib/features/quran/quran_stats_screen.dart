import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/wird.dart';
import '../../core/providers/wird_provider.dart';
import '../../core/utils/number_formatter.dart';

class QuranStatsScreen extends ConsumerWidget {
  const QuranStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(quranStatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final primary = AppConstants.getPrimary(isDark);

    return Scaffold(
      appBar: AppBar(title: Text('quran_stats_title'.tr())),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stats) => _StatsContent(
          stats: stats,
          isDark: isDark,
          isArabic: isArabic,
          primary: primary,
        ),
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  final QuranStatsData stats;
  final bool isDark;
  final bool isArabic;
  final Color primary;

  const _StatsContent({
    required this.stats,
    required this.isDark,
    required this.isArabic,
    required this.primary,
  });

  String _n(Object v) => NumberFormatter.withArabicNumeralsByLanguage(
        v.toString(),
        isArabic ? 'ar' : 'en',
      );

  @override
  Widget build(BuildContext context) {
    final isJuz = stats.wirdUnit == WirdUnit.juz;
    final secondary = isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header badges ─────────────────────────────────────────────────
          Row(
            children: [
              Expanded(child: _BadgeCard(
                emoji: '📖',
                value: _n(stats.totalPages),
                label: 'quran_stats_header_pages'.tr(),
                primary: primary,
                isDark: isDark,
              )),
              const SizedBox(width: 12),
              Expanded(child: _BadgeCard(
                emoji: '🏆',
                value: _n(stats.khatmCount),
                label: 'quran_stats_header_khatm'.tr(),
                primary: primary,
                isDark: isDark,
              )),
            ],
          ),
          const SizedBox(height: 16),

          // ── Weekly bar chart ──────────────────────────────────────────────
          _SectionCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'quran_stats_weekly_chart'.tr(),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                _BarChart(
                  values: isJuz ? stats.weeklyJuz : stats.weeklyPages,
                  primary: primary,
                  secondary: secondary,
                  isDark: isDark,
                  isArabic: isArabic,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Stats grid ────────────────────────────────────────────────────
          _SectionCard(
            isDark: isDark,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _StatTile(
                      icon: Icons.local_fire_department,
                      iconColor: const Color(0xFFFF7043),
                      label: 'quran_stats_current_streak'.tr(),
                      value: '${_n(stats.currentStreak)} ${'quran_stats_days'.tr()}',
                      secondary: secondary,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _StatTile(
                      icon: Icons.emoji_events,
                      iconColor: const Color(0xFFFFB300),
                      label: 'quran_stats_best_streak'.tr(),
                      value: '${_n(stats.bestStreak)} ${'quran_stats_days'.tr()}',
                      secondary: secondary,
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _StatTile(
                      icon: Icons.auto_graph,
                      iconColor: primary,
                      label: 'quran_stats_avg_daily'.tr(),
                      value: isJuz
                          ? '${_n(stats.averageDaily.toStringAsFixed(1))} ${'quran_stats_juz'.tr()}'
                          : '${_n(stats.averageDaily.toStringAsFixed(1))} ${'quran_stats_pages'.tr()}',
                      secondary: secondary,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _StatTile(
                      icon: Icons.calendar_today,
                      iconColor: Colors.teal,
                      label: 'quran_stats_days_active'.tr(),
                      value: '${_n(stats.totalDays)} ${'quran_stats_days'.tr()}',
                      secondary: secondary,
                    )),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Khatm progress ────────────────────────────────────────────────
          _SectionCard(
            isDark: isDark,
            child: Column(
              children: [
                Text(
                  'quran_stats_khatm_progress'.tr(),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                _KhatmCircle(
                  done: stats.allCompletedJuz.length,
                  total: 30,
                  primary: primary,
                  secondary: secondary,
                  isArabic: isArabic,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _BadgeCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color primary;
  final bool isDark;

  const _BadgeCard({
    required this.emoji,
    required this.value,
    required this.label,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary.withOpacity(0.15), primary.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primary),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _SectionCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: child,
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color secondary;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: secondary)),
        ],
      ),
    );
  }
}

class _KhatmCircle extends StatelessWidget {
  final int done;
  final int total;
  final Color primary;
  final Color secondary;
  final bool isArabic;

  const _KhatmCircle({
    required this.done,
    required this.total,
    required this.primary,
    required this.secondary,
    required this.isArabic,
  });

  String _n(int v) => NumberFormatter.withArabicNumeralsByLanguage(
        v.toString(),
        isArabic ? 'ar' : 'en',
      );

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? done / total : 0.0;
    final isComplete = done >= total;
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            strokeWidth: 10,
            backgroundColor: secondary.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(isComplete ? Colors.green : primary),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_n(done)}/${'${_n(total)}'}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  'wird_unit_juz'.tr(),
                  style: TextStyle(fontSize: 12, color: secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bar chart ─────────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  final List<int> values;
  final Color primary;
  final Color secondary;
  final bool isDark;
  final bool isArabic;

  const _BarChart({
    required this.values,
    required this.primary,
    required this.secondary,
    required this.isDark,
    required this.isArabic,
  });

  String _dayLabel(int dayOffset) {
    final day = DateTime.now().subtract(Duration(days: 6 - dayOffset));
    if (isArabic) {
      const arDays = ['أح', 'إث', 'ثل', 'أر', 'خم', 'جم', 'سب'];
      return arDays[day.weekday % 7];
    }
    const enDays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    return enDays[day.weekday % 7];
  }

  @override
  Widget build(BuildContext context) {
    final maxVal = values.isEmpty ? 0 : values.reduce(max);
    final hasData = maxVal > 0;

    if (!hasData) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'quran_stats_no_data'.tr(),
            style: TextStyle(color: secondary, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 100,
          child: CustomPaint(
            size: Size.infinite,
            painter: _BarChartPainter(
              values: values,
              maxVal: maxVal,
              barColor: primary,
              todayColor: primary,
              bgColor: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(7, (i) {
            final isToday = i == 6;
            return Expanded(
              child: Text(
                _dayLabel(i),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? primary : secondary,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<int> values;
  final int maxVal;
  final Color barColor;
  final Color todayColor;
  final Color bgColor;

  const _BarChartPainter({
    required this.values,
    required this.maxVal,
    required this.barColor,
    required this.todayColor,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveMax = maxVal == 0 ? 1 : maxVal;
    final slotW = size.width / 7;
    final barW = slotW * 0.55;
    const radius = Radius.circular(5);

    final bgPaint = Paint()..color = bgColor;

    for (int i = 0; i < 7; i++) {
      final x = slotW * i + slotW / 2;
      final fillH = (values[i] / effectiveMax) * size.height;
      final isToday = i == 6;

      // Background track
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - barW / 2, 0, barW, size.height),
          radius,
        ),
        bgPaint,
      );

      // Filled portion
      if (fillH > 0) {
        final fillPaint = Paint()
          ..color = isToday ? todayColor : barColor.withOpacity(0.75);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - barW / 2, size.height - fillH, barW, fillH),
            radius,
          ),
          fillPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.values.toString() != values.toString() ||
      old.barColor != barColor ||
      old.bgColor != bgColor;
}
