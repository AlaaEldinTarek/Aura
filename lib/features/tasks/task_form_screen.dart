import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/task.dart';
import '../../core/services/task_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/providers/task_provider.dart';
import '../../core/providers/prayer_times_provider.dart';
import '../../core/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/theme/app_typography.dart';

/// Task Form Screen - Add or Edit a task
class TaskFormScreen extends ConsumerStatefulWidget {
  final Task? task; // null for new task, non-null for editing

  const TaskFormScreen({
    super.key,
    this.task,
  });

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  TaskPriority _selectedPriority = TaskPriority.medium;
  TaskCategory _selectedCategory = TaskCategory.other;
  DateTime? _selectedDueDate;
  TimeOfDay? _selectedDueTime;
  bool _hasDueTime = false;
  List<String> _tags = [];
  List<SubTask> _subtasks = [];
  final TextEditingController _subtaskController = TextEditingController();
  // Recurrence
  bool _recurrenceEnabled = false;
  RecurrenceType _recurrenceType = RecurrenceType.daily;
  int _recurrenceInterval = 1;
  DateTime? _recurrenceEndDate;
  // Focus Mode
  bool _focusModeEnabled = false;
  int _focusDurationMinutes = 25;
  // Duration estimate
  int _estimatedMinutes = 0;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _loadTaskData(widget.task!);
    }
  }

  void _loadTaskData(Task task) {
    _titleController.text = task.title;
    _descriptionController.text = task.description ?? '';
    _selectedPriority = task.priority;
    _selectedCategory = task.category;
    _selectedDueDate = task.dueDate;
    _hasDueTime = task.hasDueTime;
    if (task.hasDueTime && task.dueDate != null) {
      _selectedDueTime = TimeOfDay.fromDateTime(task.dueDate!);
    }
    _tags = task.tags ?? [];
    _recurrenceEnabled = task.isRecurring;
    _recurrenceType = task.recurrenceType == RecurrenceType.none
        ? RecurrenceType.daily
        : task.recurrenceType;
    _recurrenceInterval = task.recurrenceInterval;
    _recurrenceEndDate = task.recurrenceEndDate;
    _subtasks = List<SubTask>.from(task.subtasks);
    _focusModeEnabled = task.focusMode;
    _focusDurationMinutes = task.focusDurationMinutes;
    _estimatedMinutes = task.estimatedMinutes;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // Get user ID from auth provider
    final userId = ref.read(currentUserIdProvider);

    try {
      final effectiveDueDate = _selectedDueTime != null && _selectedDueDate != null
          ? DateTime(
              _selectedDueDate!.year,
              _selectedDueDate!.month,
              _selectedDueDate!.day,
              _selectedDueTime!.hour,
              _selectedDueTime!.minute,
            )
          : _selectedDueDate;

      if (widget.task == null) {
        // Create new task
        final task = await TaskService.instance.addTask(
          userId: userId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          priority: _selectedPriority,
          category: _selectedCategory,
          dueDate: effectiveDueDate,
          tags: _tags.isEmpty ? null : _tags,
          hasDueTime: _hasDueTime,
          recurrenceType: _recurrenceEnabled ? _recurrenceType : RecurrenceType.none,
          recurrenceInterval: _recurrenceInterval,
          recurrenceEndDate: _recurrenceEnabled ? _recurrenceEndDate : null,
          subtasks: _subtasks,
          focusMode: _focusModeEnabled,
          focusDurationMinutes: _focusDurationMinutes,
          estimatedMinutes: _estimatedMinutes,
        );

        if (task != null && mounted) {
          // Schedule focus mode alarm if enabled
          if (_focusModeEnabled && effectiveDueDate != null) {
            final prefs = await SharedPreferences.getInstance();
            final language = prefs.getString('language') ?? 'en';
            await NotificationService.instance.scheduleFocusMode(
              taskId: task.id,
              title: task.title,
              description: task.description ?? '',
              triggerTime: effectiveDueDate!,
              durationMinutes: _focusDurationMinutes,
              language: language,
            );
          }
          final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isArabic ? 'تمت إضافة المهمة' : 'Task added'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
            ),
          );
          Future.delayed(const Duration(seconds: 2), snackCtrl.close);
          Navigator.pop(context, true); // true = task was created
        }
      } else {
        // Update existing task
        final success = await TaskService.instance.updateTask(
          userId: userId,
          taskId: widget.task!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          priority: _selectedPriority,
          category: _selectedCategory,
          dueDate: effectiveDueDate,
          tags: _tags.isEmpty ? null : _tags,
          hasDueTime: _hasDueTime,
          recurrenceType: _recurrenceEnabled ? _recurrenceType : RecurrenceType.none,
          recurrenceInterval: _recurrenceInterval,
          recurrenceEndDate: _recurrenceEnabled ? _recurrenceEndDate : null,
          subtasks: _subtasks,
          focusMode: _focusModeEnabled,
          focusDurationMinutes: _focusDurationMinutes,
          estimatedMinutes: _estimatedMinutes,
        );

        if (success && mounted) {
          // Update focus mode alarm
          if (_focusModeEnabled && effectiveDueDate != null) {
            final prefs = await SharedPreferences.getInstance();
            final language = prefs.getString('language') ?? 'en';
            await NotificationService.instance.scheduleFocusMode(
              taskId: widget.task!.id,
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              triggerTime: effectiveDueDate!,
              durationMinutes: _focusDurationMinutes,
              language: language,
            );
          } else {
            await NotificationService.instance.cancelFocusMode(widget.task!.id);
          }
          final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isArabic ? 'تمت تحديث المهمة' : 'Task updated'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
            ),
          );
          Future.delayed(const Duration(seconds: 2), snackCtrl.close);
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'حدث خطأ' : 'Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
          ),
        );
        Future.delayed(const Duration(seconds: 3), snackCtrl.close);
      }
    }
  }

  Future<void> _selectDueDate() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: isArabic ? 'اختر التاريخ' : 'Select Date',
      confirmText: isArabic ? 'تم' : 'OK',
      cancelText: isArabic ? 'إلغاء' : 'Cancel',
    );

    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  Future<void> _selectDueTime() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedDueTime ?? TimeOfDay.now(),
      helpText: isArabic ? 'اختر الوقت' : 'Select Time',
      confirmText: isArabic ? 'تم' : 'OK',
      cancelText: isArabic ? 'إلغاء' : 'Cancel',
    );

    if (picked != null) {
      setState(() {
        _selectedDueTime = picked;
        _hasDueTime = true;
      });
    }
  }

  void _clearDueTime() {
    setState(() {
      _selectedDueTime = null;
      _hasDueTime = false;
    });
  }

  void _showPrioritySelector() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppConstants.card(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  isArabic ? 'الأولوية' : 'Priority',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(height: 1),
              ...TaskPriority.values.map((priority) {
                final isSelected = _selectedPriority == priority;
                final colors = {
                  TaskPriority.low: Colors.green,
                  TaskPriority.medium: Colors.orange,
                  TaskPriority.high: Colors.red,
                };
                final labels = {
                  TaskPriority.low: isArabic ? 'منخفضة' : 'Low',
                  TaskPriority.medium: isArabic ? 'متوسطة' : 'Medium',
                  TaskPriority.high: isArabic ? 'عالية' : 'High',
                };

                return ListTile(
                  leading: Icon(
                    Icons.flag,
                    color: colors[priority],
                  ),
                  title: Text(
                    labels[priority]!,
                    style: AppTypography.bodyM.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? colors[priority] : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: colors[priority])
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedPriority = priority;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategorySelector() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppConstants.card(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    isArabic ? 'الفئة' : 'Category',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const Divider(height: 1),
                ...TaskCategory.values.map((category) {
                  if (category == TaskCategory.other) return const SizedBox.shrink();

                  final isSelected = _selectedCategory == category;
                  final labels = {
                    TaskCategory.work: isArabic ? 'عمل' : 'Work',
                    TaskCategory.personal: isArabic ? 'شخصي' : 'Personal',
                    TaskCategory.shopping: isArabic ? 'تسوق' : 'Shopping',
                    TaskCategory.health: isArabic ? 'صحة' : 'Health',
                    TaskCategory.study: isArabic ? 'دراسة' : 'Study',
                    TaskCategory.prayer: isArabic ? 'صلاة' : 'Prayer',
                  };

                  return ListTile(
                    leading: Icon(
                      _getCategoryIcon(category),
                      color: isSelected ? AppConstants.getPrimary(isDark) : Colors.grey,
                    ),
                    title: Text(
                      labels[category]!,
                      style: AppTypography.bodyM.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: AppConstants.getPrimary(isDark))
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(TaskCategory category) {
    switch (category) {
      case TaskCategory.work:
        return Icons.work;
      case TaskCategory.personal:
        return Icons.person;
      case TaskCategory.shopping:
        return Icons.shopping_cart;
      case TaskCategory.health:
        return Icons.favorite;
      case TaskCategory.study:
        return Icons.school;
      case TaskCategory.prayer:
        return Icons.mosque;
      case TaskCategory.other:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final ts = MediaQuery.textScalerOf(context);
    final isEditing = widget.task != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing
            ? (isArabic ? 'تعديل المهمة' : 'Edit Task')
            : (isArabic ? 'مهمة جديدة' : 'New Task')),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _showDeleteConfirmation(context),
              tooltip: isArabic ? 'حذف' : 'Delete',
            ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveTask,
            tooltip: isArabic ? 'حفظ' : 'Save',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(ts.scale(AppConstants.paddingMedium)),
          children: [
            // Title field
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: isArabic ? 'عنوان المهمة' : 'Task Title',
                hintText: isArabic ? 'أدخل عنوان المهمة' : 'Enter task title',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.title),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return isArabic ? 'العنوان مطلوب' : 'Title is required';
                }
                return null;
              },
            ),

            SizedBox(height: ts.scale(AppConstants.paddingMedium)),

            // Description field
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: isArabic ? 'الوصف (اختياري)' : 'Description (optional)',
                hintText: isArabic ? 'أدخل وصف المهمة' : 'Enter task description',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.description),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),

            SizedBox(height: ts.scale(AppConstants.paddingLarge)),

            // Priority selector
            InkWell(
              onTap: _showPrioritySelector,
              child: Container(
                padding: EdgeInsets.all(ts.scale(AppConstants.paddingMedium)),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppConstants.border(isDark),
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.flag,
                      color: _getPriorityColor(_selectedPriority),
                    ),
                    SizedBox(width: ts.scale(12.0)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'الأولوية' : 'Priority',
                            style: AppTypography.caption.copyWith(
                              color: AppConstants.textMuted(isDark),
                            ),
                          ),
                          Text(
                            _getPriorityLabel(_selectedPriority, isArabic),
                            style: AppTypography.bodyL.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: AppConstants.textMuted(isDark)),
                  ],
                ),
              ),
            ),

            SizedBox(height: ts.scale(AppConstants.paddingMedium)),

            // Category selector
            InkWell(
              onTap: _showCategorySelector,
              child: Container(
                padding: EdgeInsets.all(ts.scale(AppConstants.paddingMedium)),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppConstants.border(isDark),
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getCategoryIcon(_selectedCategory),
                      color: AppConstants.getPrimary(isDark),
                    ),
                    SizedBox(width: ts.scale(12.0)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'الفئة' : 'Category',
                            style: AppTypography.caption.copyWith(
                              color: AppConstants.textMuted(isDark),
                            ),
                          ),
                          Text(
                            _getCategoryLabel(_selectedCategory, isArabic),
                            style: AppTypography.bodyL.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: AppConstants.textMuted(isDark)),
                  ],
                ),
              ),
            ),

            SizedBox(height: ts.scale(AppConstants.paddingMedium)),

            // Due date & time
            InkWell(
              onTap: _selectDueDate,
              child: Container(
                padding: EdgeInsets.all(ts.scale(AppConstants.paddingMedium)),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppConstants.border(isDark),
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    SizedBox(width: ts.scale(12.0)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'تاريخ الاستحقاق' : 'Due Date',
                            style: AppTypography.caption.copyWith(
                              color: AppConstants.textMuted(isDark),
                            ),
                          ),
                          Text(
                            _selectedDueDate != null
                                ? '${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}'
                                : (isArabic ? 'غير محدد' : 'Not set'),
                            style: AppTypography.bodyL.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: AppConstants.textMuted(isDark)),
                  ],
                ),
              ),
            ),

            if (_selectedDueDate != null) ...[
              SizedBox(height: ts.scale(AppConstants.paddingMedium)),
              InkWell(
                onTap: _selectDueTime,
                child: Container(
                  padding: EdgeInsets.all(ts.scale(AppConstants.paddingMedium)),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppConstants.border(isDark),
                    ),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time),
                      SizedBox(width: ts.scale(12.0)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? 'الوقت' : 'Time',
                              style: AppTypography.caption.copyWith(
                                color: AppConstants.textMuted(isDark),
                              ),
                            ),
                            Text(
                              _selectedDueTime != null
                                  ? _selectedDueTime!.format(context)
                                  : (isArabic ? 'غير محدد' : 'Not set'),
                              style: AppTypography.bodyL.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedDueTime != null)
                        GestureDetector(
                          onTap: _clearDueTime,
                          child: Icon(Icons.close, size: 18,
                              color: AppConstants.textMuted(isDark)),
                        )
                      else
                        Icon(Icons.chevron_right,
                            color: AppConstants.textMuted(isDark)),
                    ],
                  ),
                ),
              ),
            ],

            // Prayer conflict warning (only in Both mode)
            _buildPrayerConflictWarning(isDark, isArabic),

            SizedBox(height: ts.scale(AppConstants.paddingMedium)),

            // Recurrence Card
            _buildRecurrenceCard(isDark, isArabic),

            SizedBox(height: ts.scale(AppConstants.paddingMedium)),

            // Focus Mode Card
            _buildFocusModeCard(isDark, isArabic),

            SizedBox(height: ts.scale(AppConstants.paddingMedium)),

            // Estimated Duration Card
            _buildEstimatedDurationCard(isDark, isArabic),

            SizedBox(height: ts.scale(AppConstants.paddingMedium)),

            // Tags Card
            _buildTagsCard(isDark, isArabic),

            SizedBox(height: ts.scale(AppConstants.paddingMedium)),

            // Subtasks Card
            _buildSubtasksCard(isDark, isArabic),

            SizedBox(height: ts.scale(AppConstants.paddingLarge * 2)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenceCard(bool isDark, bool isArabic) {
    final ts = MediaQuery.textScalerOf(context);
    final borderColor = AppConstants.border(isDark);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Column(
        children: [
          // Toggle header
          SwitchListTile(
            secondary: Icon(
              Icons.repeat,
              color: _recurrenceEnabled ? AppConstants.getPrimary(isDark) : Colors.grey,
            ),
            title: Text(isArabic ? 'تكرار المهمة' : 'Repeat Task'),
            subtitle: Text(
              _recurrenceEnabled
                  ? _getRecurrenceLabel(isArabic)
                  : (isArabic ? 'لا تكرار' : 'No repeat'),
              style: AppTypography.caption.copyWith(
                color: _recurrenceEnabled
                    ? AppConstants.getPrimary(isDark)
                    : Colors.grey,
              ),
            ),
            value: _recurrenceEnabled,
            activeColor: AppConstants.getPrimary(isDark),
            onChanged: (val) => setState(() => _recurrenceEnabled = val),
          ),

          // Recurrence options (only when enabled)
          if (_recurrenceEnabled) ...[
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(ts.scale(AppConstants.paddingMedium)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Frequency selector
                  Text(
                    isArabic ? 'التكرار' : 'Frequency',
                    style: AppTypography.caption.copyWith(
                      color: AppConstants.textMuted(isDark),
                    ),
                  ),
                  SizedBox(height: ts.scale(8.0)),
                  Row(
                    children: [
                      _buildFrequencyChip(RecurrenceType.daily,
                          isArabic ? 'يومي' : 'Daily', isDark),
                      SizedBox(width: ts.scale(8.0)),
                      _buildFrequencyChip(RecurrenceType.weekly,
                          isArabic ? 'أسبوعي' : 'Weekly', isDark),
                      SizedBox(width: ts.scale(8.0)),
                      _buildFrequencyChip(RecurrenceType.monthly,
                          isArabic ? 'شهري' : 'Monthly', isDark),
                    ],
                  ),

                  SizedBox(height: ts.scale(16.0)),

                  // Interval input
                  Row(
                    children: [
                      Text(
                        isArabic ? 'كل' : 'Every',
                        style: AppTypography.label,
                      ),
                      SizedBox(width: ts.scale(12.0)),
                      SizedBox(
                        width: 60,
                        child: TextFormField(
                          initialValue: '$_recurrenceInterval',
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 8),
                          ),
                          onChanged: (val) {
                            final n = int.tryParse(val);
                            if (n != null && n > 0) {
                              setState(() => _recurrenceInterval = n);
                            }
                          },
                        ),
                      ),
                      SizedBox(width: ts.scale(12.0)),
                      Text(
                        _getIntervalUnit(isArabic),
                        style: AppTypography.label,
                      ),
                    ],
                  ),

                  SizedBox(height: ts.scale(16.0)),

                  // End date (optional)
                  InkWell(
                    onTap: () => _selectRecurrenceEndDate(),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_available,
                          size: ts.scale(20.0),
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        SizedBox(width: ts.scale(8.0)),
                        Expanded(
                          child: Text(
                            _recurrenceEndDate != null
                                ? (isArabic ? 'ينتهي: ' : 'Ends: ') +
                                    '${_recurrenceEndDate!.day}/${_recurrenceEndDate!.month}/${_recurrenceEndDate!.year}'
                                : (isArabic
                                    ? 'تاريخ انتهاء (اختياري)'
                                    : 'End date (optional)'),
                            style: AppTypography.label.copyWith(
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        if (_recurrenceEndDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () =>
                                setState(() => _recurrenceEndDate = null),
                            color: Colors.grey,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Prayer Conflict Warning ───────────────────────────────────────────

  Widget _buildPrayerConflictWarning(bool isDark, bool isArabic) {
    final appMode = ref.watch(appModeProvider);
    if (appMode != AppMode.both) return const SizedBox.shrink();
    if (_selectedDueTime == null || _selectedDueDate == null) return const SizedBox.shrink();

    final prayerState = ref.watch(prayerTimesProvider);
    final prayers = prayerState?.prayerTimes ?? [];
    if (prayers.isEmpty) return const SizedBox.shrink();

    final taskDateTime = DateTime(
      _selectedDueDate!.year,
      _selectedDueDate!.month,
      _selectedDueDate!.day,
      _selectedDueTime!.hour,
      _selectedDueTime!.minute,
    );

    // Check if task time is within 30 minutes of any prayer
    String? warningPrayerName;
    String? warningPrayerNameAr;
    int? minutesDiff;
    bool isDuringPrayer = false;

    for (final prayer in prayers) {
      if (prayer.name == 'Sunrise') continue;
      final diff = taskDateTime.difference(prayer.time).inMinutes.abs();
      if (diff == 0) {
        isDuringPrayer = true;
        warningPrayerName = prayer.name;
        warningPrayerNameAr = prayer.nameAr;
        minutesDiff = 0;
        break;
      } else if (diff <= 30) {
        if (minutesDiff == null || diff < minutesDiff) {
          minutesDiff = diff;
          warningPrayerName = prayer.name;
          warningPrayerNameAr = prayer.nameAr;
          isDuringPrayer = false;
        }
      }
    }

    if (warningPrayerName == null) return const SizedBox.shrink();

    final prayerDisplay = isArabic ? warningPrayerNameAr! : warningPrayerName;
    final message = isDuringPrayer
        ? (isArabic ? '⚠️ هذا الوقت يتزامن مع صلاة $prayerDisplay' : '⚠️ This time overlaps with $prayerDisplay prayer')
        : (isArabic ? '⚠️ هذا الوقت قريب من صلاة $prayerDisplay (${NumberFormatter.withArabicNumerals('$minutesDiff')} دقيقة)' : '⚠️ This time is $minutesDiff min from $prayerDisplay prayer');

    final ts = MediaQuery.textScalerOf(context);
    return Container(
      margin: EdgeInsets.only(top: ts.scale(8.0)),
      padding: EdgeInsets.symmetric(horizontal: ts.scale(12.0), vertical: ts.scale(10.0)),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.mosque_outlined, size: ts.scale(16.0), color: Colors.orange),
          SizedBox(width: ts.scale(8.0)),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyS.copyWith(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Estimated Duration ────────────────────────────────────────────────

  Widget _buildEstimatedDurationCard(bool isDark, bool isArabic) {
    final ts = MediaQuery.textScalerOf(context);
    final borderColor = AppConstants.border(isDark);
    final presets = [15, 30, 45, 60, 90, 120];

    String _formatMins(int mins) {
      if (mins == 0) return isArabic ? 'بدون' : 'None';
      if (mins < 60) return isArabic ? '${NumberFormatter.withArabicNumerals('$mins')} د' : '${mins}m';
      final h = mins ~/ 60;
      final m = mins % 60;
      if (m == 0) return isArabic ? '${NumberFormatter.withArabicNumerals('$h')} س' : '${h}h';
      return isArabic ? '${NumberFormatter.withArabicNumerals('$h')} س ${NumberFormatter.withArabicNumerals('$m')} د' : '${h}h ${m}m';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppConstants.card(isDark),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: borderColor),
      ),
      padding: EdgeInsets.all(ts.scale(AppConstants.paddingMedium)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, size: ts.scale(18.0), color: AppConstants.getPrimary(isDark)),
              SizedBox(width: ts.scale(8.0)),
              Text(
                isArabic ? 'كم تحتاج من وقت؟' : 'Time Needed',
                style: AppTypography.headingS.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                _formatMins(_estimatedMinutes),
                style: AppTypography.label.copyWith(
                  color: AppConstants.getPrimary(isDark),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: ts.scale(12.0)),
          Wrap(
            spacing: ts.scale(8.0),
            runSpacing: ts.scale(8.0),
            children: [
              // None option
              GestureDetector(
                onTap: () => setState(() => _estimatedMinutes = 0),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: ts.scale(14.0), vertical: ts.scale(7.0)),
                  decoration: BoxDecoration(
                    color: _estimatedMinutes == 0
                        ? AppConstants.getPrimary(isDark)
                        : AppConstants.getPrimary(isDark).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isArabic ? 'بدون' : 'None',
                    style: AppTypography.bodyS.copyWith(
                      fontWeight: FontWeight.w500,
                      color: _estimatedMinutes == 0 ? Colors.white : AppConstants.getPrimary(isDark),
                    ),
                  ),
                ),
              ),
              // Preset options
              ...presets.map((mins) => GestureDetector(
                onTap: () => setState(() => _estimatedMinutes = mins),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: ts.scale(14.0), vertical: ts.scale(7.0)),
                  decoration: BoxDecoration(
                    color: _estimatedMinutes == mins
                        ? AppConstants.getPrimary(isDark)
                        : AppConstants.getPrimary(isDark).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatMins(mins),
                    style: AppTypography.bodyS.copyWith(
                      fontWeight: FontWeight.w500,
                      color: _estimatedMinutes == mins ? Colors.white : AppConstants.getPrimary(isDark),
                    ),
                  ),
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Focus Mode ────────────────────────────────────────────────────────

  Widget _buildFocusModeCard(bool isDark, bool isArabic) {
    final ts = MediaQuery.textScalerOf(context);
    final borderColor = AppConstants.border(isDark);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(
              Icons.center_focus_strong,
              color: _focusModeEnabled ? AppConstants.getPrimary(isDark) : Colors.grey,
            ),
            title: Text(isArabic ? 'وضع التركيز' : 'Focus Mode'),
            subtitle: Text(
              _focusModeEnabled
                  ? (isArabic
                      ? '${NumberFormatter.withArabicNumerals('$_focusDurationMinutes')} دقيقة'
                      : '$_focusDurationMinutes min')
                  : (isArabic
                      ? 'قفل الشاشة وكتم الإشعارات'
                      : 'Lock screen & silence notifications'),
              style: AppTypography.caption.copyWith(
                color: _focusModeEnabled
                    ? AppConstants.getPrimary(isDark)
                    : Colors.grey,
              ),
            ),
            value: _focusModeEnabled,
            activeColor: AppConstants.getPrimary(isDark),
            onChanged: (val) async {
              if (val) {
                // Check and request permissions first
                final hasOverlay = await NotificationService.instance.canDrawOverlays();
                final hasDnd = await NotificationService.instance.hasDndAccess();
                if (!hasOverlay || !hasDnd) {
                  if (!mounted) return;
                  await _showFocusPermissionDialog(isArabic, hasOverlay, hasDnd);
                  return;
                }
                final confirmed = await _showFocusModeConfirmation(isArabic);
                if (!confirmed) return;
              }
              setState(() => _focusModeEnabled = val);
            },
          ),
          if (_focusModeEnabled) ...[
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(ts.scale(AppConstants.paddingMedium)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'مدة التركيز' : 'Focus Duration',
                    style: AppTypography.caption.copyWith(
                      color: AppConstants.textMuted(isDark),
                    ),
                  ),
                  SizedBox(height: ts.scale(8.0)),
                  Row(
                    children: [
                      _buildDurationChip(15, isArabic ? '١٥' : '15', isDark),
                      SizedBox(width: ts.scale(8.0)),
                      _buildDurationChip(25, isArabic ? '٢٥' : '25', isDark),
                      SizedBox(width: ts.scale(8.0)),
                      _buildDurationChip(45, isArabic ? '٤٥' : '45', isDark),
                      SizedBox(width: ts.scale(8.0)),
                      _buildDurationChip(60, isArabic ? '٦٠' : '60', isDark),
                    ],
                  ),
                  SizedBox(height: ts.scale(12.0)),
                  // Custom duration input
                  Row(
                    children: [
                      Text(
                        isArabic ? 'أو أدخل يدوياً:' : 'Custom:',
                        style: AppTypography.caption.copyWith(
                          color: AppConstants.textMuted(isDark),
                        ),
                      ),
                      SizedBox(width: ts.scale(8.0)),
                      SizedBox(
                        width: 70,
                        child: TextFormField(
                          initialValue: _focusDurationMinutes.toString(),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            border: const OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppConstants.getPrimary(isDark)),
                            ),
                          ),
                          style: AppTypography.label.copyWith(
                            color: AppConstants.textPrimary(isDark),
                          ),
                          onChanged: (val) {
                            final n = int.tryParse(val);
                            if (n != null && n > 0 && n <= 180) {
                              setState(() => _focusDurationMinutes = n);
                            }
                          },
                        ),
                      ),
                      SizedBox(width: ts.scale(8.0)),
                      Text(
                        isArabic ? 'دقيقة' : 'min',
                        style: AppTypography.bodyS.copyWith(
                          color: AppConstants.textMuted(isDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDurationChip(int minutes, String label, bool isDark) {
    final isSelected = _focusDurationMinutes == minutes;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _focusDurationMinutes = minutes),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppConstants.getPrimary(isDark)
                : (isDark ? AppConstants.darkCard : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppConstants.getPrimary(isDark)
                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _showFocusModeConfirmation(bool isArabic) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
        title: Text(
          isArabic ? 'تفعيل وضع التركيز؟' : 'Enable Focus Mode?',
        ),
        content: Text(
          isArabic
              ? 'سيتم قفل هاتفك وكتم جميع الإشعارات لمدة ${NumberFormatter.withArabicNumerals('$_focusDurationMinutes')} دقيقة. يمكنك الخروج بالضغط على زر رفع الصوت ٣ مرات بسرعة.'
              : 'This will lock your phone and silence all notifications for $_focusDurationMinutes minutes. You can exit by pressing volume up 3 times quickly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.getPrimary(isDark),
            ),
            child: Text(isArabic ? 'تفعيل' : 'Enable'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _showFocusPermissionDialog(bool isArabic, bool hasOverlay, bool hasDnd) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
        title: Text(
          isArabic ? 'أذونات مطلوبة' : 'Permissions Required',
        ),
        content: Text(
          isArabic
              ? 'يتطلب وضع التركيز إذن الرسم فوق التطبيقات الأخرى والوصول إلى وضع عدم الإزعاج.'
              : 'Focus Mode requires permission to draw over other apps and access Do Not Disturb.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (!hasOverlay) {
                await NotificationService.instance.requestOverlayPermission();
              }
              if (!hasDnd) {
                await NotificationService.instance.requestDndAccess();
              }
              // Re-check and enable if both granted
              final overlayOk = await NotificationService.instance.canDrawOverlays();
              final dndOk = await NotificationService.instance.hasDndAccess();
              if (overlayOk && dndOk) {
                final confirmed = await _showFocusModeConfirmation(isArabic);
                if (confirmed) setState(() => _focusModeEnabled = true);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppConstants.getPrimary(isDark),
            ),
            child: Text(isArabic ? 'منح الأذونات' : 'Grant Permissions'),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyChip(RecurrenceType type, String label, bool isDark) {
    final isSelected = _recurrenceType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _recurrenceType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppConstants.getPrimary(isDark)
                : (isDark ? AppConstants.darkCard : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppConstants.getPrimary(isDark)
                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
            ),
          ),
        ),
      ),
    );
  }

  String _getRecurrenceLabel(bool isArabic) {
    final intervalStr = _recurrenceInterval == 1 ? '' : ' $_recurrenceInterval';
    switch (_recurrenceType) {
      case RecurrenceType.daily:
        return isArabic
            ? 'كل$intervalStr ${_recurrenceInterval == 1 ? 'يوم' : 'أيام'}'
            : 'Every$intervalStr day${_recurrenceInterval == 1 ? '' : 's'}';
      case RecurrenceType.weekly:
        return isArabic
            ? 'كل$intervalStr ${_recurrenceInterval == 1 ? 'أسبوع' : 'أسابيع'}'
            : 'Every$intervalStr week${_recurrenceInterval == 1 ? '' : 's'}';
      case RecurrenceType.monthly:
        return isArabic
            ? 'كل$intervalStr ${_recurrenceInterval == 1 ? 'شهر' : 'أشهر'}'
            : 'Every$intervalStr month${_recurrenceInterval == 1 ? '' : 's'}';
      case RecurrenceType.none:
        return '';
    }
  }

  String _getIntervalUnit(bool isArabic) {
    switch (_recurrenceType) {
      case RecurrenceType.daily:
        return isArabic ? 'أيام' : 'day(s)';
      case RecurrenceType.weekly:
        return isArabic ? 'أسابيع' : 'week(s)';
      case RecurrenceType.monthly:
        return isArabic ? 'أشهر' : 'month(s)';
      case RecurrenceType.none:
        return '';
    }
  }

  Future<void> _selectRecurrenceEndDate() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final picked = await showDatePicker(
      context: context,
      initialDate: _recurrenceEndDate ??
          DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: isArabic ? 'تاريخ انتهاء التكرار' : 'Recurrence End Date',
      confirmText: isArabic ? 'تم' : 'OK',
      cancelText: isArabic ? 'إلغاء' : 'Cancel',
    );
    if (picked != null) {
      setState(() => _recurrenceEndDate = picked);
    }
  }

  // ─── Subtasks ────────────────────────────────────────────────────────────

  Widget _buildSubtasksCard(bool isDark, bool isArabic) {
    final ts = MediaQuery.textScalerOf(context);
    final borderColor = AppConstants.border(isDark);
    final completedCount = _subtasks.where((s) => s.isCompleted).length;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Padding(
        padding: EdgeInsets.all(ts.scale(AppConstants.paddingMedium)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist,
                    size: ts.scale(20.0),
                    color: AppConstants.textMuted(isDark)),
                SizedBox(width: ts.scale(8.0)),
                Text(
                  isArabic ? 'الخطوات الفرعية' : 'Checklist',
                  style: AppTypography.bodyM.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppConstants.textPrimary(isDark),
                  ),
                ),
                if (_subtasks.isNotEmpty) ...[
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: ts.scale(8.0), vertical: ts.scale(2.0)),
                    decoration: BoxDecoration(
                      color: AppConstants.getPrimary(isDark).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$completedCount/${_subtasks.length}',
                      style: AppTypography.labelS.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppConstants.getPrimary(isDark),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: ts.scale(12.0)),

            // Subtask input row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subtaskController,
                    decoration: InputDecoration(
                      hintText: isArabic ? 'أضف خطوة...' : 'Add a step...',
                      hintStyle: AppTypography.bodyM.copyWith(
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade400),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: ts.scale(12.0), vertical: ts.scale(10.0)),
                      filled: true,
                      fillColor:
                          isDark ? AppConstants.darkCard : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: AppTypography.label.copyWith(
                        color: AppConstants.textPrimary(isDark)),
                    onSubmitted: (value) => _addSubtask(value),
                    textInputAction: TextInputAction.done,
                  ),
                ),
                SizedBox(width: ts.scale(8.0)),
                GestureDetector(
                  onTap: () => _addSubtask(_subtaskController.text),
                  child: Container(
                    padding: EdgeInsets.all(ts.scale(10.0)),
                    decoration: BoxDecoration(
                      color: AppConstants.getPrimary(isDark),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add, color: Colors.white, size: ts.scale(18.0)),
                  ),
                ),
              ],
            ),

            // Subtask list
            if (_subtasks.isNotEmpty) ...[
              SizedBox(height: ts.scale(8.0)),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _subtasks.isEmpty ? 0 : completedCount / _subtasks.length,
                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  color: completedCount == _subtasks.length
                      ? Colors.green
                      : AppConstants.getPrimary(isDark),
                  minHeight: 3,
                ),
              ),
              SizedBox(height: ts.scale(8.0)),
              ...List.generate(_subtasks.length, (index) {
                final subtask = _subtasks[index];
                return Dismissible(
                  key: ValueKey(subtask.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => setState(() => _subtasks.removeAt(index)),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: ts.scale(16.0)),
                    color: Colors.red,
                    child: Icon(Icons.delete, color: Colors.white, size: ts.scale(20.0)),
                  ),
                  child: InkWell(
                    onTap: () => setState(() {
                      _subtasks[index] = subtask.copyWith(
                          isCompleted: !subtask.isCompleted);
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: ts.scale(6.0)),
                      child: Row(
                        children: [
                          // Checkbox
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: ts.scale(22.0),
                            height: ts.scale(22.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: subtask.isCompleted
                                  ? AppConstants.getPrimary(isDark)
                                  : Colors.transparent,
                              border: Border.all(
                                color: subtask.isCompleted
                                    ? AppConstants.getPrimary(isDark)
                                    : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                                width: 1.5,
                              ),
                            ),
                            child: subtask.isCompleted
                                ? Icon(Icons.check, size: ts.scale(14.0), color: Colors.white)
                                : null,
                          ),
                          SizedBox(width: ts.scale(10.0)),
                          Expanded(
                            child: Text(
                              subtask.title,
                              style: AppTypography.label.copyWith(
                                color: subtask.isCompleted
                                    ? (isDark ? Colors.grey.shade600 : Colors.grey.shade400)
                                    : (AppConstants.textPrimary(isDark)),
                                decoration: subtask.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  void _addSubtask(String value) {
    final title = value.trim();
    if (title.isEmpty) {
      _subtaskController.clear();
      return;
    }
    setState(() {
      _subtasks.add(SubTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
      ));
      _subtaskController.clear();
    });
  }

  // ─── Tags ────────────────────────────────────────────────────────────────

  final TextEditingController _tagController = TextEditingController();

  Widget _buildTagsCard(bool isDark, bool isArabic) {
    final ts = MediaQuery.textScalerOf(context);
    final borderColor = AppConstants.border(isDark);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Padding(
        padding: EdgeInsets.all(ts.scale(AppConstants.paddingMedium)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.label_outline,
                    size: ts.scale(20.0),
                    color: AppConstants.textMuted(isDark)),
                SizedBox(width: ts.scale(8.0)),
                Text(
                  isArabic ? 'التصنيفات' : 'Tags',
                  style: AppTypography.bodyM.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppConstants.textPrimary(isDark),
                  ),
                ),
              ],
            ),
            SizedBox(height: ts.scale(12.0)),

            // Tag input row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: InputDecoration(
                      hintText: isArabic ? 'أضف تصنيفاً...' : 'Add a tag...',
                      hintStyle: AppTypography.bodyM.copyWith(
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade400),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: ts.scale(12.0), vertical: ts.scale(10.0)),
                      filled: true,
                      fillColor:
                          isDark ? AppConstants.darkCard : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: AppTypography.label.copyWith(
                        color: AppConstants.textPrimary(isDark)),
                    onSubmitted: (value) => _addTag(value),
                    textInputAction: TextInputAction.done,
                  ),
                ),
                SizedBox(width: ts.scale(8.0)),
                GestureDetector(
                  onTap: () => _addTag(_tagController.text),
                  child: Container(
                    padding: EdgeInsets.all(ts.scale(10.0)),
                    decoration: BoxDecoration(
                      color: AppConstants.getPrimary(isDark),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add, color: Colors.white, size: ts.scale(18.0)),
                  ),
                ),
              ],
            ),

            // Existing tags
            if (_tags.isNotEmpty) ...[
              SizedBox(height: ts.scale(10.0)),
              Wrap(
                spacing: ts.scale(6.0),
                runSpacing: ts.scale(6.0),
                children: _tags.map((tag) {
                  return Chip(
                    label: Text(tag,
                        style: AppTypography.caption.copyWith(color: Colors.white)),
                    backgroundColor: AppConstants.getPrimary(isDark),
                    deleteIconColor: Colors.white70,
                    onDeleted: () => setState(() => _tags.remove(tag)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _addTag(String value) {
    final tag = value.trim().toLowerCase();
    if (tag.isEmpty || _tags.contains(tag)) {
      _tagController.clear();
      return;
    }
    setState(() {
      _tags.add(tag);
      _tagController.clear();
    });
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
    }
  }

  String _getPriorityLabel(TaskPriority priority, bool isArabic) {
    switch (priority) {
      case TaskPriority.low:
        return isArabic ? 'منخفضة' : 'Low';
      case TaskPriority.medium:
        return isArabic ? 'متوسطة' : 'Medium';
      case TaskPriority.high:
        return isArabic ? 'عالية' : 'High';
    }
  }

  String _getCategoryLabel(TaskCategory category, bool isArabic) {
    switch (category) {
      case TaskCategory.work:
        return isArabic ? 'عمل' : 'Work';
      case TaskCategory.personal:
        return isArabic ? 'شخصي' : 'Personal';
      case TaskCategory.shopping:
        return isArabic ? 'تسوق' : 'Shopping';
      case TaskCategory.health:
        return isArabic ? 'صحة' : 'Health';
      case TaskCategory.study:
        return isArabic ? 'دراسة' : 'Study';
      case TaskCategory.prayer:
        return isArabic ? 'صلاة' : 'Prayer';
      case TaskCategory.other:
        return isArabic ? 'أخرى' : 'Other';
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
        title: Text(isArabic ? 'حذف المهمة' : 'Delete Task'),
        content: Text(
          isArabic ? 'هل أنت متأكد من حذف هذه المهمة؟' : 'Are you sure you want to delete this task?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(isArabic ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteTask();
    }
  }

  Future<void> _deleteTask() async {
    if (widget.task == null) return;

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final userId = ref.read(currentUserIdProvider);

    try {
      await TaskService.instance.deleteTask(
        userId: userId,
        taskId: widget.task!.id,
      );

      if (mounted) {
        final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'تم حذف المهمة' : 'Task deleted'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
          ),
        );
        Future.delayed(const Duration(seconds: 2), snackCtrl.close);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final snackCtrl = ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'حدث خطأ' : 'Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
          ),
        );
        Future.delayed(const Duration(seconds: 3), snackCtrl.close);
      }
    }
  }
}
