import 'dart:convert';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wird.dart';
import 'notification_service.dart';
import 'desktop_notification_service.dart';

/// Result of [WirdService.creditPages].
class CreditResult {
  /// True when this call completed the day and so gave today's streak credit.
  final bool grantedStreakCredit;

  /// Today's saved entry after the call.
  final WirdProgress progress;

  const CreditResult({required this.grantedStreakCredit, required this.progress});
}

class WirdService {
  WirdService._({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Test constructor: lets a test control the clock. Production code uses [instance].
  @visibleForTesting
  WirdService.forTesting({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static final WirdService instance = WirdService._();

  /// Every date in this service comes from here, so tests can fix the day.
  final DateTime Function() _now;

  static const _settingsKey = 'wird_settings';
  static const _streakCountKey = 'wird_streak_count';
  static const _streakDateKey = 'wird_streak_date';
  static const _totalPagesKey = 'wird_total_pages_read';
  static const _totalDaysKey = 'wird_total_days_completed';
  static const _historyKey = 'wird_progress_history';
  static const _completedJuzKey = 'wird_completed_juz';
  static const _khatmCountKey = 'wird_khatm_count';
  static const _khatmDatesKey = 'wird_khatm_dates';

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
    _pushToCloud().catchError((e) => debugPrint('⚠️ [WIRD] Cloud sync failed: $e'));
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
    final now = _now();

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

    _pushToCloud().catchError((e) => debugPrint('⚠️ [WIRD] Cloud sync failed: $e'));
    return todayProgress;
  }

  /// Credits [pages] to today's entry for a marker move (or a khatma) and
  /// returns whether the move gave today's streak credit.
  ///
  /// [fromPage] is the marker page before the move; it becomes the entry's
  /// `startPage` when this creates today's entry. [toPage] always becomes
  /// `currentPage`. Until P4b it also mirrors the pages into
  /// `wird_total_pages_read`, so achievements keep working.
  Future<CreditResult> creditPages(
    int pages, {
    required int fromPage,
    required int toPage,
  }) async {
    final settings = await getSettings();
    var history = await _loadHistory();
    final today = _todayKey();

    var entry = history.where((p) => p.dateKey == today).firstOrNull ??
        WirdProgress(date: _now(), startPage: fromPage, currentPage: toPage);

    final wasCompleted = entry.isCompleted;
    final newPagesRead = entry.pagesRead + pages;
    final nowCompleted = newPagesRead >= settings.dailyPageGoal || entry.manualCredit;

    entry = entry.copyWith(
      pagesRead: newPagesRead,
      currentPage: toPage,
      isCompleted: nowCompleted,
    );
    history = [
      for (final p in history)
        if (p.dateKey != today) p,
      entry,
    ];
    await _saveHistory(history);

    final prefs = await _prefs;
    final granted = nowCompleted && !wasCompleted;
    if (granted) {
      await _incrementStreak();
      await prefs.setInt(_totalDaysKey, (prefs.getInt(_totalDaysKey) ?? 0) + 1);
    }
    // Mirror (removed in P4b): same condition as recordPagesRead. The pages are
    // added unless the day was already complete before this call.
    if (!wasCompleted) {
      await prefs.setInt(_totalPagesKey, (prefs.getInt(_totalPagesKey) ?? 0) + pages);
    }

    _pushToCloud().catchError((e) => debugPrint('⚠️ [WIRD] Cloud sync failed: $e'));
    return CreditResult(grantedStreakCredit: granted, progress: entry);
  }

  /// Takes back [pages] from the entry for [dateKey] (an undone marker move).
  /// Does nothing when there is no entry for that date. If [removeCredit] is
  /// true and the day goes from complete to not complete, today's streak
  /// credit and day count are rolled back.
  Future<void> removePages(
    int pages, {
    required String dateKey,
    required bool removeCredit,
    required int restoreCurrentPage,
  }) async {
    final settings = await getSettings();
    var history = await _loadHistory();
    final existing = history.where((p) => p.dateKey == dateKey).firstOrNull;
    if (existing == null) return;

    final wasCompleted = existing.isCompleted;
    final newPagesRead = existing.pagesRead - pages < 0 ? 0 : existing.pagesRead - pages;
    final nowCompleted = newPagesRead >= settings.dailyPageGoal || existing.manualCredit;

    final entry = existing.copyWith(
      pagesRead: newPagesRead,
      currentPage: restoreCurrentPage,
      isCompleted: nowCompleted,
    );
    history = [for (final p in history) p.dateKey == dateKey ? entry : p];
    await _saveHistory(history);

    final prefs = await _prefs;
    if (removeCredit && wasCompleted && !nowCompleted) {
      await _rollbackStreakCredit(prefs, _todayKey());
      final days = (prefs.getInt(_totalDaysKey) ?? 0) - 1;
      await prefs.setInt(_totalDaysKey, days < 0 ? 0 : days);
    }
    // Mirror (removed in P4b).
    final total = (prefs.getInt(_totalPagesKey) ?? 0) - pages;
    await prefs.setInt(_totalPagesKey, total < 0 ? 0 : total);

    _pushToCloud().catchError((e) => debugPrint('⚠️ [WIRD] Cloud sync failed: $e'));
  }

  /// Undoes today's streak credit. Acts only when the streak date is [today].
  /// The day count is changed by the callers, not here.
  Future<void> _rollbackStreakCredit(SharedPreferences prefs, String today) async {
    if (prefs.getString(_streakDateKey) != today) return;
    final count = prefs.getInt(_streakCountKey) ?? 0;
    if (count > 0) await prefs.setInt(_streakCountKey, count - 1);
    if (count <= 1) {
      await prefs.remove(_streakDateKey);
    } else {
      await prefs.setString(_streakDateKey, _yesterdayKey());
    }
  }

  Future<void> markDayComplete() async {
    final settings = await getSettings();
    var history = await _loadHistory();
    final today = _todayKey();
    final now = _now();

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
    _pushToCloud().catchError((e) => debugPrint('⚠️ [WIRD] Cloud sync failed: $e'));
  }

  Future<void> undoComplete() async {
    final settings = await getSettings();
    var history = await _loadHistory();
    final today = _todayKey();

    WirdProgress? todayProgress;
    try {
      todayProgress = history.firstWhere((p) => p.dateKey == today);
    } catch (_) {
      return;
    }

    if (!todayProgress.isCompleted) return;

    final pagesToUndo = todayProgress.pagesRead;

    // Revert history entry
    todayProgress = todayProgress.copyWith(
      pagesRead: 0,
      isCompleted: false,
    );
    history = history.map((p) => p.dateKey == today ? todayProgress! : p).toList();
    await _saveHistory(history);

    // Decrement streak
    final prefs = await _prefs;
    final streakDate = prefs.getString(_streakDateKey);
    if (streakDate == today) {
      final currentCount = prefs.getInt(_streakCountKey) ?? 0;
      if (currentCount > 0) {
        await prefs.setInt(_streakCountKey, currentCount - 1);
      }
      // Roll back streak date to yesterday only if streak was 1 (just started)
      if (currentCount <= 1) {
        await prefs.remove(_streakDateKey);
      } else {
        final y = _now().subtract(const Duration(days: 1));
        await prefs.setString(_streakDateKey, _yesterdayKey());
      }
    }

    // Decrement totals
    final totalPages = (prefs.getInt(_totalPagesKey) ?? 0) - pagesToUndo;
    await prefs.setInt(_totalPagesKey, totalPages < 0 ? 0 : totalPages);
    final totalDays = (prefs.getInt(_totalDaysKey) ?? 0) - 1;
    await prefs.setInt(_totalDaysKey, totalDays < 0 ? 0 : totalDays);
    _pushToCloud().catchError((e) => debugPrint('⚠️ [WIRD] Cloud sync failed: $e'));
  }

  /// Resets ALL Wird progress to zero. Keeps user settings (goal, reminders, linked color).
  Future<void> resetAllProgress() async {
    final prefs = await _prefs;
    await prefs.setInt(_streakCountKey, 0);
    await prefs.remove(_streakDateKey);
    await prefs.setInt(_totalPagesKey, 0);
    await prefs.setInt(_totalDaysKey, 0);
    await prefs.setString(_historyKey, jsonEncode([]));
    await prefs.setString(_completedJuzKey, jsonEncode([]));
    await prefs.setInt(_khatmCountKey, 0);
    await prefs.setString(_khatmDatesKey, jsonEncode([]));
    _pushToCloud().catchError((e) => debugPrint('⚠️ [WIRD] Cloud sync failed: $e'));
  }

  // ── Juz Tracking ────────────────────────────────────────────────────────

  Future<List<int>> getCompletedJuz() async {
    final prefs = await _prefs;
    final json = prefs.getString(_completedJuzKey);
    if (json == null) return [];
    return (jsonDecode(json) as List<dynamic>).map((e) => e as int).toList();
  }

  Future<void> toggleJuzCompleted(int juzNo) async {
    final settings = await getSettings();
    final prefs = await _prefs;

    // Update all-time completed juz
    final completed = (await getCompletedJuz()).toSet();
    final wasCompleted = completed.contains(juzNo);
    if (wasCompleted) {
      completed.remove(juzNo);
    } else {
      completed.add(juzNo);
    }
    await prefs.setString(_completedJuzKey, jsonEncode(completed.toList()..sort()));

    // Update today's progress
    var history = await _loadHistory();
    final today = _todayKey();
    final now = _now();

    WirdProgress todayProgress;
    try {
      todayProgress = history.firstWhere((p) => p.dateKey == today);
    } catch (_) {
      todayProgress = WirdProgress(date: now);
      history.add(todayProgress);
    }

    final juzToday = todayProgress.juzCompletedToday.toList();
    if (wasCompleted) {
      juzToday.remove(juzNo);
    } else {
      if (!juzToday.contains(juzNo)) juzToday.add(juzNo);
    }

    final wasCompletedToday = todayProgress.isCompleted;
    final nowCompleted = juzToday.length >= settings.dailyJuzGoal;

    todayProgress = todayProgress.copyWith(
      juzCompletedToday: juzToday,
      isCompleted: nowCompleted,
    );
    history = history.map((p) => p.dateKey == today ? todayProgress : p).toList();
    await _saveHistory(history);

    // Streak + stats on first daily completion
    if (nowCompleted && !wasCompletedToday) {
      await _incrementStreak();
      await prefs.setInt(_totalDaysKey, (prefs.getInt(_totalDaysKey) ?? 0) + 1);
    } else if (!nowCompleted && wasCompletedToday) {
      // Undo completion if juz removed and now below goal
      final streakDate = prefs.getString(_streakDateKey);
      if (streakDate == today) {
        final count = prefs.getInt(_streakCountKey) ?? 0;
        if (count > 0) await prefs.setInt(_streakCountKey, count - 1);
        if (count <= 1) {
          await prefs.remove(_streakDateKey);
        } else {
          await prefs.setString(_streakDateKey, _yesterdayKey());
        }
      }
      final totalDays = (prefs.getInt(_totalDaysKey) ?? 0) - 1;
      await prefs.setInt(_totalDaysKey, totalDays < 0 ? 0 : totalDays);
    }

    _pushToCloud().catchError((e) => debugPrint('⚠️ [WIRD] Cloud sync failed: $e'));
  }

  // ── Khatma ──────────────────────────────────────────────────────────────

  Future<int> getKhatmCount() async {
    final prefs = await _prefs;
    return prefs.getInt(_khatmCountKey) ?? 0;
  }

  Future<List<String>> getKhatmDates() async {
    final prefs = await _prefs;
    final json = prefs.getString(_khatmDatesKey);
    if (json == null) return [];
    return (jsonDecode(json) as List<dynamic>).map((e) => e as String).toList();
  }

  /// Records a new khatma (increments count, saves date) and returns the new count.
  Future<int> recordKhatma() async {
    final prefs = await _prefs;
    final newCount = (prefs.getInt(_khatmCountKey) ?? 0) + 1;
    await prefs.setInt(_khatmCountKey, newCount);
    final dates = await getKhatmDates();
    dates.add(_todayKey());
    await prefs.setString(_khatmDatesKey, jsonEncode(dates));
    _pushToCloud().catchError((e) => debugPrint('⚠️ [WIRD] Cloud sync failed: $e'));
    return newCount;
  }

  /// Clears all completed juz so the user can start a new khatma cycle.
  Future<void> resetAllJuz() async {
    final prefs = await _prefs;
    await prefs.setString(_completedJuzKey, jsonEncode([]));
    _pushToCloud().catchError((e) => debugPrint('⚠️ [WIRD] Cloud sync failed: $e'));
  }

  // ── Bookmark Sync ───────────────────────────────────────────────────────

  /// Sync bookmark pages with Wird progress.
  /// Returns the number of newly added pages (0 if nothing new).
  Future<int> syncBookmarkPages(Set<int> currentBookmarkPages) async {
    final settings = await getSettings();
    if (settings.linkedBookmarkColor == null) return 0;

    final counted = settings.countedBookmarkPages.toSet();
    final newPages = currentBookmarkPages.difference(counted);
    if (newPages.isEmpty) return 0;

    final newCount = newPages.length;
    final maxPage = newPages.reduce((a, b) => a > b ? a : b);
    await recordPagesRead(newCount, maxPage);

    final updatedCounted = {...counted, ...newPages}.toList()..sort();
    final newSettings = settings.copyWith(countedBookmarkPages: updatedCounted);
    await updateSettings(newSettings);

    return newCount;
  }

  /// Set the linked bookmark color and save initial counted pages.
  Future<void> setLinkedBookmarkColor(String colorName, Set<int> initialPages) async {
    final settings = await getSettings();
    final newSettings = settings.copyWith(
      linkedBookmarkColor: colorName,
      countedBookmarkPages: initialPages.toList()..sort(),
    );
    await updateSettings(newSettings);
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
    final cutoff = _now().subtract(const Duration(days: 90));
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
    final allCompletedJuz = await getCompletedJuz();
    final khatmCount = await getKhatmCount();
    final khatmDates = await getKhatmDates();
    final prefs = await _prefs;
    return WirdState(
      settings: settings,
      todayProgress: todayProgress,
      streakCount: streakCount,
      streakDate: prefs.getString(_streakDateKey),
      totalPagesRead: prefs.getInt(_totalPagesKey) ?? 0,
      totalDaysCompleted: prefs.getInt(_totalDaysKey) ?? 0,
      allCompletedJuz: allCompletedJuz,
      khatmCount: khatmCount,
      khatmDates: khatmDates,
    );
  }

  // ── Notifications ────────────────────────────────────────────────────────

  Future<void> scheduleReminders() async {
    final settings = await getSettings();
    if (!settings.remindersEnabled || settings.reminderTimes.isEmpty) {
      await cancelAllReminders();
      return;
    }
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      await DesktopNotificationService.instance.scheduleWirdReminders(
        reminderTimes: settings.reminderTimes,
        dailyGoal: settings.dailyPageGoal,
        isJuzMode: settings.wirdUnit == WirdUnit.juz,
      );
    } else {
      await NotificationService.instance.scheduleWirdReminders(
        reminderTimes: settings.reminderTimes,
        dailyPageGoal: settings.dailyPageGoal,
      );
    }
  }

  Future<void> cancelAllReminders() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      DesktopNotificationService.instance.cancelWirdReminders();
    } else {
      await NotificationService.instance.cancelWirdReminders();
    }
  }

  // ── Firestore Sync ───────────────────────────────────────────────────────

  Future<void> _pushToCloud() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await syncToFirestore(uid);
  }

  Future<void> syncToFirestore(String userId) async {
    try {
      final settings = await getSettings();
      final completedJuz = await getCompletedJuz();
      final khatmCount = await getKhatmCount();
      final khatmDates = await getKhatmDates();
      final prefs = await _prefs;
      final doc = FirebaseFirestore.instance.collection('users').doc(userId).collection('wird').doc('data');
      await doc.set({
        'settings': settings.toJson(),
        'streakCount': prefs.getInt(_streakCountKey) ?? 0,
        'streakDate': prefs.getString(_streakDateKey),
        'totalPagesRead': prefs.getInt(_totalPagesKey) ?? 0,
        'totalDaysCompleted': prefs.getInt(_totalDaysKey) ?? 0,
        'completedJuz': completedJuz,
        'khatmCount': khatmCount,
        'khatmDates': khatmDates,
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
          .get()
          .timeout(const Duration(seconds: 5));
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
      if (data['completedJuz'] != null) {
        final juzList = (data['completedJuz'] as List<dynamic>).map((e) => e as int).toList();
        await prefs.setString(_completedJuzKey, jsonEncode(juzList));
      }
      if (data['khatmCount'] != null) {
        await prefs.setInt(_khatmCountKey, data['khatmCount'] as int);
      }
      if (data['khatmDates'] != null) {
        final dateList = (data['khatmDates'] as List<dynamic>).map((e) => e as String).toList();
        await prefs.setString(_khatmDatesKey, jsonEncode(dateList));
      }
    } catch (e) {
      debugPrint('❌ Wird sync from Firestore error: $e');
    }
  }

  // ── Stats ────────────────────────────────────────────────────────────────

  /// Pages read for each of the last 7 days (index 0 = 6 days ago, 6 = today).
  Future<List<int>> getWeeklyPageData() async {
    final history = await _loadHistory();
    final map = <String, WirdProgress>{for (final p in history) p.dateKey: p};
    final now = _now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      return map[key]?.pagesRead ?? 0;
    });
  }

  /// Juz completed for each of the last 7 days (index 0 = 6 days ago, 6 = today).
  Future<List<int>> getWeeklyJuzData() async {
    final history = await _loadHistory();
    final map = <String, WirdProgress>{for (final p in history) p.dateKey: p};
    final now = _now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      return map[key]?.juzRead ?? 0;
    });
  }

  /// Best consecutive streak within the stored 90-day history.
  Future<int> getBestStreak() async {
    final history = await _loadHistory();
    if (history.isEmpty) return 0;
    final completed = <String>{
      for (final p in history)
        if (p.isCompleted) p.dateKey,
    };
    int best = 0;
    int current = 0;
    final now = _now();
    for (int i = 89; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      if (completed.contains(key)) {
        current++;
        if (current > best) best = current;
      } else {
        current = 0;
      }
    }
    return best;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _todayKey() {
    final now = _now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _yesterdayKey() {
    final y = _now().subtract(const Duration(days: 1));
    return '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
  }
}
