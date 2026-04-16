import 'package:cloud_firestore/cloud_firestore.dart';

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
  // Recurrence fields
  final RecurrenceType recurrenceType;
  final int recurrenceInterval;
  final DateTime? recurrenceEndDate;
  final String? parentTaskId;

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
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceInterval = 1,
    this.recurrenceEndDate,
    this.parentTaskId,
  });

  bool get isRecurring => recurrenceType != RecurrenceType.none;

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
      recurrenceType: RecurrenceType.fromString(
          data['recurrenceType'] as String? ?? 'none'),
      recurrenceInterval: data['recurrenceInterval'] as int? ?? 1,
      recurrenceEndDate: data['recurrenceEndDate'] != null
          ? DateTime.parse(data['recurrenceEndDate'] as String)
          : null,
      parentTaskId: data['parentTaskId'] as String?,
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
      'recurrenceType': recurrenceType.value,
      'recurrenceInterval': recurrenceInterval,
      'recurrenceEndDate': recurrenceEndDate?.toIso8601String(),
      'parentTaskId': parentTaskId,
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
    RecurrenceType? recurrenceType,
    int? recurrenceInterval,
    DateTime? recurrenceEndDate,
    String? parentTaskId,
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
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceEndDate: clearRecurrenceEndDate
          ? null
          : (recurrenceEndDate ?? this.recurrenceEndDate),
      parentTaskId: clearParentTaskId
          ? null
          : (parentTaskId ?? this.parentTaskId),
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

  /// Check if task is due within next 7 days (but not today)
  bool get isUpcoming {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final weekLater = today.add(const Duration(days: 7));
    return dueDay.isAfter(today) && dueDay.isBefore(weekLater);
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
