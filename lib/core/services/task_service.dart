import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import 'notification_service.dart';
import 'desktop_notification_service.dart';
import 'achievement_service.dart';

class TaskService {
  TaskService._();

  static final TaskService _instance = TaskService._();
  static TaskService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, Task> _taskCache = {};
  static const int _pageSize = 20;
  DocumentSnapshot? _lastDocument;
  bool _isInitialized = false;

  // ── Local / guest storage ──────────────────────────────────────────────────
  static const String _localTasksKey = 'guest_tasks';
  final List<Task> _localTasks = [];
  StreamController<List<Task>>? _localTasksController;
  bool _localTasksLoaded = false;

  bool _isGuest(String userId) => userId == 'guest_user';

  String _generateLocalId() => _firestore.collection('_').doc().id;

  Stream<List<Task>> _getLocalStream({
    TaskPriority? priorityFilter,
    TaskCategory? categoryFilter,
    bool? completedFilter,
    int limit = _pageSize,
  }) {
    if (_localTasksController == null || _localTasksController!.isClosed) {
      _localTasksController = StreamController<List<Task>>.broadcast();
    }
    _initLocalTasks();
    return _localTasksController!.stream.map((tasks) {
      var filtered = tasks;
      if (priorityFilter != null) filtered = filtered.where((t) => t.priority == priorityFilter).toList();
      if (categoryFilter != null) filtered = filtered.where((t) => t.category == categoryFilter).toList();
      if (completedFilter != null) filtered = filtered.where((t) => t.isCompleted == completedFilter).toList();
      return filtered.take(limit).toList();
    });
  }

  Future<void> _initLocalTasks() async {
    if (_localTasksLoaded) {
      _localTasksController?.add(List.from(_localTasks));
      return;
    }
    _localTasksLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_localTasksKey);
      if (json != null) {
        final list = jsonDecode(json) as List;
        _localTasks.clear();
        _localTasks.addAll(
          list.map((e) => Task.fromJson(e as Map<String, dynamic>)),
        );
      }
    } catch (e) {
      debugPrint('TaskService: Error loading local tasks - $e');
    }
    _localTasksController?.add(List.from(_localTasks));
  }

  Future<void> _saveLocalTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _localTasksKey,
        jsonEncode(_localTasks.map((t) => t.toJson()).toList()),
      );
      _localTasksController?.add(List.from(_localTasks));
    } catch (e) {
      debugPrint('TaskService: Error saving local tasks - $e');
    }
  }

  Future<int> getLocalTaskCount() async {
    await _initLocalTasks();
    return _localTasks.length;
  }

  /// Migrate all local guest tasks to Firestore after sign-up.
  Future<void> migrateGuestTasksToFirestore(String userId) async {
    await _initLocalTasks();
    if (_localTasks.isEmpty) return;
    debugPrint('TaskService: Migrating ${_localTasks.length} guest tasks → Firestore');
    try {
      final batch = _firestore.batch();
      for (final task in _localTasks) {
        final docRef = _firestore.collection('users').doc(userId).collection('tasks').doc();
        batch.set(docRef, task.copyWith(id: docRef.id).toFirestore());
      }
      await batch.commit();
      _localTasks.clear();
      _localTasksLoaded = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localTasksKey);
      debugPrint('TaskService: Migration complete');
    } catch (e) {
      debugPrint('TaskService: Migration failed - $e');
    }
  }

  // ── Initialisation ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugPrint('TaskService: Initialized');
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  Stream<List<Task>> getTasksStream({
    required String userId,
    TaskPriority? priorityFilter,
    TaskCategory? categoryFilter,
    bool? completedFilter,
    int limit = _pageSize,
  }) {
    if (_isGuest(userId)) {
      return _getLocalStream(
        priorityFilter: priorityFilter,
        categoryFilter: categoryFilter,
        completedFilter: completedFilter,
        limit: limit,
      );
    }

    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (priorityFilter != null) query = query.where('priority', isEqualTo: priorityFilter.value);
    if (categoryFilter != null) query = query.where('category', isEqualTo: categoryFilter.value);
    if (completedFilter != null) query = query.where('isCompleted', isEqualTo: completedFilter);

    return query.snapshots().map((snapshot) {
      final tasks = snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
      for (final task in tasks) {
        _taskCache[task.id] = task;
      }
      return tasks;
    });
  }

  Future<List<Task>> getTasksOnce({required String userId, int limit = _pageSize}) async {
    if (_isGuest(userId)) {
      await _initLocalTasks();
      return List.from(_localTasks.take(limit));
    }
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final tasks = snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
      for (final task in tasks) {
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

  Future<List<Task>> loadMoreTasks({required String userId, int limit = _pageSize}) async {
    if (_isGuest(userId)) return [];
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

      final tasks = snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
      _lastDocument = snapshot.docs.isEmpty ? null : snapshot.docs.last;
      debugPrint('TaskService: Loaded ${tasks.length} more tasks');
      return tasks;
    } catch (e) {
      debugPrint('TaskService: Error loading more tasks - $e');
      return [];
    }
  }

  // ── Add ────────────────────────────────────────────────────────────────────

  Future<Task?> addTask({
    required String userId,
    required String title,
    String? description,
    TaskPriority priority = TaskPriority.medium,
    TaskCategory category = TaskCategory.other,
    DateTime? dueDate,
    List<String>? tags,
    bool hasDueTime = false,
    RecurrenceType recurrenceType = RecurrenceType.none,
    int recurrenceInterval = 1,
    DateTime? recurrenceEndDate,
    String? parentTaskId,
    List<SubTask> subtasks = const [],
    bool focusMode = false,
    int focusDurationMinutes = 25,
    int estimatedMinutes = 0,
  }) async {
    if (_isGuest(userId)) {
      await _initLocalTasks();
      final task = Task(
        id: _generateLocalId(),
        title: title,
        description: description,
        priority: priority,
        category: category,
        dueDate: dueDate,
        createdAt: DateTime.now(),
        tags: tags,
        hasDueTime: hasDueTime,
        recurrenceType: recurrenceType,
        recurrenceInterval: recurrenceInterval,
        recurrenceEndDate: recurrenceEndDate,
        parentTaskId: parentTaskId,
        subtasks: subtasks,
        focusMode: focusMode,
        focusDurationMinutes: focusDurationMinutes,
        estimatedMinutes: estimatedMinutes,
      );
      _localTasks.insert(0, task);
      await _saveLocalTasks();
      await _scheduleReminder(task);
      debugPrint('TaskService: Added local task ${task.id}');
      _refreshDailySummary(userId);
      return task;
    }

    try {
      final docRef = _firestore.collection('users').doc(userId).collection('tasks').doc();
      final task = Task(
        id: docRef.id,
        title: title,
        description: description,
        priority: priority,
        category: category,
        dueDate: dueDate,
        createdAt: DateTime.now(),
        tags: tags,
        hasDueTime: hasDueTime,
        recurrenceType: recurrenceType,
        recurrenceInterval: recurrenceInterval,
        recurrenceEndDate: recurrenceEndDate,
        parentTaskId: parentTaskId,
        subtasks: subtasks,
        focusMode: focusMode,
        focusDurationMinutes: focusDurationMinutes,
        estimatedMinutes: estimatedMinutes,
      );
      await docRef.set(task.toFirestore());
      _taskCache[task.id] = task;
      await _scheduleReminder(task);
      debugPrint('TaskService: Added task ${task.id}');
      _refreshDailySummary(userId);
      return task;
    } catch (e) {
      debugPrint('TaskService: Error adding task - $e');
      return null;
    }
  }

  // ── Update ─────────────────────────────────────────────────────────────────

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
    bool? hasDueTime,
    RecurrenceType? recurrenceType,
    int? recurrenceInterval,
    DateTime? recurrenceEndDate,
    List<SubTask>? subtasks,
    bool? isPinned,
    bool? focusMode,
    int? focusDurationMinutes,
    int? estimatedMinutes,
  }) async {
    if (_isGuest(userId)) {
      await _initLocalTasks();
      final idx = _localTasks.indexWhere((t) => t.id == taskId);
      if (idx == -1) return false;
      final current = _localTasks[idx];
      final updated = current.copyWith(
        title: title,
        description: description,
        isCompleted: isCompleted,
        priority: priority,
        category: category,
        dueDate: dueDate,
        tags: tags,
        hasDueTime: hasDueTime,
        completedAt: isCompleted == true && !current.isCompleted ? DateTime.now() : null,
        recurrenceType: recurrenceType,
        recurrenceInterval: recurrenceInterval,
        recurrenceEndDate: recurrenceEndDate,
        subtasks: subtasks,
        isPinned: isPinned,
        focusMode: focusMode,
        focusDurationMinutes: focusDurationMinutes,
        estimatedMinutes: estimatedMinutes,
      );
      _localTasks[idx] = updated;
      await _saveLocalTasks();
      if (updated.isCompleted) {
        _cancelReminder(taskId);
      } else if (updated.dueDate != null) {
        await _scheduleReminder(updated);
      }
      debugPrint('TaskService: Updated local task $taskId');
      _refreshDailySummary(userId);
      return true;
    }

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

      final updatedTask = currentTask.copyWith(
        title: title,
        description: description,
        isCompleted: isCompleted,
        priority: priority,
        category: category,
        dueDate: dueDate,
        tags: tags,
        hasDueTime: hasDueTime,
        completedAt: isCompleted == true && !currentTask.isCompleted ? DateTime.now() : null,
        recurrenceType: recurrenceType,
        recurrenceInterval: recurrenceInterval,
        recurrenceEndDate: recurrenceEndDate,
        subtasks: subtasks,
        isPinned: isPinned,
        focusMode: focusMode,
        focusDurationMinutes: focusDurationMinutes,
        estimatedMinutes: estimatedMinutes,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(taskId)
          .update(updatedTask.toFirestore());
      _taskCache[taskId] = updatedTask;

      if (updatedTask.isCompleted) {
        _cancelReminder(taskId);
      } else if (updatedTask.dueDate != null) {
        await _scheduleReminder(updatedTask);
      }

      debugPrint('TaskService: Updated task $taskId');
      _refreshDailySummary(userId);
      return true;
    } catch (e) {
      debugPrint('TaskService: Error updating task - $e');
      return false;
    }
  }

  // ── Toggle completion ──────────────────────────────────────────────────────

  Future<bool> toggleTaskCompletion({required String userId, required String taskId}) async {
    try {
      Task? currentTask;

      if (_isGuest(userId)) {
        await _initLocalTasks();
        currentTask = _localTasks.firstWhere((t) => t.id == taskId, orElse: () => throw StateError('not found'));
      } else {
        currentTask = _taskCache[taskId];
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
      }

      final newStatus = !currentTask.isCompleted;

      if (currentTask.isRecurring) {
        if (newStatus) {
          await _completeRecurringTask(userId: userId, task: currentTask);
          return true;
        } else {
          await _deleteChildTasks(userId: userId, parentTaskId: currentTask.id);
          if (currentTask.parentTaskId != null) {
            await _deleteChildTasks(userId: userId, parentTaskId: currentTask.parentTaskId!);
          }
        }
      }

      final result = await updateTask(userId: userId, taskId: taskId, isCompleted: newStatus);
      if (result && newStatus) {
        AchievementService.instance.checkAndAward(userId: userId);
      }
      return result;
    } catch (e) {
      debugPrint('TaskService: Error toggling task - $e');
      return false;
    }
  }

  Future<void> _deleteChildTasks({required String userId, required String parentTaskId}) async {
    if (_isGuest(userId)) {
      _localTasks.removeWhere((t) => t.parentTaskId == parentTaskId && !t.isCompleted);
      await _saveLocalTasks();
      return;
    }
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .where('parentTaskId', isEqualTo: parentTaskId)
          .where('isCompleted', isEqualTo: false)
          .get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
        _taskCache.remove(doc.id);
      }
    } catch (e) {
      debugPrint('TaskService: Error deleting child tasks - $e');
    }
  }

  Future<void> _completeRecurringTask({required String userId, required Task task}) async {
    await updateTask(userId: userId, taskId: task.id, isCompleted: true);
    final nextDate = task.nextRecurrenceDate;
    if (nextDate == null) return;
    if (task.recurrenceEndDate != null && nextDate.isAfter(task.recurrenceEndDate!)) return;

    if (!_isGuest(userId)) {
      final existingChildren = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .where('parentTaskId', isEqualTo: task.id)
          .where('isCompleted', isEqualTo: false)
          .limit(1)
          .get();
      if (existingChildren.docs.isNotEmpty) return;
    }

    await addTask(
      userId: userId,
      title: task.title,
      description: task.description,
      priority: task.priority,
      category: task.category,
      dueDate: nextDate,
      tags: task.tags,
      hasDueTime: task.hasDueTime,
      recurrenceType: task.recurrenceType,
      recurrenceInterval: task.recurrenceInterval,
      recurrenceEndDate: task.recurrenceEndDate,
      parentTaskId: task.id,
    );
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<bool> deleteTask({required String userId, required String taskId}) async {
    if (_isGuest(userId)) {
      await _initLocalTasks();
      _localTasks.removeWhere((t) => t.id == taskId);
      await _saveLocalTasks();
      _cancelReminder(taskId);
      debugPrint('TaskService: Deleted local task $taskId');
      _refreshDailySummary(userId);
      return true;
    }

    try {
      await _firestore.collection('users').doc(userId).collection('tasks').doc(taskId).delete();
      _taskCache.remove(taskId);
      _cancelReminder(taskId);
      debugPrint('TaskService: Deleted task $taskId');
      _refreshDailySummary(userId);
      return true;
    } catch (e) {
      debugPrint('TaskService: Error deleting task - $e');
      return false;
    }
  }

  // ── Ordering ───────────────────────────────────────────────────────────────

  Future<void> updateTaskOrders({required String userId, required List<Task> tasks}) async {
    if (_isGuest(userId)) {
      await _initLocalTasks();
      for (int i = 0; i < tasks.length; i++) {
        final idx = _localTasks.indexWhere((t) => t.id == tasks[i].id);
        if (idx != -1) _localTasks[idx] = _localTasks[idx].copyWith(manualOrder: i);
      }
      await _saveLocalTasks();
      return;
    }

    try {
      final batch = _firestore.batch();
      for (int i = 0; i < tasks.length; i++) {
        final ref = _firestore
            .collection('users')
            .doc(userId)
            .collection('tasks')
            .doc(tasks[i].id);
        batch.update(ref, {'manualOrder': i});
        _taskCache[tasks[i].id] = tasks[i].copyWith(manualOrder: i);
      }
      await batch.commit();
      debugPrint('TaskService: Updated order for ${tasks.length} tasks');
    } catch (e) {
      debugPrint('TaskService: Error updating task orders - $e');
    }
  }

  // ── Statistics ─────────────────────────────────────────────────────────────

  Future<TaskStatistics> getStatistics({required String userId}) async {
    if (_isGuest(userId)) {
      await _initLocalTasks();
      final tasks = _localTasks;
      final total = tasks.length;
      final completed = tasks.where((t) => t.isCompleted).length;
      final overdue = tasks.where((t) => t.isOverdue).length;
      final dueToday = tasks.where((t) => t.isDueToday && !t.isCompleted).length;
      return TaskStatistics(
        total: total,
        completed: completed,
        pending: total - completed,
        overdue: overdue,
        dueToday: dueToday,
        completionRate: total > 0 ? (completed / total * 100).round() : 0,
      );
    }

    try {
      final tasks = await getTasksOnce(userId: userId, limit: 100);
      final total = tasks.length;
      final completed = tasks.where((t) => t.isCompleted).length;
      return TaskStatistics(
        total: total,
        completed: completed,
        pending: total - completed,
        overdue: tasks.where((t) => t.isOverdue).length,
        dueToday: tasks.where((t) => t.isDueToday && !t.isCompleted).length,
        completionRate: total > 0 ? (completed / total * 100).round() : 0,
      );
    } catch (e) {
      debugPrint('TaskService: Error getting statistics - $e');
      return TaskStatistics.empty();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _scheduleReminder(Task task) async {
    if (task.dueDate == null) return;
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString('language') ?? 'en';
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      await DesktopNotificationService.instance.scheduleTaskReminder(
        taskId: task.id,
        title: task.title,
        dueDate: task.dueDate!,
        hasDueTime: task.hasDueTime,
        language: language,
      );
    } else {
      await NotificationService.instance.scheduleTaskReminder(
        taskId: task.id,
        title: task.title,
        dueDate: task.dueDate!,
        hasDueTime: task.hasDueTime,
        language: language,
      );
    }
  }

  void _cancelReminder(String taskId) {
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      DesktopNotificationService.instance.cancelTaskReminder(taskId);
    } else {
      NotificationService.instance.cancelTaskNotification(taskId);
    }
  }

  Future<void> _refreshDailySummary(String userId) async {
    try {
      final stats = await getStatistics(userId: userId);
      final prefs = await SharedPreferences.getInstance();
      final language = prefs.getString('language') ?? 'en';
      await NotificationService.instance.scheduleDailyTaskSummary(
        todayCount: stats.dueToday,
        overdueCount: stats.overdue,
        language: language,
      );
    } catch (e) {
      debugPrint('TaskService: Error refreshing daily summary - $e');
    }
  }

  void clearCache() {
    _taskCache.clear();
    _lastDocument = null;
  }

  void dispose() {
    clearCache();
    _localTasksController?.close();
    _localTasksController = null;
    _isInitialized = false;
  }
}

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

  factory TaskStatistics.empty() => const TaskStatistics(
        total: 0,
        completed: 0,
        pending: 0,
        overdue: 0,
        dueToday: 0,
        completionRate: 0,
      );
}
