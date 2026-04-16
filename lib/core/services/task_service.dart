import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import 'notification_service.dart';

/// Service for managing tasks with Firestore
/// Optimized for performance with pagination and caching
class TaskService {
  TaskService._();

  static final TaskService _instance = TaskService._();
  static TaskService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache for performance
  final Map<String, Task> _taskCache = {};
  List<Task>? _cachedTaskList;

  // Pagination settings
  static const int _pageSize = 20;
  DocumentSnapshot? _lastDocument;

  bool _isInitialized = false;

  /// Initialize the task service
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugPrint('TaskService: Initialized');
  }

  /// Get tasks stream for real-time updates (paginated)
  Stream<List<Task>> getTasksStream({
    required String userId,
    TaskPriority? priorityFilter,
    TaskCategory? categoryFilter,
    bool? completedFilter,
    int limit = _pageSize,
  }) {
    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    // Apply filters
    if (priorityFilter != null) {
      query = query.where('priority', isEqualTo: priorityFilter.value);
    }
    if (categoryFilter != null) {
      query = query.where('category', isEqualTo: categoryFilter.value);
    }
    if (completedFilter != null) {
      query = query.where('isCompleted', isEqualTo: completedFilter);
    }

    return query.snapshots().map((snapshot) {
      final tasks = snapshot.docs
          .map((doc) => Task.fromFirestore(doc))
          .toList();

      // Update cache
      _cachedTaskList = tasks;
      for (var task in tasks) {
        _taskCache[task.id] = task;
      }

      return tasks;
    });
  }

  /// Get tasks once (for initial load or refresh)
  Future<List<Task>> getTasksOnce({
    required String userId,
    int limit = _pageSize,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final tasks = snapshot.docs
          .map((doc) => Task.fromFirestore(doc))
          .toList();

      // Update cache
      _cachedTaskList = tasks;
      for (var task in tasks) {
        _taskCache[task.id] = task;
      }

      _lastDocument = snapshot.docs.isEmpty ? null : snapshot.docs.last;

      debugPrint('TaskService: Loaded ${tasks.length} tasks');
      return tasks;
    } catch (e) {
      debugPrint('TaskService: Error loading tasks - $e');
      return [];
    }
  }

  /// Load more tasks (pagination)
  Future<List<Task>> loadMoreTasks({
    required String userId,
    int limit = _pageSize,
  }) async {
    if (_lastDocument == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(limit)
          .get();

      final tasks = snapshot.docs
          .map((doc) => Task.fromFirestore(doc))
          .toList();

      _lastDocument = snapshot.docs.isEmpty ? null : snapshot.docs.last;

      debugPrint('TaskService: Loaded ${tasks.length} more tasks');
      return tasks;
    } catch (e) {
      debugPrint('TaskService: Error loading more tasks - $e');
      return [];
    }
  }

  /// Add a new task
  Future<Task?> addTask({
    required String userId,
    required String title,
    String? description,
    TaskPriority priority = TaskPriority.medium,
    TaskCategory category = TaskCategory.other,
    DateTime? dueDate,
    List<String>? tags,
    RecurrenceType recurrenceType = RecurrenceType.none,
    int recurrenceInterval = 1,
    DateTime? recurrenceEndDate,
    String? parentTaskId,
  }) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc();

      final task = Task(
        id: docRef.id,
        title: title,
        description: description,
        priority: priority,
        category: category,
        dueDate: dueDate,
        createdAt: DateTime.now(),
        tags: tags,
        recurrenceType: recurrenceType,
        recurrenceInterval: recurrenceInterval,
        recurrenceEndDate: recurrenceEndDate,
        parentTaskId: parentTaskId,
      );

      await docRef.set(task.toFirestore());

      // Update cache
      _taskCache[task.id] = task;

      // Schedule reminder notification if task has a due date
      if (task.dueDate != null) {
        final prefs = await SharedPreferences.getInstance();
        final language = prefs.getString('language') ?? 'en';
        await NotificationService.instance.scheduleTaskReminder(
          taskId: task.id,
          title: task.title,
          dueDate: task.dueDate!,
          language: language,
        );
      }

      debugPrint('TaskService: Added task ${task.id}');
      return task;
    } catch (e) {
      debugPrint('TaskService: Error adding task - $e');
      return null;
    }
  }

  /// Update an existing task
  Future<bool> updateTask({
    required String userId,
    required String taskId,
    String? title,
    String? description,
    bool? isCompleted,
    TaskPriority? priority,
    TaskCategory? category,
    DateTime? dueDate,
    List<String>? tags,
    RecurrenceType? recurrenceType,
    int? recurrenceInterval,
    DateTime? recurrenceEndDate,
  }) async {
    try {
      // Get current task from cache or Firestore
      Task? currentTask = _taskCache[taskId];
      if (currentTask == null) {
        final doc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(taskId)
            .get();

        if (!doc.exists) {
          debugPrint('TaskService: Task not found');
          return false;
        }

        currentTask = Task.fromFirestore(doc);
      }

      // Create updated task
      final updatedTask = currentTask.copyWith(
        title: title,
        description: description,
        isCompleted: isCompleted,
        priority: priority,
        category: category,
        dueDate: dueDate,
        tags: tags,
        completedAt: isCompleted == true && !currentTask.isCompleted
            ? DateTime.now()
            : null,
        recurrenceType: recurrenceType,
        recurrenceInterval: recurrenceInterval,
        recurrenceEndDate: recurrenceEndDate,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(taskId)
          .update(updatedTask.toFirestore());

      // Update cache
      _taskCache[taskId] = updatedTask;

      // Handle notification: cancel if completed, reschedule if due date changed
      if (updatedTask.isCompleted) {
        await NotificationService.instance.cancelTaskNotification(taskId);
      } else if (updatedTask.dueDate != null) {
        final prefs = await SharedPreferences.getInstance();
        final language = prefs.getString('language') ?? 'en';
        await NotificationService.instance.scheduleTaskReminder(
          taskId: taskId,
          title: updatedTask.title,
          dueDate: updatedTask.dueDate!,
          language: language,
        );
      }

      debugPrint('TaskService: Updated task $taskId');
      return true;
    } catch (e) {
      debugPrint('TaskService: Error updating task - $e');
      return false;
    }
  }

  /// Toggle task completion status
  /// For recurring tasks: marks complete and auto-creates next occurrence
  Future<bool> toggleTaskCompletion({
    required String userId,
    required String taskId,
  }) async {
    try {
      Task? currentTask = _taskCache[taskId];
      if (currentTask == null) {
        final doc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(taskId)
            .get();

        if (!doc.exists) return false;

        currentTask = Task.fromFirestore(doc);
      }

      final newStatus = !currentTask.isCompleted;

      // For recurring tasks being completed, create next occurrence
      if (newStatus && currentTask.isRecurring) {
        await _completeRecurringTask(userId: userId, task: currentTask);
        return true;
      }

      return await updateTask(
        userId: userId,
        taskId: taskId,
        isCompleted: newStatus,
      );
    } catch (e) {
      debugPrint('TaskService: Error toggling task - $e');
      return false;
    }
  }

  /// Complete a recurring task and create the next occurrence
  Future<void> _completeRecurringTask({
    required String userId,
    required Task task,
  }) async {
    // 1. Mark current task as completed
    await updateTask(
      userId: userId,
      taskId: task.id,
      isCompleted: true,
    );

    // 2. Calculate next due date
    final nextDate = task.nextRecurrenceDate;
    if (nextDate == null) return;

    // 3. Check if recurrence end date has passed
    if (task.recurrenceEndDate != null &&
        nextDate.isAfter(task.recurrenceEndDate!)) {
      debugPrint('TaskService: Recurrence series ended for ${task.id}');
      return;
    }

    // 4. Create next task instance
    await addTask(
      userId: userId,
      title: task.title,
      description: task.description,
      priority: task.priority,
      category: task.category,
      dueDate: nextDate,
      tags: task.tags,
      recurrenceType: task.recurrenceType,
      recurrenceInterval: task.recurrenceInterval,
      recurrenceEndDate: task.recurrenceEndDate,
      parentTaskId: task.parentTaskId ?? task.id,
    );

    debugPrint('TaskService: Created next recurrence for task ${task.id}');
  }

  /// Delete a task
  Future<bool> deleteTask({
    required String userId,
    required String taskId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(taskId)
          .delete();

      // Remove from cache
      _taskCache.remove(taskId);

      // Cancel any scheduled reminder
      await NotificationService.instance.cancelTaskNotification(taskId);

      debugPrint('TaskService: Deleted task $taskId');
      return true;
    } catch (e) {
      debugPrint('TaskService: Error deleting task - $e');
      return false;
    }
  }

  /// Get task statistics (optimized with single query)
  Future<TaskStatistics> getStatistics({required String userId}) async {
    try {
      // Use aggregation query for better performance
      final tasks = await getTasksOnce(userId: userId, limit: 100);

      final total = tasks.length;
      final completed = tasks.where((t) => t.isCompleted).length;
      final pending = total - completed;
      final overdue = tasks.where((t) => t.isOverdue).length;
      final dueToday = tasks.where((t) => t.isDueToday && !t.isCompleted).length;

      return TaskStatistics(
        total: total,
        completed: completed,
        pending: pending,
        overdue: overdue,
        dueToday: dueToday,
        completionRate: total > 0 ? (completed / total * 100).round() : 0,
      );
    } catch (e) {
      debugPrint('TaskService: Error getting statistics - $e');
      return TaskStatistics.empty();
    }
  }

  /// Clear cache
  void clearCache() {
    _taskCache.clear();
    _cachedTaskList = null;
    _lastDocument = null;
  }

  /// Dispose of resources
  void dispose() {
    clearCache();
    _isInitialized = false;
  }
}

/// Task statistics model
class TaskStatistics {
  final int total;
  final int completed;
  final int pending;
  final int overdue;
  final int dueToday;
  final int completionRate;

  const TaskStatistics({
    required this.total,
    required this.completed,
    required this.pending,
    required this.overdue,
    required this.dueToday,
    required this.completionRate,
  });

  factory TaskStatistics.empty() {
    return const TaskStatistics(
      total: 0,
      completed: 0,
      pending: 0,
      overdue: 0,
      dueToday: 0,
      completionRate: 0,
    );
  }
}
