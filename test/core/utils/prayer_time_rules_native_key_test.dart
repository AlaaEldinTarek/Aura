import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/utils/prayer_time_rules.dart';

void main() {
  group('nativePrayerKey', () {
    test('maps standard prayer names to lowercase', () {
      expect(nativePrayerKey('Fajr'), 'fajr');
      expect(nativePrayerKey('Sunrise'), 'sunrise');
      expect(nativePrayerKey('Asr'), 'asr');
      expect(nativePrayerKey('Maghrib'), 'maghrib');
      expect(nativePrayerKey('Isha'), 'isha');
    });

    test('maps Zuhr and Dhuhr to dhuhr', () {
      expect(nativePrayerKey('Zuhr'), 'dhuhr');
      expect(nativePrayerKey('Dhuhr'), 'dhuhr');
      expect(nativePrayerKey('zuhr'), 'dhuhr');
      expect(nativePrayerKey('dhuhr'), 'dhuhr');
    });
  });
}
