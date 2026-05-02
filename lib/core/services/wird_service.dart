import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wird.dart';
import 'notification_service.dart';

class WirdService {
  WirdService._();
  static final WirdService instance = WirdService._();

  static const _settingsKey = 'wird_settings';
  static const _streakCountKey = 'wird_streak_count';
  static const _streakDateKey = 'wird_streak_date';
  static const _totalPagesKey = 'wird_total_pages_read';
  static const _totalDaysKey = 'wird_total_days_completed';
  static const _historyKey = 'wird_progress_history';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ── Settings ─────────────────────────────────────────────────────────────

  Future<WirdSettings> getSettings() async {
    final prefs = await _prefs;
    final json = prefs.getString(_settingsKey);
    if (json == null) return const WirdSettings();
    return WirdSettings.fromJson(
      Map<String, dynamic>.from(jsonDecode(json)),
    );
  }

  Future<void> updateSettings(WirdSettings settings) async {
    final prefs = await _prefs;
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    if (settings.remindersEnabled && settings.reminderTimes.isNotEmpty) {
      await scheduleReminders();
    } else {
      await cancelAllReminders();
    }
  }

  // ── Daily Progress ───────────────────────────────────────────────────────

  Future<WirdProgress?> getTodayProgress() async {
    final history = await _loadHistory();
    final today = _todayKey();
    try {
      return history.firstWhere((p) => p.dateKey == today);
    } catch (_) {
      return null;
    }
  }

  Future<WirdProgress> recordPagesRead(
    int additionalPages,
    int currentPage,
  ) async {
    final settings = await getSettings();
    var history = await _loadHistory();
    final today = _todayKey();
    final now = DateTime.now();

    WirdProgress todayProgress;
    try {
      todayProgress = history.firstWhere((p) => p.dateKey == today);
    } catch (_) {
      todayProgress = WirdProgress(
        date: now,
        startPage: currentPage,
        currentPage: currentPage,
      );
      history.add(todayProgress);
    }

    final newPagesRead = todayProgress.pagesRead + additionalPages;
    final wasCompleted = todayProgress.isCompleted;
    final nowCompleted = newPagesRead >= settings.dailyPageGoal;

    todayProgress = todayProgress.copyWith(
      pagesRead: newPagesRead,
      currentPage: currentPage,
      isCompleted: nowCompleted,
    );

    // Update history
    history = history.map((p) => p.dateKey == today ? todayProgress : p).toList();
    if (!history.any((p) => p.dateKey == today)) {
      history.add(todayProgress);
    }
    await _saveHistory(history);

    // Streak + stats on first completion
    if (nowCompleted && !wasCompleted) {
      await _incrementStreak();
      final prefs = await _prefs;
      final totalPages = (prefs.getInt(_totalPagesKey) ?? 0) + additionalPages;
      final totalDays = (prefs.getInt(_totalDaysKey) ?? 0) + 1;
      await prefs.setInt(_totalPagesKey, totalPages);
      await prefs.setInt(_totalDaysKey, totalDays);
    } else if (!nowCompleted) {
      // Update total pages even if not completed
      final prefs = await _prefs;
      final totalPages = (prefs.getInt(_totalPagesKey) ?? 0) + additionalPages;
      await prefs.setInt(_totalPagesKey, totalPages);
    }

    return todayProgress;
  }

  Future<void> markDayComplete() async {
    final settings = await getSettings();
    var history = await _loadHistory();
    final today = _todayKey();
    final now = DateTime.now();

    WirdProgress todayProgress;
    try {
      todayProgress = history.firstWhere((p) => p.dateKey == today);
      if (todayProgress.isCompleted) return;
      todayProgress = todayProgress.copyWith(
        pagesRead: settings.dailyPageGoal,
        isCompleted: true,
      );
    } catch (_) {
      todayProgress = WirdProgress(
        date: now,
        pagesRead: settings.dailyPageGoal,
        startPage: 1,
        currentPage: settings.dailyPageGoal,
        isCompleted: true,
      );
      history.add(todayProgress);
    }

    history = history.map((p) => p.dateKey == today ? todayProgress : p).toList();
    if (!history.any((p) => p.dateKey == today)) {
      history.add(todayProgress);
    }
    await _saveHistory(history);

    await _incrementStreak();
    final prefs = await _prefs;
    await prefs.setInt(
      _totalPagesKey,
      (prefs.getInt(_totalPagesKey) ?? 0) + settings.dailyPageGoal,
    );
    await prefs.setInt(
      _totalDaysKey,
      (prefs.getInt(_totalDaysKey) ?? 0) + 1,
    );
  }

  // ── Streak ───────────────────────────────────────────────────────────────

  Future<int> getStreakCount() async {
    await _refreshStreak();
    final prefs = await _prefs;
    return prefs.getInt(_streakCountKey) ?? 0;
  }

  Future<void> _refreshStreak() async {
    final prefs = await _prefs;
    final streakDate = prefs.getString(_streakDateKey);
    if (streakDate == null) return;

    final today = _todayKey();
    final yesterday = _yesterdayKey();

    if (streakDate != today && streakDate != yesterday) {
      await prefs.setInt(_streakCountKey, 0);
    }
  }

  Future<void> _incrementStreak() async {
    final prefs = await _prefs;
    final streakDate = prefs.getString(_streakDateKey);
    final today = _todayKey();

    if (streakDate == today) return;

    final yesterday = _yesterdayKey();
    final currentCount = prefs.getInt(_streakCountKey) ?? 0;

    if (streakDate == yesterday) {
      await prefs.setInt(_streakCountKey, currentCount + 1);
    } else {
      await prefs.setInt(_streakCountKey, 1);
    }
    await prefs.setString(_streakDateKey, today);
  }

  // ── History ──────────────────────────────────────────────────────────────

  Future<List<WirdProgress>> _loadHistory() async {
    final prefs = await _prefs;
    final json = prefs.getString(_historyKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List<dynamic>;
    var history = list.map((e) => WirdProgress.fromJson(Map<String, dynamic>.from(e))).toList();

    // Prune to 90 days
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    history = history.where((p) => p.date.isAfter(cutoff)).toList();
    return history;
  }

  Future<void> _saveHistory(List<WirdProgress> history) async {
    final prefs = await _prefs;
    await prefs.setString(
      _historyKey,
      jsonEncode(history.map((e) => e.toJson()).toList()),
    );
  }

  // ── Full State ───────────────────────────────────────────────────────────

  Future<WirdState> getFullState() async {
    final settings = await getSettings();
    final todayProgress = await getTodayProgress();
    final streakCount = await getStreakCount();
    final prefs = await _prefs;
    return WirdState(
      settings: settings,
      todayProgress: todayProgress,
      streakCount: streakCount,
      streakDate: prefs.getString(_streakDateKey),
      totalPagesRead: prefs.getInt(_totalPagesKey) ?? 0,
      totalDaysCompleted: prefs.getInt(_totalDaysKey) ?? 0,
    );
  }

  // ── Notifications ────────────────────────────────────────────────────────

  Future<void> scheduleReminders() async {
    final settings = await getSettings();
    if (!settings.remindersEnabled || settings.reminderTimes.isEmpty) {
      await cancelAllReminders();
      return;
    }
    await NotificationService.instance.scheduleWirdReminders(
      reminderTimes: settings.reminderTimes,
      dailyPageGoal: settings.dailyPageGoal,
    );
  }

  Future<void> cancelAllReminders() async {
    await NotificationService.instance.cancelWirdReminders();
  }

  // ── Firestore Sync ───────────────────────────────────────────────────────

  Future<void> syncToFirestore(String userId) async {
    try {
      final settings = await getSettings();
      final prefs = await _prefs;
      final doc = FirebaseFirestore.instance.collection('users').doc(userId).collection('wird').doc('data');
      await doc.set({
        'settings': settings.toJson(),
        'streakCount': prefs.getInt(_streakCountKey) ?? 0,
        'streakDate': prefs.getString(_streakDateKey),
        'totalPagesRead': prefs.getInt(_totalPagesKey) ?? 0,
        'totalDaysCompleted': prefs.getInt(_totalDaysKey) ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Wird sync to Firestore error: $e');
    }
  }

  Future<void> syncFromFirestore(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('wird')
          .doc('data')
          .get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final prefs = await _prefs;

      if (data['settings'] != null) {
        await prefs.setString(
          _settingsKey,
          jsonEncode(Map<String, dynamic>.from(data['settings'] as Map)),
        );
      }
      if (data['streakCount'] != null) {
        await prefs.setInt(_streakCountKey, data['streakCount'] as int);
      }
      if (data['streakDate'] != null) {
        await prefs.setString(_streakDateKey, data['streakDate'] as String);
      }
      if (data['totalPagesRead'] != null) {
        await prefs.setInt(_totalPagesKey, data['totalPagesRead'] as int);
      }
      if (data['totalDaysCompleted'] != null) {
        await prefs.setInt(_totalDaysKey, data['totalDaysCompleted'] as int);
      }
    } catch (e) {
      debugPrint('❌ Wird sync from Firestore error: $e');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _yesterdayKey() {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
  }
}
