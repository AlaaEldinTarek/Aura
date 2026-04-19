import 'package:flutter/material.dart';
import '../models/task.dart';
import '../constants/app_constants.dart';

/// Task card with top-row actions, bottom action bar, and swipe gestures
class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onLongPress;
  final VoidCallback? onMenuTap;
  final VoidCallback? onPostpone;
  final VoidCallback? onExpand;
  final bool isExpanded;
  final bool isSelected;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onToggle,
    this.onDelete,
    this.onLongPress,
    this.onMenuTap,
    this.onPostpone,
    this.onExpand,
    this.isExpanded = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isOverdue = task.isOverdue && !task.isCompleted;

    // Left accent color
    final Color leftAccent;
    if (task.isCompleted) {
      leftAccent = Colors.transparent;
    } else if (isOverdue) {
      leftAccent = Colors.red;
    } else if (isSelected) {
      leftAccent = AppConstants.primaryColor;
    } else {
      switch (task.priority) {
        case TaskPriority.high:
          leftAccent = Colors.orange;
        case TaskPriority.medium:
          leftAccent = Colors.amber;
        case TaskPriority.low:
          leftAccent = Colors.green;
      }
    }
    final showAccent = !task.isCompleted;
    final pinColor = isDark ? Colors.amber.shade300 : Colors.amber.shade700;

    // Determine if bottom bar is needed
    final showBottomBar = onToggle != null ||
        onDelete != null ||
        onPostpone != null ||
        onExpand != null;

    final card = Container(
      decoration: BoxDecoration(
        color: isOverdue
            ? (isDark
                ? Colors.red.withOpacity(0.07)
                : Colors.red.withOpacity(0.04))
            : (isDark ? AppConstants.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: isSelected
            ? Border.all(color: AppConstants.primaryColor, width: 2)
            : Border.all(
                color:
                    isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
              ),
        boxShadow: [
          BoxShadow(
            color: isOverdue
                ? Colors.red.withOpacity(0.1)
                : Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Main content
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.paddingMedium,
                  AppConstants.paddingMedium,
                  AppConstants.paddingMedium,
                  6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === TOP ROW: trash | title | menu ===
                    Row(
                      children: [
                        // Title
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: task.isCompleted
                                        ? (isDark
                                            ? Colors.grey.shade600
                                            : Colors.grey.shade400)
                                        : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (task.isPinned && !task.isCompleted)
                                Padding(
                                  padding: EdgeInsets.only(
                                      left: isArabic ? 0 : 4,
                                      right: isArabic ? 4 : 0),
                                  child: Icon(Icons.push_pin,
                                      size: 14, color: pinColor),
                                ),
                            ],
                          ),
                        ),
                        // 3-dot menu (right)
                        if (onMenuTap != null)
                          GestureDetector(
                            onTap: onMenuTap,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.more_vert,
                                  size: 20,
                                  color: isDark
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade600),
                            ),
                          ),
                      ],
                    ),

                    // Description
                    if (task.description != null &&
                        task.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          task.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 8),

                    // Badges — all info under title
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _PriorityBadge(priority: task.priority),
                        if (task.category != TaskCategory.other)
                          _CategoryBadge(category: task.category),
                        if (task.dueDate != null)
                          _DueDateBadge(
                            dueDate: task.dueDate!,
                            isOverdue: task.isOverdue,
                            hasDueTime: task.hasDueTime,
                          ),
                        if (task.isRecurring)
                          _RecurrenceBadge(
                              recurrenceType: task.recurrenceType),
                        if (task.subtasks.isNotEmpty)
                          _SubtaskBadge(
                            completed: task.completedSubtasks,
                            total: task.subtasks.length,
                          ),
                        if (task.estimatedMinutes > 0)
                          _EstimateBadge(minutes: task.estimatedMinutes),
                      ],
                    ),

                    // Progress bar
                    if (task.subtasks.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: task.subtaskProgress,
                          backgroundColor: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                          color:
                              task.completedSubtasks == task.subtasks.length
                                  ? Colors.green
                                  : AppConstants.primaryColor,
                          minHeight: 3,
                        ),
                      ),
                    ],

                    // Tags
                    if (task.tags != null && task.tags!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: task.tags!.take(3).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 15, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  AppConstants.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '#$tag',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppConstants.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // === BOTTOM ACTION BAR ===
                    if (showBottomBar) ...[
                      const SizedBox(height: 8),
                      Divider(
                          height: 1,
                          color: isDark
                              ? AppConstants.darkBorder
                              : AppConstants.lightBorder),
                      const SizedBox(height: 6),
                      _buildBottomBar(context, isDark, isArabic),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Left accent bar
          if (showAccent)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 5,
                decoration: BoxDecoration(
                  color: leftAccent,
                  borderRadius: BorderRadius.only(
                    topLeft:
                        Radius.circular(AppConstants.radiusMedium),
                    bottomLeft:
                        Radius.circular(AppConstants.radiusMedium),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (onToggle == null && onDelete == null) return card;

    return Dismissible(
      key: ValueKey('dismissible_${task.id}'),
      background: _buildSwipeBackground(
        alignment: Alignment.centerLeft,
        color: task.isCompleted ? Colors.orange : Colors.green,
        icon: task.isCompleted ? Icons.refresh : Icons.check,
        label: task.isCompleted
            ? (isArabic ? 'إلغاء الإتمام' : 'Undo')
            : (isArabic ? 'إتمام' : 'Complete'),
      ),
      secondaryBackground: _buildSwipeBackground(
        alignment: Alignment.centerRight,
        color: Colors.red,
        icon: Icons.delete,
        label: isArabic ? 'حذف' : 'Delete',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onToggle?.call();
          return false;
        } else {
          return onDelete != null;
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onDelete?.call();
        }
      },
      child: card,
    );
  }

  Widget _buildBottomBar(BuildContext context, bool isDark, bool isArabic) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Complete toggle
          if (onToggle != null)
            _ActionButton(
              icon: task.isCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              label: task.isCompleted
                  ? (isArabic ? 'تم' : 'Done')
                  : (isArabic ? 'إتمام' : 'Complete'),
              color: task.isCompleted
                  ? Colors.green
                  : AppConstants.primaryColor,
              onTap: onToggle!,
            ),
          if (onToggle != null) const SizedBox(width: 6),
          // Postpone
          if (onPostpone != null && !task.isCompleted) ...[
            _ActionButton(
              icon: Icons.event_outlined,
              label: isArabic ? 'تأجيل' : 'Postpone',
              color: Colors.orange,
              onTap: onPostpone!,
            ),
            const SizedBox(width: 6),
          ],
          // Expand subtasks
          if (onExpand != null) ...[
            _ActionButton(
              icon: isExpanded ? Icons.expand_less : Icons.expand_more,
              label: isExpanded
                  ? (isArabic ? 'إخفاء' : 'Hide')
                  : (task.subtasks.isNotEmpty
                      ? (isArabic ? 'الفرعية' : 'Subtasks')
                      : (isArabic ? 'إضافة فرعية' : '+ Sub')),
              color: AppConstants.primaryColor,
              onTap: onExpand!,
            ),
            const SizedBox(width: 6),
          ],
          // Delete
          if (onDelete != null)
            _ActionButton(
              icon: Icons.delete_outline,
              label: isArabic ? 'حذف' : 'Delete',
              color: Colors.red.shade400,
              onTap: onDelete!,
            ),
        ],
      ),
    );
  }

  Widget _buildSwipeBackground({
    required AlignmentGeometry alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignment == Alignment.centerLeft) ...[
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ] else ...[
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white, size: 22),
          ],
        ],
      ),
    );
  }
}

/// Compact action button for the bottom bar
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    color: color),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final TaskPriority priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final colors = {
      TaskPriority.high: Colors.red,
      TaskPriority.medium: Colors.orange,
      TaskPriority.low: Colors.green,
    };
    final labels = {
      TaskPriority.high: isArabic ? 'عالية' : 'High',
      TaskPriority.medium: isArabic ? 'متوسطة' : 'Medium',
      TaskPriority.low: isArabic ? 'منخفضة' : 'Low',
    };
    final color = colors[priority]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4)),
      child: Text(labels[priority]!,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final TaskCategory category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final labels = {
      TaskCategory.work: isArabic ? 'عمل' : 'Work',
      TaskCategory.personal: isArabic ? 'شخصي' : 'Personal',
      TaskCategory.shopping: isArabic ? 'تسوق' : 'Shopping',
      TaskCategory.health: isArabic ? 'صحة' : 'Health',
      TaskCategory.study: isArabic ? 'دراسة' : 'Study',
      TaskCategory.prayer: isArabic ? 'صلاة' : 'Prayer',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: AppConstants.primaryColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4)),
      child: Text(labels[category] ?? category.value,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppConstants.primaryColor)),
    );
  }
}

class _RecurrenceBadge extends StatelessWidget {
  final RecurrenceType recurrenceType;
  const _RecurrenceBadge({required this.recurrenceType});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final labels = {
      RecurrenceType.daily: isArabic ? 'يومي' : 'Daily',
      RecurrenceType.weekly: isArabic ? 'أسبوعي' : 'Weekly',
      RecurrenceType.monthly: isArabic ? 'شهري' : 'Monthly',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat, size: 11, color: Colors.purple),
          const SizedBox(width: 4),
          Text(labels[recurrenceType] ?? '',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.purple)),
        ],
      ),
    );
  }
}

class _DueDateBadge extends StatelessWidget {
  final DateTime dueDate;
  final bool isOverdue;
  final bool hasDueTime;
  const _DueDateBadge({required this.dueDate, required this.isOverdue, required this.hasDueTime});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

    String label;
    if (dueDay == today) {
      label = isArabic ? 'اليوم' : 'Today';
    } else {
      final tomorrow = today.add(const Duration(days: 1));
      label = dueDay == tomorrow
          ? (isArabic ? 'غداً' : 'Tomorrow')
          : '${dueDate.day}/${dueDate.month}';
    }

    if (hasDueTime) {
      final hour = dueDate.hour;
      final minute = dueDate.minute;
      final period = hour >= 12 ? (isArabic ? 'م' : 'PM') : (isArabic ? 'ص' : 'AM');
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final timeStr = '$displayHour:${minute.toString().padLeft(2, '0')} $period';
      label = isArabic ? '$label $timeStr' : '$label, $timeStr';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isOverdue
            ? Colors.red.withOpacity(0.15)
            : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isOverdue ? Icons.warning : Icons.schedule,
              size: 11, color: isOverdue ? Colors.red : Colors.grey),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isOverdue ? Colors.red : Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _SubtaskBadge extends StatelessWidget {
  final int completed;
  final int total;
  const _SubtaskBadge({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: completed == total
              ? Colors.green.withOpacity(0.15)
              : Colors.blue.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.checklist,
              size: 11,
              color: completed == total ? Colors.green : Colors.blue),
          const SizedBox(width: 4),
          Text('$completed/$total',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: completed == total ? Colors.green : Colors.blue)),
        ],
      ),
    );
  }
}

class _EstimateBadge extends StatelessWidget {
  final int minutes;
  const _EstimateBadge({required this.minutes});

  @override
  Widget build(BuildContext context) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final label = h > 0
        ? (m > 0 ? '${h}h ${m}m' : '${h}h')
        : '${m}m';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
          color: AppConstants.primaryColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 11, color: AppConstants.primaryColor),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppConstants.primaryColor)),
        ],
      ),
    );
  }
}
