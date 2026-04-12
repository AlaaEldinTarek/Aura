import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/task.dart';
import '../../core/services/task_service.dart';

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
  List<String> _tags = [];

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
    _tags = task.tags ?? [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // TODO: Get user ID from auth
    const userId = 'guest_user';

    try {
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
          dueDate: _selectedDueTime != null && _selectedDueDate != null
              ? DateTime(
                  _selectedDueDate!.year,
                  _selectedDueDate!.month,
                  _selectedDueDate!.day,
                  _selectedDueTime!.hour,
                  _selectedDueTime!.minute,
                )
              : _selectedDueDate,
          tags: _tags.isEmpty ? null : _tags,
        );

        if (task != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isArabic ? 'تمت إضافة المهمة' : 'Task added'),
              backgroundColor: Colors.green,
            ),
          );
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
          dueDate: _selectedDueTime != null && _selectedDueDate != null
              ? DateTime(
                  _selectedDueDate!.year,
                  _selectedDueDate!.month,
                  _selectedDueDate!.day,
                  _selectedDueTime!.hour,
                  _selectedDueTime!.minute,
                )
              : _selectedDueDate,
          tags: _tags.isEmpty ? null : _tags,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isArabic ? 'تمت تحديث المهمة' : 'Task updated'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'حدث خطأ' : 'Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
      });
    }
  }

  void _showPrioritySelector() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppConstants.darkCard : Colors.white,
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
                    style: TextStyle(
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
          color: isDark ? AppConstants.darkCard : Colors.white,
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
                      color: isSelected ? AppConstants.primaryColor : Colors.grey,
                    ),
                    title: Text(
                      labels[category]!,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: AppConstants.primaryColor)
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
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
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

            const SizedBox(height: AppConstants.paddingMedium),

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

            const SizedBox(height: AppConstants.paddingLarge),

            // Priority selector
            InkWell(
              onTap: _showPrioritySelector,
              child: Container(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.flag,
                      color: _getPriorityColor(_selectedPriority),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'الأولوية' : 'Priority',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            _getPriorityLabel(_selectedPriority, isArabic),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppConstants.paddingMedium),

            // Category selector
            InkWell(
              onTap: _showCategorySelector,
              child: Container(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getCategoryIcon(_selectedCategory),
                      color: AppConstants.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'الفئة' : 'Category',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            _getCategoryLabel(_selectedCategory, isArabic),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppConstants.paddingMedium),

            // Due date & time
            InkWell(
              onTap: _selectDueDate,
              child: Container(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'تاريخ الاستحقاق' : 'Due Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            _selectedDueDate != null
                                ? '${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}'
                                : (isArabic ? 'غير محدد' : 'Not set'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ],
                ),
              ),
            ),

            if (_selectedDueDate != null) ...[
              const SizedBox(height: AppConstants.paddingMedium),
              InkWell(
                onTap: _selectDueTime,
                child: Container(
                  padding: const EdgeInsets.all(AppConstants.paddingMedium),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? AppConstants.darkBorder : AppConstants.lightBorder,
                    ),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? 'الوقت' : 'Time',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              _selectedDueTime != null
                                  ? _selectedDueTime!.format(context)
                                  : (isArabic ? 'غير محدد' : 'Not set'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppConstants.paddingLarge * 2),
          ],
        ),
      ),
    );
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
    const userId = 'guest_user';

    try {
      await TaskService.instance.deleteTask(
        userId: userId,
        taskId: widget.task!.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'تم حذف المهمة' : 'Task deleted'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'حدث خطأ' : 'Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
