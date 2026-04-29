import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/quran_provider.dart';
import '../../core/utils/number_formatter.dart';

class QuranStatsScreen extends ConsumerWidget {
  const QuranStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final progressAsync = ref.watch(quranReadingProgressProvider);
    final historyAsync = ref.watch(quranReadingHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text('quran_stats'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Streak & Progress
            progressAsync.when(
              data: (progress) => _buildStreakCard(progress, isDark, isArabic),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppConstants.paddingMedium),

            // Stats grid
            progressAsync.when(
              data: (progress) => _buildStatsGrid(progress, isDark, isArabic),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppConstants.paddingMedium),

            // 30-day chart
            historyAsync.when(
              data: (logs) => _buildReadingChart(logs, isDark, isArabic),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard(dynamic progress, bool isDark, bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2A2B2E), const Color(0xFF1A1B1E)]
              : [const Color(0xFFFFEACC), const Color(0xFFFFF3D6)],
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: AppConstants.getPrimary(isDark).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStreakItem(
            icon: Icons.local_fire_department,
            value: isArabic ? NumberFormatter.withArabicNumerals('${progress.currentStreak}') : '${progress.currentStreak}',
            label: 'current_streak'.tr(),
            color: Colors.orange,
            isDark: isDark,
          ),
          _buildStreakItem(
            icon: Icons.emoji_events,
            value: isArabic ? NumberFormatter.withArabicNumerals('${progress.longestStreak}') : '${progress.longestStreak}',
            label: 'longest_streak'.tr(),
            color: Colors.amber,
            isDark: isDark,
          ),
          _buildStreakItem(
            icon: Icons.auto_stories,
            value: isArabic ? NumberFormatter.withArabicNumerals('${progress.khatmahCount}') : '${progress.khatmahCount}',
            label: 'khatmah_count'.tr(),
            color: AppConstants.getPrimary(isDark),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStreakItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppConstants.lightTextPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(dynamic progress, bool isDark, bool isArabic) {
    final pagesRead = progress.totalPagesRead;
    final pagesInKhatmah = progress.pagesInCurrentKhatmah;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.8,
      children: [
        _buildStatCard(
          title: 'total_pages_read'.tr(),
          value: isArabic ? NumberFormatter.withArabicNumerals('$pagesRead') : '$pagesRead',
          icon: Icons.menu_book,
          isDark: isDark,
        ),
        _buildStatCard(
          title: 'current_khatmah'.tr(),
          value: isArabic
              ? '${NumberFormatter.withArabicNumerals('$pagesInKhatmah')} / ${NumberFormatter.withArabicNumerals('604')}'
              : '$pagesInKhatmah / 604',
          icon: Icons.auto_stories,
          isDark: isDark,
        ),
        _buildStatCard(
          title: 'khatmah_progress'.tr(),
          value: '${(progress.khatmahProgress * 100).toStringAsFixed(1)}%',
          icon: Icons.pie_chart,
          isDark: isDark,
        ),
        _buildStatCard(
          title: 'avg_per_day'.tr(),
          value: pagesRead > 0
              ? (isArabic
                  ? NumberFormatter.withArabicNumerals('${(pagesRead / (progress.currentStreak > 0 ? progress.currentStreak : 1)).toStringAsFixed(1)}')
                  : (pagesRead / (progress.currentStreak > 0 ? progress.currentStreak : 1)).toStringAsFixed(1))
              : '0',
          icon: Icons.trending_up,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkSurface : AppConstants.lightSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppConstants.getPrimary(isDark)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppConstants.lightTextPrimary,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingChart(List logs, bool isDark, bool isArabic) {
    if (logs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'reading_history_30'.tr(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppConstants.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 180,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? AppConstants.darkSurface : AppConstants.lightSurface,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _getMaxY(logs),
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (val, _) => Text(
                      '${val.toInt()}',
                      style: TextStyle(fontSize: 10, color: isDark ? AppConstants.darkTextSecondary : AppConstants.lightTextSecondary),
                    ),
                  ),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(show: false),
              barGroups: logs.map<BarChartGroupData>((log) {
                return BarChartGroupData(
                  x: 0,
                  barRods: [
                    BarChartRodData(
                      toY: (log.pagesRead as num).toDouble(),
                      color: AppConstants.getPrimary(isDark),
                      width: 8,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  double _getMaxY(List logs) {
    if (logs.isEmpty) return 10;
    final maxPages = logs.map((l) => (l.pagesRead as num).toDouble()).reduce((a, b) => a > b ? a : b);
    return (maxPages * 1.2).clamp(5, double.infinity);
  }
}
