class IslamicEvent {
  final String id;
  final String nameEn;
  final String nameAr;
  final int hijriMonth;
  final int hijriDay;
  final String descriptionEn;
  final String descriptionAr;
  final String emoji;

  const IslamicEvent({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.hijriMonth,
    required this.hijriDay,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.emoji,
  });
}

class IslamicEventWithDate {
  final IslamicEvent event;
  final DateTime date;
  final int daysUntil;

  const IslamicEventWithDate({
    required this.event,
    required this.date,
    required this.daysUntil,
  });
}
