// Spec: docs/designs/mode-separation.md, M2 (decisions A, B, D, K) and the
// Wird block of checkAndAward. Prefs are mocked; no Firebase.
import 'dart:convert';

import 'package:aura_app/core/models/wird.dart';
import 'package:aura_app/core/services/achievement_service.dart';
import 'package:aura_app/core/services/wird_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoCloudWird extends WirdService {
  _NoCloudWird(DateTime Function() now) : super.forTesting(now: now);
}

void main() {
  final clock = DateTime(2026, 11, 15, 10);
  late WirdService wird;

  Map<String, Object> seed() => {
        'wird_completed_juz': jsonEncode([1, 2, 3, 5]),
        'wird_khatm_count': 2,
        'wird_khatm_dates': jsonEncode(['2026-01-01', '2026-06-01']),
        'wird_streak_count': 6,
        'wird_streak_date': '2026-11-15',
        'wird_total_days_completed': 40,
        'wird_progress_history': jsonEncode([
          WirdProgress(
            date: clock,
            juzCompletedToday: const [3, 5],
            isCompleted: true,
          ).toJson(),
        ]),
        'wird_marker': 'marker-record',
      };

  setUp(() {
    SharedPreferences.setMockInitialValues(seed());
    wird = _NoCloudWird(() => clock);
  });

  group('emptyJuzData (decisions A, B, D, K)', () {
    test('empties the checked cards and today\'s juz list', () async {
      await wird.emptyJuzData();
      expect(await wird.getCompletedJuz(), isEmpty);
      final today = await wird.getTodayProgress();
      expect(today!.juzCompletedToday, isEmpty);
    });

    test('keeps khatma count and dates, streak, days, marker, history day',
        () async {
      await wird.emptyJuzData();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('wird_khatm_count'), 2);
      expect(prefs.getString('wird_khatm_dates'),
          jsonEncode(['2026-01-01', '2026-06-01']));
      expect(prefs.getInt('wird_streak_count'), 6);
      expect(prefs.getString('wird_streak_date'), '2026-11-15');
      expect(prefs.getInt('wird_total_days_completed'), 40);
      expect(prefs.getString('wird_marker'), 'marker-record');
      final today = await wird.getTodayProgress();
      expect(today!.isCompleted, isTrue, reason: 'day credit is kept');
    });

    test('works with no data at all (local only, no throw)', () async {
      SharedPreferences.setMockInitialValues({});
      await wird.emptyJuzData();
      expect(await wird.getCompletedJuz(), isEmpty);
    });
  });

  group('localWirdJuzAchievementIds (Wird block of checkAndAward)', () {
    test('reads khatmas x 30 + checked cards from prefs', () async {
      SharedPreferences.setMockInitialValues({
        'wird_completed_juz': jsonEncode([1, 2, 3, 4, 5]),
      });
      expect(await localWirdJuzAchievementIds(wird: wird), ['wird_juz_5']);
    });

    test('a juz khatma alone earns all three', () async {
      SharedPreferences.setMockInitialValues({'wird_khatm_count': 1});
      expect(await localWirdJuzAchievementIds(wird: wird),
          ['wird_juz_5', 'wird_juz_15', 'wird_juz_khatma']);
    });

    test('nothing checked, no khatma: nothing', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await localWirdJuzAchievementIds(wird: wird), isEmpty);
    });
  });
}
