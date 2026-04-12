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
    final tasksAsync = ref.watch(todayTasksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'مهام اليوم' : 'Today\'s Tasks',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: () {
                _tabController.animateTo(2); // Switch to tasks tab
              },
              child: Text(isArabic ? 'عرض الكل' : 'View All'),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        tasksAsync.when(
          data: (tasks) {
            if (tasks.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(AppConstants.paddingLarge),
                decoration: BoxDecoration(
                  color: isDark ? AppConstants.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  border: Border.all(
                    color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: Colors.green.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isArabic ? 'لا توجد مهام لليوم' : 'No tasks for today',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: tasks.take(3).map((task) {
                return TaskCard(
                  key: ValueKey(task.id),
                  task: task,
                  onToggle: () => _toggleTask(task.id),
                );
              }).toList(),
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

  /// Tasks Tab - Shows all tasks
  Widget _buildTasksTab(BuildContext context, bool isDark, bool isArabic) {
    final filterParams = const TaskFilterParams(limit: 50);
    final tasksAsync = ref.watch(tasksProvider(filterParams));

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
            // Filter chips
            _buildFilterChips(context, isDark, isArabic),

            const SizedBox(height: AppConstants.paddingMedium),

            // Add task FAB hint
            Container(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_circle, color: AppConstants.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isArabic ? 'اضغط على + لإضافة مهمة جديدة' : 'Tap + to add a new task',
                      style: TextStyle(
                        color: AppConstants.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppConstants.paddingMedium),

            // Tasks list
            tasksAsync.when(
              data: (tasks) {
                if (tasks.isEmpty) {
                  return _buildEmptyTasksState(context, isDark, isArabic);
                }

                return Column(
                  children: tasks.map((task) {
                    return TaskCard(
                      key: ValueKey(task.id),
                      task: task,
                      onToggle: () => _toggleTask(task.id),
                      onTap: () => _editTask(task),
                      onDelete: () => _deleteTask(task.id),
                    );
                  }).toList(),
                );
              },
              loading: () => const ShimmerListTile(),
              error: (error, _) => Center(
                child: Text('Error: $error'),
              ),
            ),

            const SizedBox(height: 100), // Extra space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, bool isDark, bool isArabic) {
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          label: const Text('All'),
          selected: true,
          onSelected: (_) {},
          backgroundColor: isDark ? AppConstants.darkCard : Colors.white,
          selectedColor: AppConstants.primaryColor.withOpacity(0.2),
          checkmarkColor: AppConstants.primaryColor,
        ),
        FilterChip(
          label: const Text('Today'),
          selected: false,
          onSelected: (_) {},
          backgroundColor: isDark ? AppConstants.darkCard : Colors.white,
          selectedColor: AppConstants.primaryColor.withOpacity(0.2),
        ),
        FilterChip(
          label: const Text('High Priority'),
          selected: false,
          onSelected: (_) {},
          backgroundColor: isDark ? AppConstants.darkCard : Colors.white,
          selectedColor: Colors.red.withOpacity(0.2),
        ),
      ],
    );
  }

  Widget _buildEmptyTasksState(BuildContext context, bool isDark, bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingLarge * 2),
      child: Column(
        children: [
          Icon(
            Icons.task_alt_outlined,
            size: 64,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'لا توجد مهام' : 'No tasks yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            isArabic ? 'ابدأ بإضافة مهمتك الأولى' : 'Start by adding your first task',
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
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
    const userId = 'guest_user';
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
    const userId = 'guest_user';
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
