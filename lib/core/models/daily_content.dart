enum DailyContentType { ayah, hadith }

class DailyContent {
  final DailyContentType type;
  final String arabic;
  final String translation;
  final String source; // surah:verse or hadith book

  const DailyContent({
    required this.type,
    required this.arabic,
    required this.translation,
    required this.source,
  });
}
