import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aura_app/core/models/prayer_time.dart';
import 'package:aura_app/core/services/prayer_widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic>? capturedWidgetArgs;

  setUp(() {
    capturedWidgetArgs = null;
    SharedPreferences.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.aura.hala/widgets'),
      (call) async {
        if (call.method == 'updatePrayerWidgets') {
          capturedWidgetArgs = Map<String, dynamic>.from(call.arguments as Map);
        }
        return null;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.aura.hala/background_service'),
      (call) async {
        if (call.method == 'updatePrayerTimes') {}
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.aura.hala/widgets'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.aura.hala/background_service'),
      null,
    );
  });

  test('savePrayerTimes sends dhuhr_time for Zuhr, never zuhr_time', () async {
    final service = await PrayerWidgetService.init();

    final now = DateTime.now();
    final prayers = [
      PrayerTime(name: 'Fajr', nameAr: 'الفجر', time: now),
      PrayerTime(name: 'Sunrise', nameAr: 'الشروق', time: now.add(const Duration(hours: 1))),
      PrayerTime(
        name: 'Zuhr',
        nameAr: 'الظهر',
        time: now.add(const Duration(hours: 5)),
        iqamaTime: now.add(const Duration(hours: 5, minutes: 15)),
      ),
      PrayerTime(name: 'Asr', nameAr: 'العصر', time: now.add(const Duration(hours: 8))),
      PrayerTime(name: 'Maghrib', nameAr: 'المغرب', time: now.add(const Duration(hours: 10))),
      PrayerTime(name: 'Isha', nameAr: 'العشاء', time: now.add(const Duration(hours: 12))),
    ];

    await service.savePrayerTimes(
      prayerTimes: prayers,
      nextPrayer: prayers[2],
      language: 'en',
    );

    final prayerTimesMap = Map<String, String>.from(
        capturedWidgetArgs!['prayerTimes'] as Map);
    final iqamaTimesMap = Map<String, String>.from(
        capturedWidgetArgs!['iqamaTimes'] as Map);

    expect(prayerTimesMap.containsKey('dhuhr_time'), isTrue);
    expect(prayerTimesMap.containsKey('zuhr_time'), isFalse);
    expect(iqamaTimesMap.containsKey('dhuhr_iqama_time'), isTrue);
    expect(iqamaTimesMap.containsKey('zuhr_iqama_time'), isFalse);
  });
}
