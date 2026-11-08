// Generates test/fixtures/prayer_parity.csv: adhan package output (plus the
// documented app adjustments) for every city × date × method × madhab.
//
// Run by hand from the project root:
//   dart run tool/generate_prayer_parity_fixture.dart
//
// Run on a host with UTC offset >= 0: the package's dayOfYear depends on the
// host offset (spec docs/designs/fx-0-prayer-settings.md, item 2).
//
// This script cannot import lib/core/services/prayer_times_service.dart (it
// imports package:flutter/foundation.dart, which `dart run` cannot load), so it
// keeps its own copy of the internal-name -> package-method map and of the
// Umm al-Qura Dhuhr +3 min adjustment.
import 'dart:io';

import 'package:adhan/adhan.dart' as adhan;

/// City, latitude and longitude exactly as written in the spec, IANA zone.
const _cities = <List<String>>[
  ['Cairo', '30.0444', '31.2357', 'Africa/Cairo'],
  ['Makkah', '21.4225', '39.8262', 'Asia/Riyadh'],
  ['Doha', '25.2854', '51.5310', 'Asia/Qatar'],
  ['Dubai', '25.2048', '55.2708', 'Asia/Dubai'],
  ['Istanbul', '41.0082', '28.9784', 'Europe/Istanbul'],
  ['Singapore', '1.3521', '103.8198', 'Asia/Singapore'],
  ['Karachi', '24.8607', '67.0011', 'Asia/Karachi'],
  ['Tehran', '35.6892', '51.3890', 'Asia/Tehran'],
  ['Toronto', '43.6532', '-79.3832', 'America/Toronto'],
  ['New York', '40.7128', '-74.0060', 'America/New_York'],
  ['London', '51.5074', '-0.1278', 'Europe/London'],
  ['Birmingham (UK)', '52.4862', '-1.8904', 'Europe/London'],
  ['Oslo', '59.9139', '10.7522', 'Europe/Oslo'],
];

/// 4 seasonal dates and 6 DST change days, year 2026.
const _dates = <List<int>>[
  [2026, 3, 20],
  [2026, 6, 21],
  [2026, 9, 23],
  [2026, 12, 21],
  [2026, 4, 24],
  [2026, 10, 29],
  [2026, 3, 29],
  [2026, 10, 25],
  [2026, 3, 8],
  [2026, 11, 1],
];

/// Internal method names (the `prayer_calc_method` contract strings) mapped
/// to their package method. Copy of the app mapping in prayer_times_service.dart.
const _methods = <String, adhan.CalculationMethod>{
  'muslimWorldLeague': adhan.CalculationMethod.muslim_world_league,
  'isna': adhan.CalculationMethod.north_america,
  'egyptian': adhan.CalculationMethod.egyptian,
  'makkah': adhan.CalculationMethod.umm_al_qura,
  'karachi': adhan.CalculationMethod.karachi,
  'tehran': adhan.CalculationMethod.tehran,
  'kuwait': adhan.CalculationMethod.kuwait,
  'fixedAngle': adhan.CalculationMethod.egyptian,
  'proportional': adhan.CalculationMethod.muslim_world_league,
  'qatar': adhan.CalculationMethod.qatar,
  'dubai': adhan.CalculationMethod.dubai,
  'turkey': adhan.CalculationMethod.turkey,
  'singapore': adhan.CalculationMethod.singapore,
  'moonsightingCommittee': adhan.CalculationMethod.moon_sighting_committee,
};

const _madhabs = <String, adhan.Madhab>{
  'shafi': adhan.Madhab.shafi,
  'hanafi': adhan.Madhab.hanafi,
};

String _two(int n) => n.toString().padLeft(2, '0');

void main() {
  final out = StringBuffer(
      'city,lat,lng,tz,date,method,madhab,fajr,sunrise,dhuhr,asr,maghrib,isha\n');
  var rows = 0;

  for (final city in _cities) {
    final coordinates =
        adhan.Coordinates(double.parse(city[1]), double.parse(city[2]));
    for (final d in _dates) {
      final date = '${d[0]}-${_two(d[1])}-${_two(d[2])}';
      for (final method in _methods.entries) {
        for (final madhab in _madhabs.entries) {
          final params = method.value.getParameters();
          // Documented app adjustment: Umm al-Qura Dhuhr +3 min.
          if (method.key == 'makkah') params.adjustments.dhuhr = 3;
          params.madhab = madhab.value;

          final times = adhan.PrayerTimes(
              coordinates, adhan.DateComponents(d[0], d[1], d[2]), params);
          final cityName = city[0].contains(',') ? '"${city[0]}"' : city[0];
          out.writeln([
            cityName,
            city[1],
            city[2],
            city[3],
            date,
            method.key,
            madhab.key,
            times.fajr.millisecondsSinceEpoch,
            times.sunrise.millisecondsSinceEpoch,
            times.dhuhr.millisecondsSinceEpoch,
            times.asr.millisecondsSinceEpoch,
            times.maghrib.millisecondsSinceEpoch,
            times.isha.millisecondsSinceEpoch,
          ].join(','));
          rows++;
        }
      }
    }
  }

  final file = File('test/fixtures/prayer_parity.csv');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(out.toString());
  stdout.writeln('Wrote $rows rows to ${file.path} '
      '(host UTC offset ${DateTime.now().timeZoneOffset}).');
}
