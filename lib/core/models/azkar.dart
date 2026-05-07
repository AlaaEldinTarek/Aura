import 'dart:convert';

enum AzkarCategory { morning, evening }

class ZikrItem {
  final String id;
  final String textAr;
  final String textEn;
  final int repeatCount;
  final AzkarCategory category;

  const ZikrItem({
    required this.id,
    required this.textAr,
    required this.textEn,
    required this.repeatCount,
    required this.category,
  });
}

class AzkarData {
  static const List<ZikrItem> morning = [
    ZikrItem(
      id: 'm_01',
      textAr: 'أَعُوذُ بِاللَّهِ السَّمِيعِ الْعَلِيمِ مِنَ الشَّيْطَانِ الرَّجِيمِ',
      textEn: 'I seek refuge in Allah, the All-Hearing, All-Knowing, from Satan the outcast.',
      repeatCount: 1,
      category: AzkarCategory.morning,
    ),
    ZikrItem(
      id: 'm_02',
      textAr: 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ',
      textEn: 'Ayat Al-Kursi — Allah! There is no deity except Him, the Ever-Living, the Sustainer of existence... (Al-Baqarah 2:255)',
      repeatCount: 1,
      category: AzkarCategory.morning,
    ),
    ZikrItem(
      id: 'm_03',
      textAr: 'قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ',
      textEn: 'Say: He is Allah, the One. Allah, the Eternal Refuge. He neither begets nor was born. Nor is there any equivalent to Him. (Surah Al-Ikhlas)',
      repeatCount: 3,
      category: AzkarCategory.morning,
    ),
    ZikrItem(
      id: 'm_04',
      textAr: 'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِنْ شَرِّ مَا خَلَقَ ۝ وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ',
      textEn: 'Say: I seek refuge in the Lord of the daybreak, from the evil of what He has created, and from the evil of darkness when it settles... (Surah Al-Falaq)',
      repeatCount: 3,
      category: AzkarCategory.morning,
    ),
    ZikrItem(
      id: 'm_05',
      textAr: 'قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ',
      textEn: 'Say: I seek refuge in the Lord of mankind, the Sovereign of mankind, the God of mankind, from the evil of the retreating whisperer... (Surah An-Nas)',
      repeatCount: 3,
      category: AzkarCategory.morning,
    ),
    ZikrItem(
      id: 'm_06',
      textAr: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
      textEn: 'We have reached the morning and the kingdom belongs to Allah. All praise is for Allah. None has the right to be worshipped except Allah, alone, without partner, to Him belongs all sovereignty and all praise, and He is over all things competent.',
      repeatCount: 1,
      category: AzkarCategory.morning,
    ),
    ZikrItem(
      id: 'm_07',
      textAr: 'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ',
      textEn: 'O Allah, by You we have reached the morning, and by You we reach the evening, by You we live and by You we die, and to You is the Resurrection.',
      repeatCount: 1,
      category: AzkarCategory.morning,
    ),
    ZikrItem(
      id: 'm_08',
      textAr: 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَٰهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي، فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
      textEn: 'Sayyid Al-Istighfar — O Allah, You are my Lord, none has the right to be worshipped except You. You created me and I am Your servant, and I abide by Your covenant and promise as best I can. I seek refuge in You from the evil of what I have done...',
      repeatCount: 1,
      category: AzkarCategory.morning,
    ),
    ZikrItem(
      id: 'm_09',
      textAr: 'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي وَبَصَرِي، اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ وَالْفَقْرِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، لَا إِلَٰهَ إِلَّا أَنْتَ',
      textEn: 'O Allah, grant me health in my body. O Allah, grant me health in my hearing and my sight. O Allah, I seek refuge in You from disbelief and poverty, and I seek refuge in You from the punishment of the grave. None has the right to be worshipped except You.',
      repeatCount: 3,
      category: AzkarCategory.morning,
    ),
    ZikrItem(
      id: 'm_10',
      textAr: 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
      textEn: 'In the name of Allah with Whose name nothing can cause harm in the earth nor in the heavens, and He is the All-Hearing, the All-Knowing.',
      repeatCount: 3,
      category: AzkarCategory.morning,
    ),
    ZikrItem(
      id: 'm_11',
      textAr: 'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا وَرَسُولًا',
      textEn: 'I am pleased with Allah as my Lord, with Islam as my religion, and with Muhammad (ﷺ) as my Prophet and Messenger.',
      repeatCount: 3,
      category: AzkarCategory.morning,
    ),
    ZikrItem(
      id: 'm_12',
      textAr: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
      textEn: 'Glory be to Allah and praise Him.',
      repeatCount: 100,
      category: AzkarCategory.morning,
    ),
  ];

  static const List<ZikrItem> evening = [
    ZikrItem(
      id: 'e_01',
      textAr: 'أَعُوذُ بِاللَّهِ السَّمِيعِ الْعَلِيمِ مِنَ الشَّيْطَانِ الرَّجِيمِ',
      textEn: 'I seek refuge in Allah, the All-Hearing, All-Knowing, from Satan the outcast.',
      repeatCount: 1,
      category: AzkarCategory.evening,
    ),
    ZikrItem(
      id: 'e_02',
      textAr: 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ',
      textEn: 'Ayat Al-Kursi — Allah! There is no deity except Him, the Ever-Living, the Sustainer of existence... (Al-Baqarah 2:255)',
      repeatCount: 1,
      category: AzkarCategory.evening,
    ),
    ZikrItem(
      id: 'e_03',
      textAr: 'قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ',
      textEn: 'Say: He is Allah, the One. Allah, the Eternal Refuge. He neither begets nor was born. Nor is there any equivalent to Him. (Surah Al-Ikhlas)',
      repeatCount: 3,
      category: AzkarCategory.evening,
    ),
    ZikrItem(
      id: 'e_04',
      textAr: 'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِنْ شَرِّ مَا خَلَقَ ۝ وَمِنْ شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِنْ شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِنْ شَرِّ حَاسِدٍ إِذَا حَسَدَ',
      textEn: 'Say: I seek refuge in the Lord of the daybreak, from the evil of what He has created, and from the evil of darkness when it settles... (Surah Al-Falaq)',
      repeatCount: 3,
      category: AzkarCategory.evening,
    ),
    ZikrItem(
      id: 'e_05',
      textAr: 'قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ مِنْ شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ',
      textEn: 'Say: I seek refuge in the Lord of mankind, the Sovereign of mankind, the God of mankind, from the evil of the retreating whisperer... (Surah An-Nas)',
      repeatCount: 3,
      category: AzkarCategory.evening,
    ),
    ZikrItem(
      id: 'e_06',
      textAr: 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَٰهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
      textEn: 'We have reached the evening and the kingdom belongs to Allah. All praise is for Allah. None has the right to be worshipped except Allah, alone, without partner, to Him belongs all sovereignty and all praise, and He is over all things competent.',
      repeatCount: 1,
      category: AzkarCategory.evening,
    ),
    ZikrItem(
      id: 'e_07',
      textAr: 'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ الْمَصِيرُ',
      textEn: 'O Allah, by You we have reached the evening, and by You we reach the morning, by You we live and by You we die, and to You is the final return.',
      repeatCount: 1,
      category: AzkarCategory.evening,
    ),
    ZikrItem(
      id: 'e_08',
      textAr: 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَٰهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي، فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
      textEn: 'Sayyid Al-Istighfar — O Allah, You are my Lord, none has the right to be worshipped except You. You created me and I am Your servant, and I abide by Your covenant and promise as best I can. I seek refuge in You from the evil of what I have done...',
      repeatCount: 1,
      category: AzkarCategory.evening,
    ),
    ZikrItem(
      id: 'e_09',
      textAr: 'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي وَبَصَرِي، اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ وَالْفَقْرِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، لَا إِلَٰهَ إِلَّا أَنْتَ',
      textEn: 'O Allah, grant me health in my body. O Allah, grant me health in my hearing and my sight. O Allah, I seek refuge in You from disbelief and poverty, and I seek refuge in You from the punishment of the grave. None has the right to be worshipped except You.',
      repeatCount: 3,
      category: AzkarCategory.evening,
    ),
    ZikrItem(
      id: 'e_10',
      textAr: 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
      textEn: 'In the name of Allah with Whose name nothing can cause harm in the earth nor in the heavens, and He is the All-Hearing, the All-Knowing.',
      repeatCount: 3,
      category: AzkarCategory.evening,
    ),
    ZikrItem(
      id: 'e_11',
      textAr: 'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ نَبِيًّا وَرَسُولًا',
      textEn: 'I am pleased with Allah as my Lord, with Islam as my religion, and with Muhammad (ﷺ) as my Prophet and Messenger.',
      repeatCount: 3,
      category: AzkarCategory.evening,
    ),
    ZikrItem(
      id: 'e_12',
      textAr: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
      textEn: 'Glory be to Allah and praise Him.',
      repeatCount: 100,
      category: AzkarCategory.evening,
    ),
  ];

  static List<ZikrItem> forCategory(AzkarCategory cat) =>
      cat == AzkarCategory.morning ? morning : evening;
}

class AzkarState {
  final Set<String> completedMorning;
  final Set<String> completedEvening;
  final String dateKey;
  final int streakCount;
  final int totalSessions;

  const AzkarState({
    required this.completedMorning,
    required this.completedEvening,
    required this.dateKey,
    required this.streakCount,
    required this.totalSessions,
  });

  bool get isMorningComplete =>
      AzkarData.morning.every((z) => completedMorning.contains(z.id));

  bool get isEveningComplete =>
      AzkarData.evening.every((z) => completedEvening.contains(z.id));

  bool isItemDone(String id, AzkarCategory cat) =>
      cat == AzkarCategory.morning
          ? completedMorning.contains(id)
          : completedEvening.contains(id);

  int doneCount(AzkarCategory cat) =>
      cat == AzkarCategory.morning
          ? completedMorning.length
          : completedEvening.length;

  AzkarState copyWith({
    Set<String>? completedMorning,
    Set<String>? completedEvening,
    String? dateKey,
    int? streakCount,
    int? totalSessions,
  }) {
    return AzkarState(
      completedMorning: completedMorning ?? this.completedMorning,
      completedEvening: completedEvening ?? this.completedEvening,
      dateKey: dateKey ?? this.dateKey,
      streakCount: streakCount ?? this.streakCount,
      totalSessions: totalSessions ?? this.totalSessions,
    );
  }

  Map<String, dynamic> toJson() => {
        'completedMorning': completedMorning.toList(),
        'completedEvening': completedEvening.toList(),
        'dateKey': dateKey,
        'streakCount': streakCount,
        'totalSessions': totalSessions,
      };

  factory AzkarState.fromJson(Map<String, dynamic> json, String todayKey) {
    final storedDate = json['dateKey'] as String? ?? '';
    final isToday = storedDate == todayKey;
    return AzkarState(
      completedMorning: isToday
          ? Set<String>.from((json['completedMorning'] as List?) ?? [])
          : {},
      completedEvening: isToday
          ? Set<String>.from((json['completedEvening'] as List?) ?? [])
          : {},
      dateKey: todayKey,
      streakCount: json['streakCount'] as int? ?? 0,
      totalSessions: json['totalSessions'] as int? ?? 0,
    );
  }

  factory AzkarState.empty() {
    final today = _todayKey();
    return AzkarState(
      completedMorning: {},
      completedEvening: {},
      dateKey: today,
      streakCount: 0,
      totalSessions: 0,
    );
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
