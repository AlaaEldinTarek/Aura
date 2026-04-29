import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:aura_app/core/models/quran_models.dart';

class QuranService {
  static List<Ayah>? _cachedAyahs;
  static List<Surah>? _cachedSurahs;
  static List<Juz>? _cachedJuzList;

  static Future<void> initialize() async {
    await loadQuranData();
  }

  static Future<List<Ayah>> loadQuranData() async {
    if (_cachedAyahs != null) return _cachedAyahs!;

    final String jsonString =
        await rootBundle.loadString('assets/data/quran_hafs.json');
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

    _cachedAyahs =
        jsonList.map((e) => Ayah.fromJson(e as Map<String, dynamic>)).toList();
    return _cachedAyahs!;
  }

  static List<Ayah> get ayahs => _cachedAyahs ?? [];

  static Future<List<Surah>> getSurahs() async {
    if (_cachedSurahs != null) return _cachedSurahs!;

    final allAyahs = await loadQuranData();
    final Map<int, List<Ayah>> surahMap = {};

    for (final ayah in allAyahs) {
      surahMap.putIfAbsent(ayah.suraNo, () => []).add(ayah);
    }

    _cachedSurahs = kSurahMetaData.map((meta) {
      final ayahs = surahMap[meta.suraNo] ?? [];
      return Surah(meta: meta, ayahs: ayahs);
    }).toList();

    return _cachedSurahs!;
  }

  static Future<List<Ayah>> getAyahsBySurah(int suraNo) async {
    final surahs = await getSurahs();
    if (suraNo < 1 || suraNo > surahs.length) return [];
    return surahs[suraNo - 1].ayahs;
  }

  static Future<List<Ayah>> getAyahsByJuz(int juzNo) async {
    final allAyahs = await loadQuranData();
    return allAyahs.where((a) => a.jozz == juzNo).toList();
  }

  static Future<List<Ayah>> getAyahsByPage(int page) async {
    final allAyahs = await loadQuranData();
    return allAyahs.where((a) => a.page == page).toList();
  }

  static Future<List<Juz>> getJuzList() async {
    if (_cachedJuzList != null) return _cachedJuzList!;

    final allAyahs = await loadQuranData();
    final Map<int, Ayah> firstAyahPerJuz = {};

    for (final ayah in allAyahs) {
      firstAyahPerJuz.putIfAbsent(ayah.jozz, () => ayah);
    }

    // Standard juz page ranges
    const juzPages = [
      (1, 21), (22, 41), (42, 61), (62, 81), (82, 101),
      (102, 121), (122, 141), (142, 161), (162, 181), (182, 201),
      (202, 221), (222, 241), (242, 261), (262, 281), (282, 301),
      (302, 321), (322, 341), (342, 361), (362, 381), (382, 401),
      (402, 421), (422, 441), (442, 461), (462, 481), (482, 501),
      (502, 521), (522, 541), (542, 561), (562, 581), (582, 604),
    ];

    _cachedJuzList = List.generate(30, (i) {
      final first = firstAyahPerJuz[i + 1]!;
      return Juz(
        juzNo: i + 1,
        startPage: juzPages[i].$1,
        endPage: juzPages[i].$2,
        firstSurahNameAr: first.suraNameAr,
        firstSurahNameEn: first.suraNameEn,
      );
    });

    return _cachedJuzList!;
  }

  static Future<List<Ayah>> searchAyahs(String query) async {
    if (query.trim().isEmpty) return [];
    final allAyahs = await loadQuranData();
    final lowerQuery = query.trim();
    return allAyahs
        .where((a) => a.ayaTextEmlaey.contains(lowerQuery))
        .toList();
  }

  static SurahMetaData? getSurahMeta(int suraNo) {
    if (suraNo < 1 || suraNo > kSurahMetaData.length) return null;
    return kSurahMetaData[suraNo - 1];
  }

  static List<Juz>? getJuzListSync() => _cachedJuzList;

  static int getPageForSurahAya(int suraNo, int ayaNo) {
    if (_cachedAyahs == null) return 1;
    for (final a in _cachedAyahs!) {
      if (a.suraNo == suraNo && a.ayaNo == ayaNo) return a.page;
    }
    final meta = getSurahMeta(suraNo);
    return meta?.startPage ?? 1;
  }
}
