import 'dart:io';

import 'package:adhan/adhan.dart' as adhan;
import 'package:aura_app/core/models/prayer_settings.dart';
import 'package:aura_app/core/models/prayer_time.dart';
import 'package:aura_app/core/services/prayer_times_service.dart';
import 'package:flutter/foundation.dart';
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
  CalculationMethod.qatar: adhan.CalculationMethod.qatar,
  CalculationMethod.dubai: adhan.CalculationMethod.dubai,
  CalculationMethod.turkey: adhan.CalculationMethod.turkey,
  CalculationMethod.singapore: adhan.CalculationMethod.singapore,
  CalculationMethod.moonsightingCommittee:
      adhan.CalculationMethod.moon_sighting_committee,
};

/// Each stored UI method string (the 12 picker values) and the internal name
/// (fixture `method` column) it must map to.
const _uiToInternal = <String, String>{
  'MuslimWorldLeague': 'muslimWorldLeague',
  'Egyptian': 'egyptian',
  'Karachi': 'karachi',
  'UmmAlQura': 'makkah',
  'NorthAmerica': 'isna',
  'Kuwait': 'kuwait',
  'Tehran': 'tehran',
  'Qatar': 'qatar',
  'Dubai': 'dubai',
  'Turkey': 'turkey',
  'Singapore': 'singapore',
  'MoonsightingCommittee': 'moonsightingCommittee',
};

/// One fixture row: coordinates, date and the six expected epoch ms.
class _FixtureRow {
  final String city;
  final double lat;
  final double lng;
  final DateTime date;
  final List<int> times;

  _FixtureRow(this.city, this.lat, this.lng, this.date, this.times);
}

/// Fixture rows keyed by '{method}|{madhab}'.
Map<String, List<_FixtureRow>> _readFixture() {
  final lines = File('test/fixtures/prayer_parity.csv').readAsLinesSync();
  final rows = <String, List<_FixtureRow>>{};
  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;
    final f = line.split(',');
    final d = f[4].split('-').map(int.parse).toList();
    rows.putIfAbsent('${f[5]}|${f[6]}', () => []).add(_FixtureRow(
          f[0],
          double.parse(f[1]),
          double.parse(f[2]),
          DateTime(d[0], d[1], d[2]),
          f.sublist(7, 13).map(int.parse).toList(),
        ));
  }
  return rows;
}

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

  // The service logs every calculation; thousands of lines slow the run.
  final originalDebugPrint = debugPrint;
  setUpAll(() => debugPrint = (String? message, {int? wrapWidth}) {});
  tearDownAll(() => debugPrint = originalDebugPrint);

  group('mapping functions', () {
    test('every UI method string maps to its own internal value', () {
      for (final entry in _uiToInternal.entries) {
        expect(calculationMethodFromPref(entry.key).name, entry.value,
            reason: entry.key);
      }
    });

    test('an exact enum name is accepted; null / unknown -> MWL', () {
      for (final m in CalculationMethod.values) {
        expect(calculationMethodFromPref(m.name), m);
      }
      expect(
          calculationMethodFromPref(null), CalculationMethod.muslimWorldLeague);
      expect(calculationMethodFromPref('Unknown'),
          CalculationMethod.muslimWorldLeague);
    });

    test('madhab is matched case-insensitively; null / unknown -> shafi', () {
      expect(asrMadhabFromPref('Hanafi'), AsrMadhab.hanafi);
      expect(asrMadhabFromPref('hanafi'), AsrMadhab.hanafi);
      expect(asrMadhabFromPref('HANAFI'), AsrMadhab.hanafi);
      expect(asrMadhabFromPref('Shafi'), AsrMadhab.shafi);
      expect(asrMadhabFromPref('shafi'), AsrMadhab.shafi);
      expect(asrMadhabFromPref(null), AsrMadhab.shafi);
      expect(asrMadhabFromPref('Maliki'), AsrMadhab.shafi);
    });
  });

  group('UI method x madhab equals the fixture', () {
    final fixture = _readFixture();
    for (final ui in _uiToInternal.entries) {
      for (final storedMadhab in ['Shafi', 'Hanafi']) {
        test('${ui.key} / $storedMadhab', () async {
          final method = calculationMethodFromPref(ui.key);
          final madhab = asrMadhabFromPref(storedMadhab);
          final rows = fixture['${ui.value}|${storedMadhab.toLowerCase()}']!;
          expect(rows.length, 130); // 13 cities x 10 dates
          for (final row in rows) {
            final times = await service.getPrayerTimes(
              date: row.date,
              latitude: row.lat,
              longitude: row.lng,
              calculationMethod: method,
              asrMadhab: madhab,
            );
            expect(_epochs(times), row.times,
                reason: '${row.city} ${row.date}');
          }
        });
      }
    }
  });

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
