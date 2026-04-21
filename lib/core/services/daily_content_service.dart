import '../models/daily_content.dart';

class DailyContentService {
  DailyContentService._();
  static final DailyContentService instance = DailyContentService._();

  static const List<DailyContent> _content = [
    // ── Ayahs ──────────────────────────────────────────────────────────────
    DailyContent(
      type: DailyContentType.ayah,
      arabic: 'إِنَّ مَعَ الْعُسْرِ يُسْرًا',
      translation: 'Indeed, with hardship comes ease.',
      source: 'Ash-Sharh 94:6',
    ),
    DailyContent(
      type: DailyContentType.ayah,
      arabic: 'وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ',
      translation: 'And whoever relies upon Allah — then He is sufficient for him.',
      source: 'At-Talaq 65:3',
    ),
    DailyContent(
      type: DailyContentType.ayah,
      arabic: 'فَاذْكُرُونِي أَذْكُرْكُمْ وَاشْكُرُوا لِي وَلَا تَكْفُرُونِ',
      translation: 'So remember Me; I will remember you. And be grateful to Me and do not deny Me.',
      source: 'Al-Baqarah 2:152',
    ),
    DailyContent(
      type: DailyContentType.ayah,
      arabic: 'وَلَا تَهِنُوا وَلَا تَحْزَنُوا وَأَنتُمُ الْأَعْلَوْنَ إِن كُنتُم مُّؤْمِنِينَ',
      translation: 'Do not weaken and do not grieve, and you will be superior if you are true believers.',
      source: 'Aal-e-Imran 3:139',
    ),
    DailyContent(
      type: DailyContentType.ayah,
      arabic: 'يَا أَيُّهَا الَّذِينَ آمَنُوا اسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ',
      translation: 'O you who have believed, seek help through patience and prayer.',
      source: 'Al-Baqarah 2:153',
    ),
    DailyContent(
      type: DailyContentType.ayah,
      arabic: 'وَإِذَا سَأَلَكَ عِبَادِي عَنِّي فَإِنِّي قَرِيبٌ',
      translation: 'And when My servants ask you about Me — indeed I am near.',
      source: 'Al-Baqarah 2:186',
    ),
    DailyContent(
      type: DailyContentType.ayah,
      arabic: 'حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ',
      translation: 'Allah is sufficient for us, and He is the best Disposer of affairs.',
      source: 'Aal-e-Imran 3:173',
    ),
    DailyContent(
      type: DailyContentType.ayah,
      arabic: 'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
      translation: 'Indeed, Allah is with the patient.',
      source: 'Al-Baqarah 2:153',
    ),
    DailyContent(
      type: DailyContentType.ayah,
      arabic: 'وَقُل رَّبِّ زِدْنِي عِلْمًا',
      translation: 'And say: My Lord, increase me in knowledge.',
      source: 'Ta-Ha 20:114',
    ),
    DailyContent(
      type: DailyContentType.ayah,
      arabic: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً',
      translation: 'Our Lord, give us in this world good and in the Hereafter good.',
      source: 'Al-Baqarah 2:201',
    ),

    // ── Hadiths ────────────────────────────────────────────────────────────
    DailyContent(
      type: DailyContentType.hadith,
      arabic: 'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ',
      translation: 'Actions are judged by intentions.',
      source: 'Bukhari & Muslim',
    ),
    DailyContent(
      type: DailyContentType.hadith,
      arabic: 'خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ',
      translation: 'The best of you are those who learn the Quran and teach it.',
      source: 'Bukhari',
    ),
    DailyContent(
      type: DailyContentType.hadith,
      arabic: 'الْمُسْلِمُ مَنْ سَلِمَ الْمُسْلِمُونَ مِنْ لِسَانِهِ وَيَدِهِ',
      translation: 'A Muslim is one from whose tongue and hand other Muslims are safe.',
      source: 'Bukhari & Muslim',
    ),
    DailyContent(
      type: DailyContentType.hadith,
      arabic: 'لَا يُؤْمِنُ أَحَدُكُمْ حَتَّى يُحِبَّ لِأَخِيهِ مَا يُحِبُّ لِنَفْسِهِ',
      translation: 'None of you truly believes until he loves for his brother what he loves for himself.',
      source: 'Bukhari & Muslim',
    ),
    DailyContent(
      type: DailyContentType.hadith,
      arabic: 'الدُّنْيَا سِجْنُ الْمُؤْمِنِ وَجَنَّةُ الْكَافِرِ',
      translation: 'The world is a prison for the believer and a paradise for the disbeliever.',
      source: 'Muslim',
    ),
    DailyContent(
      type: DailyContentType.hadith,
      arabic: 'مَنْ صَلَّى الصُّبْحَ فَهُوَ فِي ذِمَّةِ اللَّهِ',
      translation: 'Whoever prays Fajr is under the protection of Allah.',
      source: 'Muslim',
    ),
    DailyContent(
      type: DailyContentType.hadith,
      arabic: 'أَحَبُّ الأَعْمَالِ إِلَى اللَّهِ أَدْوَمُهَا وَإِنْ قَلَّ',
      translation: 'The most beloved deeds to Allah are those done consistently, even if small.',
      source: 'Bukhari & Muslim',
    ),
    DailyContent(
      type: DailyContentType.hadith,
      arabic: 'تَبَسُّمُكَ فِي وَجْهِ أَخِيكَ صَدَقَةٌ',
      translation: 'Your smile in the face of your brother is charity.',
      source: 'Tirmidhi',
    ),
    DailyContent(
      type: DailyContentType.hadith,
      arabic: 'مَنْ كَانَ يُؤْمِنُ بِاللَّهِ وَالْيَوْمِ الآخِرِ فَلْيَقُلْ خَيْرًا أَوْ لِيَصْمُتْ',
      translation: 'Whoever believes in Allah and the Last Day, let him speak good or remain silent.',
      source: 'Bukhari & Muslim',
    ),
    DailyContent(
      type: DailyContentType.hadith,
      arabic: 'إِنَّ اللَّهَ جَمِيلٌ يُحِبُّ الْجَمَالَ',
      translation: 'Indeed Allah is beautiful and loves beauty.',
      source: 'Muslim',
    ),
  ];

  /// Returns today's content — rotates daily through the list
  DailyContent getToday() {
    final dayOfYear = _dayOfYear(DateTime.now());
    return _content[dayOfYear % _content.length];
  }

  int _dayOfYear(DateTime date) {
    return date.difference(DateTime(date.year, 1, 1)).inDays;
  }
}
