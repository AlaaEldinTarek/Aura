import 'package:equatable/equatable.dart';

enum RevelationType { makki, madani }

class Ayah extends Equatable {
  final int id;
  final int jozz;
  final int suraNo;
  final String suraNameEn;
  final String suraNameAr;
  final int page;
  final int lineStart;
  final int lineEnd;
  final int ayaNo;
  final String ayaText;
  final String ayaTextEmlaey;

  const Ayah({
    required this.id,
    required this.jozz,
    required this.suraNo,
    required this.suraNameEn,
    required this.suraNameAr,
    required this.page,
    required this.lineStart,
    required this.lineEnd,
    required this.ayaNo,
    required this.ayaText,
    required this.ayaTextEmlaey,
  });

  factory Ayah.fromJson(Map<String, dynamic> json) => Ayah(
        id: json['id'] as int,
        jozz: json['jozz'] as int,
        suraNo: json['sura_no'] as int,
        suraNameEn: json['sura_name_en'] as String,
        suraNameAr: json['sura_name_ar'] as String,
        page: json['page'] as int,
        lineStart: json['line_start'] as int,
        lineEnd: json['line_end'] as int,
        ayaNo: json['aya_no'] as int,
        ayaText: json['aya_text'] as String,
        ayaTextEmlaey: json['aya_text_emlaey'] as String,
      );

  @override
  List<Object?> get props => [id];
}

class SurahMetaData extends Equatable {
  final int suraNo;
  final String nameEn;
  final String nameAr;
  final int ayahCount;
  final RevelationType revelationType;
  final int startPage;
  final int endPage;

  const SurahMetaData(
    this.suraNo,
    this.nameEn,
    this.nameAr,
    this.ayahCount,
    this.revelationType,
    this.startPage,
    this.endPage,
  );

  @override
  List<Object?> get props => [suraNo];
}

class Surah {
  final SurahMetaData meta;
  final List<Ayah> ayahs;

  const Surah({required this.meta, required this.ayahs});
}

class Juz {
  final int juzNo;
  final int startPage;
  final int endPage;
  final String firstSurahNameAr;
  final String firstSurahNameEn;

  const Juz({
    required this.juzNo,
    required this.startPage,
    required this.endPage,
    required this.firstSurahNameAr,
    required this.firstSurahNameEn,
  });
}

class QuranBookmark extends Equatable {
  final String id;
  final int suraNo;
  final int ayaNo;
  final int page;
  final String suraNameAr;
  final String suraNameEn;
  final String ayaText;
  final DateTime createdAt;

  const QuranBookmark({
    required this.id,
    required this.suraNo,
    required this.ayaNo,
    required this.page,
    required this.suraNameAr,
    required this.suraNameEn,
    required this.ayaText,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'suraNo': suraNo,
        'ayaNo': ayaNo,
        'page': page,
        'suraNameAr': suraNameAr,
        'suraNameEn': suraNameEn,
        'ayaText': ayaText,
        'createdAt': createdAt.toIso8601String(),
      };

  factory QuranBookmark.fromJson(Map<String, dynamic> json) => QuranBookmark(
        id: json['id'] as String,
        suraNo: json['suraNo'] as int,
        ayaNo: json['ayaNo'] as int,
        page: json['page'] as int,
        suraNameAr: json['suraNameAr'] as String,
        suraNameEn: json['suraNameEn'] as String,
        ayaText: json['ayaText'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  List<Object?> get props => [id];
}

class QuranReadingProgress extends Equatable {
  final int suraNo;
  final int ayaNo;
  final int page;
  final DateTime lastReadAt;

  const QuranReadingProgress({
    required this.suraNo,
    required this.ayaNo,
    required this.page,
    required this.lastReadAt,
  });

  Map<String, dynamic> toJson() => {
        'suraNo': suraNo,
        'ayaNo': ayaNo,
        'page': page,
        'lastReadAt': lastReadAt.toIso8601String(),
      };

  factory QuranReadingProgress.fromJson(Map<String, dynamic> json) =>
      QuranReadingProgress(
        suraNo: json['suraNo'] as int,
        ayaNo: json['ayaNo'] as int,
        page: json['page'] as int,
        lastReadAt: DateTime.parse(json['lastReadAt'] as String),
      );

  @override
  List<Object?> get props => [suraNo, ayaNo];
}

const List<SurahMetaData> kSurahMetaData = [
  SurahMetaData(1, 'Al-Fātiḥah', 'الفَاتِحة', 7, RevelationType.makki, 1, 1),
  SurahMetaData(2, 'Al-Baqarah', 'البَقَرَة', 286, RevelationType.madani, 2, 49),
  SurahMetaData(3, 'Āl-‘Imrān', 'آل عِمران', 200, RevelationType.makki, 50, 76),
  SurahMetaData(4, 'An-Nisā’', 'النِّسَاء', 176, RevelationType.makki, 77, 106),
  SurahMetaData(5, 'Al-Mā’idah', 'المَائدة', 120, RevelationType.makki, 106, 127),
  SurahMetaData(6, 'Al-An‘ām', 'الأنعَام', 165, RevelationType.makki, 128, 150),
  SurahMetaData(7, 'Al-A‘rāf', 'الأعرَاف', 206, RevelationType.makki, 151, 176),
  SurahMetaData(8, 'Al-Anfāl', 'الأنفَال', 75, RevelationType.makki, 177, 186),
  SurahMetaData(9, 'At-Taubah', 'التوبَة', 129, RevelationType.madani, 187, 207),
  SurahMetaData(10, 'Yūnus', 'يُونس', 109, RevelationType.makki, 208, 221),
  SurahMetaData(11, 'Hūd', 'هُود', 123, RevelationType.makki, 221, 235),
  SurahMetaData(12, 'Yūsuf', 'يُوسُف', 111, RevelationType.makki, 235, 248),
  SurahMetaData(13, 'Ar-Ra‘d', 'الرَّعد', 43, RevelationType.madani, 249, 255),
  SurahMetaData(14, 'Ibrāhīm', 'إبراهِيم', 52, RevelationType.makki, 255, 261),
  SurahMetaData(15, 'Al-Ḥijr', 'الحِجر', 99, RevelationType.makki, 262, 267),
  SurahMetaData(16, 'An-Naḥl', 'النَّحل', 128, RevelationType.makki, 267, 281),
  SurahMetaData(17, 'Al-Isrā’', 'الإسرَاء', 111, RevelationType.makki, 282, 293),
  SurahMetaData(18, 'Al-Kahf', 'الكَهف', 110, RevelationType.makki, 293, 304),
  SurahMetaData(19, 'Maryam', 'مَريَم', 98, RevelationType.makki, 305, 312),
  SurahMetaData(20, 'Ṭā-Hā', 'طه', 135, RevelationType.makki, 312, 321),
  SurahMetaData(21, 'Al-Anbiyā’', 'الأنبيَاء', 112, RevelationType.makki, 322, 331),
  SurahMetaData(22, 'Al-Ḥajj', 'الحج', 78, RevelationType.madani, 332, 341),
  SurahMetaData(23, 'Al-Mu’minūn', 'المؤمنُون', 118, RevelationType.makki, 342, 349),
  SurahMetaData(24, 'An-Nūr', 'النور', 64, RevelationType.madani, 350, 359),
  SurahMetaData(25, 'Al-Furqān', 'الفُرقَان', 77, RevelationType.makki, 359, 366),
  SurahMetaData(26, 'Ash-Shu‘arā’', 'الشعراء', 227, RevelationType.makki, 367, 376),
  SurahMetaData(27, 'An-Naml', 'النَّمل', 93, RevelationType.makki, 377, 385),
  SurahMetaData(28, 'Al-Qaṣaṣ', 'القَصَص', 88, RevelationType.makki, 385, 396),
  SurahMetaData(29, 'Al-‘Ankabūt', 'العَنكبُوت', 69, RevelationType.makki, 396, 404),
  SurahMetaData(30, 'Ar-Rūm', 'الرُّوم', 60, RevelationType.makki, 404, 410),
  SurahMetaData(31, 'Luqmān', 'لُقمَان', 34, RevelationType.makki, 411, 414),
  SurahMetaData(32, 'As-Sajdah', 'السَّجدة', 30, RevelationType.makki, 415, 417),
  SurahMetaData(33, 'Al-Aḥzāb', 'الأحزَاب', 73, RevelationType.madani, 418, 427),
  SurahMetaData(34, 'Saba’', 'سَبإ', 54, RevelationType.makki, 428, 434),
  SurahMetaData(35, 'Fāṭir', 'فَاطِر', 45, RevelationType.makki, 434, 440),
  SurahMetaData(36, 'Yā-Sīn', 'يسٓ', 83, RevelationType.makki, 440, 445),
  SurahMetaData(37, 'Aṣ-Ṣāffāt', 'الصَّافَات', 182, RevelationType.makki, 446, 452),
  SurahMetaData(38, 'Ṣād', 'صٓ', 88, RevelationType.makki, 453, 458),
  SurahMetaData(39, 'Az-Zumar', 'الزُّمَر', 75, RevelationType.makki, 458, 467),
  SurahMetaData(40, 'Ghāfir', 'غَافِر', 85, RevelationType.makki, 467, 476),
  SurahMetaData(41, 'Fuṣṣilat', 'فُصِّلَت', 54, RevelationType.makki, 477, 482),
  SurahMetaData(42, 'Ash-Shūra', 'الشُّورى', 53, RevelationType.makki, 483, 489),
  SurahMetaData(43, 'Az-Zukhruf', 'الزُّخرُف', 89, RevelationType.makki, 489, 495),
  SurahMetaData(44, 'Ad-Dukhān', 'الدُّخان', 59, RevelationType.makki, 496, 498),
  SurahMetaData(45, 'Al-Jāthiyah', 'الجاثِية', 37, RevelationType.makki, 499, 502),
  SurahMetaData(46, 'Al-Aḥqāf', 'الأحقَاف', 35, RevelationType.makki, 502, 506),
  SurahMetaData(47, 'Muḥammad', 'مُحمد', 38, RevelationType.madani, 507, 510),
  SurahMetaData(48, 'Al-Fatḥ', 'الفَتح', 29, RevelationType.madani, 511, 515),
  SurahMetaData(49, 'Al-Ḥujurāt', 'الحُجُرَات', 18, RevelationType.madani, 515, 517),
  SurahMetaData(50, 'Qāf', 'قٓ', 45, RevelationType.makki, 518, 520),
  SurahMetaData(51, 'Adh-Dhāriyāt', 'الذَّاريَات', 60, RevelationType.makki, 520, 523),
  SurahMetaData(52, 'Aṭ-Ṭūr', 'الطُّور', 49, RevelationType.makki, 523, 525),
  SurahMetaData(53, 'An-Najm', 'النَّجم', 62, RevelationType.makki, 526, 528),
  SurahMetaData(54, 'Al-Qamar', 'القَمَر', 55, RevelationType.makki, 528, 531),
  SurahMetaData(55, 'Ar-Raḥmān', 'الرَّحمٰن', 78, RevelationType.madani, 531, 534),
  SurahMetaData(56, 'Al-Wāqi‘ah', 'الوَاقِعة', 96, RevelationType.makki, 534, 537),
  SurahMetaData(57, 'Al-Ḥadīd', 'الحدِيد', 29, RevelationType.madani, 537, 541),
  SurahMetaData(58, 'Al-Mujādilah', 'المُجَادلة', 22, RevelationType.madani, 542, 545),
  SurahMetaData(59, 'Al-Ḥashr', 'الحَشر', 24, RevelationType.madani, 545, 548),
  SurahMetaData(60, 'Al-Mumtaḥanah', 'المُمتَحنَة', 13, RevelationType.madani, 549, 551),
  SurahMetaData(61, 'Aṣ-Ṣaff', 'الصَّف', 14, RevelationType.madani, 551, 552),
  SurahMetaData(62, 'Al-Jumu‘ah', 'الجُمعَة', 11, RevelationType.madani, 553, 554),
  SurahMetaData(63, 'Al-Munāfiqūn', 'المُنَافِقُونَ', 11, RevelationType.madani, 554, 555),
  SurahMetaData(64, 'At-Taghābun', 'التغَابُن', 18, RevelationType.madani, 556, 557),
  SurahMetaData(65, 'Aṭ-Ṭalāq', 'الطَّلَاق', 12, RevelationType.madani, 558, 559),
  SurahMetaData(66, 'At-Taḥrīm', 'التَّحرِيم', 12, RevelationType.madani, 560, 561),
  SurahMetaData(67, 'Al-Mulk', 'المُلك', 30, RevelationType.makki, 562, 564),
  SurahMetaData(68, 'Al-Qalam', 'القَلَم', 52, RevelationType.makki, 564, 566),
  SurahMetaData(69, 'Al-Ḥāqqah', 'الحَاقة', 52, RevelationType.makki, 566, 568),
  SurahMetaData(70, 'Al-Ma‘ārij', 'المَعَارج', 44, RevelationType.makki, 568, 570),
  SurahMetaData(71, 'Nūḥ', 'نُوح', 28, RevelationType.makki, 570, 571),
  SurahMetaData(72, 'Al-Jinn', 'الجِن', 28, RevelationType.makki, 572, 573),
  SurahMetaData(73, 'Al-Muzzammil', 'المُزمل', 20, RevelationType.makki, 574, 575),
  SurahMetaData(74, 'Al-Muddaththir', 'المُدثر', 56, RevelationType.makki, 575, 577),
  SurahMetaData(75, 'Al-Qiyāmah', 'القِيَامة', 40, RevelationType.makki, 577, 578),
  SurahMetaData(76, 'Al-Insān', 'الإنسَان', 31, RevelationType.madani, 578, 580),
  SurahMetaData(77, 'Al-Mursalāt', 'المُرسَلات', 50, RevelationType.makki, 580, 581),
  SurahMetaData(78, 'An-Naba’', 'النَّبَإ', 40, RevelationType.makki, 582, 583),
  SurahMetaData(79, 'An-Nāzi‘āt', 'النَّازعَات', 46, RevelationType.makki, 583, 584),
  SurahMetaData(80, '‘Abasa', 'عَبَسَ', 42, RevelationType.makki, 585, 586),
  SurahMetaData(81, 'At-Takwīr', 'التَّكوير', 29, RevelationType.makki, 586, 586),
  SurahMetaData(82, 'Al-Infiṭār', 'الانفِطَار', 19, RevelationType.makki, 587, 587),
  SurahMetaData(83, 'Al-Muṭaffifīn', 'المُطَففين', 36, RevelationType.makki, 587, 589),
  SurahMetaData(84, 'Al-Inshiqāq', 'الانشِقَاق', 25, RevelationType.makki, 589, 590),
  SurahMetaData(85, 'Al-Burūj', 'البُرُوج', 22, RevelationType.makki, 590, 590),
  SurahMetaData(86, 'Aṭ-Ṭāriq', 'الطَّارق', 17, RevelationType.makki, 591, 591),
  SurahMetaData(87, 'Al-A‘lā', 'الأعلى', 19, RevelationType.makki, 591, 592),
  SurahMetaData(88, 'Al-Ghāshiyah', 'الغَاشِية', 26, RevelationType.makki, 592, 593),
  SurahMetaData(89, 'Al-Fajr', 'الفَجر', 30, RevelationType.makki, 593, 594),
  SurahMetaData(90, 'Al-Balad', 'البَلَد', 20, RevelationType.makki, 594, 595),
  SurahMetaData(91, 'Ash-Shams', 'الشَّمس', 15, RevelationType.makki, 595, 595),
  SurahMetaData(92, 'Al-Lail', 'اللَّيل', 21, RevelationType.makki, 595, 596),
  SurahMetaData(93, 'Aḍ-Ḍuḥā', 'الضُّحى', 11, RevelationType.makki, 596, 596),
  SurahMetaData(94, 'Ash-Sharḥ', 'الشَّرح', 8, RevelationType.makki, 596, 597),
  SurahMetaData(95, 'At-Tīn', 'التِّين', 8, RevelationType.makki, 597, 597),
  SurahMetaData(96, 'Al-‘Alaq', 'العَلَق', 19, RevelationType.makki, 597, 598),
  SurahMetaData(97, 'Al-Qadr', 'القَدر', 5, RevelationType.makki, 598, 598),
  SurahMetaData(98, 'Al-Bayyinah', 'البَينَة', 8, RevelationType.madani, 598, 599),
  SurahMetaData(99, 'Az-Zalzalah', 'الزَّلزَلة', 8, RevelationType.madani, 599, 599),
  SurahMetaData(100, 'Al-‘Ādiyāt', 'العَاديَات', 11, RevelationType.makki, 599, 600),
  SurahMetaData(101, 'Al-Qāri‘ah', 'القَارعَة', 11, RevelationType.makki, 600, 600),
  SurahMetaData(102, 'At-Takāthur', 'التَّكاثُر', 8, RevelationType.makki, 600, 600),
  SurahMetaData(103, 'Al-‘Aṣr', 'العَصر', 3, RevelationType.makki, 601, 601),
  SurahMetaData(104, 'Al-Humazah', 'الهُمَزة', 9, RevelationType.makki, 601, 601),
  SurahMetaData(105, 'Al-Fīl', 'الفِيل', 5, RevelationType.makki, 601, 601),
  SurahMetaData(106, 'Quraish', 'قُرَيش', 4, RevelationType.makki, 602, 602),
  SurahMetaData(107, 'Al-Mā‘ūn', 'المَاعُون', 7, RevelationType.makki, 602, 602),
  SurahMetaData(108, 'Al-Kauthar', 'الكَوثر', 3, RevelationType.makki, 602, 602),
  SurahMetaData(109, 'Al-Kāfirūn', 'الكافِرون', 6, RevelationType.makki, 603, 603),
  SurahMetaData(110, 'An-Naṣr', 'النَّصر', 3, RevelationType.madani, 603, 603),
  SurahMetaData(111, 'Al-Masad', 'المَسَد', 5, RevelationType.makki, 603, 603),
  SurahMetaData(112, 'Al-Ikhlāṣ', 'الإخلَاص', 4, RevelationType.makki, 604, 604),
  SurahMetaData(113, 'Al-Falaq', 'الفَلَق', 5, RevelationType.makki, 604, 604),
  SurahMetaData(114, 'An-Nās', 'النَّاس', 6, RevelationType.makki, 604, 604),
];
