import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/prayer_record.dart';
import '../models/achievement.dart';
import 'achievement_service.dart';
import 'notification_service.dart';
import 'prayer_alarm_service.dart';

/// Service for tracking prayer completion
/// Optimized with local caching and batched writes
class PrayerTrackingService {
  PrayerTrackingService._();

  static final PrayerTrackingService _instance = PrayerTrackingService._();
  static PrayerTrackingService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Local cache for performance
  final Map<String, List<PrayerRecord>> _dailyCache = {};

  // Prayer names
  static const List<String> _prayerNames = kPrayerNames;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugPrint('PrayerTrackingService: Initialized');
  }

  /// Record a completed prayer
  Future<bool> recordPrayer({
    required String userId,
    required String prayerName,
    required DateTime date,
    required DateTime prayedAt,
    PrayerStatus status = PrayerStatus.onTime,
    PrayerMethod method = PrayerMethod.congregation,
    String? notes,
  }) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('prayer_records')
          .doc();

      final record = PrayerRecord(
        id: docRef.id,
        userId: userId,
        prayerName: prayerName,
        date: DateTime(date.year, date.month, date.day),
        prayedAt: prayedAt,
        status: status,
        method: method,
        notes: notes,
      );

      await docRef.set(record.toFirestore());

      // Update cache
      _updateCache(record);

      // Check achievements in background (don't block)
      AchievementService.instance.checkAndAward(userId: userId);

      // Cancel the post-prayer check notification since user already logged it
      NotificationService.instance.cancelPostPrayerCheck(prayerName);

      // Mark prayer as tracked in native SharedPreferences so the 30-min check sees it
      try {
        const notificationIds = {
          'Fajr': 1001, 'Sunrise': 1002, 'Zuhr': 1003,
          'Asr': 1004, 'Maghrib': 1005, 'Isha': 1006,
        };
        await PrayerAlarmService.instance.markPrayerTracked(
          prayerName: prayerName,
          status: status.value,
        );
        await PrayerAlarmService.instance.cancelPostPrayerCheck(
          prayerName: prayerName,
          requestCode: notificationIds[prayerName] ?? 1000,
        );
      } catch (e) {
        debugPrint('PrayerTrackingService: Error marking native prayer tracked - $e');
      }

      debugPrint('PrayerTrackingService: Recorded $prayerName for $date');
      return true;
    } catch (e) {
      debugPrint('PrayerTrackingService: Error recording prayer - $e');
      return false;
    }
  }

  /// Get prayer records for a specific date
  Future<List<PrayerRecord>> getPrayersForDate({
    required String userId,
    required DateTime date,
  }) async {
    final dayKey = _getDayKey(userId, date);

    // Check cache first
    if (_dailyCache.containsKey(dayKey)) {
      return _dailyCache[dayKey]!;
    }

    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('prayer_records')
          .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('date', isLessThan: endOfDay.toIso8601String())
          .get(const GetOptions(source: Source.serverAndCache));

      final records = snapshot.docs.map((doc) => PrayerRecord.fromFirestore(doc)).toList();

      // Cache the results
      _dailyCache[dayKey] = records;

      return records;
    } catch (e) {
      debugPrint('PrayerTrackingService: Error getting prayers for date - $e');
      return [];
    }
  }

  /// Get prayer records for a date range
  Future<List<PrayerRecord>> getPrayersForDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day)
          .add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('prayer_records')
          .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('date', isLessThan: endOfDay.toIso8601String())
          .get(const GetOptions(source: Source.serverAndCache));

      return snapshot.docs.map((doc) => PrayerRecord.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('PrayerTrackingService: Error getting prayers for range - $e');
      return [];
    }
  }

  /// Get daily summary for a date
  Future<DailyPrayerSummary> getDailySummary({
    required String userId,
    required DateTime date,
  }) async {
    final records = await getPrayersForDate(userId: userId, date: date);

    final Map<String, PrayerStatus> prayerStatuses = {};

    // Only add prayers that have actual records
    for (final record in records) {
      prayerStatuses[record.prayerName] = record.status;
    }

    return DailyPrayerSummary(
      date: DateTime(date.year, date.month, date.day),
      prayers: prayerStatuses,
    );
  }

  /// Get prayer statistics for a date range
  Future<PrayerStatistics> getStatistics({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day).add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('prayer_records')
          .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('date', isLessThan: endOfDay.toIso8601String())
          .orderBy('date', descending: false)
          .get();

      final records = snapshot.docs.map((doc) => PrayerRecord.fromFirestore(doc)).toList();

      int completedOnTime = 0;
      int completedLate = 0;
      int missed = 0;

      for (final record in records) {
        switch (record.status) {
          case PrayerStatus.onTime:
            completedOnTime++;
            break;
          case PrayerStatus.late:
            completedLate++;
            break;
          case PrayerStatus.missed:
            missed++;
            break;
          case PrayerStatus.excused:
            // Don't count as missed
            break;
        }
      }

      final totalPrayers = completedOnTime + completedLate + missed;
      final completionRate = totalPrayers > 0
          ? ((completedOnTime + completedLate) / totalPrayers) as double
          : 0.0;

      // Calculate streaks
      final currentStreak = await calculateCurrentStreak(userId: userId);
      final bestStreak = await _calculateBestStreak(userId: userId);

      return PrayerStatistics(
        totalPrayers: totalPrayers,
        completedOnTime: completedOnTime,
        completedLate: completedLate,
        missed: missed,
        currentStreak: currentStreak,
        bestStreak: bestStreak,
        completionRate: completionRate,
      );
    } catch (e) {
      debugPrint('PrayerTrackingService: Error getting statistics - $e');
      return PrayerStatistics.empty();
    }
  }

  /// Get calendar data for a month
  Future<Map<DateTime, DailyPrayerSummary>> getMonthData({
    required String userId,
    required DateTime month,
  }) async {
    final Map<DateTime, DailyPrayerSummary> monthlyData = {};

    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 1);

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('prayer_records')
          .where('date', isGreaterThanOrEqualTo: startOfMonth.toIso8601String())
          .where('date', isLessThan: endOfMonth.toIso8601String())
          .get(const GetOptions(source: Source.serverAndCache));

      // Group by date
      final Map<String, List<PrayerRecord>> recordsByDate = {};
      for (final doc in snapshot.docs) {
        final record = PrayerRecord.fromFirestore(doc);
        final dateKey = record.date.toIso8601String();
        recordsByDate.putIfAbsent(dateKey, () => []).add(record);
      }

      // Create summaries for each day
      for (final entry in recordsByDate.entries) {
        final date = DateTime.parse(entry.key);
        final records = entry.value;

        final Map<String, PrayerStatus> prayerStatuses = {};
        for (final prayerName in _prayerNames) {
          prayerStatuses[prayerName] = PrayerStatus.missed;
        }

        for (final record in records) {
          prayerStatuses[record.prayerName] = record.status;
        }

        monthlyData[DateTime(date.year, date.month, date.day)] = DailyPrayerSummary(
          date: date,
          prayers: prayerStatuses,
        );
      }

      return monthlyData;
    } catch (e) {
      debugPrint('PrayerTrackingService: Error getting month data - $e');
      return {};
    }
  }

  /// Calculate current streak of completed prayers
  /// Optimized: single Firestore query instead of one per day
  Future<int> calculateCurrentStreak({required String userId}) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 365));
      final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);

      // Single query to get all records from the past year
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('prayer_records')
          .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .get(const GetOptions(source: Source.serverAndCache));

      // Group records by day
      final Map<String, Set<String>> prayersByDay = {};
      for (final doc in snapshot.docs) {
        final record = PrayerRecord.fromFirestore(doc);
        final dayKey = '${record.date.year}-${record.date.month}-${record.date.day}';
        prayersByDay.putIfAbsent(dayKey, () => {}).add(record.prayerName);
      }

      // Count consecutive complete days from today going backwards
      int streak = 0;
      DateTime checkDate = DateTime(now.year, now.month, now.day);

      while (true) {
        final dayKey = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
        final prayers = prayersByDay[dayKey];

        // A day is complete if all 5 prayers are recorded
        final isComplete = prayers != null && prayers.length >= 5;

        if (isComplete) {
          streak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          // Allow today to not be complete yet
          final today = DateTime(now.year, now.month, now.day);
          if (checkDate == today) {
            checkDate = checkDate.subtract(const Duration(days: 1));
            continue;
          }
          break;
        }

        if (streak > 365) break;
      }

      return streak;
    } catch (e) {
      debugPrint('PrayerTrackingService: Error calculating current streak - $e');
      return 0;
    }
  }

  /// Calculate best streak ever (counts consecutive complete days, not individual records)
  Future<int> _calculateBestStreak({required String userId}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('prayer_records')
          .orderBy('date', descending: false)
          .limit(5000)
          .get();

      if (snapshot.docs.isEmpty) return 0;

      // Group records by day, collect unique prayer names per day
      final Map<String, Set<String>> prayersByDay = {};
      for (final doc in snapshot.docs) {
        final record = PrayerRecord.fromFirestore(doc);
        final dayKey = '${record.date.year}-${record.date.month}-${record.date.day}';
        prayersByDay.putIfAbsent(dayKey, () => {}).add(record.prayerName);
      }

      // Build sorted list of dates that are complete (all 5 prayers)
      final completeDays = <DateTime>[];
      for (final entry in prayersByDay.entries) {
        if (entry.value.length >= 5) {
          final parts = entry.key.split('-');
          completeDays.add(DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          ));
        }
      }
      completeDays.sort();

      if (completeDays.isEmpty) return 0;

      // Find longest consecutive run
      int bestStreak = 1;
      int currentStreak = 1;
      for (int i = 1; i < completeDays.length; i++) {
        final diff = completeDays[i].difference(completeDays[i - 1]).inDays;
        if (diff == 1) {
          currentStreak++;
          if (currentStreak > bestStreak) bestStreak = currentStreak;
        } else if (diff > 1) {
          currentStreak = 1;
        }
      }

      return bestStreak;
    } catch (e) {
      debugPrint('PrayerTrackingService: Error calculating best streak - $e');
      return 0;
    }
  }

  /// Update local cache
  void _updateCache(PrayerRecord record) {
    final dayKey = _getDayKey(record.userId, record.date);
    _dailyCache.putIfAbsent(dayKey, () => []).add(record);
  }

  /// Remove a specific prayer record from cache (instead of clearing entire day)
  void _removeFromCache(String userId, DateTime date, String prayerName) {
    final dayKey = _getDayKey(userId, date);
    final cached = _dailyCache[dayKey];
    if (cached != null) {
      cached.removeWhere((r) => r.prayerName == prayerName);
      if (cached.isEmpty) {
        _dailyCache.remove(dayKey);
      }
    }
  }

  /// Get cache key for a day
  String _getDayKey(String userId, DateTime date) {
    return '${userId}_${date.year}_${date.month}_${date.day}';
  }

  /// Clear cache
  void clearCache() {
    _dailyCache.clear();
  }

  /// Delete a prayer record (for undo functionality)
  Future<bool> deletePrayerRecord({
    required String userId,
    required String prayerName,
    required DateTime date,
  }) async {
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final dateStr = normalizedDate.toIso8601String();

      debugPrint('🗑️ [DELETE] Looking for $prayerName with date=$dateStr for user $userId');

      // Simple query: just filter by prayerName (equality only, no composite index needed)
      // Then filter by date client-side
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('prayer_records')
          .where('prayerName', isEqualTo: prayerName)
          .get();

      debugPrint('🗑️ [DELETE] Found ${snapshot.docs.length} records for $prayerName');

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final storedDate = data['date'] as String?;
        debugPrint('🗑️ [DELETE] Checking doc ${doc.id}: storedDate=$storedDate, targetDate=$dateStr');

        if (storedDate == dateStr) {
          await doc.reference.delete();
          _removeFromCache(userId, date, prayerName);
          debugPrint('🗑️ [DELETE] Successfully deleted $prayerName for $dateStr');
          return true;
        }
      }

      debugPrint('🗑️ [DELETE] No matching record found for $prayerName on $dateStr');
      return false;
    } catch (e) {
      debugPrint('PrayerTrackingService: Error deleting prayer record - $e');

      // Fallback: fetch all records and filter completely client-side
      try {
        debugPrint('🗑️ [DELETE] Trying fallback: fetch all and filter...');
        final dateStr = DateTime(date.year, date.month, date.day).toIso8601String();

        final allSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('prayer_records')
            .get();

        for (final doc in allSnapshot.docs) {
          final data = doc.data();
          if (data['prayerName'] == prayerName && data['date'] == dateStr) {
            await doc.reference.delete();
            _removeFromCache(userId, date, prayerName);
            debugPrint('🗑️ [DELETE] Deleted via fallback');
            return true;
          }
        }
      } catch (e2) {
        debugPrint('PrayerTrackingService: Fallback also failed - $e2');
      }

      return false;
    }
  }

  /// Dispose
  void dispose() {
    clearCache();
    _isInitialized = false;
  }
}
