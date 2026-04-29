import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quran_models.dart';

class QuranReadingService {
  QuranReadingService._();
  static final QuranReadingService instance = QuranReadingService._();

  final _firestore = FirebaseFirestore.instance;

  // SharedPreferences keys
  static const _currentPageKey = 'quran_current_page';
  static const _totalPagesKey = 'quran_total_pages_read';
  static const _khatmahCountKey = 'quran_khatmah_count';
  static const _streakCountKey = 'quran_streak_count';
  static const _streakDateKey = 'quran_streak_date';
  static const _longestStreakKey = 'quran_longest_streak';

  // ─── Reading Progress ──────────────────────────────────────────────

  Future<QuranReadingProgress> getProgress(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentPage = prefs.getInt(_currentPageKey) ?? 1;
    final totalPagesRead = prefs.getInt(_totalPagesKey) ?? 0;
    final khatmahCount = prefs.getInt(_khatmahCountKey) ?? 0;
    final currentStreak = await _getStreak(prefs);
    final longestStreak = prefs.getInt(_longestStreakKey) ?? 0;
    final lastReadDate = prefs.getString(_streakDateKey) ?? '';

    return QuranReadingProgress(
      currentPage: currentPage,
      totalPagesRead: totalPagesRead,
      khatmahCount: khatmahCount,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastReadDate: lastReadDate,
    );
  }

  Future<void> markPageRead(int page, String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final totalPagesRead = (prefs.getInt(_totalPagesKey) ?? 0) + 1;
    var khatmahCount = prefs.getInt(_khatmahCountKey) ?? 0;

    // Check if a khatmah was completed
    if (totalPagesRead % 604 == 0) {
      khatmahCount++;
    }

    await prefs.setInt(_currentPageKey, page);
    await prefs.setInt(_totalPagesKey, totalPagesRead);
    await prefs.setInt(_khatmahCountKey, khatmahCount);

    await _incrementStreak(prefs);

    // Sync to Firestore
    if (userId != null && userId.isNotEmpty) {
      await _syncProgressToFirestore(userId, page, totalPagesRead, khatmahCount);
      await _updateDailyLog(userId, page);
    }
  }

  Future<void> markPagesRead(int fromPage, int toPage, String? userId) async {
    final pagesCount = toPage - fromPage + 1;
    final prefs = await SharedPreferences.getInstance();
    final totalPagesRead = (prefs.getInt(_totalPagesKey) ?? 0) + pagesCount;
    var khatmahCount = prefs.getInt(_khatmahCountKey) ?? 0;

    // Check khatmah completions
    while (totalPagesRead >= (khatmahCount + 1) * 604) {
      khatmahCount++;
    }

    await prefs.setInt(_currentPageKey, toPage);
    await prefs.setInt(_totalPagesKey, totalPagesRead);
    await prefs.setInt(_khatmahCountKey, khatmahCount);

    await _incrementStreak(prefs);

    if (userId != null && userId.isNotEmpty) {
      await _syncProgressToFirestore(userId, toPage, totalPagesRead, khatmahCount);
      await _updateDailyLog(userId, toPage, pagesCount: pagesCount);
    }
  }

  // ─── Streak ────────────────────────────────────────────────────────

  Future<int> _getStreak(SharedPreferences prefs) async {
    final count = prefs.getInt(_streakCountKey) ?? 0;
    final lastDate = prefs.getString(_streakDateKey);
    if (lastDate == null) return 0;

    final today = _todayStr();
    final yesterday = _yesterdayStr();

    if (lastDate != today && lastDate != yesterday) {
      await prefs.setInt(_streakCountKey, 0);
      return 0;
    }
    return count;
  }

  Future<void> _incrementStreak(SharedPreferences prefs) async {
    final today = _todayStr();
    final lastDate = prefs.getString(_streakDateKey);
    if (lastDate == today) return;

    final count = prefs.getInt(_streakCountKey) ?? 0;
    final yesterday = _yesterdayStr();

    final newCount = (lastDate == yesterday) ? count + 1 : 1;
    await prefs.setInt(_streakCountKey, newCount);
    await prefs.setString(_streakDateKey, today);

    final longestStreak = prefs.getInt(_longestStreakKey) ?? 0;
    if (newCount > longestStreak) {
      await prefs.setInt(_longestStreakKey, newCount);
    }
  }

  // ─── Bookmarks ─────────────────────────────────────────────────────

  Future<void> addBookmark(String? userId, QuranBookmark bookmark) async {
    if (userId == null || userId.isEmpty) {
      // Store locally for guests
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = await _getLocalBookmarks(prefs);
      final newBookmark = QuranBookmark(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        surahNumber: bookmark.surahNumber,
        ayahNumber: bookmark.ayahNumber,
        page: bookmark.page,
        note: bookmark.note,
        createdAt: bookmark.createdAt,
      );
      bookmarks.add(newBookmark);
      await _saveLocalBookmarks(prefs, bookmarks);
      return;
    }

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('quran_bookmarks')
        .add(bookmark.toFirestore());
  }

  Future<void> removeBookmark(String? userId, String bookmarkId) async {
    if (userId == null || userId.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = await _getLocalBookmarks(prefs);
      bookmarks.removeWhere((b) => b.id == bookmarkId);
      await _saveLocalBookmarks(prefs, bookmarks);
      return;
    }

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('quran_bookmarks')
        .doc(bookmarkId)
        .delete();
  }

  Future<List<QuranBookmark>> getBookmarks(String? userId) async {
    if (userId == null || userId.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      return _getLocalBookmarks(prefs);
    }

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('quran_bookmarks')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => QuranBookmark.fromFirestore(doc)).toList();
  }

  Stream<List<QuranBookmark>> getBookmarksStream(String? userId) {
    if (userId == null || userId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('quran_bookmarks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => QuranBookmark.fromFirestore(doc)).toList());
  }

  Future<bool> isBookmarked(String? userId, int surahNumber, int ayahNumber) async {
    final bookmarks = await getBookmarks(userId);
    return bookmarks.any((b) => b.surahNumber == surahNumber && b.ayahNumber == ayahNumber);
  }

  // ─── Daily Logs ────────────────────────────────────────────────────

  Future<QuranDailyLog?> getDailyLog(String? userId, String date) async {
    if (userId == null || userId.isEmpty) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('quran_daily_logs')
          .doc(date)
          .get();

      if (!doc.exists) return null;
      return QuranDailyLog.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  Future<List<QuranDailyLog>> getReadingHistory(String? userId, {int days = 30}) async {
    if (userId == null || userId.isEmpty) return [];

    final startDate = DateTime.now().subtract(Duration(days: days));
    final startDateStr = _dateStr(startDate);

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('quran_daily_logs')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDateStr)
          .get();

      return snapshot.docs.map((doc) => QuranDailyLog.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  // ─── Firestore Sync ────────────────────────────────────────────────

  Future<void> _syncProgressToFirestore(String userId, int currentPage, int totalPagesRead, int khatmahCount) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'quran_progress': {
          'currentPage': currentPage,
          'totalPagesRead': totalPagesRead,
          'khatmahCount': khatmahCount,
          'lastReadAt': DateTime.now().toIso8601String(),
        },
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ [QURAN_READING] Failed to sync progress: $e');
    }
  }

  Future<void> _updateDailyLog(String userId, int page, {int pagesCount = 1}) async {
    try {
      final today = _todayStr();
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('quran_daily_logs')
          .doc(today);

      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        await docRef.set({
          'pagesRead': (data['pagesRead'] as int? ?? 0) + pagesCount,
        }, SetOptions(merge: true));
      } else {
        await docRef.set({'pagesRead': pagesCount, 'minutesRead': 0});
      }
    } catch (e) {
      print('❌ [QURAN_READING] Failed to update daily log: $e');
    }
  }

  // ─── Local Bookmark Helpers (guest mode) ───────────────────────────

  static const _bookmarksKey = 'quran_bookmarks_local';

  Future<List<QuranBookmark>> _getLocalBookmarks(SharedPreferences prefs) async {
    final jsonStr = prefs.getString(_bookmarksKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((e) => QuranBookmark(
        id: e['id'] as String?,
        surahNumber: e['surahNumber'] as int,
        ayahNumber: e['ayahNumber'] as int,
        page: e['page'] as int,
        note: e['note'] as String?,
        createdAt: DateTime.parse(e['createdAt'] as String),
      )).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveLocalBookmarks(SharedPreferences prefs, List<QuranBookmark> bookmarks) async {
    final jsonList = bookmarks.map((b) => {
      'id': b.id,
      'surahNumber': b.surahNumber,
      'ayahNumber': b.ayahNumber,
      'page': b.page,
      'note': b.note,
      'createdAt': b.createdAt.toIso8601String(),
    }).toList();
    await prefs.setString(_bookmarksKey, jsonEncode(jsonList));
  }

  // ─── Date Helpers ──────────────────────────────────────────────────

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _yesterdayStr() {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
  }

  String _dateStr(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
