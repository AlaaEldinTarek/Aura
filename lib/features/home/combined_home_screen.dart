import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/prayer_times_provider.dart';
import '../../core/providers/task_provider.dart';
import '../../core/models/task.dart';
import '../../core/widgets/prayer_card.dart';
import '../../core/widgets/task_card.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/services/task_service.dart';
import '../../core/services/location_service.dart';

/// Combined Home Screen with Prayer Times and Tasks
/// Optimized for performance with lazy loading
class CombinedHomeScreen extends ConsumerStatefulWidget {
  const CombinedHomeScreen({super.key});

  @override
  ConsumerState<CombinedHomeScreen> createState() => _CombinedHomeScreenState();
}

class _CombinedHomeScreenState extends ConsumerState<CombinedHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load prayer times
    Future.microtask(() {
      ref.read(prayerTimesProvider.notifier).loadPrayerTimes(DateTime.now());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // Mark animations as played
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasAnimated) {
        setState(() => _hasAnimated = true);
      }
    });

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: true,
              pinned: false,
              elevation: 0,
              backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
              title: Text(
                'app_name'.tr(),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                  tooltip: isArabic ? 'الإشعارات' : 'Notifications',
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: AppConstants.primaryColor,
                labelColor: AppConstants.primaryColor,
                unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                tabs: [
                  Tab(text: 'home'.tr()),
                  Tab(text: 'prayer_times_title'.tr()),
                  Tab(text: 'task_management'.tr()),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildDashboardTab(context, isDark, isArabic),
            _buildPrayerTab(context, isDark, isArabic),
            _buildTasksTab(context, isDark, isArabic),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 2
          ? FloatingActionButton.extended(
              onPressed: () => _navigateToTaskForm(context),
              icon: const Icon(Icons.add),
              label: Text(isArabic ? 'مهمة جديدة' : 'New Task'),
              backgroundColor: AppConstants.primaryColor,
            )
          : null,
    );
  }

  /// Dashboard Tab - Shows overview of both prayers and tasks
  Widget _buildDashboardTab(BuildContext context, bool isDark, bool isArabic) {
    final prayerState = ref.watch(prayerTimesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(prayerTimesProvider.notifier).loadPrayerTimes(DateTime.now());
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Offline Banner
            const OfflineBanner(),

            // Greeting
            _buildGreeting(context, isDark, isArabic),

            const SizedBox(height: AppConstants.paddingLarge),

            // Next Prayer Card
            if (prayerState != null && prayerState.nextPrayer != null)
              _buildNextPrayerCard(context, prayerState, isDark, isArabic),

            const SizedBox(height: AppConstants.paddingMedium),

            // Quick Stats Row
            _buildQuickStatsRow(context, isDark, isArabic),

            const SizedBox(height: AppConstants.paddingMedium),

            // Today's Tasks Preview
            _buildTodayTasksPreview(context, isDark, isArabic),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting(BuildContext context, bool isDark, bool isArabic) {
    final hour = DateTime.now().hour;
    String greeting;

    if (hour < 12) {
      greeting = isArabic ? 'صباح الخير' : 'Good Morning';
    } else if (hour < 17) {
      greeting = isArabic ? 'مساء الخير' : 'Good Afternoon';
    } else {
      greeting = isArabic ? 'مساء الخير' : 'Good Evening';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          isArabic ? 'ليومك المنتج' : 'Have a productive day',
          style: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildNextPrayerCard(
    BuildContext context,
    dynamic prayerState,
    bool isDark,
    bool isArabic,
  ) {
    final nextPrayer = prayerState.nextPrayer;

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.primaryColor,
            AppConstants.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isArabic ? 'الصلاة القادمة' : 'Next Prayer',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic ? nextPrayer.nameAr : nextPrayer.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _formatTime(nextPrayer.time, isArabic),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isArabic) ...[
            const SizedBox(height: 4),
            const Text(
              'حتى موعد الأذان',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStatsRow(BuildContext context, bool isDark, bool isArabic) {
    final statsAsync = ref.watch(taskStatisticsProvider);

    return statsAsync.when(
      data: (stats) {
        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.task_alt,
                label: isArabic ? 'المهام' : 'Tasks',
                value: '${stats.pending}',
                color: AppConstants.primaryColor,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.schedule,
                label: isArabic ? 'اليوم' : 'Today',
                value: '${stats.dueToday}',
                color: Colors.orange,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.check_circle,
                label: isArabic ? 'مكتمل' : 'Done',
                value: '${stats.completed}',
                color: Colors.green,
                isDark: isDark,
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTasksPreview(BuildContext context, bool isDark, bool isArabic) {
    final allTasksAsync = ref.watch(allTasksProvider);
    final statsAsync = ref.watch(taskStatisticsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'مهام اليوم' : "Today's Tasks",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: () => _tabController.animateTo(2),
              child: Text(isArabic ? 'عرض الكل' : 'View All'),
            ),
          ],
        ),

        // Progress bar
        statsAsync.when(
          data: (stats) {
            if (stats.dueToday == 0) return const SizedBox.shrink();
            final total = stats.dueToday;
            final done = stats.completed.clamp(0, total);
            final progress = total > 0 ? done / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          progress == 1.0 ? Colors.green : AppConstants.primaryColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isArabic
                        ? '$done من $total مكتملة'
                        : '$done of $total completed',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 4),

        allTasksAsync.when(
          data: (allTasks) {
            final todayTasks =
                allTasks.where((t) => !t.isCompleted && t.isDueToday).toList();
            final upcomingTasks =
                allTasks.where((t) => !t.isCompleted && t.isUpcoming).toList();

            // Show today's tasks, or upcoming if none today
            final List<Task> toShow =
                todayTasks.isNotEmpty ? todayTasks : upcomingTasks;

            if (toShow.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(AppConstants.paddingLarge),
                decoration: BoxDecoration(
                  color: isDark ? AppConstants.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  border: Border.all(
                    color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 28, color: Colors.green.shade400),
                    const SizedBox(width: 12),
                    Text(
                      isArabic ? 'أنجزت كل مهام اليوم!' : 'All done for today!',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Show label if falling back to upcoming
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (todayTasks.isEmpty && upcomingTasks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      isArabic ? 'قريباً' : 'Upcoming',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ...toShow.take(3).map((task) => TaskCard(
                      key: ValueKey(task.id),
                      task: task,
                      onToggle: () => _toggleTask(task.id),
                      onTap: () => _editTask(task),
                    )),
              ],
            );
          },
          loading: () => const ShimmerListTile(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// Prayer Tab - Shows all prayer times
  Widget _buildPrayerTab(BuildContext context, bool isDark, bool isArabic) {
    final prayerState = ref.watch(prayerTimesProvider);

    if (prayerState == null || prayerState.isLoading == true) {
      return const Center(child: CircularProgressIndicator());
    }

    if (prayerState.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'error_loading_prayer_times'.tr(),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(prayerTimesProvider.notifier).loadPrayerTimes(DateTime.now());
              },
              child: Text('retry'.tr()),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(prayerTimesProvider.notifier).loadPrayerTimes(DateTime.now());
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          children: [
            // Location header
            if (prayerState.location != null)
              _buildLocationHeader(prayerState.location!, isDark, isArabic),

            const SizedBox(height: AppConstants.paddingSmall),

            // Next Prayer Countdown
            if (prayerState.nextPrayer != null) ...[
              _buildNextPrayerSection(prayerState.nextPrayer!, isDark, isArabic),
              const SizedBox(height: AppConstants.paddingLarge),
            ],

            // Prayer Cards
            ...prayerState.prayerTimes.map((prayer) {
              final isNext = prayerState.nextPrayer?.name == prayer.name;
              final isCurrent = prayerState.currentPrayer?.name == prayer.name;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
                child: PrayerCard(
                  key: ValueKey(prayer.name),
                  prayer: prayer,
                  isNext: isNext,
                  isCurrent: isCurrent,
                ),
              );
            }),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  /// Tasks Tab - Shows tasks split into sections
  Widget _buildTasksTab(BuildContext context, bool isDark, bool isArabic) {
    final allTasksAsync = ref.watch(allTasksProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(allTasksProvider);
        ref.invalidate(taskStatisticsProvider);
      },
      child: allTasksAsync.when(
        data: (allTasks) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          child: _buildTaskSections(allTasks, isDark, isArabic),
        ),
        loading: () => const Center(child: ShimmerListTile()),
        error: (e, _) => Center(
          child: Text(isArabic ? 'خطأ في تحميل المهام' : 'Error loading tasks'),
        ),
      ),
    );
  }

  Widget _buildTaskSections(List<Task> allTasks, bool isDark, bool isArabic) {
    final todayTasks = allTasks
        .where((t) => !t.isCompleted && t.isDueToday)
        .toList()
      ..sort((a, b) =>
          (a.dueDate ?? DateTime(2099)).compareTo(b.dueDate ?? DateTime(2099)));

    final upcomingTasks = allTasks
        .where((t) => !t.isCompleted && t.isUpcoming)
        .toList()
      ..sort((a, b) =>
          (a.dueDate ?? DateTime(2099)).compareTo(b.dueDate ?? DateTime(2099)));

    final otherTasks = allTasks
        .where((t) => !t.isCompleted && !t.isDueToday && !t.isUpcoming)
        .toList();

    if (allTasks.where((t) => !t.isCompleted).isEmpty && allTasks.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 64),
          Icon(Icons.task_alt_outlined,
              size: 72,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'لا توجد مهام' : 'No tasks yet',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic ? 'اضغط + لإضافة مهمتك الأولى' : 'Tap + to add your first task',
            style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (todayTasks.isNotEmpty) ...[
          _buildSectionLabel(
              icon: Icons.today,
              title: isArabic ? 'مهام اليوم' : "Today's Tasks",
              count: todayTasks.length,
              color: AppConstants.primaryColor,
              isDark: isDark),
          const SizedBox(height: 8),
          ...todayTasks.map((t) => _buildHomeTaskCard(t)),
          const SizedBox(height: 20),
        ],
        if (upcomingTasks.isNotEmpty) ...[
          _buildSectionLabel(
              icon: Icons.upcoming,
              title: isArabic ? 'قريباً' : 'Upcoming',
              count: upcomingTasks.length,
              color: Colors.orange,
              isDark: isDark),
          const SizedBox(height: 8),
          ...upcomingTasks.map((t) => _buildHomeTaskCard(t)),
          const SizedBox(height: 20),
        ],
        if (otherTasks.isNotEmpty) ...[
          _buildSectionLabel(
              icon: Icons.task_alt,
              title: isArabic ? 'كل المهام' : 'All Tasks',
              count: otherTasks.length,
              color: Colors.purple,
              isDark: isDark),
          const SizedBox(height: 8),
          ...otherTasks.map((t) => _buildHomeTaskCard(t)),
        ],
      ],
    );
  }

  Widget _buildSectionLabel({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12)),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ),
      ],
    );
  }

  Widget _buildHomeTaskCard(Task task) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TaskCard(
        key: ValueKey(task.id),
        task: task,
        onToggle: () => _toggleTask(task.id),
        onTap: () => _editTask(task),
        onDelete: () => _deleteTask(task.id),
      ),
    );
  }

  Widget _buildLocationHeader(dynamic location, bool isDark, bool isArabic) {
    final cityName = location.cityName ?? 'Unknown';
    final localizedCityName = getLocalizedCityName(cityName, isArabic ? 'ar' : 'en');

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingSmall),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_on, color: AppConstants.primaryColor, size: 20),
          const SizedBox(width: 6),
          Text(
            localizedCityName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextPrayerSection(dynamic nextPrayer, bool isDark, bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Text(
            'next_prayer'.tr(),
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic ? nextPrayer.nameAr : nextPrayer.name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppConstants.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatTime(nextPrayer.time, isArabic),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isArabic) ...[
            const SizedBox(height: 4),
            Text(
              'حتى موعد الأذان',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time, bool isArabic) {
    final hour = time.hour;
    final minute = time.minute;
    return isArabic
        ? NumberFormatter.withArabicNumeralsByLanguage(
            '$hour:${minute.toString().padLeft(2, '0')}',
            'ar',
          )
        : '$hour:${minute.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleTask(String taskId) async {
    final userId = ref.read(currentUserIdProvider);
    try {
      await TaskService.instance.toggleTaskCompletion(
        userId: userId,
        taskId: taskId,
      );
    } catch (e) {
      debugPrint('Error toggling task: $e');
    }
  }

  Future<void> _editTask(Task task) async {
    final result = await Navigator.of(context).pushNamed(
      '/task_form',
      arguments: task,
    );
    // Refresh if task was updated
    if (result == true) {
      // Invalidate the provider to refresh data
      ref.invalidate(tasksProvider);
    }
  }

  Future<void> _deleteTask(String taskId) async {
    final userId = ref.read(currentUserIdProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    try {
      await TaskService.instance.deleteTask(
        userId: userId,
        taskId: taskId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'تم حذف المهمة' : 'Task deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }

  Future<void> _navigateToTaskForm(BuildContext context) async {
    final result = await Navigator.of(context).pushNamed('/task_form');
    if (result == true) {
      // Task was created, refresh the list
      ref.invalidate(tasksProvider);
    }
  }
}
