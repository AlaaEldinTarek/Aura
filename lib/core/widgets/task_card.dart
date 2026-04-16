import 'package:flutter/material.dart';
import '../models/task.dart';
import '../constants/app_constants.dart';

/// Performance-optimized task card widget
/// Uses const constructors where possible and avoids unnecessary rebuilds
class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;
  final bool isSelected;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onToggle,
    this.onDelete,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final isOverdue = task.isOverdue && !task.isCompleted;

    // Left accent color: overdue > selected > priority (completed = none)
    final Color leftAccent;
    final double leftWidth;
    if (task.isCompleted) {
      leftAccent = Colors.transparent;
      leftWidth = 0;
    } else if (isOverdue) {
      leftAccent = Colors.red;
      leftWidth = 3;
    } else if (isSelected) {
      leftAccent = AppConstants.primaryColor;
      leftWidth = 3;
    } else {
      switch (task.priority) {
        case TaskPriority.high:
          leftAccent = Colors.orange;
          leftWidth = 3;
        case TaskPriority.medium:
          leftAccent = Colors.amber;
          leftWidth = 3;
        case TaskPriority.low:
          leftAccent = Colors.green;
          leftWidth = 3;
      }
    }

    final card = Container(
      decoration: BoxDecoration(
        color: isOverdue
            ? (isDark
                ? Colors.red.withOpacity(0.07)
                : Colors.red.withOpacity(0.04))
            : (isDark ? AppConstants.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border(
          left: BorderSide(color: leftAccent, width: leftWidth),
          top: BorderSide(
            color: isSelected
                ? AppConstants.primaryColor
                : isDark
                    ? AppConstants.darkBorder
                    : AppConstants.lightBorder,
            width: isSelected ? 2 : 1,
          ),
          right: BorderSide(
            color: isSelected
                ? AppConstants.primaryColor
                : isDark
                    ? AppConstants.darkBorder
                    : AppConstants.lightBorder,
            width: isSelected ? 2 : 1,
          ),
          bottom: BorderSide(
            color: isSelected
                ? AppConstants.primaryColor
                : isDark
                    ? AppConstants.darkBorder
                    : AppConstants.lightBorder,
            width: isSelected ? 2 : 1,
          ),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Row(
              children: [
                // Checkbox/Status indicator
                _buildCheckbox(context, isDark),
                const SizedBox(width: AppConstants.paddingMedium),

                // Task content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: task.isCompleted
                              ? (isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade400)
                              : (isDark ? Colors.white : Colors.black87),
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Description (if exists)
                      if (task.description != null && task.description!.isNotEmpty)
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

                      // Metadata row
                      const SizedBox(height: 8),
                  Row(
                    children: [
                      // Priority badge
                      _PriorityBadge(priority: task.priority),

                      // Category badge
                      if (task.category != TaskCategory.other) ...[
                        const SizedBox(width: 8),
                        _CategoryBadge(category: task.category),
                      ],

                      // Due date
                      if (task.dueDate != null) ...[
                        const SizedBox(width: 8),
                        _DueDateBadge(
                          dueDate: task.dueDate!,
                          isOverdue: task.isOverdue,
                        ),
                      ],

                      // Recurrence badge
                      if (task.isRecurring) ...[
                        const SizedBox(width: 8),
                        _RecurrenceBadge(recurrenceType: task.recurrenceType),
                      ],
                    ],
                  ),
                ],
            ),
          ),

                // Delete button
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red.shade400,
                    onPressed: onDelete,
                    tooltip: isArabic ? 'حذف' : 'Delete',
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // Wrap with Dismissible only if swipe actions are available
    if (onToggle == null && onDelete == null) return card;

    return Dismissible(
      key: ValueKey('dismissible_${task.id}'),
      // Swipe right → complete/uncomplete
      background: _buildSwipeBackground(
        alignment: Alignment.centerLeft,
        color: task.isCompleted ? Colors.orange : Colors.green,
        icon: task.isCompleted ? Icons.refresh : Icons.check,
        label: task.isCompleted
            ? (isArabic ? 'إلغاء الإتمام' : 'Undo')
            : (isArabic ? 'إتمام' : 'Complete'),
      ),
      // Swipe left → delete
      secondaryBackground: _buildSwipeBackground(
        alignment: Alignment.centerRight,
        color: Colors.red,
        icon: Icons.delete,
        label: isArabic ? 'حذف' : 'Delete',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right: toggle completion, don't remove from list
          onToggle?.call();
          return false;
        } else {
          // Swipe left: confirm delete
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

  Widget _buildCheckbox(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: task.isCompleted
              ? AppConstants.primaryColor
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          border: Border.all(
            color: task.isCompleted
                ? AppConstants.primaryColor
                : (isDark ? Colors.grey.shade700 : Colors.grey.shade400),
          ),
        ),
        child: task.isCompleted
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}

/// Priority badge widget
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
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        labels[priority]!,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Category badge widget
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
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        labels[category] ?? category.value,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppConstants.primaryColor,
        ),
      ),
    );
  }
}

/// Recurrence badge widget
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
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat, size: 11, color: Colors.purple),
          const SizedBox(width: 4),
          Text(
            labels[recurrenceType] ?? '',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }
}

/// Due date badge widget
class _DueDateBadge extends StatelessWidget {
  final DateTime dueDate;
  final bool isOverdue;

  const _DueDateBadge({
    required this.dueDate,
    required this.isOverdue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // Format date
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

    String label;
    if (dueDay == today) {
      label = isArabic ? 'اليوم' : 'Today';
    } else {
      final tomorrow = today.add(const Duration(days: 1));
      if (dueDay == tomorrow) {
        label = isArabic ? 'غداً' : 'Tomorrow';
      } else {
        label = '${dueDate.day}/${dueDate.month}';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isOverdue
            ? Colors.red.withOpacity(0.15)
            : (isDark
                ? Colors.grey.shade800
                : Colors.grey.shade200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOverdue ? Icons.warning : Icons.schedule,
            size: 11,
            color: isOverdue ? Colors.red : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isOverdue ? Colors.red : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
