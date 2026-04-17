import 'package:cloud_firestore/cloud_firestore.dart';

/// Subtask item within a task
class SubTask {
  final String id;
  final String title;
  final bool isCompleted;

  const SubTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
      };

  factory SubTask.fromMap(Map<String, dynamic> map) => SubTask(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        isCompleted: map['isCompleted'] as bool? ?? false,
      );

  SubTask copyWith({String? title, bool? isCompleted}) => SubTask(
        id: id,
        title: title ?? this.title,
        isCompleted: isCompleted ?? this.isCompleted,
      );
}

/// Task model for task management feature
class Task {
  final String id;
  final String title;
  final String? description;
  final bool isCompleted;
  final TaskPriority priority;
  final TaskCategory category;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<String>? tags;
  final bool hasDueTime;
  // Recurrence fields
  final RecurrenceType recurrenceType;
  final int recurrenceInterval;
  final DateTime? recurrenceEndDate;
  final String? parentTaskId;
  final List<SubTask> subtasks;
  final bool isPinned;
  final bool focusMode;
  final int focusDurationMinutes;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    this.priority = TaskPriority.medium,
    this.category = TaskCategory.other,
    this.dueDate,
    required this.createdAt,
    this.completedAt,
    this.tags,
    this.hasDueTime = false,
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceInterval = 1,
    this.recurrenceEndDate,
    this.parentTaskId,
    this.subtasks = const [],
    this.isPinned = false,
    this.focusMode = false,
    this.focusDurationMinutes = 25,
  });

  bool get isRecurring => recurrenceType != RecurrenceType.none;

  /// Subtask progress (0.0 to 1.0)
  double get subtaskProgress {
    if (subtasks.isEmpty) return 0;
    return subtasks.where((s) => s.isCompleted).length / subtasks.length;
  }

  /// Number of completed subtasks
  int get completedSubtasks => subtasks.where((s) => s.isCompleted).length;

  /// Create Task from Firestore document
  factory Task.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      isCompleted: data['isCompleted'] as bool? ?? false,
      priority: TaskPriority.fromString(data['priority'] as String? ?? 'medium'),
      category: TaskCategory.fromString(data['category'] as String? ?? 'other'),
      dueDate: data['dueDate'] != null
          ? DateTime.parse(data['dueDate'] as String)
          : null,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'] as String)
          : DateTime.now(),
      completedAt: data['completedAt'] != null
          ? DateTime.parse(data['completedAt'] as String)
          : null,
      tags: data['tags'] != null
          ? List<String>.from(data['tags'] as List)
          : null,
      hasDueTime: data['hasDueTime'] as bool? ?? false,
      recurrenceType: RecurrenceType.fromString(
          data['recurrenceType'] as String? ?? 'none'),
      recurrenceInterval: data['recurrenceInterval'] as int? ?? 1,
      recurrenceEndDate: data['recurrenceEndDate'] != null
          ? DateTime.parse(data['recurrenceEndDate'] as String)
          : null,
      parentTaskId: data['parentTaskId'] as String?,
      subtasks: data['subtasks'] != null
          ? (data['subtasks'] as List)
              .map((e) => SubTask.fromMap(e as Map<String, dynamic>))
              .toList()
          : [],
      isPinned: data['isPinned'] as bool? ?? false,
      focusMode: data['focusMode'] as bool? ?? false,
      focusDurationMinutes: data['focusDurationMinutes'] as int? ?? 25,
    );
  }

  /// Convert Task to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'priority': priority.value,
      'category': category.value,
      'dueDate': dueDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'tags': tags,
      'hasDueTime': hasDueTime,
      'recurrenceType': recurrenceType.value,
      'recurrenceInterval': recurrenceInterval,
      'recurrenceEndDate': recurrenceEndDate?.toIso8601String(),
      'parentTaskId': parentTaskId,
      'subtasks': subtasks.map((s) => s.toMap()).toList(),
      'isPinned': isPinned,
      'focusMode': focusMode,
      'focusDurationMinutes': focusDurationMinutes,
    };
  }

  /// Create a copy with updated fields
  Task copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    TaskPriority? priority,
    TaskCategory? category,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? completedAt,
    List<String>? tags,
    bool? hasDueTime,
    RecurrenceType? recurrenceType,
    int? recurrenceInterval,
    DateTime? recurrenceEndDate,
    String? parentTaskId,
    List<SubTask>? subtasks,
    bool? isPinned,
    bool? focusMode,
    int? focusDurationMinutes,
    bool clearDueDate = false,
    bool clearCompletedAt = false,
    bool clearRecurrenceEndDate = false,
    bool clearParentTaskId = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      tags: tags ?? this.tags,
      hasDueTime: hasDueTime ?? this.hasDueTime,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceEndDate: clearRecurrenceEndDate
          ? null
          : (recurrenceEndDate ?? this.recurrenceEndDate),
      parentTaskId: clearParentTaskId
          ? null
          : (parentTaskId ?? this.parentTaskId),
      subtasks: subtasks ?? this.subtasks,
      isPinned: isPinned ?? this.isPinned,
      focusMode: focusMode ?? this.focusMode,
      focusDurationMinutes: focusDurationMinutes ?? this.focusDurationMinutes,
    );
  }

  /// Check if task is overdue
  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// Check if task is due today
  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return dueDay == today;
  }

  /// Check if task is due tomorrow (but not today)
  bool get isUpcoming {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final tomorrow = today.add(const Duration(days: 1));
    return dueDay == tomorrow;
  }

  /// Calculate the next due date for a recurring task
  DateTime? get nextRecurrenceDate {
    if (!isRecurring || dueDate == null) return null;
    switch (recurrenceType) {
      case RecurrenceType.daily:
        return dueDate!.add(Duration(days: recurrenceInterval));
      case RecurrenceType.weekly:
        return dueDate!.add(Duration(days: 7 * recurrenceInterval));
      case RecurrenceType.monthly:
        return DateTime(
          dueDate!.year,
          dueDate!.month + recurrenceInterval,
          dueDate!.day,
          dueDate!.hour,
          dueDate!.minute,
        );
      case RecurrenceType.none:
        return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Task && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Task priority levels
enum TaskPriority {
  low('low', 1),
  medium('medium', 2),
  high('high', 3);

  final String value;
  final int level;

  const TaskPriority(this.value, this.level);

  static TaskPriority fromString(String value) {
    return TaskPriority.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TaskPriority.medium,
    );
  }
}

/// Task categories
enum TaskCategory {
  work('work'),
  personal('personal'),
  shopping('shopping'),
  health('health'),
  study('study'),
  prayer('prayer'),
  other('other');

  final String value;

  const TaskCategory(this.value);

  static TaskCategory fromString(String value) {
    return TaskCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TaskCategory.other,
    );
  }
}

/// Recurrence type for tasks
enum RecurrenceType {
  none('none'),
  daily('daily'),
  weekly('weekly'),
  monthly('monthly');

  final String value;

  const RecurrenceType(this.value);

  static RecurrenceType fromString(String value) {
    return RecurrenceType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RecurrenceType.none,
    );
  }
}
