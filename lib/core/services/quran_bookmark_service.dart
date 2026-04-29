import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aura_app/core/models/quran_models.dart';

class QuranBookmarkService {
  static const _bookmarksKey = 'quran_bookmarks';
  static const _progressKey = 'quran_reading_progress';

  static Future<List<QuranBookmark>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_bookmarksKey);
    if (data == null) return [];

    final List<dynamic> jsonList = json.decode(data) as List<dynamic>;
    return jsonList
        .map((e) => QuranBookmark.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> addBookmark(QuranBookmark bookmark) async {
    final bookmarks = await getBookmarks();
    final exists = bookmarks.any((b) => b.id == bookmark.id);
    if (exists) return;

    bookmarks.insert(0, bookmark);
    await _saveBookmarks(bookmarks);
  }

  static Future<void> removeBookmark(String id) async {
    final bookmarks = await getBookmarks();
    bookmarks.removeWhere((b) => b.id == id);
    await _saveBookmarks(bookmarks);
  }

  static Future<bool> isBookmarked(String id) async {
    final bookmarks = await getBookmarks();
    return bookmarks.any((b) => b.id == id);
  }

  static Future<void> _saveBookmarks(List<QuranBookmark> bookmarks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = bookmarks.map((b) => b.toJson()).toList();
    await prefs.setString(_bookmarksKey, json.encode(jsonList));
  }

  static Future<QuranReadingProgress?> getReadingProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_progressKey);
    if (data == null) return null;

    return QuranReadingProgress.fromJson(
        json.decode(data) as Map<String, dynamic>);
  }

  static Future<void> saveReadingProgress(QuranReadingProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_progressKey, json.encode(progress.toJson()));
  }
}
