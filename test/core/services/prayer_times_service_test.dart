import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/models/prayer_time.dart';
import 'package:aura_app/core/services/prayer_times_service.dart';

/// Canonical "next prayer" derivation spec.
///
/// The recurring day-transition bugs (phantom Fajr, morning recalc, the
/// notification getting stuck on "Fajr 19h until azan") all came from a cached
/// next-prayer value drifting out of sync. The durable principle is: the next
/// prayer is ALWAYS *derived* from the day's times + the current clock —
/// `prayers.firstWhere(time > now) ?? tomorrowsFajr`. These tests pin that
/// behavior on the Flutter side; the native `findNextPrayer` /
/// `soonestUpcomingFromPrefs` must mirror it.
void main() {
  final service = PrayerTimesService();

  // Builds a full 6-entry day where each prayer is at `now + offsetHours`.
  // Negative offsets = already passed today.
  List<PrayerTime> day(Map<String, double> offsetsHours) {
    final now = DateTime.now();
    PrayerTime p(String n, String ar, double h) => PrayerTime(
          name: n,
          nameAr: ar,
          time: now.add(Duration(milliseconds: (h * 3600 * 1000).round())),
        );
    return [
      p('Fajr', 'الفجر', offsetsHours['Fajr']!),
      p('Sunrise', 'الشروق', offsetsHours['Sunrise']!),
      p('Zuhr', 'الظهر', offsetsHours['Zuhr']!),
      p('Asr', 'العصر', offsetsHours['Asr']!),
      p('Maghrib', 'المغرب', offsetsHours['Maghrib']!),
      p('Isha', 'العشاء', offsetsHours['Isha']!),
    ];
  }

  group('getNextPrayer — canonical next-prayer derivation', () {
    test('pre-dawn: returns Fajr when every prayer is still ahead', () {
      final next = service.getNextPrayer(day({
        'Fajr': 1, 'Sunrise': 2, 'Zuhr': 6, 'Asr': 9, 'Maghrib': 11, 'Isha': 12,
      }));
      expect(next!.name, 'Fajr');
    });

    test(
        'REGRESSION: after Fajr+Sunrise pass, next is Zuhr — never a stuck Fajr',
        () {
      // The exact day-transition bug: Fajr & Sunrise behind us, Zuhr onward
      // still ahead. Must return today's Zuhr, not yesterday's/tomorrow's Fajr.
      final next = service.getNextPrayer(day({
        'Fajr': -3, 'Sunrise': -1, 'Zuhr': 4, 'Asr': 7, 'Maghrib': 9, 'Isha': 10,
      }));
      expect(next!.name, 'Zuhr');
      expect(next.time.isAfter(DateTime.now()), isTrue);
    });

    test('between Fajr and Sunrise, next is Sunrise (Sunrise is included)', () {
      final next = service.getNextPrayer(day({
        'Fajr': -1, 'Sunrise': 1, 'Zuhr': 5, 'Asr': 8, 'Maghrib': 10, 'Isha': 11,
      }));
      expect(next!.name, 'Sunrise');
    });

    test('only Isha left → returns Isha', () {
      final next = service.getNextPrayer(day({
        'Fajr': -10, 'Sunrise': -9, 'Zuhr': -5, 'Asr': -3, 'Maghrib': -1, 'Isha': 1,
      }));
      expect(next!.name, 'Isha');
    });

    test('after Isha (all passed) → rolls over to a FUTURE tomorrow Fajr', () {
      final next = service.getNextPrayer(day({
        'Fajr': -12, 'Sunrise': -11, 'Zuhr': -7, 'Asr': -4, 'Maghrib': -2, 'Isha': -1,
      }));
      expect(next!.name, 'Fajr');
      // Must always be in the future — never a stale past timestamp.
      expect(next.time.isAfter(DateTime.now()), isTrue);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(next.time.day, tomorrow.day);
    });

    test('derivation is order-independent (unsorted input still finds soonest)',
        () {
      final now = DateTime.now();
      final unsorted = [
        PrayerTime(
            name: 'Isha', nameAr: 'العشاء', time: now.add(const Duration(hours: 10))),
        PrayerTime(
            name: 'Zuhr', nameAr: 'الظهر', time: now.add(const Duration(hours: 2))),
        PrayerTime(
            name: 'Maghrib', nameAr: 'المغرب', time: now.add(const Duration(hours: 8))),
      ];
      expect(service.getNextPrayer(unsorted)!.name, 'Zuhr');
    });

    test('empty list returns null (no crash)', () {
      expect(service.getNextPrayer(const []), isNull);
    });
  });
}
