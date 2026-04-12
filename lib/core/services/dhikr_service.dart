import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/dhikr.dart';

/// Service for tracking dhikr (tasbeeh) sessions
class DhikrService {
  DhikrService._();

  static final DhikrService _instance = DhikrService._();
  static DhikrService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Record a completed dhikr session
  Future<bool> recordSession({
    required String userId,
    required String dhikrText,
    required int count,
    required int target,
  }) async {
    try {
      final now = DateTime.now();
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('dhikr_sessions')
          .doc();

      final session = DhikrSession(
        id: docRef.id,
        userId: userId,
        dhikrText: dhikrText,
        count: count,
        target: target,
        createdAt: now,
        completedAt: now,
      );

      await docRef.set(session.toFirestore());
      debugPrint('📿 Dhikr session recorded: $dhikrText x$count');
      return true;
    } catch (e) {
      debugPrint('❌ Error recording dhikr session: $e');
      return false;
    }
  }

  /// Get dhikr sessions for a date range
  Future<List<DhikrSession>> getSessionsForDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('dhikr_sessions')
          .where('createdAt', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('createdAt', isLessThanOrEqualTo: endDate.toIso8601String())
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => DhikrSession.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error getting dhikr sessions: $e');
      return [];
    }
  }

  /// Get dhikr statistics
  Future<DhikrStatistics> getStatistics({required String userId}) async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('dhikr_sessions')
          .where('createdAt', isGreaterThanOrEqualTo: thirtyDaysAgo.toIso8601String())
          .get();

      final sessions = snapshot.docs.map((doc) => DhikrSession.fromFirestore(doc)).toList();

      int totalDhikrCount = 0;
      int todayCount = 0;
      final today = DateTime(now.year, now.month, now.day);

      for (final session in sessions) {
        totalDhikrCount += session.count;
        final sessionDate = DateTime(
          session.createdAt.year,
          session.createdAt.month,
          session.createdAt.day,
        );
        if (sessionDate == today) {
          todayCount += session.count;
        }
      }

      // Calculate streak
      int streakDays = 0;
      final allSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('dhikr_sessions')
          .orderBy('createdAt', descending: true)
          .limit(365)
          .get();

      final allSessions = allSnapshot.docs.map((doc) => DhikrSession.fromFirestore(doc)).toList();

      if (allSessions.isNotEmpty) {
        final Set<String> daysWithDhikr = {};
        for (final s in allSessions) {
          daysWithDhikr.add('${s.createdAt.year}-${s.createdAt.month}-${s.createdAt.day}');
        }

        DateTime checkDay = today;
        // Check if today has a session, if not start from yesterday
        if (!daysWithDhikr.contains('${checkDay.year}-${checkDay.month}-${checkDay.day}')) {
          checkDay = checkDay.subtract(const Duration(days: 1));
        }

        while (daysWithDhikr.contains('${checkDay.year}-${checkDay.month}-${checkDay.day}')) {
          streakDays++;
          checkDay = checkDay.subtract(const Duration(days: 1));
        }
      }

      return DhikrStatistics(
        totalSessions: sessions.length,
        totalDhikrCount: totalDhikrCount,
        todayCount: todayCount,
        streakDays: streakDays,
      );
    } catch (e) {
      debugPrint('❌ Error getting dhikr statistics: $e');
      return DhikrStatistics.empty();
    }
  }

  /// Get recent sessions (last 10)
  Future<List<DhikrSession>> getRecentSessions({required String userId, int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('dhikr_sessions')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => DhikrSession.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error getting recent dhikr sessions: $e');
      return [];
    }
  }
}
