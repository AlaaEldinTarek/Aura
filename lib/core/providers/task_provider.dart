import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import 'auth_provider.dart';

/// Task Service provider
final taskServiceProvider = Provider<TaskService>((ref) {
  final service = TaskService.instance;
  ref.onDispose(() => service.dispose());
  return service;
});

/// Current user ID provider - gets user ID from auth system
/// Falls back to 'guest_user' for guest mode
final currentUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  // Use actual user UID if logged in, otherwise use guest ID
  return user?.uid ?? 'guest_user';
});

/// Tasks list provider with real-time updates
/// Uses autoDispose to free memory when not in use
final tasksProvider = StreamProvider.family<List<Task>, TaskFilterParams>(
  (ref, params) {
    final service = ref.watch(taskServiceProvider);
    final userId = ref.watch(currentUserIdProvider);

    return service.getTasksStream(
      userId: userId,
      priorityFilter: params.priorityFilter,
      categoryFilter: params.categoryFilter,
      completedFilter: params.completedFilter,
      limit: params.limit,
    );
  },
  name: 'tasksProvider',
);

/// All tasks provider — used by TasksScreen to split into sections
/// Fetches all tasks without filters for client-side section splitting
final allTasksProvider = StreamProvider.autoDispose<List<Task>>((ref) {
  final service = ref.watch(taskServiceProvider);
  final userId = ref.watch(currentUserIdProvider);
  return service.getTasksStream(userId: userId, limit: 200);
});

/// Task statistics provider
final taskStatisticsProvider = FutureProvider.autoDispose<TaskStatistics>((ref) async {
  final service = ref.watch(taskServiceProvider);
  final userId = ref.watch(currentUserIdProvider);
  return service.getStatistics(userId: userId);
});

/// Filtered tasks provider - for specific views
final todayTasksProvider = Provider.autoDispose<AsyncValue<List<Task>>>((ref) {
  final filterParams = TaskFilterParams(
    completedFilter: false,
    limit: 50,
  );

  final tasksAsync = ref.watch(tasksProvider(filterParams));

  return tasksAsync.when(
    data: (tasks) {
      final todayTasks = tasks.where((t) => t.isDueToday).toList();
      return AsyncValue.data(todayTasks);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Upcoming tasks provider (due within 7 days)
final upcomingTasksProvider = Provider.autoDispose<AsyncValue<List<Task>>>((ref) {
  final filterParams = TaskFilterParams(
    completedFilter: false,
    limit: 50,
  );

  final tasksAsync = ref.watch(tasksProvider(filterParams));

  return tasksAsync.when(
    data: (tasks) {
      final now = DateTime.now();
      final weekLater = now.add(const Duration(days: 7));

      final upcoming = tasks.where((t) {
        if (t.dueDate == null) return false;
        return t.dueDate!.isAfter(now) && t.dueDate!.isBefore(weekLater);
      }).toList();

      // Sort by due date
      upcoming.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

      return AsyncValue.data(upcoming);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// High priority tasks provider
final highPriorityTasksProvider = Provider.autoDispose<AsyncValue<List<Task>>>((ref) {
  final filterParams = TaskFilterParams(
    priorityFilter: TaskPriority.high,
    completedFilter: false,
    limit: 20,
  );

  return ref.watch(tasksProvider(filterParams));
});

/// Parameters for filtering tasks
class TaskFilterParams {
  final TaskPriority? priorityFilter;
  final TaskCategory? categoryFilter;
  final bool? completedFilter;
  final int limit;

  const TaskFilterParams({
    this.priorityFilter,
    this.categoryFilter,
    this.completedFilter,
    this.limit = 20,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskFilterParams &&
          runtimeType == other.runtimeType &&
          priorityFilter == other.priorityFilter &&
          categoryFilter == other.categoryFilter &&
          completedFilter == other.completedFilter &&
          limit == other.limit;

  @override
  int get hashCode =>
      priorityFilter.hashCode ^
      categoryFilter.hashCode ^
      completedFilter.hashCode ^
      limit.hashCode;
}
