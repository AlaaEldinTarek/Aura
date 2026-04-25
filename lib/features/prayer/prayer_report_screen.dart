import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/prayer_record.dart';
import '../../core/services/prayer_tracking_service.dart';
import '../../core/utils/number_formatter.dart';

/// Prayer Report Screen - Weekly/Monthly statistics with charts
class PrayerReportScreen extends StatefulWidget {
  const PrayerReportScreen({super.key});

  @override
  State<PrayerReportScreen> createState() => _PrayerReportScreenState();
}

class _PrayerReportScreenState extends State<PrayerReportScreen>
    with SingleTickerProviderStateMixin {
  final PrayerTrackingService _trackingService = PrayerTrackingService.instance;
  bool _isLoading = true;

  // Stats data
  int _currentStreak = 0;
  int _bestStreak = 0;
  int _totalCompleted = 0;
  int _totalOnTime = 0;
  int _totalLate = 0;
  int _totalMissed = 0;
  int _totalExcused = 0;
  double _completionRate = 0;
  double _onTimeRate = 0;

  // Per-prayer stats
  final Map<String, int> _prayerCompleted = {};
  final Map<String, int> _prayerTotal = {};

  // Weekly chart data (last 4 weeks)
  final List<double> _weeklyRates = [];
  final List<String> _weeklyLabels = [];

  // Monthly comparison
  double _thisMonthRate = 0;
  double _lastMonthRate = 0;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReportData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);

    final userId = getCurrentUserId();
    final now = DateTime.now();

    try {
      // Fetch records for last 60 days (covers this month + last month for comparison)
      final sixtyDaysAgo = now.subtract(const Duration(days: 60));

      // Run streak + records in parallel (2 queries instead of 4 sequential)
      final results = await Future.wait([
        _trackingService.calculateCurrentStreak(userId: userId),
        _trackingService.getPrayersForDateRange(
          userId: userId,
          startDate: sixtyDaysAgo,
          endDate: now,
        ),
      ]);

      final streak = results[0] as int;
      final allRecords = results[1] as List<PrayerRecord>;

      // Filter last 30 days for main stats
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final records = allRecords.where((r) => r.date.isAfter(thirtyDaysAgo)).toList();

      // Compute stats from records (eliminates getStatistics call)
      int bestStreak = streak; // Use current streak as baseline
      {
        // Calculate best streak from records
        int tempStreak = 0;
        int tempBest = 0;
        DateTime? lastDate;
        final sortedRecords = List<PrayerRecord>.from(records)
          ..sort((a, b) => a.date.compareTo(b.date));
        for (final record in sortedRecords) {
          final d = DateTime(record.date.year, record.date.month, record.date.day);
          if (lastDate != null && d.difference(lastDate).inDays > 1) {
            tempStreak = 0;
          }
          if (record.status == PrayerStatus.onTime || record.status == PrayerStatus.late) {
            if (lastDate == null || d != lastDate) {
              tempStreak++;
              if (tempStreak > tempBest) tempBest = tempStreak;
            }
          } else {
            tempStreak = 0;
          }
          lastDate = d;
        }
        if (tempBest > bestStreak) bestStreak = tempBest;
      }

      // Initialize per-prayer counters
      final Map<String, int> prayerCompleted = {};
      final Map<String, int> prayerTotal = {};
      for (final name in kPrayerNames) {
        prayerCompleted[name] = 0;
        prayerTotal[name] = 30;
      }

      int completedOnTime = 0;
      int completedLate = 0;
      int totalExcused = 0;

      for (final record in records) {
        prayerTotal[record.prayerName] = (prayerTotal[record.prayerName] ?? 0);
        if (record.status == PrayerStatus.onTime || record.status == PrayerStatus.late) {
          prayerCompleted[record.prayerName] = (prayerCompleted[record.prayerName] ?? 0) + 1;
          if (record.status == PrayerStatus.onTime) {
            completedOnTime++;
          } else {
            completedLate++;
          }
        } else if (record.status == PrayerStatus.excused) {
          totalExcused++;
        }
      }

      final totalMissed = ((kPrayerNames.length * 30) - completedOnTime - completedLate - totalExcused).clamp(0, kPrayerNames.length * 30);
      final totalPrayers = completedOnTime + completedLate + totalMissed;
      final completionRate = totalPrayers > 0 ? (completedOnTime + completedLate) / totalPrayers : 0.0;
      final onTimeRate = totalPrayers > 0 ? completedOnTime / totalPrayers : 0.0;

      // Weekly chart data (last 4 weeks) - computed from records we already have
      final List<double> weeklyRates = [];
      final List<String> weeklyLabels = [];
      for (int i = 3; i >= 0; i--) {
        final weekEnd = now.subtract(Duration(days: i * 7));
        final weekStart = weekEnd.subtract(const Duration(days: 6));
        final weekRecords = records.where((r) {
          final d = r.date;
          return d.isAfter(weekStart.subtract(const Duration(days: 1))) &&
              d.isBefore(weekEnd.add(const Duration(days: 1)));
        }).toList();

        final weekCompleted = weekRecords.where((r) =>
            r.status == PrayerStatus.onTime || r.status == PrayerStatus.late).length;
        final weekExpected = kPrayerNames.length * 7;
        weeklyRates.add(weekExpected > 0 ? weekCompleted / weekExpected : 0);
        weeklyLabels.add('${weekStart.day}/${weekStart.month}');
      }

      // Monthly comparison - computed from allRecords (60 days covers both months)
      final thisMonthStart = DateTime(now.year, now.month, 1);
      final thisMonthRecords = allRecords.where((r) =>
          !r.date.isBefore(thisMonthStart)).toList();
      final thisCompleted = thisMonthRecords.where((r) =>
          r.status == PrayerStatus.onTime || r.status == PrayerStatus.late).length;
      final daysThisMonth = now.day;
      final expectedThisMonth = kPrayerNames.length * daysThisMonth;
      final thisMonthRate = expectedThisMonth > 0 ? thisCompleted / expectedThisMonth : 0.0;

      // Last month - computed from same allRecords, no extra Firestore query
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      final lastMonthStart = DateTime(lastMonth.year, lastMonth.month, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0);
      final lastMonthRecords = allRecords.where((r) =>
          !r.date.isBefore(lastMonthStart) && !r.date.isAfter(lastMonthEnd)).toList();
      final lastMonthCompleted = lastMonthRecords.where((r) =>
          r.status == PrayerStatus.onTime || r.status == PrayerStatus.late).length;
      final daysLastMonth = lastMonthEnd.day;
      final expectedLastMonth = kPrayerNames.length * daysLastMonth;
      final lastMonthRate = expectedLastMonth > 0 ? lastMonthCompleted / expectedLastMonth : 0.0;

      if (mounted) {
        setState(() {
          _currentStreak = streak;
          _bestStreak = bestStreak;
          _totalCompleted = completedOnTime + completedLate;
          _totalOnTime = completedOnTime;
          _totalLate = completedLate;
          _totalMissed = totalMissed;
          _totalExcused = totalExcused;
          _completionRate = completionRate;
          _onTimeRate = onTimeRate;
          _prayerCompleted.clear();
          _prayerCompleted.addAll(prayerCompleted);
          _prayerTotal.clear();
          _prayerTotal.addAll(prayerTotal);
          _weeklyRates.clear();
          _weeklyRates.addAll(weeklyRates);
          _weeklyLabels.clear();
          _weeklyLabels.addAll(weeklyLabels);
          _thisMonthRate = thisMonthRate;
          _lastMonthRate = lastMonthRate;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading report: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Format number string for current locale (Arabic numerals if Arabic)
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
        title: Text(isArabic ? 'تقرير الصلوات' : 'Prayer Report'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: isArabic ? 'نظرة عامة' : 'Overview'),
            Tab(text: isArabic ? 'التفاصيل' : 'Details'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(context, isDark, isArabic),
                _buildDetailsTab(context, isDark, isArabic),
              ],
            ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, bool isDark, bool isArabic) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top stats cards
          Row(
            children: [
              Expanded(
                child: _ReportCard(
                  icon: Icons.local_fire_department,
                  label: isArabic ? 'التتابع' : 'Streak',
                  value: _n(_currentStreak, isArabic: isArabic),
                  subtitle: isArabic ? 'أفضل: ${_n(_bestStreak, isArabic: isArabic)}' : 'Best: $_bestStreak',
                  color: Colors.orange,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: AppConstants.paddingSmall),
              Expanded(
                child: _ReportCard(
                  icon: Icons.check_circle,
                  label: isArabic ? 'الإتمام' : 'Completion',
                  value: _n((_completionRate * 100).toStringAsFixed(0), isArabic: isArabic) + '%',
                  subtitle: isArabic ? '${_n(_totalCompleted, isArabic: isArabic)} من ${_n(_totalCompleted + _totalMissed, isArabic: isArabic)}' : '$_totalCompleted of ${_totalCompleted + _totalMissed}',
                  color: Colors.green,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: AppConstants.paddingSmall),
              Expanded(
                child: _ReportCard(
                  icon: Icons.schedule,
                  label: isArabic ? 'في الوقت' : 'On Time',
                  value: _n((_onTimeRate * 100).toStringAsFixed(0), isArabic: isArabic) + '%',
                  subtitle: isArabic ? '${_n(_totalOnTime, isArabic: isArabic)} صلاة' : '$_totalOnTime prayers',
                  color: AppConstants.getPrimary(isDark),
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.paddingLarge),

          // Weekly Trend Chart
          _buildSectionCard(
            context,
            isArabic ? 'الاتجاه الأسبوعي' : 'Weekly Trend',
            isArabic ? 'معدل إتمام الصلوات في آخر 4 أسابيع' : 'Completion rate over last 4 weeks',
            _buildWeeklyChart(isDark, isArabic),
            isDark,
          ),

          const SizedBox(height: AppConstants.paddingLarge),

          // Monthly Comparison
          _buildSectionCard(
            context,
            isArabic ? 'مقارنة شهرية' : 'Monthly Comparison',
            isArabic ? 'هذا الشهر مقارنة بالشهر الماضي' : 'This month vs last month',
            _buildMonthlyComparison(isDark, isArabic),
            isDark,
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(BuildContext context, bool isDark, bool isArabic) {
    final prayerEmojis = {
      'Fajr': '🌙', 'Zuhr': '☀️', 'Asr': '🌤️', 'Maghrib': '🌇', 'Isha': '🌃',
    };
    final prayerNamesAr = {
      'Fajr': 'الفجر', 'Zuhr': 'الظهر', 'Asr': 'العصر', 'Maghrib': 'المغرب', 'Isha': 'العشاء',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status breakdown
          _buildSectionCard(
            context,
            isArabic ? 'حالة الصلوات (30 يوم)' : 'Prayer Status (30 days)',
            '',
            Column(
              children: [
                _buildStatusBar(
                  isArabic ? 'في الوقت' : 'On Time',
                  _totalOnTime,
                  _totalOnTime + _totalLate + _totalMissed + _totalExcused,
                  Colors.green,
                  isDark,
                  isArabic: isArabic,
                ),
                const SizedBox(height: 8),
                _buildStatusBar(
                  isArabic ? 'متأخر' : 'Late',
                  _totalLate,
                  _totalOnTime + _totalLate + _totalMissed + _totalExcused,
                  Colors.orange,
                  isDark,
                  isArabic: isArabic,
                ),
                const SizedBox(height: 8),
                _buildStatusBar(
                  isArabic ? 'لم أصلّ' : 'Missed',
                  _totalMissed,
                  _totalOnTime + _totalLate + _totalMissed + _totalExcused,
                  Colors.red,
                  isDark,
                  isArabic: isArabic,
                ),
                const SizedBox(height: 8),
                _buildStatusBar(
                  isArabic ? 'معذور' : 'Excused',
                  _totalExcused,
                  _totalOnTime + _totalLate + _totalMissed + _totalExcused,
                  Colors.grey,
                  isDark,
                  isArabic: isArabic,
                ),
              ],
            ),
            isDark,
          ),

          const SizedBox(height: AppConstants.paddingLarge),

          // Per-prayer breakdown
          _buildSectionCard(
            context,
            isArabic ? 'تفاصيل كل صلاة' : 'Per-Prayer Breakdown',
            isArabic ? 'معدل الإتمام لكل صلاة' : 'Completion rate for each prayer',
            Column(
              children: kPrayerNames.map((name) {
                final completed = _prayerCompleted[name] ?? 0;
                final total = _prayerTotal[name] ?? 30;
                final rate = total > 0 ? completed / total : 0.0;
                final emoji = prayerEmojis[name] ?? '🕌';
                final displayName = isArabic ? (prayerNamesAr[name] ?? name) : name;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: rate,
                                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                                color: rate >= 0.8
                                    ? Colors.green
                                    : rate >= 0.5
                                        ? Colors.orange
                                        : Colors.red,
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 45,
                        child: Text(
                          '${_n((rate * 100).toStringAsFixed(0), isArabic: isArabic)}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            isDark,
          ),

          const SizedBox(height: 80),
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
        border: Border.all(
          color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
          const SizedBox(height: AppConstants.paddingMedium),
          child,
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(bool isDark, bool isArabic) {
    if (_weeklyRates.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 1.0,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.blueGrey.shade800,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final rate = _n((rod.toY * 100).toStringAsFixed(0), isArabic: isArabic);
                return BarTooltipItem(
                  '$rate%',
                  TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
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
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
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
                  return Text(
                    '${_n((value * 100).toStringAsFixed(0), isArabic: isArabic)}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
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
            horizontalInterval: 0.25,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark ? Colors.white10 : Colors.black12,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: _weeklyRates.asMap().entries.map((entry) {
            final rate = entry.value;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: rate,
                  color: rate >= 0.8
                      ? Colors.green
                      : rate >= 0.5
                          ? Colors.orange
                          : Colors.red,
                  width: 32,
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

  Widget _buildMonthlyComparison(bool isDark, bool isArabic) {
    final diff = _thisMonthRate - _lastMonthRate;
    final isPositive = diff >= 0;
    final diffText = '${isPositive ? '+' : ''}${_n((diff * 100).toStringAsFixed(1), isArabic: isArabic)}%';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMonthCard(
                isArabic ? 'هذا الشهر' : 'This Month',
                _thisMonthRate,
                AppConstants.getPrimary(isDark),
                isDark,
                isArabic: isArabic,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMonthCard(
                isArabic ? 'الشهر الماضي' : 'Last Month',
                _lastMonthRate,
                Colors.grey,
                isDark,
                isArabic: isArabic,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: (isPositive ? Colors.green : Colors.red).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: isPositive ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                isArabic
                    ? '$diffText ${isPositive ? 'تحسن' : 'تراجع'}'
                    : '$diffText ${isPositive ? 'improvement' : 'decline'}',
                style: TextStyle(
                  color: isPositive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthCard(String label, double rate, Color color, bool isDark, {bool isArabic = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_n((rate * 100).toStringAsFixed(1), isArabic: isArabic)}%',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(String label, int count, int total, Color color, bool isDark, {bool isArabic = false}) {
    final rate = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              color: color,
              minHeight: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 35,
          child: Text(
            _n(count, isArabic: isArabic),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final bool isDark;

  const _ReportCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
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
        border: Border.all(
          color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}
