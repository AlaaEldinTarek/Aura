import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/quran_models.dart';

class QuranDataService {
  QuranDataService._();
  static final QuranDataService instance = QuranDataService._();

  List<QuranSurahMeta>? _surahsMeta;
  List<QuranPageIndex>? _pageIndex;
  final Map<int, QuranSurah> _surahCache = {};

  Future<void> initialize() async {
    await loadSurahsMeta();
    await loadPageIndex();
    debugPrint('✅ [QURAN_DATA] Initialized: ${_surahsMeta?.length} surahs, ${_pageIndex?.length} pages');
  }

  /// Load lightweight surah metadata index
  Future<List<QuranSurahMeta>> loadSurahsMeta() async {
    if (_surahsMeta != null) return _surahsMeta!;

    try {
      final jsonStr = await rootBundle.loadString('assets/data/quran/surahs_meta.json');
      final List<dynamic> jsonList = json.decode(jsonStr);
      _surahsMeta = jsonList.map((e) => QuranSurahMeta.fromJson(e as Map<String, dynamic>)).toList();
      return _surahsMeta!;
    } catch (e) {
      debugPrint('❌ [QURAN_DATA] Failed to load surahs meta: $e');
      return [];
    }
  }

  /// Load page index for page-based navigation
  Future<List<QuranPageIndex>> loadPageIndex() async {
    if (_pageIndex != null) return _pageIndex!;

    try {
      final jsonStr = await rootBundle.loadString('assets/data/quran/page_index.json');
      final List<dynamic> jsonList = json.decode(jsonStr);
      _pageIndex = jsonList.map((e) => QuranPageIndex.fromJson(e as Map<String, dynamic>)).toList();
      return _pageIndex!;
    } catch (e) {
      debugPrint('❌ [QURAN_DATA] Failed to load page index: $e');
      return [];
    }
  }

  /// Load full surah data (Arabic + English)
  Future<QuranSurah?> loadSurah(int number) async {
    if (number < 1 || number > 114) return null;
    if (_surahCache.containsKey(number)) return _surahCache[number]!;

    try {
      final padded = number.toString().padLeft(3, '0');
      final jsonStr = await rootBundle.loadString('assets/data/quran/surahs/$padded.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonStr);
      final surah = QuranSurah.fromJson(jsonMap);
      _surahCache[number] = surah;
      return surah;
    } catch (e) {
      debugPrint('❌ [QURAN_DATA] Failed to load surah $number: $e');
      return null;
    }
  }

  /// Get all ayahs on a specific page (1-604)
  Future<List<QuranAyah>> loadPage(int pageNumber) async {
    if (pageNumber < 1 || pageNumber > 604) return [];

    final index = await loadPageIndex();
    if (pageNumber > index.length) return [];

    final pageEntry = index[pageNumber - 1];
    final List<QuranAyah> pageAyahs = [];

    for (final range in pageEntry.surahs) {
      final surah = await loadSurah(range.surah);
      if (surah == null) continue;

      for (final ayah in surah.ayahs) {
        if (ayah.numberInSurah >= range.startAyah && ayah.numberInSurah <= range.endAyah) {
          pageAyahs.add(ayah);
        }
      }
    }

    return pageAyahs;
  }

  /// Get surah metadata by number (fast, no asset loading)
  QuranSurahMeta? getSurahMeta(int number) {
    if (_surahsMeta == null || number < 1 || number > 114) return null;
    return _surahsMeta![number - 1];
  }

  /// Get page index entry for a page number
  QuranPageIndex? getPageEntry(int pageNumber) {
    if (_pageIndex == null || pageNumber < 1 || pageNumber > _pageIndex!.length) return null;
    return _pageIndex![pageNumber - 1];
  }

  /// Get the surah number that starts on a given page
  int? getSurahStartingOnPage(int pageNumber) {
    final entry = getPageEntry(pageNumber);
    if (entry == null || entry.surahs.isEmpty) return null;
    // Check if first surah on this page starts at ayah 1
    final firstRange = entry.surahs.first;
    if (firstRange.startAyah == 1) return firstRange.surah;
    return null;
  }

  /// Get surah meta for a specific ayah on a page (used for surah headers)
  QuranSurahMeta? getSurahMetaForPage(int page, int numberInSurah) {
    final entry = getPageEntry(page);
    if (entry == null) return null;
    for (final range in entry.surahs) {
      if (numberInSurah >= range.startAyah && numberInSurah <= range.endAyah) {
        return getSurahMeta(range.surah);
      }
    }
    return null;
  }

  void debugPrint(String message) {
    print(message);
  }

  /// Clear cache (for memory management)
  void clearCache() {
    _surahCache.clear();
  }

  /// Preload surahs in a range (e.g., nearby pages for smooth scrolling)
  Future<void> preloadSurahs(List<int> surahNumbers) async {
    for (final n in surahNumbers) {
      if (!_surahCache.containsKey(n)) {
        await loadSurah(n);
      }
    }
  }
}
