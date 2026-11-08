import 'package:aura_app/core/models/prayer_settings.dart';
import 'package:aura_app/core/models/prayer_time.dart';
import 'package:aura_app/core/services/prayer_times_service.dart';
import 'package:aura_app/core/utils/prayer_refresh.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const _cairo = (30.0444, 31.2357);
const _alexandria = (31.2001, 29.9187);

/// Seven days of times starting at [start], as the provider computes them.
Future<List<List<PrayerTime>>> _week(
  DateTime start, {
  (double, double) location = _cairo,
  CalculationMethod method = CalculationMethod.muslimWorldLeague,
  AsrMadhab madhab = AsrMadhab.shafi,
}) async {
  final service = PrayerTimesService();
  return [
    for (final d in cacheDays(start))
      await service.getPrayerTimes(
        date: d,
        latitude: location.$1,
        longitude: location.$2,
        calculationMethod: method,
        asrMadhab: madhab,
      ),
  ];
}

String _fp(
  List<List<PrayerTime>> days, {
  CalculationMethod method = CalculationMethod.muslimWorldLeague,
  AsrMadhab madhab = AsrMadhab.shafi,
  Map<String, int> iqama = const {'Maghrib': 5},
}) =>
    sideEffectsFingerprint(
      today: DateTime(2026, 11, 8),
      method: method,
      madhab: madhab,
      iqama: iqama,
      days: days,
    );

/// A day of prayer times at fixed clock times on [day].
List<PrayerTime> _day(DateTime day) {
  DateTime at(int h, int m) => DateTime(day.year, day.month, day.day, h, m);
  return [
    PrayerTime(name: 'Fajr', nameAr: 'الفجر', time: at(4, 46)),
    PrayerTime(name: 'Sunrise', nameAr: 'الشروق', time: at(6, 4)),
    PrayerTime(name: 'Zuhr', nameAr: 'الظهر', time: at(11, 38)),
    PrayerTime(name: 'Asr', nameAr: 'العصر', time: at(14, 46)),
    PrayerTime(name: 'Maghrib', nameAr: 'المغرب', time: at(17, 9)),
    PrayerTime(name: 'Isha', nameAr: 'العشاء', time: at(18, 22)),
  ];
}

void main() {
  final originalDebugPrint = debugPrint;
  setUpAll(() => debugPrint = (String? message, {int? wrapWidth}) {});
  tearDownAll(() => debugPrint = originalDebugPrint);

  final start = DateTime(2026, 11, 8);

  group('sideEffectsFingerprint', () {
    test('method change: MWL vs Egyptian days -> differ', () async {
      final mwl = await _week(start);
      final egy = await _week(start, method: CalculationMethod.egyptian);
      expect(_fp(mwl), isNot(_fp(egy, method: CalculationMethod.egyptian)));
    });

    test('madhab: Shafi vs Hanafi days -> differ', () async {
      final shafi = await _week(start);
      final hanafi = await _week(start, madhab: AsrMadhab.hanafi);
      expect(_fp(shafi), isNot(_fp(hanafi, madhab: AsrMadhab.hanafi)));
    });

    test('iqama: Maghrib 5 vs 10 -> differ', () async {
      final days = await _week(start);
      expect(_fp(days, iqama: {'Maghrib': 5}),
          isNot(_fp(days, iqama: {'Maghrib': 10})));
    });

    test('location: Cairo vs Alexandria days -> differ', () async {
      final cairo = await _week(start);
      final alex = await _week(start, location: _alexandria);
      expect(_fp(cairo), isNot(_fp(alex)));
    });

    test('adjustment: Dhuhr +0 vs +3 -> differ', () async {
      final days = await _week(start);
      final adjusted = [
        for (final day in days)
          [
            for (final p in day)
              p.name == 'Zuhr'
                  ? p.copyWith(time: p.time.add(const Duration(minutes: 3)))
                  : p,
          ],
      ];
      expect(_fp(days), isNot(_fp(adjusted)));
    });

    test('app open: an empty previous fingerprint never equals -> run',
        () async {
      final days = await _week(start);
      const String? previous = null;
      expect(_fp(days) == previous, isFalse);
      expect(_fp(days), isNot(''));
    });

    test('same inputs twice -> equal -> no run', () async {
      expect(_fp(await _week(start)), _fp(await _week(start)));
    });
  });

  test('overlap: generations 1 and 2, run 1 finishes last -> only run 2 writes',
      () {
    var latest = 0;
    final run1 = ++latest;
    final run2 = ++latest;
    // Run 2 reaches its writes first, run 1 afterwards.
    expect(isLatest(run2, latest), isTrue);
    expect(isLatest(run1, latest), isFalse);
  });

  group('cacheDays', () {
    for (final now in [
      DateTime(2026, 3, 28, 23, 30), // London DST eve
      DateTime(2026, 4, 23, 23, 30), // Cairo DST eve
    ]) {
      test('$now -> 7 distinct consecutive calendar dates', () {
        final days = cacheDays(now);
        expect(days.length, 7);
        for (var i = 0; i < 7; i++) {
          expect(days[i], DateTime(now.year, now.month, now.day + i));
        }
        expect(days.toSet().length, 7);
      });
    }
  });

  test('buildNativeCache over 7 days -> exactly 42 keys, values = inputs', () {
    final dates = cacheDays(start);
    final days = [for (final d in dates) (d, _day(d))];
    final cache = buildNativeCache(days);
    expect(cache.length, 42);
    for (final (date, times) in days) {
      final key =
          'cached_${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      for (final p in times) {
        final name = p.name == 'Zuhr' ? 'dhuhr' : p.name.toLowerCase();
        expect(cache['${key}_$name'], p.time.millisecondsSinceEpoch.toString());
      }
    }
  });

  group('nextOccurrences', () {
    final today = _day(start);
    final tomorrow = _day(DateTime(2026, 11, 9));
    Map<String, DateTime> run(DateTime now) => {
          for (final p in nextOccurrences(today, tomorrow, now)) p.name: p.time,
        };

    test('before Fajr -> all five from today', () {
      final r = run(DateTime(2026, 11, 8, 3, 0));
      expect(r.keys, ['Fajr', 'Zuhr', 'Asr', 'Maghrib', 'Isha']);
      for (final p in today.where((p) => p.name != 'Sunrise')) {
        expect(r[p.name], p.time);
      }
    });

    test(
        'between Dhuhr and Asr -> Fajr, Zuhr tomorrow; Asr, Maghrib, Isha today',
        () {
      final r = run(DateTime(2026, 11, 8, 12, 0));
      expect(r['Fajr'], tomorrow[0].time);
      expect(r['Zuhr'], tomorrow[2].time);
      expect(r['Asr'], today[3].time);
      expect(r['Maghrib'], today[4].time);
      expect(r['Isha'], today[5].time);
    });

    test('after Isha -> all five from tomorrow', () {
      final r = run(DateTime(2026, 11, 8, 20, 0));
      expect(r.length, 5);
      for (final p in tomorrow.where((p) => p.name != 'Sunrise')) {
        expect(r[p.name], p.time);
      }
    });
  });

  group('postChecksToSchedule', () {
    final today = _day(start);
    List<String> names(DateTime now) =>
        postChecksToSchedule(today, now).map((p) => p.name).toList();

    test('Asr + 30 min still ahead (Asr already passed) -> Asr included', () {
      // Asr 14:46, now 15:00: Asr itself is past, its check (15:16) is ahead.
      expect(names(DateTime(2026, 11, 8, 15, 0)), ['Asr', 'Maghrib', 'Isha']);
    });

    test('Asr + 30 min already past -> Asr not included', () {
      expect(names(DateTime(2026, 11, 8, 15, 20)), ['Maghrib', 'Isha']);
    });

    test('Sunrise is never included', () {
      expect(names(DateTime(2026, 11, 8, 0, 0)),
          ['Fajr', 'Zuhr', 'Asr', 'Maghrib', 'Isha']);
    });
  });
}
