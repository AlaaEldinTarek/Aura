import 'package:flutter/material.dart';
import '../models/task.dart';
import '../constants/app_constants.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

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
    final ts = MediaQuery.textScalerOf(context);

    // Left accent color
    final Color leftAccent;
    if (task.isCompleted) {
      leftAccent = Colors.transparent;
    } else if (isOverdue) {
      leftAccent = Colors.red;
    } else if (isSelected) {
      leftAccent = AppConstants.getPrimary(isDark);
    } else {
      switch (task.priority) {
        case TaskPriority.high:
          leftAccent = Colors.red;
        case TaskPriority.medium:
          leftAccent = Colors.orange;
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
            : (AppConstants.card(isDark)),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: isSelected
            ? Border.all(color: AppConstants.getPrimary(isDark), width: 2)
            : Border.all(
                color:
                    AppConstants.border(isDark),
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
                padding: EdgeInsets.fromLTRB(
                  ts.scale(AppSpacing.base),
                  ts.scale(AppSpacing.base),
                  ts.scale(AppSpacing.base),
                  ts.scale(6.0),
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
                                  style: AppTypography.bodyL.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: task.isCompleted
                                        ? (isDark ? Colors.grey.shade600 : Colors.grey.shade400)
                                        : (AppConstants.textPrimary(isDark)),
                                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (task.isPinned && !task.isCompleted)
                                Padding(
                                  padding: EdgeInsets.only(
                                      left: isArabic ? 0 : ts.scale(4.0),
                                      right: isArabic ? ts.scale(4.0) : 0),
                                  child: Icon(Icons.push_pin,
                                      size: ts.scale(14.0), color: pinColor),
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
                              padding: EdgeInsets.all(ts.scale(4.0)),
                              child: Icon(Icons.more_vert,
                                  size: ts.scale(20.0),
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
                        padding: EdgeInsets.only(top: ts.scale(4.0)),
                        child: Text(
                          task.description!,
                          style: AppTypography.bodyS.copyWith(
                            color: AppConstants.textMuted(isDark),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    SizedBox(height: ts.scale(8.0)),

                    // Badges — all info under title
                    Wrap(
                      spacing: ts.scale(8.0),
                      runSpacing: ts.scale(4.0),
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
                      SizedBox(height: ts.scale(6.0)),
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
                                  : AppConstants.getPrimary(isDark),
                          minHeight: 3,
                        ),
                      ),
                    ],

                    // Tags
                    if (task.tags != null && task.tags!.isNotEmpty) ...[
                      SizedBox(height: ts.scale(6.0)),
                      Wrap(
                        spacing: ts.scale(6.0),
                        runSpacing: ts.scale(6.0),
                        children: task.tags!.take(3).map((tag) {
                          return Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: ts.scale(15.0), vertical: ts.scale(4.0)),
                            decoration: BoxDecoration(
                              color:
                                  AppConstants.getPrimary(isDark).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${AppConstants.tagPrefix}$tag',
                              style: AppTypography.caption.copyWith(
                                color: AppConstants.getPrimary(isDark),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // === BOTTOM ACTION BAR ===
                    if (showBottomBar) ...[
                      SizedBox(height: ts.scale(8.0)),
                      Divider(
                          height: 1,
                          color: isDark
                              ? AppConstants.darkBorder
                              : AppConstants.lightBorder),
                      SizedBox(height: ts.scale(6.0)),
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
                  borderRadius: const BorderRadius.only(
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
      movementDuration: const Duration(milliseconds: 250),
      resizeDuration: const Duration(milliseconds: 200),
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
    final ts = MediaQuery.textScalerOf(context);
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
                  : AppConstants.getPrimary(isDark),
              onTap: onToggle!,
            ),
          if (onToggle != null) SizedBox(width: ts.scale(6.0)),
          // Postpone
          if (onPostpone != null && !task.isCompleted) ...[
            _ActionButton(
              icon: Icons.event_outlined,
              label: isArabic ? 'تأجيل' : 'Postpone',
              color: Colors.orange,
              onTap: onPostpone!,
            ),
            SizedBox(width: ts.scale(6.0)),
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
              color: AppConstants.getPrimary(isDark),
              onTap: onExpand!,
            ),
            SizedBox(width: ts.scale(6.0)),
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
    return Builder(builder: (ctx) {
      final ts = MediaQuery.textScalerOf(ctx);
      return Container(
        alignment: alignment,
        padding: EdgeInsets.symmetric(horizontal: ts.scale(20.0)),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (alignment == Alignment.centerLeft) ...[
              Icon(icon, color: Colors.white, size: ts.scale(22.0)),
              SizedBox(width: ts.scale(8.0)),
              Text(label,
                  style: AppTypography.bodyS.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ] else ...[
              Text(label,
                  style: AppTypography.bodyS.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
              SizedBox(width: ts.scale(8.0)),
              Icon(icon, color: Colors.white, size: ts.scale(22.0)),
            ],
          ],
        ),
      );
    });
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
    final ts = MediaQuery.textScalerOf(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ts.scale(8.0), vertical: ts.scale(4.0)),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: ts.scale(14.0), color: color),
            SizedBox(width: ts.scale(4.0)),
            Text(label,
                style: AppTypography.labelS.copyWith(
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
    final ts = MediaQuery.textScalerOf(context);
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
      padding: EdgeInsets.symmetric(horizontal: ts.scale(8.0), vertical: ts.scale(2.0)),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4)),
      child: Text(labels[priority]!,
          style: AppTypography.labelS.copyWith(fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final TaskCategory category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final ts = MediaQuery.textScalerOf(context);
    final labels = {
      TaskCategory.work: isArabic ? 'عمل' : 'Work',
      TaskCategory.personal: isArabic ? 'شخصي' : 'Personal',
      TaskCategory.shopping: isArabic ? 'تسوق' : 'Shopping',
      TaskCategory.health: isArabic ? 'صحة' : 'Health',
      TaskCategory.study: isArabic ? 'دراسة' : 'Study',
      TaskCategory.prayer: isArabic ? 'صلاة' : 'Prayer',
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ts.scale(8.0), vertical: ts.scale(2.0)),
      decoration: BoxDecoration(
          color: AppConstants.getPrimary(isDark).withOpacity(0.15),
          borderRadius: BorderRadius.circular(4)),
      child: Text(labels[category] ?? category.value,
          style: AppTypography.labelS.copyWith(
              fontWeight: FontWeight.w600,
              color: AppConstants.getPrimary(isDark))),
    );
  }
}

class _RecurrenceBadge extends StatelessWidget {
  final RecurrenceType recurrenceType;
  const _RecurrenceBadge({required this.recurrenceType});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final ts = MediaQuery.textScalerOf(context);
    final labels = {
      RecurrenceType.daily: isArabic ? 'يومي' : 'Daily',
      RecurrenceType.weekly: isArabic ? 'أسبوعي' : 'Weekly',
      RecurrenceType.monthly: isArabic ? 'شهري' : 'Monthly',
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ts.scale(8.0), vertical: ts.scale(2.0)),
      decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat, size: ts.scale(11.0), color: Colors.purple),
          SizedBox(width: ts.scale(4.0)),
          Text(labels[recurrenceType] ?? '',
              style: AppTypography.labelS.copyWith(
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
    final ts = MediaQuery.textScalerOf(context);
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
      padding: EdgeInsets.symmetric(horizontal: ts.scale(8.0), vertical: ts.scale(2.0)),
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
              size: ts.scale(11.0), color: isOverdue ? Colors.red : Colors.grey),
          SizedBox(width: ts.scale(4.0)),
          Text(label,
              style: AppTypography.labelS.copyWith(
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
    final ts = MediaQuery.textScalerOf(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ts.scale(8.0), vertical: ts.scale(2.0)),
      decoration: BoxDecoration(
          color: completed == total
              ? Colors.green.withOpacity(0.15)
              : Colors.blue.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.checklist,
              size: ts.scale(11.0),
              color: completed == total ? Colors.green : Colors.blue),
          SizedBox(width: ts.scale(4.0)),
          Text('$completed/$total',
              style: AppTypography.labelS.copyWith(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ts = MediaQuery.textScalerOf(context);
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final label = h > 0
        ? (m > 0 ? '${h}h ${m}m' : '${h}h')
        : '${m}m';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ts.scale(6.0), vertical: ts.scale(3.0)),
      decoration: BoxDecoration(
          color: AppConstants.getPrimary(isDark).withOpacity(0.12),
          borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: ts.scale(11.0), color: AppConstants.getPrimary(isDark)),
          SizedBox(width: ts.scale(3.0)),
          Text(label,
              style: AppTypography.labelS.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppConstants.getPrimary(isDark))),
        ],
      ),
    );
  }
}
