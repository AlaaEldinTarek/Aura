import 'package:cloud_firestore/cloud_firestore.dart';

/// Lightweight surah metadata for index/listing
class QuranSurahMeta {
  final int number;
  final String nameAr;
  final String nameEn;
  final String nameEnTranslation;
  final String revelationType;
  final int numberOfAyahs;
  final int startPage;
  final int endPage;
  final int startJuz;
  final int endJuz;

  const QuranSurahMeta({
    required this.number,
    required this.nameAr,
    required this.nameEn,
    required this.nameEnTranslation,
    required this.revelationType,
    required this.numberOfAyahs,
    required this.startPage,
    required this.endPage,
    required this.startJuz,
    required this.endJuz,
  });

  factory QuranSurahMeta.fromJson(Map<String, dynamic> json) {
    return QuranSurahMeta(
      number: json['number'] as int,
      nameAr: json['name'] as String,
      nameEn: json['englishName'] as String,
      nameEnTranslation: json['englishNameTranslation'] as String,
      revelationType: json['revelationType'] as String,
      numberOfAyahs: json['numberOfAyahs'] as int,
      startPage: json['startPage'] as int,
      endPage: json['endPage'] as int,
      startJuz: json['startJuz'] as int,
      endJuz: json['endJuz'] as int,
    );
  }

  String name(bool isArabic) => isArabic ? nameAr : nameEn;
}

/// Single ayah with Arabic + English text
class QuranAyah {
  final int number;
  final int numberInSurah;
  final String textAr;
  final String textEn;
  final int juz;
  final int page;
  final int ruku;
  final bool sajda;

  const QuranAyah({
    required this.number,
    required this.numberInSurah,
    required this.textAr,
    required this.textEn,
    required this.juz,
    required this.page,
    required this.ruku,
    required this.sajda,
  });

  factory QuranAyah.fromJson(Map<String, dynamic> json) {
    return QuranAyah(
      number: json['number'] as int,
      numberInSurah: json['numberInSurah'] as int,
      textAr: json['text'] as String,
      textEn: json['translation'] as String,
      juz: json['juz'] as int,
      page: json['page'] as int,
      ruku: json['ruku'] as int? ?? 0,
      sajda: json['sajda'] as bool? ?? false,
    );
  }
}

/// Full surah with metadata and all ayahs
class QuranSurah {
  final QuranSurahMeta meta;
  final List<QuranAyah> ayahs;

  const QuranSurah({required this.meta, required this.ayahs});

  factory QuranSurah.fromJson(Map<String, dynamic> json) {
    return QuranSurah(
      meta: QuranSurahMeta(
        number: json['number'] as int,
        nameAr: json['name'] as String,
        nameEn: json['englishName'] as String,
        nameEnTranslation: json['englishNameTranslation'] as String,
        revelationType: json['revelationType'] as String,
        numberOfAyahs: json['numberOfAyahs'] as int,
        startPage: (json['ayahs'] as List).map((a) => a['page'] as int).reduce((a, b) => a < b ? a : b),
        endPage: (json['ayahs'] as List).map((a) => a['page'] as int).reduce((a, b) => a > b ? a : b),
        startJuz: (json['ayahs'] as List).map((a) => a['juz'] as int).reduce((a, b) => a < b ? a : b),
        endJuz: (json['ayahs'] as List).map((a) => a['juz'] as int).reduce((a, b) => a > b ? a : b),
      ),
      ayahs: (json['ayahs'] as List).map((a) => QuranAyah.fromJson(a as Map<String, dynamic>)).toList(),
    );
  }

  /// Get ayahs for a specific page
  List<QuranAyah> ayahsForPage(int pageNumber) {
    return ayahs.where((a) => a.page == pageNumber).toList();
  }
}

/// Page index entry mapping page to surah/ayah ranges
class QuranPageIndex {
  final int page;
  final int juz;
  final List<QuranPageSurahRange> surahs;

  const QuranPageIndex({required this.page, required this.juz, required this.surahs});

  factory QuranPageIndex.fromJson(Map<String, dynamic> json) {
    return QuranPageIndex(
      page: json['page'] as int,
      juz: json['juz'] as int,
      surahs: (json['surahs'] as List)
          .map((s) => QuranPageSurahRange.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Range of ayahs on a page belonging to one surah
class QuranPageSurahRange {
  final int surah;
  final int startAyah;
  final int endAyah;

  const QuranPageSurahRange({required this.surah, required this.startAyah, required this.endAyah});

  factory QuranPageSurahRange.fromJson(Map<String, dynamic> json) {
    return QuranPageSurahRange(
      surah: json['surah'] as int,
      startAyah: json['startAyah'] as int,
      endAyah: json['endAyah'] as int,
    );
  }
}

/// User bookmark
class QuranBookmark {
  final String? id;
  final int surahNumber;
  final int ayahNumber;
  final int page;
  final String? note;
  final DateTime createdAt;

  const QuranBookmark({
    this.id,
    required this.surahNumber,
    required this.ayahNumber,
    required this.page,
    this.note,
    required this.createdAt,
  });

  QuranBookmark copyWith({String? id, String? note}) {
    return QuranBookmark(
      id: id ?? this.id,
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      page: page,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }

  factory QuranBookmark.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuranBookmark(
      id: doc.id,
      surahNumber: data['surahNumber'] as int,
      ayahNumber: data['ayahNumber'] as int,
      page: data['page'] as int,
      note: data['note'] as String?,
      createdAt: DateTime.parse(data['createdAt'] as String),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'surahNumber': surahNumber,
      'ayahNumber': ayahNumber,
      'page': page,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Reading progress state
class QuranReadingProgress {
  final int currentPage;
  final int totalPagesRead;
  final int khatmahCount;
  final int currentStreak;
  final int longestStreak;
  final String lastReadDate;
  final DateTime? lastReadAt;

  const QuranReadingProgress({
    this.currentPage = 1,
    this.totalPagesRead = 0,
    this.khatmahCount = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastReadDate = '',
    this.lastReadAt,
  });

  double get khatmahProgress => totalPagesRead > 0 ? (totalPagesRead % 604) / 604 : 0;
  int get pagesInCurrentKhatmah => totalPagesRead > 0 ? totalPagesRead % 604 : 0;

  QuranReadingProgress copyWith({
    int? currentPage,
    int? totalPagesRead,
    int? khatmahCount,
    int? currentStreak,
    int? longestStreak,
    String? lastReadDate,
    DateTime? lastReadAt,
  }) {
    return QuranReadingProgress(
      currentPage: currentPage ?? this.currentPage,
      totalPagesRead: totalPagesRead ?? this.totalPagesRead,
      khatmahCount: khatmahCount ?? this.khatmahCount,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastReadDate: lastReadDate ?? this.lastReadDate,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }

  factory QuranReadingProgress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return QuranReadingProgress(
      currentPage: data['currentPage'] as int? ?? 1,
      totalPagesRead: data['totalPagesRead'] as int? ?? 0,
      khatmahCount: data['khatmahCount'] as int? ?? 0,
      currentStreak: data['currentStreak'] as int? ?? 0,
      longestStreak: data['longestStreak'] as int? ?? 0,
      lastReadDate: data['lastReadDate'] as String? ?? '',
      lastReadAt: data['lastReadAt'] != null
          ? DateTime.parse(data['lastReadAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'currentPage': currentPage,
      'totalPagesRead': totalPagesRead,
      'khatmahCount': khatmahCount,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastReadDate': lastReadDate,
      'lastReadAt': lastReadAt?.toIso8601String(),
    };
  }
}

/// Daily reading log
class QuranDailyLog {
  final String date;
  final int pagesRead;
  final int minutesRead;

  const QuranDailyLog({required this.date, this.pagesRead = 0, this.minutesRead = 0});

  QuranDailyLog copyWith({int? pagesRead, int? minutesRead}) {
    return QuranDailyLog(
      date: date,
      pagesRead: pagesRead ?? this.pagesRead,
      minutesRead: minutesRead ?? this.minutesRead,
    );
  }

  factory QuranDailyLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuranDailyLog(
      date: doc.id,
      pagesRead: data['pagesRead'] as int? ?? 0,
      minutesRead: data['minutesRead'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'pagesRead': pagesRead,
      'minutesRead': minutesRead,
    };
  }
}

/// Audio reciter info
class QuranReciter {
  final String id;
  final String nameEn;
  final String nameAr;

  const QuranReciter({required this.id, required this.nameEn, required this.nameAr});

  String name(bool isArabic) => isArabic ? nameAr : nameEn;
}

/// Available reciters
class QuranReciters {
  static const List<QuranReciter> all = [
    QuranReciter(id: 'ar.mahermuaiqly', nameEn: 'Maher Al Muaiqly', nameAr: 'ماهر المعيقلي'),
    QuranReciter(id: 'ar.alafasy', nameEn: 'Mishary Alafasy', nameAr: 'مشاري العفاسي'),
    QuranReciter(id: 'ar.abdurrahmaansudais', nameEn: 'Abdurrahman As-Sudais', nameAr: 'عبدالرحمن السديس'),
    QuranReciter(id: 'ar.husary', nameEn: 'Mahmoud Khalil Al-Husary', nameAr: 'محمود خليل الحصري'),
    QuranReciter(id: 'ar.abdullahbasfar', nameEn: 'Abdullah Basfar', nameAr: 'عبدالله بصفر'),
  ];

  static QuranReciter byId(String id) {
    return all.firstWhere((r) => r.id == id, orElse: () => all.first);
  }
}

/// Audio state for playback
enum QuranAudioState { stopped, loading, playing, paused }

class QuranAudioInfo {
  final QuranAudioState state;
  final String reciterId;
  final int currentAyah;
  final int totalAyahs;
  final int surahNumber;

  const QuranAudioInfo({
    this.state = QuranAudioState.stopped,
    this.reciterId = 'ar.mahermuaiqly',
    this.currentAyah = 0,
    this.totalAyahs = 0,
    this.surahNumber = 0,
  });

  QuranAudioInfo copyWith({
    QuranAudioState? state,
    String? reciterId,
    int? currentAyah,
    int? totalAyahs,
    int? surahNumber,
  }) {
    return QuranAudioInfo(
      state: state ?? this.state,
      reciterId: reciterId ?? this.reciterId,
      currentAyah: currentAyah ?? this.currentAyah,
      totalAyahs: totalAyahs ?? this.totalAyahs,
      surahNumber: surahNumber ?? this.surahNumber,
    );
  }

  double get progress => totalAyahs > 0 ? currentAyah / totalAyahs : 0;
}
