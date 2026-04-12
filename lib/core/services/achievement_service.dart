import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/achievement.dart';
import 'prayer_tracking_service.dart';
import 'dhikr_service.dart';

/// Service for checking and awarding achievements
class AchievementService {
  AchievementService._();

  static final AchievementService _instance = AchievementService._();
  static AchievementService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  /// Check and award any newly earned achievements
  Future<List<Achievement>> checkAndAward({required String userId}) async {
    final newlyEarned = <Achievement>[];

    try {
      // Get already earned achievement IDs
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

      // Check streak-based achievements
      final streak = await PrayerTrackingService.instance.calculateCurrentStreak(userId: userId);

      if (!earnedIds.contains('first_prayer')) {
        // Check if user has any prayer records at all
        final stats = await PrayerTrackingService.instance.getStatistics(
          userId: userId,
          startDate: now.subtract(const Duration(days: 365)),
          endDate: now,
        );
        if (stats.completedOnTime + stats.completedLate > 0) {
          await _award(userId, 'first_prayer', now);
          newlyEarned.add(AchievementDefinitions.all.firstWhere((a) => a.id == 'first_prayer'));
        }
      }

      if (!earnedIds.contains('streak_7') && streak >= 7) {
        await _award(userId, 'streak_7', now);
        newlyEarned.add(AchievementDefinitions.all.firstWhere((a) => a.id == 'streak_7'));
      }

      if (!earnedIds.contains('streak_30') && streak >= 30) {
        await _award(userId, 'streak_30', now);
        newlyEarned.add(AchievementDefinitions.all.firstWhere((a) => a.id == 'streak_30'));
      }

      if (!earnedIds.contains('streak_100') && streak >= 100) {
        await _award(userId, 'streak_100', now);
        newlyEarned.add(AchievementDefinitions.all.firstWhere((a) => a.id == 'streak_100'));
      }

      // Check consistency achievements
      if (!earnedIds.contains('perfect_day')) {
        // Check if today is a perfect day
        final todayData = await PrayerTrackingService.instance.getMonthData(
          userId: userId,
          month: now,
        );
        final today = DateTime(now.year, now.month, now.day);
        final todaySummary = todayData[today];
        if (todaySummary != null && todaySummary.isComplete) {
          await _award(userId, 'perfect_day', now);
          newlyEarned.add(AchievementDefinitions.all.firstWhere((a) => a.id == 'perfect_day'));
        }
      }

      if (!earnedIds.contains('consistency_80')) {
        final stats = await PrayerTrackingService.instance.getStatistics(
          userId: userId,
          startDate: now.subtract(const Duration(days: 30)),
          endDate: now,
        );
        if (stats.completionRate >= 0.8) {
          await _award(userId, 'consistency_80', now);
          newlyEarned.add(AchievementDefinitions.all.firstWhere((a) => a.id == 'consistency_80'));
        }
      }

      if (!earnedIds.contains('prayers_100')) {
        final stats = await PrayerTrackingService.instance.getStatistics(
          userId: userId,
          startDate: now.subtract(const Duration(days: 365)),
          endDate: now,
        );
        if (stats.completedOnTime + stats.completedLate >= 100) {
          await _award(userId, 'prayers_100', now);
          newlyEarned.add(AchievementDefinitions.all.firstWhere((a) => a.id == 'prayers_100'));
        }
      }

      // Check dhikr achievements
      final dhikrStats = await DhikrService.instance.getStatistics(userId: userId);

      if (!earnedIds.contains('dhikr_first') && dhikrStats.totalSessions >= 1) {
        await _award(userId, 'dhikr_first', now);
        newlyEarned.add(AchievementDefinitions.all.firstWhere((a) => a.id == 'dhikr_first'));
      }

      if (!earnedIds.contains('dhikr_50') && dhikrStats.totalSessions >= 50) {
        await _award(userId, 'dhikr_50', now);
        newlyEarned.add(AchievementDefinitions.all.firstWhere((a) => a.id == 'dhikr_50'));
      }

      if (!earnedIds.contains('dhikr_100') && dhikrStats.totalSessions >= 100) {
        await _award(userId, 'dhikr_100', now);
        newlyEarned.add(AchievementDefinitions.all.firstWhere((a) => a.id == 'dhikr_100'));
      }

      if (newlyEarned.isNotEmpty) {
        debugPrint('🏆 ${newlyEarned.length} new achievement(s) earned!');
      }
    } catch (e) {
      debugPrint('❌ Error checking achievements: $e');
    }

    return newlyEarned;
  }

  Future<void> _award(String userId, String achievementId, DateTime earnedAt) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .doc(achievementId)
          .set({
        'id': achievementId,
        'earnedAt': earnedAt.toIso8601String(),
      });
      debugPrint('🏆 Achievement earned: $achievementId');
    } catch (e) {
      debugPrint('❌ Error awarding achievement: $e');
    }
  }

  /// Get count of earned achievements
  Future<int> getEarnedCount({required String userId}) async {
    final achievements = await getEarnedAchievements(userId: userId);
    return achievements.length;
  }
}
