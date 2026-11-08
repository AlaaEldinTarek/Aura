import 'package:adhan/adhan.dart' as adhan;
import 'package:aura_app/core/models/prayer_settings.dart';
import 'package:aura_app/core/models/prayer_time.dart';
import 'package:aura_app/core/services/prayer_times_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Package method for each internal method name (spec item 2 map).
const _packageMethod = <CalculationMethod, adhan.CalculationMethod>{
  CalculationMethod.muslimWorldLeague:
      adhan.CalculationMethod.muslim_world_league,
  CalculationMethod.isna: adhan.CalculationMethod.north_america,
  CalculationMethod.egyptian: adhan.CalculationMethod.egyptian,
  CalculationMethod.makkah: adhan.CalculationMethod.umm_al_qura,
  CalculationMethod.karachi: adhan.CalculationMethod.karachi,
  CalculationMethod.tehran: adhan.CalculationMethod.tehran,
  CalculationMethod.kuwait: adhan.CalculationMethod.kuwait,
  CalculationMethod.fixedAngle: adhan.CalculationMethod.egyptian,
  CalculationMethod.proportional: adhan.CalculationMethod.muslim_world_league,
};

/// Package output for one date as epoch ms, in the service's order
/// (Fajr, Sunrise, Zuhr, Asr, Maghrib, Isha).
List<int> _packageTimes(
  double lat,
  double lng,
  DateTime date,
  adhan.CalculationMethod method,
  adhan.Madhab madhab, {
  int dhuhrAdjustment = 0,
}) {
  final params = method.getParameters();
  params.adjustments.dhuhr = dhuhrAdjustment;
  params.madhab = madhab;
  final t = adhan.PrayerTimes(
    adhan.Coordinates(lat, lng),
    adhan.DateComponents(date.year, date.month, date.day),
    params,
  );
  return [t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha]
      .map((d) => d.millisecondsSinceEpoch)
      .toList();
}

List<int> _epochs(List<PrayerTime> times) =>
    times.map((p) => p.time.millisecondsSinceEpoch).toList();

void main() {
  final service = PrayerTimesService();
  const cairoLat = 30.0444;
  const cairoLng = 31.2357;

  group('per-date calculation', () {
    // Windows contain Cairo's 2026 DST days (2026-04-24 and 2026-10-29).
    for (final base in [DateTime(2026, 4, 21), DateTime(2026, 10, 26)]) {
      for (var i = 0; i < 7; i++) {
        final date = DateTime(base.year, base.month, base.day + i);
        test(
            'Cairo MWL Shafi ${date.toIso8601String().substring(0, 10)} '
            'equals the package for that date', () async {
          final times = await service.getPrayerTimes(
            date: date,
            latitude: cairoLat,
            longitude: cairoLng,
            calculationMethod: CalculationMethod.muslimWorldLeague,
            asrMadhab: AsrMadhab.shafi,
          );
          expect(
            _epochs(times),
            _packageTimes(
                cairoLat,
                cairoLng,
                date,
                adhan.CalculationMethod.muslim_world_league,
                adhan.Madhab.shafi),
          );
        });
      }
    }
  });

  group('Umm al-Qura adjustment', () {
    const makkahLat = 21.4225;
    const makkahLng = 39.8262;
    final date = DateTime(2026, 6, 21);

    test('makkah: Dhuhr = package + 3 min, other times = package', () async {
      final times = await service.getPrayerTimes(
        date: date,
        latitude: makkahLat,
        longitude: makkahLng,
        calculationMethod: CalculationMethod.makkah,
        asrMadhab: AsrMadhab.shafi,
      );
      final package = _packageTimes(makkahLat, makkahLng, date,
          adhan.CalculationMethod.umm_al_qura, adhan.Madhab.shafi);
      final expected = [...package];
      expected[2] = package[2] + const Duration(minutes: 3).inMilliseconds;
      expect(_epochs(times), expected);
    });

    for (final entry in _packageMethod.entries) {
      if (entry.key == CalculationMethod.makkah) continue;
      test('${entry.key.name}: every time equals the package exactly',
          () async {
        final times = await service.getPrayerTimes(
          date: date,
          latitude: makkahLat,
          longitude: makkahLng,
          calculationMethod: entry.key,
          asrMadhab: AsrMadhab.shafi,
        );
        expect(
          _epochs(times),
          _packageTimes(
              makkahLat, makkahLng, date, entry.value, adhan.Madhab.shafi),
        );
      });
    }
  });
}
