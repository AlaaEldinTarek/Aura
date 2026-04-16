import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/task_provider.dart';
import '../../core/models/task.dart';
import '../../core/widgets/task_card.dart';
import '../../core/widgets/shimmer_loading.dart';
import '../../core/services/task_service.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

enum _SortOrder { dateDesc, dateAsc, priority, title }

class _TasksScreenState extends ConsumerState<TasksScreen> {
  TaskCategory? _selectedCategory;
  bool _showCompleted = false;
  bool _showSearch = false;
  String _searchQuery = '';
  _SortOrder _sortOrder = _SortOrder.dateDesc;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final allTasksAsync = ref.watch(allTasksProvider);
    final statsAsync = ref.watch(taskStatisticsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppConstants.darkBackground : const Color(0xFFF5F7FA),
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
              ),
        backgroundColor: isDark ? AppConstants.darkSurface : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
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
          // Sort menu
          PopupMenuButton<_SortOrder>(
            icon: const Icon(Icons.sort),
            tooltip: isArabic ? 'ترتيب' : 'Sort',
            onSelected: (order) => setState(() => _sortOrder = order),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _SortOrder.dateDesc,
                child: Row(children: [
                  Icon(Icons.arrow_downward, size: 16,
                      color: _sortOrder == _SortOrder.dateDesc ? AppConstants.primaryColor : null),
                  const SizedBox(width: 8),
                  Text(isArabic ? 'الأحدث أولاً' : 'Newest first'),
                ]),
              ),
              PopupMenuItem(
                value: _SortOrder.dateAsc,
                child: Row(children: [
                  Icon(Icons.arrow_upward, size: 16,
                      color: _sortOrder == _SortOrder.dateAsc ? AppConstants.primaryColor : null),
                  const SizedBox(width: 8),
                  Text(isArabic ? 'الأقدم أولاً' : 'Oldest first'),
                ]),
              ),
              PopupMenuItem(
                value: _SortOrder.priority,
                child: Row(children: [
                  Icon(Icons.flag, size: 16,
                      color: _sortOrder == _SortOrder.priority ? AppConstants.primaryColor : null),
                  const SizedBox(width: 8),
                  Text(isArabic ? 'حسب الأولوية' : 'By priority'),
                ]),
              ),
              PopupMenuItem(
                value: _SortOrder.title,
                child: Row(children: [
                  Icon(Icons.sort_by_alpha, size: 16,
                      color: _sortOrder == _SortOrder.title ? AppConstants.primaryColor : null),
                  const SizedBox(width: 8),
                  Text(isArabic ? 'أبجدياً' : 'Alphabetical'),
                ]),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: GestureDetector(
        onLongPress: () => _navigateToTaskForm(context),
        child: FloatingActionButton.extended(
          onPressed: () => _showQuickAdd(context, isArabic, isDark),
          icon: const Icon(Icons.add),
          label: Text(isArabic ? 'إضافة سريعة' : 'Quick Add'),
          backgroundColor: AppConstants.primaryColor,
        ),
      ),
      body: RefreshIndicator(
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
                loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            // Category Filter Chips
            SliverToBoxAdapter(
              child: _buildCategoryChips(isDark, isArabic),
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
                    child: Text(isArabic ? 'خطأ في تحميل المهام' : 'Error loading tasks'),
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

  // ─── Stats Row ───────────────────────────────────────────────────────────

  Widget _buildStatsRow(TaskStatistics stats, bool isDark, bool isArabic) {
    return Padding(
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
        ],
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
      (TaskCategory.personal, isArabic ? 'شخصي' : 'Personal', Icons.person_outline),
      (TaskCategory.shopping, isArabic ? 'تسوق' : 'Shopping', Icons.shopping_cart_outlined),
      (TaskCategory.health, isArabic ? 'صحة' : 'Health', Icons.favorite_outline),
      (TaskCategory.study, isArabic ? 'دراسة' : 'Study', Icons.school_outlined),
      (TaskCategory.prayer, isArabic ? 'صلاة' : 'Prayer', Icons.mosque_outlined),
      (TaskCategory.other, isArabic ? 'أخرى' : 'Other', Icons.more_horiz),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (category, label, icon) = categories[index];
          final isSelected = _selectedCategory == category;
          return FilterChip(
            avatar: Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppConstants.primaryColor
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => setState(() {
              _selectedCategory = isSelected ? null : category;
            }),
            backgroundColor: isDark ? AppConstants.darkCard : Colors.white,
            selectedColor: AppConstants.primaryColor.withOpacity(0.15),
            checkmarkColor: AppConstants.primaryColor,
            labelStyle: TextStyle(
              fontSize: 12,
              color: isSelected
                  ? AppConstants.primaryColor
                  : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            side: BorderSide(
              color: isSelected
                  ? AppConstants.primaryColor
                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
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
        const order = {TaskPriority.high: 0, TaskPriority.medium: 1, TaskPriority.low: 2};
        sorted.sort((a, b) => (order[a.priority] ?? 1).compareTo(order[b.priority] ?? 1));
      case _SortOrder.title:
        sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return sorted;
  }

  Widget _buildSections(List<Task> allTasks, bool isDark, bool isArabic) {
    // Apply category filter
    var tasks = _selectedCategory == null
        ? allTasks
        : allTasks.where((t) => t.category == _selectedCategory).toList();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      tasks = tasks
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              (t.description?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    // Apply sort
    tasks = _applySort(tasks);

    // Split into sections
    final overdueTasks = tasks
        .where((t) => !t.isCompleted && t.isOverdue)
        .toList()
      ..sort((a, b) => (a.dueDate ?? DateTime(2099))
          .compareTo(b.dueDate ?? DateTime(2099)));

    final todayTasks = tasks
        .where((t) => !t.isCompleted && t.isDueToday && !t.isOverdue)
        .toList()
      ..sort((a, b) => (a.dueDate ?? DateTime(2099))
          .compareTo(b.dueDate ?? DateTime(2099)));

    final upcomingTasks = tasks
        .where((t) => !t.isCompleted && t.isUpcoming)
        .toList()
      ..sort((a, b) => (a.dueDate ?? DateTime(2099))
          .compareTo(b.dueDate ?? DateTime(2099)));

    final otherTasks = tasks
        .where((t) => !t.isCompleted && !t.isDueToday && !t.isUpcoming && !t.isOverdue)
        .toList();

    final completedTasks = tasks.where((t) => t.isCompleted).toList();

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

          // Upcoming Section
          if (upcomingTasks.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.upcoming,
              title: isArabic ? 'قريباً' : 'Upcoming',
              count: upcomingTasks.length,
              color: Colors.orange,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            ...upcomingTasks.map((task) => _buildTaskCard(task)),
            const SizedBox(height: 20),
          ],

          // All Other Tasks Section
          if (otherTasks.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.task_alt,
              title: isArabic ? 'كل المهام' : 'All Tasks',
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
            InkWell(
              onTap: () => setState(() => _showCompleted = !_showCompleted),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              child: _buildSectionHeader(
                icon: _showCompleted
                    ? Icons.expand_less
                    : Icons.expand_more,
                title: isArabic ? 'المكتملة' : 'Completed',
                count: completedTasks.length,
                color: Colors.green,
                isDark: isDark,
              ),
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

  Widget _buildTaskCard(Task task) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TaskCard(
        key: ValueKey(task.id),
        task: task,
        onToggle: () => _toggleTask(task),
        onTap: () => _editTask(task),
        onDelete: () => _deleteTask(task.id, isArabic),
      ),
    );
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
            isArabic
                ? 'جرب كلمة بحث مختلفة'
                : 'Try a different search term',
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
            isArabic ? 'اضغط + لإضافة مهمتك الأولى' : 'Tap + to add your first task',
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

  Future<void> _toggleTask(Task task) async {
    final userId = ref.read(currentUserIdProvider);
    try {
      await TaskService.instance.toggleTaskCompletion(
        userId: userId,
        taskId: task.id,
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
    if (result == true) {
      ref.invalidate(allTasksProvider);
      ref.invalidate(taskStatisticsProvider);
    }
  }

  Future<void> _deleteTask(String taskId, bool isArabic) async {
    final userId = ref.read(currentUserIdProvider);
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
      ref.invalidate(allTasksProvider);
      ref.invalidate(taskStatisticsProvider);
    }
  }

  Future<void> _showQuickAdd(BuildContext context, bool isArabic, bool isDark) async {
    final controller = TextEditingController();
    TaskPriority priority = TaskPriority.medium;
    DateTime? dueDate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
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
                  // Handle bar
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title field
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
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
                    onSubmitted: (_) => _submitQuickAdd(controller, priority, dueDate, ctx, isArabic),
                  ),
                  const SizedBox(height: 12),

                  // Priority + due date row
                  Row(
                    children: [
                      // Priority chips
                      ...[
                        (TaskPriority.high, isArabic ? 'عالية' : 'High', Colors.orange),
                        (TaskPriority.medium, isArabic ? 'متوسطة' : 'Medium', Colors.amber),
                        (TaskPriority.low, isArabic ? 'منخفضة' : 'Low', Colors.green),
                      ].map((entry) {
                        final (p, label, color) = entry;
                        final selected = priority == p;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setModalState(() => priority = p),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: selected ? color.withOpacity(0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected ? color : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                                ),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                  color: selected ? color : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                      const Spacer(),

                      // Due date picker
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setModalState(() => dueDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: dueDate != null
                                ? AppConstants.primaryColor.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: dueDate != null
                                  ? AppConstants.primaryColor
                                  : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 14,
                                  color: dueDate != null
                                      ? AppConstants.primaryColor
                                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                              const SizedBox(width: 4),
                              Text(
                                dueDate != null
                                    ? '${dueDate!.day}/${dueDate!.month}'
                                    : (isArabic ? 'التاريخ' : 'Date'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: dueDate != null
                                      ? AppConstants.primaryColor
                                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Add button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _submitQuickAdd(controller, priority, dueDate, ctx, isArabic),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
        });
      },
    );
    controller.dispose();
  }

  Future<void> _submitQuickAdd(
    TextEditingController controller,
    TaskPriority priority,
    DateTime? dueDate,
    BuildContext sheetContext,
    bool isArabic,
  ) async {
    final title = controller.text.trim();
    if (title.isEmpty) return;

    Navigator.of(sheetContext).pop();

    final userId = ref.read(currentUserIdProvider);
    await TaskService.instance.addTask(
      userId: userId,
      title: title,
      priority: priority,
      dueDate: dueDate,
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
