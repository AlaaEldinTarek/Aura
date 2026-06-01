import 'dart:convert';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_record.dart';
import '../models/prayer_time.dart';
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

  // Guest local storage
  static const String _localPrayerRecordsKey = 'guest_prayer_records';
  final List<PrayerRecord> _localPrayerRecords = [];
  bool _localPrayerRecordsLoaded = false;

  bool _isGuest(String userId) => userId == 'guest_user';

  Future<List<PrayerRecord>> _getLocalRecords() async {
    if (!_localPrayerRecordsLoaded) {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_localPrayerRecordsKey);
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List;
        _localPrayerRecords.clear();
        _localPrayerRecords.addAll(
          list.map((e) => PrayerRecord.fromJson(e as Map<String, dynamic>)),
        );
      }
      _localPrayerRecordsLoaded = true;
    }
    return List.unmodifiable(_localPrayerRecords);
  }

  Future<void> _saveLocalRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localPrayerRecordsKey,
      jsonEncode(_localPrayerRecords.map((r) => r.toJson()).toList()),
    );
  }

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
    final normalizedDate = DateTime(date.year, date.month, date.day);

    if (_isGuest(userId)) {
      try {
        await _getLocalRecords();
        _localPrayerRecords.removeWhere(
          (r) => r.prayerName == prayerName && r.date == normalizedDate,
        );
        final record = PrayerRecord(
          id: '${prayerName}_${normalizedDate.millisecondsSinceEpoch}',
          userId: userId,
          prayerName: prayerName,
          date: normalizedDate,
          prayedAt: prayedAt,
          status: status,
          method: method,
          notes: notes,
        );
        _localPrayerRecords.add(record);
        await _saveLocalRecords();
        _updateCache(record);
        NotificationService.instance.cancelPostPrayerCheck(prayerName);
        debugPrint('PrayerTrackingService: Recorded local $prayerName for $date');
        return true;
      } catch (e) {
        debugPrint('PrayerTrackingService: Error recording local prayer - $e');
        return false;
      }
    }

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
        date: normalizedDate,
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

      // Cancel the post-prayer check notification (flutter_local_notifications not initialized on desktop)
      if (kIsWeb || (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux)) {
        NotificationService.instance.cancelPostPrayerCheck(prayerName);
      }

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

  /// Get prayer records for a specific date.
  /// [forceRefresh] bypasses the in-memory cache and queries Firestore directly —
  /// required for cross-device sync (e.g. desktop picking up a prayer marked on phone).
  Future<List<PrayerRecord>> getPrayersForDate({
    required String userId,
    required DateTime date,
    bool forceRefresh = false,
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final dayKey = _getDayKey(userId, date);

    if (_isGuest(userId)) {
      if (!forceRefresh && _dailyCache.containsKey(dayKey)) return _dailyCache[dayKey]!;
      final all = await _getLocalRecords();
      final records = all.where((r) => r.date == normalizedDate).toList();
      if (records.isNotEmpty) _dailyCache[dayKey] = records;
      return records;
    }

    // Check cache first (unless a fresh read is forced)
    if (!forceRefresh && _dailyCache.containsKey(dayKey)) {
      return _dailyCache[dayKey]!;
    }

    try {
      final startOfDay = normalizedDate;
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // forceRefresh → server-first so changes made on another device are picked up
      final source = forceRefresh ? Source.server : Source.serverAndCache;
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('prayer_records')
          .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('date', isLessThan: endOfDay.toIso8601String())
          .get(GetOptions(source: source));

      final records = snapshot.docs.map((doc) => PrayerRecord.fromFirestore(doc)).toList();

      if (records.isNotEmpty) {
        _dailyCache[dayKey] = records;
      } else if (forceRefresh) {
        // Empty on a forced read = another device unmarked everything; clear stale cache
        _dailyCache.remove(dayKey);
      }

      return records;
    } catch (e) {
      debugPrint('PrayerTrackingService: Error getting prayers for date - $e');
      // Fall back to cache if the forced server read failed (e.g. offline)
      return _dailyCache[dayKey] ?? [];
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
    bool forceRefresh = false,
  }) async {
    final records = await getPrayersForDate(userId: userId, date: date, forceRefresh: forceRefresh);

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

      // Deduplicate: keep last recorded status per prayer per day (same as getMonthData).
      // recordPrayer() uses .doc() (auto-ID), so re-recordings create new docs instead of
      // updating existing ones — without dedup the count inflates beyond 5×days.
      final Map<String, Map<String, PrayerStatus>> deduped = {};
      for (final record in records) {
        final dateKey = record.date.toIso8601String();
        deduped.putIfAbsent(dateKey, () => <String, PrayerStatus>{})[record.prayerName] = record.status;
      }

      int completedOnTime = 0;
      int completedLate = 0;
      int missed = 0;

      for (final dayStatuses in deduped.values) {
        for (final status in dayStatuses.values) {
          switch (status) {
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
              break;
          }
        }
      }

      final totalPrayers = completedOnTime + completedLate + missed;
      final completionRate = totalPrayers > 0
          ? (completedOnTime + completedLate) / totalPrayers
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

    if (_isGuest(userId)) {
      final all = await _getLocalRecords();
      final monthRecords = all.where(
        (r) => !r.date.isBefore(startOfMonth) && r.date.isBefore(endOfMonth),
      ).toList();

      final Map<String, List<PrayerRecord>> recordsByDate = {};
      for (final record in monthRecords) {
        recordsByDate.putIfAbsent(record.date.toIso8601String(), () => []).add(record);
      }
      for (final entry in recordsByDate.entries) {
        final date = DateTime.parse(entry.key);
        final Map<String, PrayerStatus> statuses = {};
        for (final record in entry.value) {
          statuses[record.prayerName] = record.status;
        }
        monthlyData[DateTime(date.year, date.month, date.day)] =
            DailyPrayerSummary(date: date, prayers: statuses);
      }
      return monthlyData;
    }

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
    if (_isGuest(userId)) {
      final all = await _getLocalRecords();
      return _streakFromRecords(all);
    }

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

      final records = snapshot.docs.map(PrayerRecord.fromFirestore).toList();
      return _streakFromRecords(records);
    } catch (e) {
      debugPrint('PrayerTrackingService: Error calculating current streak - $e');
      return 0;
    }
  }

  int _streakFromRecords(List<PrayerRecord> records) {
    final now = DateTime.now();
    final Map<String, Set<String>> prayersByDay = {};
    for (final record in records) {
      final dayKey = '${record.date.year}-${record.date.month}-${record.date.day}';
      prayersByDay.putIfAbsent(dayKey, () => {}).add(record.prayerName);
    }

    int streak = 0;
    DateTime checkDate = DateTime(now.year, now.month, now.day);

    while (true) {
      final dayKey = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
      final prayers = prayersByDay[dayKey];
      final isComplete = prayers != null && prayers.length >= 5;

      if (isComplete) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
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
    // Force reload from disk on next guest read
    _localPrayerRecordsLoaded = false;
    _localPrayerRecords.clear();
  }

  /// Delete a prayer record (for undo functionality)
  Future<bool> deletePrayerRecord({
    required String userId,
    required String prayerName,
    required DateTime date,
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    if (_isGuest(userId)) {
      try {
        await _getLocalRecords();
        final before = _localPrayerRecords.length;
        _localPrayerRecords.removeWhere(
          (r) => r.prayerName == prayerName && r.date == normalizedDate,
        );
        if (_localPrayerRecords.length < before) {
          await _saveLocalRecords();
          _removeFromCache(userId, date, prayerName);
          return true;
        }
        return false;
      } catch (e) {
        debugPrint('PrayerTrackingService: Error deleting local prayer - $e');
        return false;
      }
    }

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

  /// Delete prayer records for today where the record was created before
  /// the prayer's Adhan + 20-min window — i.e. impossible to have been created
  /// by a legitimate user action (canMarkPrayer blocks early marking).
  /// Called once per day from the prayer times side-effects block to clean up
  /// any records produced by historical bugs.
  Future<void> cleanupFuturePrayerRecords({
    required String userId,
    required List<PrayerTime> prayerTimes,
  }) async {
    if (_isGuest(userId)) return;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final records = await getPrayersForDate(userId: userId, date: today);
      for (final record in records) {
        final prayer = prayerTimes.where((p) => p.name == record.prayerName).firstOrNull;
        if (prayer == null) continue;
        final windowEnd = prayer.time.add(const Duration(minutes: 20));
        // prayedAt before the window = physically impossible legitimate record
        if (record.prayedAt.isBefore(windowEnd)) {
          await deletePrayerRecord(
            userId: userId,
            prayerName: record.prayerName,
            date: today,
          );
          debugPrint('🧹 Removed invalid prayer record: ${record.prayerName} (prayedAt=${record.prayedAt}, windowEnd=$windowEnd)');
        }
      }
    } catch (e) {
      debugPrint('PrayerTrackingService: cleanupFuturePrayerRecords error - $e');
    }
  }

  /// Dispose
  void dispose() {
    clearCache();
    _isInitialized = false;
  }
}
