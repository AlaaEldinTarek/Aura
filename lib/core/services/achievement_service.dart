import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement.dart';
import '../models/prayer_record.dart';
import 'prayer_tracking_service.dart';
import 'dhikr_service.dart';
import 'task_service.dart';

/// Service for checking and awarding achievements.
/// Listen to [newAchievements] stream to show UI notifications on unlock.
class AchievementService {
  AchievementService._();

  static final AchievementService _instance = AchievementService._();
  static AchievementService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream emitting each achievement the moment it is earned
  final _controller = StreamController<Achievement>.broadcast();
  Stream<Achievement> get newAchievements => _controller.stream;

  /// Get all earned achievements for a user
  Future<List<Achievement>> getEarnedAchievements({required String userId}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Achievement.earnedFromFirestore(
          data['id'] as String? ?? doc.id,
          DateTime.parse(data['earnedAt'] as String),
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting achievements: $e');
      return [];
    }
  }

  /// Check and award any newly earned achievements.
  /// Returns the list of newly earned achievements this call.
  Future<List<Achievement>> checkAndAward({required String userId}) async {
    final newlyEarned = <Achievement>[];

    try {
      final earnedSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .get();

      final earnedIds = earnedSnapshot.docs.map((doc) {
        final data = doc.data();
        return data['id'] as String? ?? doc.id;
      }).toSet();

      final now = DateTime.now();

      // ── Prayer stats (reused across multiple checks) ───────────────────────
      final stats365 = await PrayerTrackingService.instance.getStatistics(
        userId: userId,
        startDate: now.subtract(const Duration(days: 365)),
        endDate: now,
      );
      final totalPrayers = stats365.completedOnTime + stats365.completedLate;

      // ── first_prayer ───────────────────────────────────────────────────────
      if (!earnedIds.contains('first_prayer') && totalPrayers > 0) {
        await _award(userId, 'first_prayer', now, newlyEarned);
      }

      // ── Prayer streak achievements ─────────────────────────────────────────
      final streak = await PrayerTrackingService.instance
          .calculateCurrentStreak(userId: userId);

      if (!earnedIds.contains('streak_7') && streak >= 7) {
        await _award(userId, 'streak_7', now, newlyEarned);
      }
      if (!earnedIds.contains('streak_30') && streak >= 30) {
        await _award(userId, 'streak_30', now, newlyEarned);
      }
      if (!earnedIds.contains('streak_100') && streak >= 100) {
        await _award(userId, 'streak_100', now, newlyEarned);
      }
      if (!earnedIds.contains('streak_365') && streak >= 365) {
        await _award(userId, 'streak_365', now, newlyEarned);
      }

      // ── perfect_day ───────────────────────────────────────────────────────
      if (!earnedIds.contains('perfect_day')) {
        final todayData = await PrayerTrackingService.instance.getMonthData(
          userId: userId,
          month: now,
        );
        final today = DateTime(now.year, now.month, now.day);
        if (todayData[today]?.isComplete == true) {
          await _award(userId, 'perfect_day', now, newlyEarned);
        }
      }

      // ── consistency_80 ────────────────────────────────────────────────────
      if (!earnedIds.contains('consistency_80')) {
        final stats30 = await PrayerTrackingService.instance.getStatistics(
          userId: userId,
          startDate: now.subtract(const Duration(days: 30)),
          endDate: now,
        );
        if (stats30.completionRate >= 0.8) {
          await _award(userId, 'consistency_80', now, newlyEarned);
        }
      }

      // ── prayers_100 ───────────────────────────────────────────────────────
      if (!earnedIds.contains('prayers_100') && totalPrayers >= 100) {
        await _award(userId, 'prayers_100', now, newlyEarned);
      }

      // ── prayers_500 ──────────────────────────────────────────────────────
      if (!earnedIds.contains('prayers_500') && totalPrayers >= 500) {
        await _award(userId, 'prayers_500', now, newlyEarned);
      }

      // ── perfect_week (7 consecutive perfect days) ────────────────────────
      if (!earnedIds.contains('perfect_week')) {
        if (await _checkPerfectWeek(userId: userId, now: now)) {
          await _award(userId, 'perfect_week', now, newlyEarned);
        }
      }

      // ── on_time_50 (50 on-time prayers total) ─────────────────────────────
      if (!earnedIds.contains('on_time_50') && stats365.completedOnTime >= 50) {
        await _award(userId, 'on_time_50', now, newlyEarned);
      }

      // ── early_bird (Fajr on-time 7 consecutive days) ──────────────────────
      if (!earnedIds.contains('early_bird')) {
        if (await _checkSpecificPrayerStreak(
          userId: userId, prayerName: 'Fajr', requiredDays: 7, now: now,
        )) {
          await _award(userId, 'early_bird', now, newlyEarned);
        }
      }

      // ── night_prayer (Isha on-time 7 consecutive days) ────────────────────
      if (!earnedIds.contains('night_prayer')) {
        if (await _checkSpecificPrayerStreak(
          userId: userId, prayerName: 'Isha', requiredDays: 7, now: now,
        )) {
          await _award(userId, 'night_prayer', now, newlyEarned);
        }
      }

      // ── fajr_streak_30 ───────────────────────────────────────────────────
      if (!earnedIds.contains('fajr_streak_30')) {
        if (await _checkSpecificPrayerStreak(
          userId: userId, prayerName: 'Fajr', requiredDays: 30, now: now,
        )) {
          await _award(userId, 'fajr_streak_30', now, newlyEarned);
        }
      }

      // ── isha_streak_30 ───────────────────────────────────────────────────
      if (!earnedIds.contains('isha_streak_30')) {
        if (await _checkSpecificPrayerStreak(
          userId: userId, prayerName: 'Isha', requiredDays: 30, now: now,
        )) {
          await _award(userId, 'isha_streak_30', now, newlyEarned);
        }
      }

      // ── all_on_time_day (all 5 on-time in one day) ──────────────────────
      if (!earnedIds.contains('all_on_time_day')) {
        if (await _checkAllOnTimeDay(userId: userId, now: now)) {
          await _award(userId, 'all_on_time_day', now, newlyEarned);
        }
      }

      // ── Dhikr achievements ────────────────────────────────────────────────
      final dhikrStats = await DhikrService.instance.getStatistics(userId: userId);

      if (!earnedIds.contains('dhikr_first') && dhikrStats.totalSessions >= 1) {
        await _award(userId, 'dhikr_first', now, newlyEarned);
      }
      if (!earnedIds.contains('dhikr_10') && dhikrStats.totalSessions >= 10) {
        await _award(userId, 'dhikr_10', now, newlyEarned);
      }
      if (!earnedIds.contains('dhikr_50') && dhikrStats.totalSessions >= 50) {
        await _award(userId, 'dhikr_50', now, newlyEarned);
      }
      if (!earnedIds.contains('dhikr_100') && dhikrStats.totalSessions >= 100) {
        await _award(userId, 'dhikr_100', now, newlyEarned);
      }
      if (!earnedIds.contains('dhikr_200') && dhikrStats.totalSessions >= 200) {
        await _award(userId, 'dhikr_200', now, newlyEarned);
      }

      // ── Task achievements ─────────────────────────────────────────────────
      final prefs = await SharedPreferences.getInstance();
      final taskStats = await TaskService.instance.getStatistics(userId: userId);
      final completedTasks = taskStats.completed;

      if (!earnedIds.contains('first_task') && completedTasks >= 1) {
        await _award(userId, 'first_task', now, newlyEarned);
      }
      if (!earnedIds.contains('tasks_10') && completedTasks >= 10) {
        await _award(userId, 'tasks_10', now, newlyEarned);
      }
      if (!earnedIds.contains('tasks_25') && completedTasks >= 25) {
        await _award(userId, 'tasks_25', now, newlyEarned);
      }
      if (!earnedIds.contains('tasks_50') && completedTasks >= 50) {
        await _award(userId, 'tasks_50', now, newlyEarned);
      }
      if (!earnedIds.contains('tasks_100') && completedTasks >= 100) {
        await _award(userId, 'tasks_100', now, newlyEarned);
      }

      // ── task_streak_7 ─────────────────────────────────────────────────────
      if (!earnedIds.contains('task_streak_7')) {
        final taskStreak = prefs.getInt('task_streak_count') ?? 0;
        if (taskStreak >= 7) {
          await _award(userId, 'task_streak_7', now, newlyEarned);
        }
      }

      // ── task_streak_30 ────────────────────────────────────────────────────
      if (!earnedIds.contains('task_streak_30')) {
        final taskStreak = prefs.getInt('task_streak_count') ?? 0;
        if (taskStreak >= 30) {
          await _award(userId, 'task_streak_30', now, newlyEarned);
        }
      }

      // ── Wird achievements ──────────────────────────────────────────────────

      if (!earnedIds.contains('wird_first')) {
        final daysCompleted = prefs.getInt('wird_total_days_completed') ?? 0;
        if (daysCompleted >= 1) {
          await _award(userId, 'wird_first', now, newlyEarned);
        }
      }

      if (!earnedIds.contains('wird_streak_7')) {
        final wirdStreak = prefs.getInt('wird_streak_count') ?? 0;
        if (wirdStreak >= 7) {
          await _award(userId, 'wird_streak_7', now, newlyEarned);
        }
      }

      if (!earnedIds.contains('wird_streak_30')) {
        final wirdStreak = prefs.getInt('wird_streak_count') ?? 0;
        if (wirdStreak >= 30) {
          await _award(userId, 'wird_streak_30', now, newlyEarned);
        }
      }

      if (!earnedIds.contains('wird_khatma')) {
        final totalPages = prefs.getInt('wird_total_pages_read') ?? 0;
        if (totalPages >= 604) {
          await _award(userId, 'wird_khatma', now, newlyEarned);
        }
      }

      if (!earnedIds.contains('wird_streak_100')) {
        final wirdStreak = prefs.getInt('wird_streak_count') ?? 0;
        if (wirdStreak >= 100) {
          await _award(userId, 'wird_streak_100', now, newlyEarned);
        }
      }

      if (!earnedIds.contains('wird_pages_100')) {
        final totalPages = prefs.getInt('wird_total_pages_read') ?? 0;
        if (totalPages >= 100) {
          await _award(userId, 'wird_pages_100', now, newlyEarned);
        }
      }

      if (!earnedIds.contains('wird_pages_300')) {
        final totalPages = prefs.getInt('wird_total_pages_read') ?? 0;
        if (totalPages >= 300) {
          await _award(userId, 'wird_pages_300', now, newlyEarned);
        }
      }

      if (newlyEarned.isNotEmpty) {
        debugPrint('🏆 ${newlyEarned.length} new achievement(s) earned!');
      }
    } catch (e) {
      debugPrint('❌ Error checking achievements: $e');
    }

    return newlyEarned;
  }

  /// Returns true if [prayerName] was recorded on-time for [requiredDays]
  /// consecutive days ending today.
  Future<bool> _checkSpecificPrayerStreak({
    required String userId,
    required String prayerName,
    required int requiredDays,
    required DateTime now,
  }) async {
    try {
      final start = now.subtract(Duration(days: requiredDays - 1));
      final records = await PrayerTrackingService.instance.getPrayersForDateRange(
        userId: userId,
        startDate: start,
        endDate: now,
      );

      for (int i = 0; i < requiredDays; i++) {
        final day = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: i));
        final hasOnTime = records.any((r) =>
            r.prayerName == prayerName &&
            r.status == PrayerStatus.onTime &&
            DateTime(r.date.year, r.date.month, r.date.day) == day);
        if (!hasOnTime) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns true if all 5 prayers were completed for 7 consecutive days.
  Future<bool> _checkPerfectWeek({
    required String userId,
    required DateTime now,
  }) async {
    try {
      const prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
      final start = now.subtract(const Duration(days: 6));
      final records = await PrayerTrackingService.instance.getPrayersForDateRange(
        userId: userId,
        startDate: start,
        endDate: now,
      );

      for (int i = 0; i < 7; i++) {
        final day = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: i));
        for (final prayer in prayerNames) {
          final hasRecord = records.any((r) =>
              r.prayerName == prayer &&
              r.status != PrayerStatus.missed &&
              DateTime(r.date.year, r.date.month, r.date.day) == day);
          if (!hasRecord) return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns true if all 5 prayers were recorded on-time today.
  Future<bool> _checkAllOnTimeDay({
    required String userId,
    required DateTime now,
  }) async {
    try {
      const prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
      final today = DateTime(now.year, now.month, now.day);
      final records = await PrayerTrackingService.instance.getPrayersForDateRange(
        userId: userId,
        startDate: today,
        endDate: now,
      );

      for (final prayer in prayerNames) {
        final hasOnTime = records.any((r) =>
            r.prayerName == prayer &&
            r.status == PrayerStatus.onTime &&
            DateTime(r.date.year, r.date.month, r.date.day) == today);
        if (!hasOnTime) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _award(
    String userId,
    String achievementId,
    DateTime earnedAt,
    List<Achievement> newlyEarned,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .doc(achievementId)
          .set({'id': achievementId, 'earnedAt': earnedAt.toIso8601String()});

      final def = AchievementDefinitions.all.firstWhere(
        (a) => a.id == achievementId,
        orElse: () => Achievement(
          id: achievementId,
          nameEn: achievementId,
          nameAr: achievementId,
          descriptionEn: '',
          descriptionAr: '',
          iconEmoji: '🏅',
          category: AchievementCategory.special,
          threshold: 0,
        ),
      );
      final earned = Achievement(
        id: def.id,
        nameEn: def.nameEn,
        nameAr: def.nameAr,
        descriptionEn: def.descriptionEn,
        descriptionAr: def.descriptionAr,
        iconEmoji: def.iconEmoji,
        category: def.category,
        threshold: def.threshold,
        earnedAt: earnedAt,
      );

      newlyEarned.add(earned);
      _controller.add(earned); // notify UI listeners
      debugPrint('🏆 Achievement earned: $achievementId');
    } catch (e) {
      debugPrint('❌ Error awarding achievement $achievementId: $e');
    }
  }

  Future<int> getEarnedCount({required String userId}) async {
    final achievements = await getEarnedAchievements(userId: userId);
    return achievements.length;
  }
}
