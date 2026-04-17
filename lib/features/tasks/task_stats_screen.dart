import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/task.dart';
import '../../core/providers/task_provider.dart';
import '../../core/services/task_service.dart';
import '../../core/utils/number_formatter.dart';

class TaskStatsScreen extends ConsumerStatefulWidget {
  const TaskStatsScreen({super.key});

  @override
  ConsumerState<TaskStatsScreen> createState() => _TaskStatsScreenState();
}

class _TaskStatsScreenState extends ConsumerState<TaskStatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _streak = 0;

  static const _streakKey = 'task_streak_count';
  static const _streakDateKey = 'task_streak_date';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStreak();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_streakKey) ?? 0;
    final lastDate = prefs.getString(_streakDateKey);
    if (lastDate == null) {
      if (mounted) setState(() => _streak = 0);
      return;
    }
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    if (lastDate != today && lastDate != yesterdayStr) {
      if (mounted) setState(() => _streak = 0);
    } else {
      if (mounted) setState(() => _streak = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor:
          isDark ? AppConstants.darkBackground : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          isArabic ? 'إحصائيات المهام' : 'Task Statistics',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? AppConstants.darkSurface : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppConstants.primaryColor,
          unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey,
          indicatorColor: AppConstants.primaryColor,
          tabs: [
            Tab(text: isArabic ? 'نظرة عامة' : 'Overview'),
            Tab(text: isArabic ? 'التفاصيل' : 'Details'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(isDark, isArabic),
          _buildDetailsTab(isDark, isArabic),
        ],
      ),
    );
  }

  // ─── Overview Tab ─────────────────────────────────────────────────────────

  Widget _buildOverviewTab(bool isDark, bool isArabic) {
    final statsAsync = ref.watch(taskStatisticsProvider);
    final allTasksAsync = ref.watch(allTasksProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(taskStatisticsProvider);
        ref.invalidate(allTasksProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Streak + Rate row
            statsAsync.when(
              data: (stats) => _buildTopCards(stats, isDark, isArabic),
              loading: () => const SizedBox(
                  height: 120, child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),

            // 7-Day Chart
            allTasksAsync.when(
              data: (tasks) =>
                  _buildWeeklyChart(tasks, isDark, isArabic),
              loading: () => _buildChartPlaceholder(isDark),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),

            // Category Breakdown
            allTasksAsync.when(
              data: (tasks) =>
                  _buildCategoryBreakdown(tasks, isDark, isArabic),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),

            // Priority Breakdown
            allTasksAsync.when(
              data: (tasks) =>
                  _buildPriorityBreakdown(tasks, isDark, isArabic),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCards(TaskStatistics stats, bool isDark, bool isArabic) {
    return Row(
      children: [
        // Streak card
        Expanded(
          child: _buildInfoCard(
            icon: Icons.local_fire_department,
            iconColor: Colors.orange,
            title: isArabic ? 'السلسلة' : 'Streak',
            value: isArabic
                ? NumberFormatter.withArabicNumerals('$_streak')
                : '$_streak',
            subtitle: _streak == 1
                ? (isArabic ? 'يوم' : 'day')
                : (isArabic ? 'أيام' : 'days'),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        // Completion rate card
        Expanded(
          child: _buildInfoCard(
            icon: Icons.trending_up,
            iconColor: Colors.green,
            title: isArabic ? 'نسبة الإتمام' : 'Rate',
            value: '${stats.completionRate}%',
            subtitle: isArabic
                ? '${stats.completed} من ${stats.total}'
                : '${stats.completed} of ${stats.total}',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        // Today card
        Expanded(
          child: _buildInfoCard(
            icon: Icons.today,
            iconColor: AppConstants.primaryColor,
            title: isArabic ? 'اليوم' : 'Today',
            value: '${stats.dueToday}',
            subtitle: stats.overdue > 0
                ? (isArabic
                    ? '${stats.overdue} متأخرة'
                    : '${stats.overdue} overdue')
                : (isArabic ? 'لا متأخرة' : 'No overdue'),
            isDark: isDark,
            subtitleColor: stats.overdue > 0 ? Colors.red : null,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required bool isDark,
    Color? subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: subtitleColor ??
                  (isDark ? Colors.grey.shade500 : Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 7-Day Completion Chart ────────────────────────────────────────────────

  Widget _buildWeeklyChart(List<Task> tasks, bool isDark, bool isArabic) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build data for last 7 days
    final days = <_DayData>[];
    int maxCount = 1;

    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final completed = tasks.where((t) {
        if (t.completedAt == null) return false;
        final completedDay = DateTime(
            t.completedAt!.year, t.completedAt!.month, t.completedAt!.day);
        return completedDay == day;
      }).length;
      if (completed > maxCount) maxCount = completed;

      String label;
      if (i == 0) {
        label = isArabic ? 'اليوم' : 'Today';
      } else if (i == 1) {
        label = isArabic ? 'أمس' : 'Yest';
      } else {
        final weekdays = isArabic
            ? ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح']
            : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        // weekday is 1=Monday..7=Sunday
        label = weekdays[day.weekday - 1];
      }

      days.add(_DayData(day: day, label: label, count: completed));
    }

    // Calculate total completed this week
    final weekTotal = days.fold<int>(0, (sum, d) => sum + d.count);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded,
                  color: AppConstants.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'آخر 7 أيام' : 'Last 7 Days',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isArabic
                      ? NumberFormatter.withArabicNumerals('$weekTotal')
                      : '$weekTotal',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Bar chart
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((d) {
                final barHeight =
                    maxCount > 0 ? (d.count / maxCount) * 110 : 0.0;
                final isToday = d.day == today;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Count above bar
                        if (d.count > 0)
                          Text(
                            isArabic
                                ? NumberFormatter.withArabicNumerals('${d.count}')
                                : '${d.count}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                            ),
                          ),
                        const SizedBox(height: 4),
                        // Bar
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          height: barHeight.clamp(4, 110),
                          decoration: BoxDecoration(
                            color: isToday
                                ? AppConstants.primaryColor
                                : AppConstants.primaryColor.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Label
                        Text(
                          d.label,
                          style: TextStyle(
                            fontSize: 10,
                            color: isToday
                                ? AppConstants.primaryColor
                                : (isDark
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade600),
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartPlaceholder(bool isDark) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  // ─── Category Breakdown ────────────────────────────────────────────────────

  Widget _buildCategoryBreakdown(List<Task> tasks, bool isDark, bool isArabic) {
    final categoryData = <TaskCategory, _CategoryStats>{};

    for (final task in tasks) {
      final stats = categoryData.putIfAbsent(
          task.category,
          () => _CategoryStats(
                category: task.category,
                total: 0,
                completed: 0,
              ));
      stats.total++;
      if (task.isCompleted) stats.completed++;
    }

    if (categoryData.isEmpty) return const SizedBox.shrink();

    // Sort by total descending
    final sorted = categoryData.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    final categoryInfo = {
      TaskCategory.work: (Icons.work_outline, isArabic ? 'عمل' : 'Work', Colors.blue),
      TaskCategory.personal: (Icons.person_outline, isArabic ? 'شخصي' : 'Personal', Colors.teal),
      TaskCategory.shopping: (Icons.shopping_cart_outlined, isArabic ? 'تسوق' : 'Shopping', Colors.purple),
      TaskCategory.health: (Icons.favorite_outline, isArabic ? 'صحة' : 'Health', Colors.red),
      TaskCategory.study: (Icons.school_outlined, isArabic ? 'دراسة' : 'Study', Colors.indigo),
      TaskCategory.prayer: (Icons.mosque_outlined, isArabic ? 'صلاة' : 'Prayer', Colors.green),
      TaskCategory.other: (Icons.more_horiz, isArabic ? 'أخرى' : 'Other', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category_outlined,
                  color: AppConstants.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'حسب الفئة' : 'By Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...sorted.map((s) {
            final info = categoryInfo[s.category];
            final icon = info?.$1 ?? Icons.label_outline;
            final label = info?.$2 ?? s.category.value;
            final color = info?.$3 ?? Colors.grey;
            final rate = s.total > 0 ? (s.completed / s.total * 100).round() : 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 18, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        '${s.completed}/${s.total}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 42,
                        child: Text(
                          '$rate%',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: rate >= 70
                                ? Colors.green
                                : (rate >= 40 ? Colors.orange : Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: s.total > 0 ? s.completed / s.total : 0,
                      backgroundColor:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      color: color,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Priority Breakdown ────────────────────────────────────────────────────

  Widget _buildPriorityBreakdown(List<Task> tasks, bool isDark, bool isArabic) {
    final priorityData = <TaskPriority, _PriorityStats>{};

    for (final task in tasks) {
      final stats = priorityData.putIfAbsent(
          task.priority,
          () => _PriorityStats(
                priority: task.priority,
                total: 0,
                completed: 0,
              ));
      stats.total++;
      if (task.isCompleted) stats.completed++;
    }

    if (priorityData.isEmpty) return const SizedBox.shrink();

    // Sort by priority level
    final sorted = priorityData.values.toList()
      ..sort((a, b) => b.priority.level.compareTo(a.priority.level));

    final priorityInfo = {
      TaskPriority.high: (Icons.flag, isArabic ? 'عالية' : 'High', Colors.orange),
      TaskPriority.medium: (Icons.flag, isArabic ? 'متوسطة' : 'Medium', Colors.amber),
      TaskPriority.low: (Icons.flag, isArabic ? 'منخفضة' : 'Low', Colors.green),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined,
                  color: AppConstants.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'حسب الأولوية' : 'By Priority',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...sorted.map((s) {
            final info = priorityInfo[s.priority];
            final label = info?.$2 ?? s.priority.value;
            final color = info?.$3 ?? Colors.grey;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  // Donut indicator
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: s.total > 0 ? s.completed / s.total : 0,
                          backgroundColor: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                          color: color,
                          strokeWidth: 4,
                        ),
                        Text(
                          '${s.total > 0 ? (s.completed / s.total * 100).round() : 0}%',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isArabic
                              ? '${s.completed} مكتمل من ${s.total}'
                              : '${s.completed} done of ${s.total}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Details Tab ──────────────────────────────────────────────────────────

  Widget _buildDetailsTab(bool isDark, bool isArabic) {
    final allTasksAsync = ref.watch(allTasksProvider);

    return allTasksAsync.when(
      data: (tasks) {
        final uncompleted = tasks.where((t) => !t.isCompleted).toList();
        final completed =
            tasks.where((t) => t.isCompleted).toList();
        final overdue = tasks.where((t) => t.isOverdue).toList();
        final recurring = tasks.where((t) => t.isRecurring).toList();
        final withDueDate = tasks.where((t) => t.dueDate != null).toList();
        final withTags = tasks.where((t) => t.tags != null && t.tags!.isNotEmpty).toList();

        // Time-based stats
        final now = DateTime.now();
        final thisWeekStart = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        final thisMonthStart = DateTime(now.year, now.month, 1);

        final completedThisWeek = completed.where((t) {
          if (t.completedAt == null) return false;
          return t.completedAt!.isAfter(thisWeekStart);
        }).length;

        final completedThisMonth = completed.where((t) {
          if (t.completedAt == null) return false;
          return t.completedAt!.isAfter(thisMonthStart);
        }).length;

        // Average completion time (for tasks with dueDate and completedAt)
        final completedWithBoth = completed.where(
            (t) => t.dueDate != null && t.completedAt != null).toList();
        double avgCompletionHours = 0;
        if (completedWithBoth.isNotEmpty) {
          final totalHours = completedWithBoth.fold<double>(
            0,
            (sum, t) => sum + t.completedAt!.difference(t.createdAt).inHours.toDouble(),
          );
          avgCompletionHours = totalHours / completedWithBoth.length;
        }

        // Most productive day (day with most completions)
        final completionsByDay = <int, int>{};
        for (final t in completed) {
          if (t.completedAt != null) {
            completionsByDay[t.completedAt!.weekday] =
                (completionsByDay[t.completedAt!.weekday] ?? 0) + 1;
          }
        }
        int? mostProductiveDay;
        int maxCompletions = 0;
        completionsByDay.forEach((day, count) {
          if (count > maxCompletions) {
            maxCompletions = count;
            mostProductiveDay = day;
          }
        });

        final dayNames = isArabic
            ? {1: 'الاثنين', 2: 'الثلاثاء', 3: 'الأربعاء', 4: 'الخميس', 5: 'الجمعة', 6: 'السبت', 7: 'الأحد'}
            : {1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 5: 'Friday', 6: 'Saturday', 7: 'Sunday'};

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allTasksProvider);
            ref.invalidate(taskStatisticsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Summary grid
                _buildDetailGrid([
                  _DetailItem(
                    icon: Icons.task_alt,
                    label: isArabic ? 'إجمالي المهام' : 'Total Tasks',
                    value: '${tasks.length}',
                    color: AppConstants.primaryColor,
                  ),
                  _DetailItem(
                    icon: Icons.check_circle,
                    label: isArabic ? 'مكتملة' : 'Completed',
                    value: '${completed.length}',
                    color: Colors.green,
                  ),
                  _DetailItem(
                    icon: Icons.pending_outlined,
                    label: isArabic ? 'قيد الانتظار' : 'Pending',
                    value: '${uncompleted.length}',
                    color: Colors.orange,
                  ),
                  _DetailItem(
                    icon: Icons.warning_amber,
                    label: isArabic ? 'متأخرة' : 'Overdue',
                    value: '${overdue.length}',
                    color: Colors.red,
                  ),
                  _DetailItem(
                    icon: Icons.date_range,
                    label: isArabic ? 'بتاريخ استحقاق' : 'With Due Date',
                    value: '${withDueDate.length}',
                    color: Colors.teal,
                  ),
                  _DetailItem(
                    icon: Icons.repeat,
                    label: isArabic ? 'متكررة' : 'Recurring',
                    value: '${recurring.length}',
                    color: Colors.purple,
                  ),
                  _DetailItem(
                    icon: Icons.tag,
                    label: isArabic ? 'بوسوم' : 'With Tags',
                    value: '${withTags.length}',
                    color: Colors.indigo,
                  ),
                  _DetailItem(
                    icon: Icons.local_fire_department,
                    label: isArabic ? 'السلسلة' : 'Streak',
                    value: '$_streak',
                    color: Colors.orange,
                  ),
                ], isDark, isArabic),
                const SizedBox(height: 20),

                // Time-based stats
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppConstants.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              color: AppConstants.primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isArabic ? 'إحصائيات زمنية' : 'Time Stats',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTimeStat(
                        icon: Icons.calendar_view_week,
                        label: isArabic ? 'مكتملة هذا الأسبوع' : 'Completed this week',
                        value: '$completedThisWeek',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildTimeStat(
                        icon: Icons.calendar_month,
                        label: isArabic ? 'مكتملة هذا الشهر' : 'Completed this month',
                        value: '$completedThisMonth',
                        isDark: isDark,
                      ),
                      if (avgCompletionHours > 0) ...[
                        const SizedBox(height: 12),
                        _buildTimeStat(
                          icon: Icons.timer_outlined,
                          label: isArabic ? 'متوسط وقت الإتمام' : 'Avg. completion time',
                          value: avgCompletionHours >= 24
                              ? isArabic
                                  ? '${(avgCompletionHours / 24).toStringAsFixed(1)} يوم'
                                  : '${(avgCompletionHours / 24).toStringAsFixed(1)} days'
                              : isArabic
                                  ? '${avgCompletionHours.round()} ساعة'
                                  : '${avgCompletionHours.round()} hours',
                          isDark: isDark,
                        ),
                      ],
                      if (mostProductiveDay != null) ...[
                        const SizedBox(height: 12),
                        _buildTimeStat(
                          icon: Icons.star,
                          label: isArabic ? 'أكثر يوم إنتاجاً' : 'Most productive day',
                          value: dayNames[mostProductiveDay] ?? '',
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text(isArabic ? 'خطأ في التحميل' : 'Error loading'),
      ),
    );
  }

  Widget _buildDetailGrid(
      List<_DetailItem> items, bool isDark, bool isArabic) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: items.length,
      itemBuilder: (_, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppConstants.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(item.icon, color: item.color, size: 18),
                  const Spacer(),
                  Text(
                    isArabic
                        ? NumberFormatter.withArabicNumerals(item.value)
                        : item.value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeStat({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade300 : Colors.black87,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}

// ─── Helper Classes ─────────────────────────────────────────────────────────

class _DayData {
  final DateTime day;
  final String label;
  final int count;
  _DayData({required this.day, required this.label, required this.count});
}

class _CategoryStats {
  final TaskCategory category;
  int total;
  int completed;
  _CategoryStats({required this.category, required this.total, required this.completed});
}

class _PriorityStats {
  final TaskPriority priority;
  int total;
  int completed;
  _PriorityStats({required this.priority, required this.total, required this.completed});
}

class _DetailItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}
