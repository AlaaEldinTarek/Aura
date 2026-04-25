import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/dhikr.dart';
import '../../core/models/prayer_record.dart';
import '../../core/services/dhikr_service.dart';
import '../../core/utils/number_formatter.dart';

/// Dhikr Statistics Screen - Shows session history and stats
class DhikrStatsScreen extends StatefulWidget {
  const DhikrStatsScreen({super.key});

  @override
  State<DhikrStatsScreen> createState() => _DhikrStatsScreenState();
}

class _DhikrStatsScreenState extends State<DhikrStatsScreen> {
  final DhikrService _dhikrService = DhikrService.instance;
  bool _isLoading = true;

  DhikrStatistics _stats = DhikrStatistics.empty();
  List<DhikrSession> _recentSessions = [];
  List<double> _weeklyCounts = [];
  List<String> _weeklyLabels = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final userId = getCurrentUserId();
    final now = DateTime.now();

    try {
      final stats = await _dhikrService.getStatistics(userId: userId);
      final recent = await _dhikrService.getRecentSessions(userId: userId);

      // Weekly chart data (last 7 days)
      final List<double> weeklyCounts = [];
      final List<String> weeklyLabels = [];
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final dayStart = DateTime(day.year, day.month, day.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        final sessions = await _dhikrService.getSessionsForDateRange(
          userId: userId,
          startDate: dayStart,
          endDate: dayEnd,
        );

        int dayCount = 0;
        for (final s in sessions) {
          dayCount += s.count;
        }
        weeklyCounts.add(dayCount.toDouble());
        weeklyLabels.add('${day.day}/${day.month}');
      }

      if (mounted) {
        setState(() {
          _stats = stats;
          _recentSessions = recent;
          _weeklyCounts = weeklyCounts;
          _weeklyLabels = weeklyLabels;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dhikr stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _n(dynamic value, {bool isArabic = false}) {
    final str = value.toString();
    return isArabic ? NumberFormatter.withArabicNumerals(str) : str;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'إحصائيات الأذكار' : 'Zikr Statistics'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top stats cards
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.local_fire_department,
                            label: isArabic ? 'التتابع' : 'Streak',
                            value: _n(_stats.streakDays, isArabic: isArabic),
                            color: Colors.orange,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: AppConstants.paddingSmall),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.pan_tool,
                            label: isArabic ? 'اليوم' : 'Today',
                            value: _n(_stats.todayCount, isArabic: isArabic),
                            color: Colors.green,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: AppConstants.paddingSmall),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.format_list_numbered,
                            label: isArabic ? 'الجلسات' : 'Sessions',
                            value: _n(_stats.totalSessions, isArabic: isArabic),
                            color: AppConstants.getPrimary(isDark),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppConstants.paddingLarge),

                    // Weekly activity chart
                    _buildSectionCard(
                      context,
                      isArabic ? 'النشاط الأسبوعي' : 'Weekly Activity',
                      isArabic ? 'عدد التسبيحات في آخر 7 أيام' : 'Zikr count over last 7 days',
                      _buildWeeklyChart(isDark, isArabic),
                      isDark,
                    ),

                    const SizedBox(height: AppConstants.paddingLarge),

                    // Recent sessions
                    _buildSectionCard(
                      context,
                      isArabic ? 'الجلسات الأخيرة' : 'Recent Sessions',
                      '',
                      _recentSessions.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                isArabic ? 'لا توجد جلسات بعد' : 'No sessions yet',
                                style: TextStyle(
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : Column(
                              children: _recentSessions.map((session) {
                                return _buildSessionRow(session, isDark, isArabic);
                              }).toList(),
                            ),
                      isDark,
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSessionRow(DhikrSession session, bool isDark, bool isArabic) {
    final date = session.createdAt;
    final dateStr = '${date.day}/${date.month}/${date.year}';
    final completed = session.isCompleted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: completed ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.dhikrText.isNotEmpty ? session.dhikrText : 'Custom',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  _n(dateStr, isArabic: isArabic),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${_n(session.count, isArabic: isArabic)}/${_n(session.target, isArabic: isArabic)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    String title,
    String subtitle,
    Widget child,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
          ],
          const SizedBox(height: AppConstants.paddingMedium),
          child,
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(bool isDark, bool isArabic) {
    if (_weeklyCounts.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _weeklyCounts.reduce((a, b) => a > b ? a : b) * 1.2 + 1,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.blueGrey.shade800,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final count = _n(rod.toY.round(), isArabic: isArabic);
                return BarTooltipItem(
                  count,
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < _weeklyLabels.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _n(_weeklyLabels[idx], isArabic: isArabic),
                        style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black54),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(
                    _n(value.round(), isArabic: isArabic),
                    style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark ? Colors.white10 : Colors.black12,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: _weeklyCounts.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value,
                  color: AppConstants.getPrimary(isDark),
                  width: 28,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : AppConstants.lightCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
