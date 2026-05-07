import '../models/islamic_event.dart';
import '../utils/hijri_date.dart';

class IslamicEventsService {
  static const List<IslamicEvent> events = [
    IslamicEvent(
      id: 'islamic_new_year',
      nameEn: 'Islamic New Year',
      nameAr: 'رأس السنة الهجرية',
      hijriMonth: 1,
      hijriDay: 1,
      emoji: '🌙',
      descriptionEn: 'The first day of Muharram marks the start of a new Hijri year.',
      descriptionAr: 'أول أيام محرم، يُعلن مطلع السنة الهجرية الجديدة.',
    ),
    IslamicEvent(
      id: 'ashura',
      nameEn: 'Day of Ashura',
      nameAr: 'يوم عاشوراء',
      hijriMonth: 1,
      hijriDay: 10,
      emoji: '🤲',
      descriptionEn: 'The 10th of Muharram — a day of fasting and remembrance. The Prophet ﷺ said it expiates the sins of the previous year.',
      descriptionAr: 'عاشر محرم — يوم صيام وذكر. قال النبي ﷺ إن صيامه يُكفّر ذنوب السنة الماضية.',
    ),
    IslamicEvent(
      id: 'mawlid',
      nameEn: "Mawlid al-Nabi",
      nameAr: 'المولد النبوي الشريف',
      hijriMonth: 3,
      hijriDay: 12,
      emoji: '✨',
      descriptionEn: "The 12th of Rabi al-Awwal — the birth of Prophet Muhammad ﷺ.",
      descriptionAr: 'الثاني عشر من ربيع الأول — ذكرى مولد النبي محمد ﷺ.',
    ),
    IslamicEvent(
      id: 'ramadan',
      nameEn: 'Ramadan',
      nameAr: 'رمضان المبارك',
      hijriMonth: 9,
      hijriDay: 1,
      emoji: '🌙',
      descriptionEn: 'The holy month of fasting, prayer, and Quran recitation. One of the five pillars of Islam.',
      descriptionAr: 'شهر الصيام المبارك، شهر القرآن والعبادة. ركنٌ من أركان الإسلام الخمسة.',
    ),
    IslamicEvent(
      id: 'laylat_al_qadr',
      nameEn: "Laylat al-Qadr",
      nameAr: 'ليلة القدر',
      hijriMonth: 9,
      hijriDay: 27,
      emoji: '⭐',
      descriptionEn: 'The Night of Power — better than a thousand months. Seek it in the last 10 nights of Ramadan.',
      descriptionAr: 'ليلة خير من ألف شهر — التمسوها في العشر الأواخر من رمضان.',
    ),
    IslamicEvent(
      id: 'eid_al_fitr',
      nameEn: 'Eid al-Fitr',
      nameAr: 'عيد الفطر المبارك',
      hijriMonth: 10,
      hijriDay: 1,
      emoji: '🎉',
      descriptionEn: 'Festival of breaking the fast. Marks the end of Ramadan — a day of joy, charity, and celebration.',
      descriptionAr: 'عيد الفطر السعيد — يُعلن انتهاء رمضان المبارك، يومٌ من الفرح والعطاء.',
    ),
    IslamicEvent(
      id: 'dhul_hijjah_first',
      nameEn: 'First 10 Days of Dhul Hijjah',
      nameAr: 'أوائل عشر ذي الحجة',
      hijriMonth: 12,
      hijriDay: 1,
      emoji: '🕋',
      descriptionEn: 'The 10 best days of the year. Increase dhikr, fasting, and good deeds — especially on the Day of Arafah.',
      descriptionAr: 'أفضل أيام السنة. أكثر من الذكر والصيام والأعمال الصالحة، ولا سيّما يوم عرفة.',
    ),
    IslamicEvent(
      id: 'eid_al_adha',
      nameEn: 'Eid al-Adha',
      nameAr: 'عيد الأضحى المبارك',
      hijriMonth: 12,
      hijriDay: 10,
      emoji: '🐑',
      descriptionEn: 'Festival of Sacrifice — commemorates the sacrifice of Ibrahim ﷺ. Pilgrims complete Hajj on this day.',
      descriptionAr: 'عيد الأضحى المبارك — ذكرى فداء إبراهيم ﷺ. يُتمّ فيه الحجاج مناسكهم.',
    ),
  ];

  /// Returns all events sorted by days until next occurrence.
  static List<IslamicEventWithDate> getUpcomingEvents() {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final result = <IslamicEventWithDate>[];

    for (final event in events) {
      for (int offset = 0; offset <= 400; offset++) {
        final candidate = todayNorm.add(Duration(days: offset));
        final hijri = HijriDate.toHijri(candidate);
        if (hijri['month'] == event.hijriMonth &&
            int.parse(hijri['day'].toString()) == event.hijriDay) {
          result.add(IslamicEventWithDate(
            event: event,
            date: candidate,
            daysUntil: offset,
          ));
          break;
        }
      }
    }

    result.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    return result;
  }
}
