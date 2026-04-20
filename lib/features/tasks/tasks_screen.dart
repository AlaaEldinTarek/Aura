import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/task_provider.dart';
import '../../core/providers/preferences_provider.dart' show taskNotificationsEnabledProvider, taskReminderMinutesProvider;
import '../../core/models/task.dart';
import '../../core/widgets/task_card.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/services/task_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/haptic_feedback.dart' as app_haptic;

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

enum _SortOrder { dateDesc, dateAsc, priority, title, manual }

class _TasksScreenState extends ConsumerState<TasksScreen> with WidgetsBindingObserver {
  TaskCategory? _selectedCategory;
  String? _selectedTag;
  bool _showCompleted = false;
  bool _showSearch = false;
  bool _showCalendar = false;
  bool _selectMode = false;
  final Set<String> _selectedTaskIds = {};
  DateTime _calendarFocusDay = DateTime.now();
  DateTime _calendarSelectedDay = DateTime.now();
  String _searchQuery = '';
  _SortOrder _sortOrder = _SortOrder.dateDesc;
  final TextEditingController _searchController = TextEditingController();

  // Track recently completed tasks so they stay visible for animation
  final Set<String> _recentlyCompleted = {};

  Timer? _midnightTimer;
  DateTime _lastActiveDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSortOrder();
    _loadCategoryFilter();
    _checkFocusTaskCompleted();
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _midnightTimer?.cancel();
    super.dispose();
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final delay = midnight.difference(now);
    _midnightTimer = Timer(delay, () {
      if (!mounted) return;
      _refreshForNewDay();
      _scheduleMidnightRefresh(); // schedule next midnight
    });
  }

  void _refreshForNewDay() {
    final today = DateTime.now();
    _lastActiveDate = DateTime(today.year, today.month, today.day);
    ref.invalidate(allTasksProvider);
    ref.invalidate(taskStatisticsProvider);
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkFocusTaskCompleted();
      // Refresh if date changed while app was in background
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastDate = DateTime(_lastActiveDate.year, _lastActiveDate.month, _lastActiveDate.day);
      if (today != lastDate) {
        _refreshForNewDay();
      }
    } else if (state == AppLifecycleState.paused) {
      final now = DateTime.now();
      _lastActiveDate = DateTime(now.year, now.month, now.day);
    }
  }

  /// Check if a focus mode task was completed while app was in background
  Future<void> _checkFocusTaskCompleted() async {
    final completedTaskId = await NotificationService.instance.checkFocusTaskCompleted();
    if (completedTaskId != null && mounted) {
      debugPrint('FocusMode: Completing task $completedTaskId from focus mode');
      final userId = ref.read(currentUserIdProvider);
      if (userId.isNotEmpty) {
        await TaskService.instance.toggleTaskCompletion(
          userId: userId,
          taskId: completedTaskId,
        );
        // Refresh tasks
        ref.invalidate(tasksProvider(const TaskFilterParams()));
      }
    }
  }

  static const _sortPrefKey = 'task_sort_order';
  static const _categoryPrefKey = 'task_category_filter';

  Future<void> _loadSortOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_sortPrefKey);
    if (saved != null) {
      final order = _SortOrder.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => _SortOrder.dateDesc,
      );
      if (mounted) setState(() => _sortOrder = order);
    }
  }

  Future<void> _loadCategoryFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_categoryPrefKey);
    if (saved != null && saved.isNotEmpty) {
      final category = TaskCategory.values.firstWhere(
        (e) => e.value == saved,
        orElse: () => TaskCategory.other,
      );
      if (mounted) setState(() => _selectedCategory = category);
    }
  }

  Future<void> _saveCategoryFilter(TaskCategory? category) async {
    final prefs = await SharedPreferences.getInstance();
    if (category == null) {
      await prefs.remove(_categoryPrefKey);
    } else {
      await prefs.setString(_categoryPrefKey, category.value);
    }
  }

  Future<void> _saveSortOrder(_SortOrder order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortPrefKey, order.name);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final allTasksAsync = ref.watch(allTasksProvider);
    final statsAsync = ref.watch(taskStatisticsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppConstants.darkBackground : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isArabic ? 'بحث عن مهمة...' : 'Search tasks...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  ),
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : Text(
                'task_management'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
        centerTitle: false,
        backgroundColor: isDark ? AppConstants.darkSurface : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          // Select mode toggle (hide in search/calendar mode)
          if (!_showSearch && !_showCalendar)
            IconButton(
              icon: Icon(_selectMode ? Icons.close : Icons.checklist),
              tooltip: _selectMode
                  ? (isArabic ? 'إلغاء التحديد' : 'Cancel')
                  : (isArabic ? 'تحديد متعدد' : 'Select'),
              onPressed: () => setState(() {
                _selectMode = !_selectMode;
                _selectedTaskIds.clear();
              }),
            ),
          // Calendar toggle
          IconButton(
            icon: Icon(_showCalendar ? Icons.list : Icons.calendar_month),
            tooltip: _showCalendar
                ? (isArabic ? 'عرض القائمة' : 'List view')
                : (isArabic ? 'عرض التقويم' : 'Calendar view'),
            onPressed: () => setState(() => _showCalendar = !_showCalendar),
          ),
          // Search toggle
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          // Task settings
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: isArabic ? 'إعدادات المهام' : 'Task settings',
            onPressed: () => _showTaskSettings(context, isArabic, isDark),
          ),
          // Sort menu
          PopupMenuButton<_SortOrder>(
            icon: const Icon(Icons.sort),
            tooltip: isArabic ? 'ترتيب' : 'Sort',
            onSelected: (order) {
              setState(() => _sortOrder = order);
              _saveSortOrder(order);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _SortOrder.dateDesc,
                child: Row(children: [
                  Icon(Icons.arrow_downward,
                      size: 16,
                      color: _sortOrder == _SortOrder.dateDesc
                          ? AppConstants.primaryColor
                          : null),
                  const SizedBox(width: 8),
                  Text(isArabic ? 'الأحدث أولاً' : 'Newest first'),
                ]),
              ),
              PopupMenuItem(
                value: _SortOrder.dateAsc,
                child: Row(children: [
                  Icon(Icons.arrow_upward,
                      size: 16,
                      color: _sortOrder == _SortOrder.dateAsc
                          ? AppConstants.primaryColor
                          : null),
                  const SizedBox(width: 8),
                  Text(isArabic ? 'الأقدم أولاً' : 'Oldest first'),
                ]),
              ),
              PopupMenuItem(
                value: _SortOrder.priority,
                child: Row(children: [
                  Icon(Icons.flag,
                      size: 16,
                      color: _sortOrder == _SortOrder.priority
                          ? AppConstants.primaryColor
                          : null),
                  const SizedBox(width: 8),
                  Text(isArabic ? 'حسب الأولوية' : 'By priority'),
                ]),
              ),
              PopupMenuItem(
                value: _SortOrder.title,
                child: Row(children: [
                  Icon(Icons.sort_by_alpha,
                      size: 16,
                      color: _sortOrder == _SortOrder.title
                          ? AppConstants.primaryColor
                          : null),
                  const SizedBox(width: 8),
                  Text(isArabic ? 'أبجدياً' : 'Alphabetical'),
                ]),
              ),
              PopupMenuItem<_SortOrder>(
                value: _SortOrder.manual,
                child: Row(children: [
                  Icon(Icons.drag_handle,
                      size: 16,
                      color: _sortOrder == _SortOrder.manual
                          ? AppConstants.primaryColor
                          : null),
                  const SizedBox(width: 8),
                  Text(isArabic ? 'ترتيب يدوي' : 'Custom Order'),
                ]),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _selectMode
          ? null
          : GestureDetector(
        onLongPress: () => _navigateToTaskForm(context),
        child: FloatingActionButton.extended(
          onPressed: () => _showQuickAdd(context, isArabic, isDark),
          icon: const Icon(Icons.add),
          label: Text(isArabic ? 'إضافة سريعة' : 'Quick Add'),
          backgroundColor: AppConstants.primaryColor,
        ),
      ),
      bottomNavigationBar: _selectMode && _selectedTaskIds.isNotEmpty
          ? _buildBulkActionBar(isDark, isArabic)
          : null,
      body: _showCalendar
          ? _buildCalendarView(allTasksAsync, isDark, isArabic)
          : RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allTasksProvider);
          ref.invalidate(taskStatisticsProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Stats Row
            SliverToBoxAdapter(
              child: statsAsync.when(
                data: (stats) => _buildStatsRow(stats, isDark, isArabic),
                loading: () => const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // Estimated time summary for today
            SliverToBoxAdapter(
              child: allTasksAsync.when(
                data: (tasks) {
                  final todayEstimate = tasks
                      .where((t) => t.isDueToday && !t.isCompleted && t.estimatedMinutes > 0)
                      .fold(0, (sum, t) => sum + t.estimatedMinutes);
                  if (todayEstimate == 0) return const SizedBox.shrink();
                  final h = todayEstimate ~/ 60;
                  final m = todayEstimate % 60;
                  final label = h > 0
                      ? (isArabic ? '~$h س ${m > 0 ? '$m د' : ''} لليوم' : '~${h}h ${m > 0 ? '${m}m ' : ''}today')
                      : (isArabic ? '~$m د لليوم' : '~${m}m today');
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: AppConstants.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppConstants.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // Category Filter Chips
            SliverToBoxAdapter(
              child: _buildCategoryChips(isDark, isArabic),
            ),

            // Tag Filter Chips (only if tags exist)
            SliverToBoxAdapter(
              child: allTasksAsync.when(
                data: (tasks) => _buildTagChips(tasks, isDark, isArabic),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // Task Sections
            SliverToBoxAdapter(
              child: allTasksAsync.when(
                data: (tasks) => _buildSections(tasks, isDark, isArabic),
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: ShimmerListTile(),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(isArabic
                        ? 'خطأ في تحميل المهام'
                        : 'Error loading tasks'),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ─── Calendar View ─────────────────────────────────────────────────────────

  Widget _buildCalendarView(AsyncValue<List<Task>> allTasksAsync, bool isDark, bool isArabic) {
    return allTasksAsync.when(
      data: (allTasks) {
        // Build map of date -> task count for calendar markers
        final taskCounts = <DateTime, int>{};
        for (final t in allTasks) {
          if (t.dueDate != null) {
            final day = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
            taskCounts[day] = (taskCounts[day] ?? 0) + 1;
          }
        }

        // Get tasks for selected day
        final selectedDay = DateTime(
          _calendarSelectedDay.year,
          _calendarSelectedDay.month,
          _calendarSelectedDay.day,
        );
        final dayTasks = allTasks.where((t) {
          if (t.dueDate == null) return false;
          final taskDay = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
          return taskDay == selectedDay;
        }).toList()
          ..sort((a, b) {
            // Incomplete first, then by priority, then by due time
            if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
            const pOrder = {TaskPriority.high: 0, TaskPriority.medium: 1, TaskPriority.low: 2};
            final pc = (pOrder[a.priority] ?? 1).compareTo(pOrder[b.priority] ?? 1);
            if (pc != 0) return pc;
            return (a.dueDate ?? DateTime(2099)).compareTo(b.dueDate ?? DateTime(2099));
          });

        return Column(
          children: [
            // Calendar
            Container(
              margin: const EdgeInsets.all(16),
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
              child: TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _calendarFocusDay,
                selectedDayPredicate: (day) => isSameDay(_calendarSelectedDay, day),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _calendarSelectedDay = selected;
                    _calendarFocusDay = focused;
                  });
                },
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {
                  CalendarFormat.month: '',
                },
                headerStyle: HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  titleTextStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  leftChevronIcon: Icon(Icons.chevron_left,
                      color: isDark ? Colors.white70 : Colors.black54),
                  rightChevronIcon: Icon(Icons.chevron_right,
                      color: isDark ? Colors.white70 : Colors.black54),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  weekendStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade400,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: AppConstants.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: AppConstants.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  defaultTextStyle: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  weekendTextStyle: TextStyle(
                    color: isDark ? Colors.red.shade300 : Colors.red.shade400,
                  ),
                  outsideTextStyle: TextStyle(
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                  cellMargin: const EdgeInsets.all(4),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    final count = taskCounts[DateTime(date.year, date.month, date.day)] ?? 0;
                    if (count == 0) return null;
                    return Positioned(
                      bottom: 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          count.clamp(0, 3),
                          (_) => Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: AppConstants.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Selected day header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    _formatDate(_calendarSelectedDay, isArabic),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${dayTasks.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Task list for selected day
            Expanded(
              child: dayTasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_available,
                              size: 56,
                              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            isArabic ? 'لا مهام في هذا اليوم' : 'No tasks on this day',
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: dayTasks.length,
                      itemBuilder: (_, index) => _buildTaskCard(dayTasks[index]),
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Text(isArabic ? 'خطأ في تحميل المهام' : 'Error loading tasks'),
      ),
    );
  }

  String _formatDate(DateTime date, bool isArabic) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return isArabic ? 'اليوم' : 'Today';
    if (target == today.add(const Duration(days: 1))) return isArabic ? 'غداً' : 'Tomorrow';
    if (target == today.subtract(const Duration(days: 1))) return isArabic ? 'أمس' : 'Yesterday';

    final months = isArabic
        ? ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر']
        : ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ─── Stats Row ───────────────────────────────────────────────────────────

  Widget _buildStatsRow(TaskStatistics stats, bool isDark, bool isArabic) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/task_stats'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            _buildStatCard(
              icon: Icons.today,
              label: isArabic ? 'اليوم' : 'Today',
              value: '${stats.dueToday}',
              color: AppConstants.primaryColor,
              isDark: isDark,
            ),
            const SizedBox(width: 10),
            _buildStatCard(
              icon: Icons.warning_amber_rounded,
              label: isArabic ? 'متأخرة' : 'Overdue',
              value: '${stats.overdue}',
              color: Colors.red,
              isDark: isDark,
            ),
            const SizedBox(width: 10),
            _buildStatCard(
              icon: Icons.check_circle,
              label: isArabic ? 'مكتمل' : 'Done',
              value: '${stats.completed}',
              color: Colors.green,
              isDark: isDark,
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right,
                size: 20,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? AppConstants.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
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
                fontSize: 11,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Category Filter Chips ────────────────────────────────────────────────

  Widget _buildCategoryChips(bool isDark, bool isArabic) {
    final categories = [
      (null, isArabic ? 'الكل' : 'All', Icons.list),
      (TaskCategory.work, isArabic ? 'عمل' : 'Work', Icons.work_outline),
      (
        TaskCategory.personal,
        isArabic ? 'شخصي' : 'Personal',
        Icons.person_outline
      ),
      (
        TaskCategory.shopping,
        isArabic ? 'تسوق' : 'Shopping',
        Icons.shopping_cart_outlined
      ),
      (
        TaskCategory.health,
        isArabic ? 'صحة' : 'Health',
        Icons.favorite_outline
      ),
      (TaskCategory.study, isArabic ? 'دراسة' : 'Study', Icons.school_outlined),
      (
        TaskCategory.prayer,
        isArabic ? 'صلاة' : 'Prayer',
        Icons.mosque_outlined
      ),
      (TaskCategory.other, isArabic ? 'أخرى' : 'Other', Icons.more_horiz),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (category, label, icon) = categories[index];
          final isSelected = _selectedCategory == category;
          return GestureDetector(
            onTap: () {
              final newCat = isSelected ? null : category;
              setState(() => _selectedCategory = newCat);
              _saveCategoryFilter(newCat);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppConstants.primaryColor.withOpacity(0.12)
                    : (isDark ? AppConstants.darkCard : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppConstants.primaryColor
                      : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isSelected
                        ? AppConstants.primaryColor
                        : (isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? AppConstants.primaryColor
                          : (isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade700),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Tag Filter Chips ─────────────────────────────────────────────────────

  Widget _buildTagChips(List<Task> allTasks, bool isDark, bool isArabic) {
    // Collect all unique tags from tasks
    final allTags = <String>{};
    for (final t in allTasks) {
      if (t.tags != null) allTags.addAll(t.tags!);
    }
    if (allTags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: allTags.map((tag) {
            final isSelected = _selectedTag == tag;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedTag = isSelected ? null : tag;
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppConstants.primaryColor.withOpacity(0.15)
                        : (isDark ? AppConstants.darkCard : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppConstants.primaryColor
                          : (isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300),
                    ),
                  ),
                  child: Text(
                    '#$tag',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? AppConstants.primaryColor
                          : (isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Task Sections ────────────────────────────────────────────────────────

  List<Task> _applySort(List<Task> tasks) {
    final sorted = List<Task>.from(tasks);
    switch (_sortOrder) {
      case _SortOrder.dateDesc:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _SortOrder.dateAsc:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _SortOrder.priority:
        const order = {
          TaskPriority.high: 0,
          TaskPriority.medium: 1,
          TaskPriority.low: 2
        };
        sorted.sort((a, b) =>
            (order[a.priority] ?? 1).compareTo(order[b.priority] ?? 1));
      case _SortOrder.title:
        sorted.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case _SortOrder.manual:
        sorted.sort((a, b) => a.manualOrder.compareTo(b.manualOrder));
    }
    // Pinned tasks always float to top
    sorted.sort((a, b) {
      if (a.isPinned == b.isPinned) return 0;
      return a.isPinned ? -1 : 1;
    });
    return sorted;
  }

  Widget _buildManualOrderView(List<Task> tasks, bool isDark, bool isArabic) {
    final activeTasks = tasks.where((t) => !t.isCompleted).toList();
    final completedTasks = tasks.where((t) => t.isCompleted).toList();

    if (activeTasks.isEmpty && completedTasks.isEmpty) {
      return _buildEmptyState(isDark, isArabic);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reorderable list — long press card to drag
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;
              final reordered = List<Task>.from(activeTasks);
              final moved = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, moved);
              setState(() {});
              final userId = ref.read(currentUserIdProvider);
              if (userId.isNotEmpty) {
                await TaskService.instance.updateTaskOrders(
                  userId: userId,
                  tasks: reordered,
                );
                ref.invalidate(allTasksProvider);
              }
            },
            children: List.generate(activeTasks.length, (index) {
              final task = activeTasks[index];
              return ReorderableDelayedDragStartListener(
                key: ValueKey('reorder_${task.id}'),
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildReorderableTaskCard(task, isArabic),
                ),
              );
            }),
          ),
          // Completed section
          if (completedTasks.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _showCompleted = !_showCompleted),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    child: _buildSectionHeader(
                      icon: _showCompleted ? Icons.expand_less : Icons.expand_more,
                      title: isArabic ? 'المكتملة' : 'Completed',
                      count: completedTasks.length,
                      color: Colors.green,
                      isDark: isDark,
                    ),
                  ),
                ),
              ],
            ),
            if (_showCompleted) ...[
              const SizedBox(height: 8),
              ...completedTasks.map((task) => _buildTaskCard(task)),
            ],
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildSections(List<Task> allTasks, bool isDark, bool isArabic) {
    // Apply category filter
    var tasks = _selectedCategory == null
        ? allTasks
        : allTasks.where((t) => t.category == _selectedCategory).toList();

    // Apply tag filter
    if (_selectedTag != null) {
      tasks = tasks
          .where((t) => t.tags != null && t.tags!.contains(_selectedTag))
          .toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      tasks = tasks
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              (t.description?.toLowerCase().contains(q) ?? false) ||
              (t.tags?.any((tag) => tag.toLowerCase().contains(q)) ?? false) ||
              t.subtasks.any((s) => s.title.toLowerCase().contains(q)))
          .toList();
    }

    // Apply sort
    tasks = _applySort(tasks);

    // Manual reorder mode — flat ReorderableListView
    if (_sortOrder == _SortOrder.manual) {
      return _buildManualOrderView(tasks, isDark, isArabic);
    }

    // Split into sections
    // Recently completed tasks stay in their section for animation
    bool isVisible(Task t) =>
        !t.isCompleted || _recentlyCompleted.contains(t.id);

    final overdueTasks = tasks
        .where((t) => isVisible(t) && t.isOverdue)
        .toList()
      ..sort((a, b) =>
          (a.dueDate ?? DateTime(2099)).compareTo(b.dueDate ?? DateTime(2099)));

    final todayTasks = tasks
        .where((t) => isVisible(t) && t.isDueToday && !t.isOverdue)
        .toList()
      ..sort((a, b) =>
          (a.dueDate ?? DateTime(2099)).compareTo(b.dueDate ?? DateTime(2099)));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final in3Hours = now.add(const Duration(hours: 3));
    final thisWeekEnd = today.add(const Duration(days: 7));
    final nextWeekEnd = today.add(const Duration(days: 14));

    // Due soon — has a time component and due within 3 hours
    final dueSoonTasks = tasks.where((t) {
      if (!isVisible(t) || t.isOverdue || t.isCompleted) return false;
      if (t.dueDate == null || !t.hasDueTime) return false;
      return t.dueDate!.isAfter(now) && t.dueDate!.isBefore(in3Hours);
    }).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    final tomorrowTasks = tasks.where((t) {
      if (!isVisible(t) || t.isOverdue || t.isCompleted) return false;
      if (t.dueDate == null) return false;
      final dueDay = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return dueDay == tomorrow && !dueSoonTasks.contains(t);
    }).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    final thisWeekTasks = tasks.where((t) {
      if (!isVisible(t) || t.isOverdue || t.isDueToday || t.isCompleted) return false;
      if (t.dueDate == null) return false;
      final dueDay = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return dueDay.isAfter(tomorrow) && dueDay.isBefore(thisWeekEnd) &&
          !dueSoonTasks.contains(t) && !tomorrowTasks.contains(t);
    }).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    final nextWeekTasks = tasks.where((t) {
      if (!isVisible(t) || t.isOverdue || t.isDueToday || t.isCompleted) return false;
      if (t.dueDate == null) return false;
      final dueDay = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return !dueDay.isBefore(thisWeekEnd) && dueDay.isBefore(nextWeekEnd);
    }).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    final laterTasks = tasks.where((t) {
      if (!isVisible(t) || t.isOverdue || t.isDueToday || t.isCompleted) return false;
      if (t.dueDate == null) return false;
      final dueDay = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return !dueDay.isBefore(nextWeekEnd);
    }).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    // No due date tasks
    final otherTasks = tasks
        .where((t) => isVisible(t) && t.dueDate == null && !t.isCompleted)
        .toList();

    final completedTasks = tasks
        .where((t) => t.isCompleted && !_recentlyCompleted.contains(t.id))
        .toList();

    if (tasks.isEmpty) {
      return _searchQuery.isNotEmpty
          ? _buildNoResultsState(isDark, isArabic)
          : _buildEmptyState(isDark, isArabic);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overdue Section
          if (overdueTasks.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.warning_amber_rounded,
              title: isArabic ? 'متأخرة' : 'Overdue',
              count: overdueTasks.length,
              color: Colors.red,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            ...overdueTasks.map((task) => _buildTaskCard(task)),
            const SizedBox(height: 20),
          ],

          // Today Section
          if (todayTasks.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.today,
              title: isArabic ? 'مهام اليوم' : "Today's Tasks",
              count: todayTasks.length,
              color: AppConstants.primaryColor,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            ...todayTasks.map((task) => _buildTaskCard(task)),
            const SizedBox(height: 20),
          ],

          // Due Soon (within 3 hours)
          if (dueSoonTasks.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.alarm,
              title: isArabic ? 'خلال ٣ ساعات' : 'Due Soon',
              count: dueSoonTasks.length,
              color: Colors.deepOrange,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            ...dueSoonTasks.map((task) => _buildTaskCard(task)),
            const SizedBox(height: 20),
          ],

          // Tomorrow
          if (tomorrowTasks.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.wb_twilight,
              title: isArabic ? 'غداً' : 'Tomorrow',
              count: tomorrowTasks.length,
              color: Colors.orange,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            ...tomorrowTasks.map((task) => _buildTaskCard(task)),
            const SizedBox(height: 20),
          ],

          // This Week
          if (thisWeekTasks.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.date_range,
              title: isArabic ? 'هذا الأسبوع' : 'This Week',
              count: thisWeekTasks.length,
              color: AppConstants.primaryColor,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            ...thisWeekTasks.map((task) => _buildTaskCard(task)),
            const SizedBox(height: 20),
          ],

          // Next Week
          if (nextWeekTasks.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.calendar_month,
              title: isArabic ? 'الأسبوع القادم' : 'Next Week',
              count: nextWeekTasks.length,
              color: Colors.indigo,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            ...nextWeekTasks.map((task) => _buildTaskCard(task)),
            const SizedBox(height: 20),
          ],

          // Later (15+ days)
          if (laterTasks.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.event,
              title: isArabic ? 'لاحقاً' : 'Later',
              count: laterTasks.length,
              color: Colors.blueGrey,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            ...laterTasks.map((task) => _buildTaskCard(task)),
            const SizedBox(height: 20),
          ],

          // No due date
          if (otherTasks.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.task_alt,
              title: isArabic ? 'بدون تاريخ' : 'No Date',
              count: otherTasks.length,
              color: Colors.purple,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            ...otherTasks.map((task) => _buildTaskCard(task)),
            const SizedBox(height: 20),
          ],

          // Completed Section (collapsible)
          if (completedTasks.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _showCompleted = !_showCompleted),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    child: _buildSectionHeader(
                      icon: _showCompleted ? Icons.expand_less : Icons.expand_more,
                      title: isArabic ? 'المكتملة' : 'Completed',
                      count: completedTasks.length,
                      color: Colors.green,
                      isDark: isDark,
                    ),
                  ),
                ),
                if (_showCompleted)
                  TextButton.icon(
                    onPressed: () => _clearCompleted(completedTasks, isArabic),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: Text(
                      isArabic ? 'مسح الكل' : 'Clear',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                  ),
              ],
            ),
            if (_showCompleted) ...[
              const SizedBox(height: 8),
              ...completedTasks.map((task) => _buildTaskCard(task)),
            ],
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
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
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  /// Task card for reorder mode — no long-press context menu (long press = drag)
  Widget _buildReorderableTaskCard(Task task, bool isArabic) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        children: [
          _InlineSubtaskCard(
            key: ValueKey('inline_${task.id}'),
            task: task,
            onToggle: () => _toggleTask(task),
            onTap: () => _editTask(task),
            onDelete: () => _deleteTask(task, isArabic),
            onMenuTap: () => _showContextMenu(task, isArabic),
            onPostpone: () => _postponeTask(task),
            userId: ref.read(currentUserIdProvider),
            onChanged: () {
              ref.invalidate(allTasksProvider);
              ref.invalidate(taskStatisticsProvider);
            },
          ),
          if (task.focusMode && !task.isCompleted)
            PositionedDirectional(
              top: 8,
              end: 8,
              child: GestureDetector(
                onTap: () => _startFocusNow(task),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎯', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 3),
                      Text(
                        isArabic ? 'تركيز' : 'Focus',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isSelected = _selectedTaskIds.contains(task.id);

    if (_selectMode) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () => setState(() {
            if (isSelected) {
              _selectedTaskIds.remove(task.id);
            } else {
              _selectedTaskIds.add(task.id);
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              border: Border.all(
                color: isSelected ? AppConstants.primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                TaskCard(
                  key: ValueKey(task.id),
                  task: task,
                  onToggle: null,
                  onTap: null,
                  onDelete: null,
                ),
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppConstants.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      ),
                    ),
                  ),
                Positioned(
                  top: 8, right: 8,
                  child: AnimatedScale(
                    scale: isSelected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppConstants.primaryColor,
                      child: const Icon(Icons.check, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        children: [
          _InlineSubtaskCard(
            key: ValueKey('inline_${task.id}'),
            task: task,
            onToggle: () => _toggleTask(task),
            onTap: () => _editTask(task),
            onDelete: () => _deleteTask(task, isArabic),
            onLongPress: null,
            onMenuTap: () => _showContextMenu(task, isArabic),
            onPostpone: () => _postponeTask(task),
            userId: ref.read(currentUserIdProvider),
            onChanged: () {
              ref.invalidate(allTasksProvider);
              ref.invalidate(taskStatisticsProvider);
            },
          ),
          // Focus Mode shortcut — only on tasks with focusMode enabled
          if (task.focusMode && !task.isCompleted)
            PositionedDirectional(
              top: 8,
              end: 8,
              child: GestureDetector(
                onTap: () => _startFocusNow(task),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎯', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 3),
                      Text(
                        isArabic ? 'تركيز' : 'Focus',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _startFocusNow(Task task) async {
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString('language') ?? 'en';
    final isArabic = language == 'ar';
    final granted = await NotificationService.instance.canDrawOverlays();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isArabic ? 'يرجى منح إذن العرض فوق التطبيقات' : 'Please grant overlay permission'),
        action: SnackBarAction(
          label: isArabic ? 'منح' : 'Grant',
          onPressed: () => NotificationService.instance.requestOverlayPermission(),
        ),
      ));
      return;
    }
    await NotificationService.instance.startFocusService(
      taskId: task.id,
      taskTitle: task.title,
      taskDesc: task.description ?? '',
      durationMinutes: task.focusDurationMinutes,
      language: language,
    );
  }

  Future<void> _postponeTask(Task task) async {
    final userId = ref.read(currentUserIdProvider);
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    DateTime newDueDate;
    if (task.dueDate != null && task.hasDueTime) {
      newDueDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day,
          task.dueDate!.hour, task.dueDate!.minute);
    } else {
      newDueDate = tomorrow;
    }
    await TaskService.instance.updateTask(
      userId: userId,
      taskId: task.id,
      dueDate: newDueDate,
      hasDueTime: task.hasDueTime,
    );
    ref.invalidate(allTasksProvider);
    ref.invalidate(taskStatisticsProvider);
  }

  void _showContextMenu(Task task, bool isArabic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppConstants.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Task title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 20),

              // Edit
              ListTile(
                leading: const Icon(Icons.edit_outlined, size: 22),
                title: Text(isArabic ? 'تعديل' : 'Edit'),
                onTap: () {
                  Navigator.pop(ctx);
                  _editTask(task);
                },
              ),

              // Pin/Unpin
              ListTile(
                leading: Icon(
                  task.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 22,
                  color: task.isPinned ? Colors.amber : null,
                ),
                title: Text(
                  task.isPinned
                      ? (isArabic ? 'إلغاء التثبيت' : 'Unpin')
                      : (isArabic ? 'تثبيت في الأعلى' : 'Pin to Top'),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _togglePin(task);
                },
              ),

              // Duplicate
              ListTile(
                leading: const Icon(Icons.content_copy_outlined, size: 22),
                title: Text(isArabic ? 'نسخ' : 'Duplicate'),
                onTap: () {
                  Navigator.pop(ctx);
                  _duplicateTask(task, isArabic);
                },
              ),

              // Change Priority
              ListTile(
                leading: Icon(Icons.flag_outlined, size: 22,
                    color: task.priority == TaskPriority.high ? Colors.orange
                        : task.priority == TaskPriority.medium ? Colors.amber
                        : Colors.green),
                title: Text(isArabic ? 'تغيير الأولوية' : 'Change Priority'),
                trailing: _buildPriorityLabel(task.priority, isArabic),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPriorityPicker(task, isArabic);
                },
              ),

              // Toggle complete/incomplete
              ListTile(
                leading: Icon(
                  task.isCompleted ? Icons.undo_outlined : Icons.check_circle_outline,
                  size: 22,
                  color: task.isCompleted ? Colors.orange : Colors.green,
                ),
                title: Text(
                  task.isCompleted
                      ? (isArabic ? 'إلغاء الإتمام' : 'Mark Incomplete')
                      : (isArabic ? 'إتمام' : 'Mark Complete'),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleTask(task);
                },
              ),

              // Delete
              ListTile(
                leading: Icon(Icons.delete_outline, size: 22, color: Colors.red.shade400),
                title: Text(isArabic ? 'حذف' : 'Delete',
                    style: TextStyle(color: Colors.red.shade400)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteTask(task, isArabic);
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityLabel(TaskPriority priority, bool isArabic) {
    final labels = {
      TaskPriority.high: isArabic ? 'عالية' : 'High',
      TaskPriority.medium: isArabic ? 'متوسطة' : 'Medium',
      TaskPriority.low: isArabic ? 'منخفضة' : 'Low',
    };
    final colors = {
      TaskPriority.high: Colors.orange,
      TaskPriority.medium: Colors.amber,
      TaskPriority.low: Colors.green,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors[priority]!.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(labels[priority]!,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors[priority])),
    );
  }

  Future<void> _duplicateTask(Task task, bool isArabic) async {
    final userId = ref.read(currentUserIdProvider);
    try {
      await TaskService.instance.addTask(
        userId: userId,
        title: task.title,
        description: task.description,
        priority: task.priority,
        category: task.category,
        dueDate: task.dueDate,
        tags: task.tags,
        hasDueTime: task.hasDueTime,
      );
      ref.invalidate(allTasksProvider);
      ref.invalidate(taskStatisticsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'تم نسخ المهمة' : 'Task duplicated'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error duplicating task: $e');
    }
  }

  // ─── Bulk Actions ─────────────────────────────────────────────────────────

  Widget _buildBulkActionBar(bool isDark, bool isArabic) {
    final count = _selectedTaskIds.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Text(
              isArabic ? '$count محدد' : '$count selected',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const Spacer(),
            // Complete all
            TextButton.icon(
              onPressed: () => _bulkComplete(isArabic),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text(isArabic ? 'إتمام' : 'Complete',
                  style: const TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(foregroundColor: Colors.green),
            ),
            const SizedBox(width: 8),
            // Delete all
            TextButton.icon(
              onPressed: () => _bulkDelete(isArabic),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(isArabic ? 'حذف' : 'Delete',
                  style: const TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bulkComplete(bool isArabic) async {
    final userId = ref.read(currentUserIdProvider);
    final ids = Set<String>.from(_selectedTaskIds);
    int completed = 0;

    for (final id in ids) {
      try {
        await TaskService.instance.toggleTaskCompletion(
          userId: userId,
          taskId: id,
        );
        completed++;
      } catch (e) {
        debugPrint('Error completing task $id: $e');
      }
    }

    setState(() {
      _selectMode = false;
      _selectedTaskIds.clear();
    });
    ref.invalidate(allTasksProvider);
    ref.invalidate(taskStatisticsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          isArabic ? 'تم إتمام $completed مهام' : '$completed tasks completed',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _bulkDelete(bool isArabic) async {
    final userId = ref.read(currentUserIdProvider);
    final ids = Set<String>.from(_selectedTaskIds);
    int deleted = 0;

    for (final id in ids) {
      try {
        await TaskService.instance.deleteTask(
          userId: userId,
          taskId: id,
        );
        deleted++;
      } catch (e) {
        debugPrint('Error deleting task $id: $e');
      }
    }

    setState(() {
      _selectMode = false;
      _selectedTaskIds.clear();
    });
    ref.invalidate(allTasksProvider);
    ref.invalidate(taskStatisticsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          isArabic ? 'تم حذف $deleted مهام' : '$deleted tasks deleted',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _clearCompleted(List<Task> tasks, bool isArabic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'مسح المهام المكتملة' : 'Clear Completed'),
        content: Text(isArabic
            ? 'هل تريد حذف ${tasks.length} مهام مكتملة؟'
            : 'Delete ${tasks.length} completed tasks?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(isArabic ? 'مسح' : 'Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final userId = ref.read(currentUserIdProvider);
    int deleted = 0;
    for (final task in tasks) {
      try {
        await TaskService.instance.deleteTask(
          userId: userId,
          taskId: task.id,
        );
        deleted++;
      } catch (e) {
        debugPrint('Error clearing task ${task.id}: $e');
      }
    }

    ref.invalidate(allTasksProvider);
    ref.invalidate(taskStatisticsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          isArabic ? 'تم حذف $deleted مهام' : '$deleted tasks cleared',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _showPriorityPicker(Task task, bool isArabic) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = await showModalBottomSheet<TaskPriority>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppConstants.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  isArabic ? 'اختر الأولوية' : 'Select Priority',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              ...[
                (TaskPriority.high, isArabic ? 'عالية' : 'High', Colors.orange, Icons.flag),
                (TaskPriority.medium, isArabic ? 'متوسطة' : 'Medium', Colors.amber, Icons.flag),
                (TaskPriority.low, isArabic ? 'منخفضة' : 'Low', Colors.green, Icons.flag),
              ].map((entry) {
                final (p, label, color, icon) = entry;
                final isSelected = task.priority == p;
                return ListTile(
                  leading: Icon(icon, color: color),
                  title: Text(label),
                  trailing: isSelected
                      ? Icon(Icons.check, color: AppConstants.primaryColor)
                      : null,
                  onTap: () => Navigator.pop(ctx, p),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (selected != null && selected != task.priority) {
      final userId = ref.read(currentUserIdProvider);
      try {
        await TaskService.instance.updateTask(
          userId: userId,
          taskId: task.id,
          priority: selected,
        );
        ref.invalidate(allTasksProvider);
      } catch (e) {
        debugPrint('Error updating priority: $e');
      }
    }
  }

  Widget _buildNoResultsState(bool isDark, bool isArabic) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 72,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'لا توجد نتائج' : 'No results found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic ? 'جرب كلمة بحث مختلفة' : 'Try a different search term',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, bool isArabic) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
      child: Column(
        children: [
          Icon(
            Icons.task_alt_outlined,
            size: 72,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'لا توجد مهام' : 'No tasks yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'اضغط + لإضافة مهمتك الأولى'
                : 'Tap + to add your first task',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  bool _isToggling = false;

  Future<void> _toggleTask(Task task) async {
    if (_isToggling) return; // Prevent rapid double-tap
    _isToggling = true;

    final wasCompleted = task.isCompleted;
    final userId = ref.read(currentUserIdProvider);

    // Check BEFORE toggle: is this the last incomplete active task?
    // Counts tasks due today OR with no due date (undated tasks are always "active")
    bool shouldCelebrate = false;
    if (!wasCompleted) {
      final currentTasks = ref.read(allTasksProvider).valueOrNull ?? [];
      final activeTasks = currentTasks.where(
          (t) => !t.isCompleted && (t.isDueToday || t.dueDate == null));
      shouldCelebrate = activeTasks.length == 1 && activeTasks.first.id == task.id;
    }

    app_haptic.HapticFeedback.medium();
    try {
      await TaskService.instance.toggleTaskCompletion(
        userId: userId,
        taskId: task.id,
      );

      if (!wasCompleted) {
        // Task was just completed — keep visible for animation
        setState(() => _recentlyCompleted.add(task.id));
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() => _recentlyCompleted.remove(task.id));
          }
        });

        if (shouldCelebrate) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) _showCelebration();
          });
        }
      } else {
        // Task was undone — immediately clean up any stale animation state
        setState(() => _recentlyCompleted.remove(task.id));
      }
    } catch (e) {
      debugPrint('Error toggling task: $e');
    } finally {
      _isToggling = false;
    }
  }

  void _showCelebration() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    app_haptic.HapticFeedback.success();

    final overlay = OverlayEntry(
      builder: (_) => _CelebrationOverlay(
        isDark: isDark,
        isArabic: isArabic,
      ),
    );
    Overlay.of(context).insert(overlay);
    Future.delayed(const Duration(seconds: 3), () => overlay.remove());
  }

  Future<void> _editTask(Task task) async {
    final result = await Navigator.of(context).pushNamed(
      '/task_form',
      arguments: task,
    );
    if (result == true) {
      ref.invalidate(allTasksProvider);
      ref.invalidate(taskStatisticsProvider);
    }
  }

  Future<void> _togglePin(Task task) async {
    final userId = ref.read(currentUserIdProvider);
    try {
      await TaskService.instance.updateTask(
        userId: userId,
        taskId: task.id,
        isPinned: !task.isPinned,
      );
      ref.invalidate(allTasksProvider);
    } catch (e) {
      debugPrint('Error toggling pin: $e');
    }
  }

  Future<void> _deleteTask(Task task, bool isArabic) async {
    final userId = ref.read(currentUserIdProvider);

    try {
      await TaskService.instance.deleteTask(
        userId: userId,
        taskId: task.id,
      );

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        final controller = messenger.showSnackBar(SnackBar(
          content: Text(
            isArabic ? 'تم حذف المهمة' : 'Task deleted',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.black87,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          action: SnackBarAction(
            label: isArabic ? 'تراجع' : 'Undo',
            textColor: Colors.white,
            onPressed: () async {
              try {
                await TaskService.instance.addTask(
                  userId: userId,
                  title: task.title,
                  description: task.description,
                  priority: task.priority,
                  category: task.category,
                  dueDate: task.dueDate,
                  tags: task.tags,
                );
                ref.invalidate(allTasksProvider);
                ref.invalidate(taskStatisticsProvider);
              } catch (e) {
                debugPrint('Error restoring task: $e');
              }
            },
          ),
        ));
        Future.delayed(const Duration(seconds: 3), controller.close);
      }

      ref.invalidate(allTasksProvider);
      ref.invalidate(taskStatisticsProvider);
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }

  Future<void> _navigateToTaskForm(BuildContext context) async {
    final result = await Navigator.of(context).pushNamed('/task_form');
    if (result == true) {
      ref.invalidate(allTasksProvider);
      ref.invalidate(taskStatisticsProvider);
    }
  }

  void _showTaskSettings(BuildContext context, bool isArabic, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskSettingsSheet(isArabic: isArabic, isDark: isDark),
    );
  }

  Future<void> _showQuickAdd(
      BuildContext context, bool isArabic, bool isDark) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickAddSheet(
        isArabic: isArabic,
        isDark: isDark,
        onSubmit: (title, priority, category, dueDate, hasDueTime) =>
            _submitQuickAddData(title, priority, category, dueDate, hasDueTime, isArabic),
      ),
    );
  }

  Future<void> _submitQuickAddData(
    String title,
    TaskPriority priority,
    TaskCategory category,
    DateTime? dueDate,
    bool hasDueTime,
    bool isArabic,
  ) async {
    final userId = ref.read(currentUserIdProvider);
    await TaskService.instance.addTask(
      userId: userId,
      title: title,
      priority: priority,
      category: category,
      dueDate: dueDate,
      hasDueTime: hasDueTime,
    );

    ref.invalidate(allTasksProvider);
    ref.invalidate(taskStatisticsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'تمت إضافة المهمة' : 'Task added'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// Full-screen celebration overlay shown when all today's tasks are completed
class _CelebrationOverlay extends StatefulWidget {
  final bool isDark;
  final bool isArabic;
  const _CelebrationOverlay({required this.isDark, required this.isArabic});

  @override
  State<_CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<_CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 75),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
    ]).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Container(
              color: AppConstants.primaryColor.withValues(alpha: 0.12 * _opacityAnim.value),
              alignment: Alignment.center,
              child: Opacity(
                opacity: _opacityAnim.value,
                child: Transform.scale(
                  scale: _scaleAnim.value,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 36),
                    decoration: BoxDecoration(
                      color: widget.isDark ? AppConstants.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppConstants.primaryColor.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppConstants.primaryColor.withValues(alpha: 0.22),
                          blurRadius: 36,
                          offset: const Offset(0, 10),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Gradient header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppConstants.primaryColor, AppConstants.accentCyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                          ),
                          child: Column(
                            children: [
                              // Glowing check circle
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                                ),
                                child: const Center(
                                  child: Icon(Icons.check_rounded, size: 42, color: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Decorative dots row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(3, (i) => Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: i == 1 ? 0.9 : 0.4),
                                    shape: BoxShape.circle,
                                  ),
                                )),
                              ),
                            ],
                          ),
                        ),

                        // Body
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
                          child: Column(
                            children: [
                              Text(
                                widget.isArabic ? 'أُنجز الكل! ✨' : 'All Done! ✨',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: widget.isDark ? Colors.white : const Color(0xFF1A1A1A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.isArabic
                                    ? 'أكملت جميع مهام اليوم، استمر!'
                                    : 'You crushed every task today!',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: widget.isDark ? Colors.white60 : Colors.black45,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 18),
                              // Theme-colored badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                                decoration: BoxDecoration(
                                  color: AppConstants.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: AppConstants.primaryColor.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Text(
                                  widget.isArabic ? '🎯  يوم منتج!' : '🎯  Productive day!',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppConstants.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        ),
      ),
    );
  }
}

class _TaskSettingsSheet extends ConsumerWidget {
  final bool isArabic;
  final bool isDark;

  const _TaskSettingsSheet({required this.isArabic, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(taskNotificationsEnabledProvider);
    final isEnabled = notifAsync.valueOrNull ?? true;
    final minutesAsync = ref.watch(taskReminderMinutesProvider);
    final reminderMinutes = minutesAsync.valueOrNull ?? 30;

    final options = [5, 10, 15, 30, 45, 60];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            isArabic ? 'إعدادات المهام' : 'Task Settings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.notifications_outlined,
                color: isEnabled ? AppConstants.primaryColor : Colors.grey),
            title: Text(
              isArabic ? 'تذكير المهام' : 'Task Reminders',
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            subtitle: Text(
              isArabic ? 'إشعار قبل موعد المهمة' : 'Notify before task due time',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            value: isEnabled,
            activeColor: AppConstants.primaryColor,
            onChanged: (val) =>
                ref.read(taskNotificationsEnabledProvider.notifier).setEnabled(val),
          ),
          if (isEnabled) ...[
            const SizedBox(height: 8),
            Text(
              isArabic ? 'ذكرني قبل' : 'Remind me before',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((mins) {
                final selected = reminderMinutes == mins;
                return GestureDetector(
                  onTap: () => ref
                      .read(taskReminderMinutesProvider.notifier)
                      .setMinutes(mins),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppConstants.primaryColor.withOpacity(0.12)
                          : (isDark ? AppConstants.darkCard : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppConstants.primaryColor
                            : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                      ),
                    ),
                    child: Text(
                      isArabic ? '$mins دقيقة' : '$mins min',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        color: selected
                            ? AppConstants.primaryColor
                            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickAddSheet extends StatefulWidget {
  final bool isArabic;
  final bool isDark;
  final Future<void> Function(String title, TaskPriority priority,
      TaskCategory category, DateTime? dueDate, bool hasDueTime) onSubmit;

  const _QuickAddSheet({
    required this.isArabic,
    required this.isDark,
    required this.onSubmit,
  });

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final _controller = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  TaskCategory _category = TaskCategory.other;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    DateTime? effectiveDueDate = _dueDate;
    if (_dueDate != null && _dueTime != null) {
      effectiveDueDate = DateTime(
        _dueDate!.year, _dueDate!.month, _dueDate!.day,
        _dueTime!.hour, _dueTime!.minute,
      );
    }

    Navigator.of(context).pop();
    await widget.onSubmit(title, _priority, _category, effectiveDueDate, _dueTime != null);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = widget.isArabic;
    final isDark = widget.isDark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: isDark ? AppConstants.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              isArabic ? 'إضافة مهمة سريعة' : 'Quick Add Task',
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: isArabic ? 'عنوان المهمة...' : 'Task title...',
                filled: true,
                fillColor: isDark ? AppConstants.darkCard : const Color(0xFFF5F7FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ...[
                  (TaskPriority.high, isArabic ? 'عالية' : 'High', Colors.orange),
                  (TaskPriority.medium, isArabic ? 'متوسطة' : 'Med', Colors.amber),
                  (TaskPriority.low, isArabic ? 'منخفضة' : 'Low', Colors.green),
                ].map((entry) {
                  final (p, label, color) = entry;
                  final selected = _priority == p;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _priority = p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? color : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                          ),
                        ),
                        child: Text(label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            color: selected ? color : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          )),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _dueDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: _dueDate != null ? AppConstants.primaryColor.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _dueDate != null ? AppConstants.primaryColor : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.calendar_today, size: 13,
                          color: _dueDate != null ? AppConstants.primaryColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                      const SizedBox(width: 3),
                      Text(
                        _dueDate != null ? '${_dueDate!.day}/${_dueDate!.month}' : (isArabic ? 'التاريخ' : 'Date'),
                        style: TextStyle(fontSize: 11,
                          color: _dueDate != null ? AppConstants.primaryColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                      ),
                    ]),
                  ),
                ),
                if (_dueDate != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _dueTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) setState(() => _dueTime = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: _dueTime != null ? AppConstants.primaryColor.withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _dueTime != null ? AppConstants.primaryColor : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.access_time, size: 13,
                            color: _dueTime != null ? AppConstants.primaryColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                        const SizedBox(width: 3),
                        Text(
                          _dueTime != null ? _dueTime!.format(context) : (isArabic ? 'الوقت' : 'Time'),
                          style: TextStyle(fontSize: 11,
                            color: _dueTime != null ? AppConstants.primaryColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                        ),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  (TaskCategory.work, Icons.work_outline, isArabic ? 'عمل' : 'Work'),
                  (TaskCategory.personal, Icons.person_outline, isArabic ? 'شخصي' : 'Personal'),
                  (TaskCategory.shopping, Icons.shopping_cart_outlined, isArabic ? 'تسوق' : 'Shop'),
                  (TaskCategory.health, Icons.favorite_outline, isArabic ? 'صحة' : 'Health'),
                  (TaskCategory.study, Icons.school_outlined, isArabic ? 'دراسة' : 'Study'),
                  (TaskCategory.prayer, Icons.mosque_outlined, isArabic ? 'صلاة' : 'Prayer'),
                ].map((entry) {
                  final (cat, icon, label) = entry;
                  final selected = _category == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _category = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected ? AppConstants.primaryColor.withValues(alpha: 0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? AppConstants.primaryColor : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(icon, size: 12,
                              color: selected ? AppConstants.primaryColor : (isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                          const SizedBox(width: 3),
                          Text(label, style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            color: selected ? AppConstants.primaryColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          )),
                        ]),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isArabic ? 'إضافة' : 'Add Task',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Inline Subtask Card ─────────────────────────────────────────────────────

class _InlineSubtaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onLongPress;
  final VoidCallback? onMenuTap;
  final VoidCallback? onPostpone;
  final String userId;
  final VoidCallback onChanged;

  const _InlineSubtaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onToggle,
    this.onDelete,
    this.onLongPress,
    this.onMenuTap,
    this.onPostpone,
    required this.userId,
    required this.onChanged,
  });

  @override
  State<_InlineSubtaskCard> createState() => _InlineSubtaskCardState();
}

class _InlineSubtaskCardState extends State<_InlineSubtaskCard> {
  bool _expanded = false;
  final TextEditingController _addController = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _toggleSubtask(SubTask subtask) async {
    if (widget.userId.isEmpty) return;
    final updated = widget.task.subtasks.map((s) {
      if (s.id == subtask.id) return SubTask(id: s.id, title: s.title, isCompleted: !s.isCompleted);
      return s;
    }).toList();
    await TaskService.instance.updateTask(
      userId: widget.userId,
      taskId: widget.task.id,
      subtasks: updated,
    );
    widget.onChanged();
  }

  Future<void> _addSubtask(String title) async {
    final t = title.trim();
    if (t.isEmpty || widget.userId.isEmpty) return;
    setState(() => _adding = true);
    final newSub = SubTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: t,
      isCompleted: false,
    );
    final updated = [...widget.task.subtasks, newSub];
    await TaskService.instance.updateTask(
      userId: widget.userId,
      taskId: widget.task.id,
      subtasks: updated,
    );
    _addController.clear();
    setState(() => _adding = false);
    widget.onChanged();
  }

  Future<void> _deleteSubtask(SubTask subtask) async {
    if (widget.userId.isEmpty) return;
    final updated = widget.task.subtasks.where((s) => s.id != subtask.id).toList();
    await TaskService.instance.updateTask(
      userId: widget.userId,
      taskId: widget.task.id,
      subtasks: updated,
    );
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      children: [
        TaskCard(
          key: ValueKey(widget.task.id),
          task: widget.task,
          onToggle: widget.onToggle,
          onTap: widget.onTap,
          onDelete: widget.onDelete,
          onLongPress: widget.onLongPress,
          onMenuTap: widget.onMenuTap,
          onPostpone: widget.onPostpone,
          onExpand: () => setState(() => _expanded = !_expanded),
          isExpanded: _expanded,
        ),

        // Expanded subtask panel
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _expanded
              ? Container(
                  margin: const EdgeInsets.only(top: 2, left: 12, right: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppConstants.darkCard : Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AppConstants.radiusMedium),
                      bottomRight: Radius.circular(AppConstants.radiusMedium),
                    ),
                    border: Border.all(
                      color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Existing subtasks
                      ...widget.task.subtasks.map((sub) => InkWell(
                        onTap: () => _toggleSubtask(sub),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              AnimatedScale(
                                scale: sub.isCompleted ? 1.1 : 1.0,
                                duration: const Duration(milliseconds: 150),
                                child: Icon(
                                  sub.isCompleted
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 20,
                                  color: sub.isCompleted
                                      ? Colors.green
                                      : (isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  sub.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    decoration: sub.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: sub.isCompleted
                                        ? (isDark ? Colors.grey.shade500 : Colors.grey.shade400)
                                        : (isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _deleteSubtask(sub),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.close, size: 16,
                                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),

                      // Divider before add field
                      if (widget.task.subtasks.isNotEmpty)
                        Divider(height: 1, color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder),

                      // Quick add field
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 18, color: AppConstants.primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _addController,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: isArabic ? 'أضف مهمة فرعية...' : 'Add subtask...',
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                textInputAction: TextInputAction.done,
                                onSubmitted: _adding ? null : _addSubtask,
                              ),
                            ),
                            if (_adding)
                              const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              GestureDetector(
                                onTap: () => _addSubtask(_addController.text),
                                child: Icon(Icons.send, size: 16, color: AppConstants.primaryColor),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
