import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class TaskWidgetService {
  TaskWidgetService._();
  static TaskWidgetService? _instance;
  SharedPreferences? _prefs;
  static const _widgetChannel = MethodChannel('com.aura.hala/widgets');
  List<Task> _cachedTasks = [];

  static TaskWidgetService get instance {
    _instance ??= TaskWidgetService._();
    return _instance!;
  }

  static Future<TaskWidgetService> init() async {
    _instance ??= TaskWidgetService._();
    _instance!._prefs = await SharedPreferences.getInstance();
    return _instance!;
  }

  Future<void> saveTasks({required List<Task> tasks}) async {
    try {
      final language = _prefs?.getString('language') ?? 'en';
      final themeMode = _prefs?.getString('theme_mode') ?? 'system';
      final isArabic = language == 'ar';
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final todayTasks = tasks.where((t) {
        if (t.dueDate == null) return false;
        final dueDay = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
        return dueDay == today;
      }).toList();

      final totalToday = todayTasks.length;
      final doneToday = todayTasks.where((t) => t.isCompleted).length;
      final streak = _prefs?.getInt('task_streak_count') ?? 0;

      // Sort: overdue → priority → pinned → time
      final pendingTasks = todayTasks.where((t) => !t.isCompleted).toList()
        ..sort((a, b) {
          final aO = a.isOverdue ? 0 : 1;
          final bO = b.isOverdue ? 0 : 1;
          if (aO != bO) return aO.compareTo(bO);
          final p = b.priority.level.compareTo(a.priority.level);
          if (p != 0) return p;
          if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
          if (a.hasDueTime && b.hasDueTime) return a.dueDate!.compareTo(b.dueDate!);
          if (a.hasDueTime) return -1;
          if (b.hasDueTime) return 1;
          return 0;
        });

      final displayTasks = pendingTasks.take(5).toList();

      final args = <String, dynamic>{
        'taskCount': displayTasks.length,
        'tasksDone': doneToday,
        'tasksTotal': totalToday,
        'streak': streak,
        'language': language,
        'themeMode': themeMode,
      };

      for (int i = 0; i < 5; i++) {
        if (i < displayTasks.length) {
          final t = displayTasks[i];
          args['task_${i}_id'] = t.id;
          args['task_${i}_title'] = t.title;
          args['task_${i}_priority'] = t.priority.value;
          args['task_${i}_overdue'] = t.isOverdue;
          args['task_${i}_category'] = t.category.value;
          args['task_${i}_subtaskDone'] = t.completedSubtasks;
          args['task_${i}_subtaskTotal'] = t.subtasks.length;
          if (t.hasDueTime && t.dueDate != null) {
            args['task_${i}_time'] = _formatTime(t.dueDate!, isArabic);
          } else {
            args['task_${i}_time'] = '';
          }
        } else {
          args['task_${i}_id'] = '';
          args['task_${i}_title'] = '';
          args['task_${i}_priority'] = 'medium';
          args['task_${i}_overdue'] = false;
          args['task_${i}_category'] = 'other';
          args['task_${i}_subtaskDone'] = 0;
          args['task_${i}_subtaskTotal'] = 0;
          args['task_${i}_time'] = '';
        }
      }

      await _widgetChannel.invokeMethod('updateTasksWidget', args);
      _cachedTasks = tasks;
      debugPrint('📱 TaskWidgetService: Sent ${displayTasks.length} tasks ($doneToday/$totalToday, streak=$streak)');
    } catch (e) {
      debugPrint('📱 TaskWidgetService: Error - $e');
    }
  }

  Future<void> refreshWidget() async {
    if (_cachedTasks.isNotEmpty) await saveTasks(tasks: _cachedTasks);
  }

  String _formatTime(DateTime dt, bool isArabic) {
    final h = dt.hour;
    final m = dt.minute;
    final ampm = h < 12 ? (isArabic ? 'ص' : 'AM') : (isArabic ? 'م' : 'PM');
    final dh = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    if (isArabic) {
      return '${_toEA(dh.toString().padLeft(2, '0'))}:${_toEA(m.toString().padLeft(2, '0'))} $ampm';
    }
    return '${dh.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
  }

  String _toEA(String n) {
    const w = '0123456789';
    const e = '٠١٢٣٤٥٦٧٨٩';
    return n.split('').map((d) { final i = w.indexOf(d); return i >= 0 ? e[i] : d; }).join();
  }
}
