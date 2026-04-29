import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_app/core/models/quran_models.dart';
import 'package:aura_app/core/services/quran_service.dart';
import 'package:aura_app/core/services/quran_bookmark_service.dart';

final quranDataProvider = FutureProvider<List<Ayah>>((ref) async {
  return QuranService.loadQuranData();
});

final surahListProvider = FutureProvider<List<Surah>>((ref) async {
  return QuranService.getSurahs();
});

final juzListProvider = FutureProvider<List<Juz>>((ref) async {
  return QuranService.getJuzList();
});

final quranBookmarksProvider =
    StateNotifierProvider<QuranBookmarksNotifier, AsyncValue<List<QuranBookmark>>>((ref) {
  return QuranBookmarksNotifier();
});

class QuranBookmarksNotifier extends StateNotifier<AsyncValue<List<QuranBookmark>>> {
  QuranBookmarksNotifier() : super(const AsyncValue.loading()) {
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    try {
      final bookmarks = await QuranBookmarkService.getBookmarks();
      state = AsyncValue.data(bookmarks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addBookmark(QuranBookmark bookmark) async {
    await QuranBookmarkService.addBookmark(bookmark);
    await _loadBookmarks();
  }

  Future<void> removeBookmark(String id) async {
    await QuranBookmarkService.removeBookmark(id);
    await _loadBookmarks();
  }
}

final quranReadingProgressProvider =
    StateNotifierProvider<QuranReadingProgressNotifier, AsyncValue<QuranReadingProgress?>>((ref) {
  return QuranReadingProgressNotifier();
});

class QuranReadingProgressNotifier
    extends StateNotifier<AsyncValue<QuranReadingProgress?>> {
  QuranReadingProgressNotifier() : super(const AsyncValue.loading()) {
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final progress = await QuranBookmarkService.getReadingProgress();
      state = AsyncValue.data(progress);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveProgress(int suraNo, int ayaNo, int page) async {
    final progress = QuranReadingProgress(
      suraNo: suraNo,
      ayaNo: ayaNo,
      page: page,
      lastReadAt: DateTime.now(),
    );
    await QuranBookmarkService.saveReadingProgress(progress);
    state = AsyncValue.data(progress);
  }
}

final quranSearchProvider =
    FutureProvider.family<List<Ayah>, String>((ref, query) async {
  return QuranService.searchAyahs(query);
});

final surahAyahsProvider =
    FutureProvider.family<List<Ayah>, int>((ref, suraNo) async {
  return QuranService.getAyahsBySurah(suraNo);
});
