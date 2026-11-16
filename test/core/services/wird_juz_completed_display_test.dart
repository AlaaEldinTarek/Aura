// Spec: docs/designs/mode-separation.md, decision M (c) (owner, 2026-11-15,
// "yes mirror"): in Juz mode "completed today" is true only from juz work
// (today's checked cards reach the juz goal, or the manual credit), never from
// page progress alone. The streak and days credit stay shared and never double
// count (guarded by wird_streak_date).
import 'package:aura_app/core/models/wird.dart';
import 'package:aura_app/core/services/wird_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime _now = DateTime(2026, 11, 15, 10);

WirdService _service() => WirdService.forTesting(now: () => _now);

const _page = WirdSettings(wirdUnit: WirdUnit.page, dailyPageGoal: 5);
const _juz = WirdSettings(wirdUnit: WirdUnit.juz, dailyJuzGoal: 1);

Future<int> _days() async =>
    (await SharedPreferences.getInstance())
        .getInt('wird_total_days_completed') ??
    0;

void main() {
  setUp(() {
    _now = DateTime(2026, 11, 15, 10);
    SharedPreferences.setMockInitialValues({});
  });

  group('(i) completed by pages only, then Juz mode with 0 cards', () {
    test('Juz mode is NOT completed (so the juz actions are shown)', () async {
      final s = _service();
      await s.updateSettings(_page);
      await s.creditPages(5, fromPage: 1, toPage: 6);
      await s.updateSettings(_juz);
      final today = await s.getTodayProgress();
      expect(today!.isCompleted, isTrue, reason: 'the stored flag is set');
      expect(today.isCompletedIn(_juz), isFalse);
    });

    test('the credit is kept: streak and days unchanged', () async {
      final s = _service();
      await s.updateSettings(_page);
      await s.creditPages(5, fromPage: 1, toPage: 6);
      await s.updateSettings(_juz);
      expect(await s.getStreakCount(), 1);
      expect(await _days(), 1);
    });
  });

  group('(ii) juz-only completion', () {
    test('still shows completed in Juz mode', () async {
      final s = _service();
      await s.updateSettings(_juz);
      await s.toggleJuzCompleted(3);
      final today = await s.getTodayProgress();
      expect(today!.isCompletedIn(_juz), isTrue);
    });

    test('below the juz goal it is not completed', () async {
      final s = _service();
      const goal2 = WirdSettings(wirdUnit: WirdUnit.juz, dailyJuzGoal: 2);
      await s.updateSettings(goal2);
      await s.toggleJuzCompleted(3);
      final today = await s.getTodayProgress();
      expect(today!.isCompletedIn(goal2), isFalse);
    });
  });

  group('(iii) manual credit', () {
    test('still shows completed in Juz mode', () async {
      final s = _service();
      await s.updateSettings(_juz);
      await s.markDayComplete();
      final today = await s.getTodayProgress();
      expect(today!.isCompletedIn(_juz), isTrue);
    });
  });

  group('(iv) one credit per day, whichever order pages and juz come in', () {
    test('juz credit, then 2 pages (flag flips), then another juz card',
        () async {
      final s = _service();
      await s.updateSettings(_juz);
      await s.toggleJuzCompleted(1);
      expect(await _days(), 1);
      await s.creditPages(2, fromPage: 1, toPage: 3);
      await s.toggleJuzCompleted(2);
      expect(await _days(), 1, reason: 'no second credit for today');
      expect(await s.getStreakCount(), 1);
    });

    test('pages complete the day first, then a juz card', () async {
      final s = _service();
      await s.creditPages(5, fromPage: 1, toPage: 6);
      await s.toggleJuzCompleted(1);
      expect(await _days(), 1);
      expect(await s.getStreakCount(), 1);
    });

    test('2 pages, then a juz card completes the day, then the page goal',
        () async {
      final s = _service();
      await s.creditPages(2, fromPage: 1, toPage: 3);
      await s.toggleJuzCompleted(1);
      expect(await _days(), 1);
      await s.creditPages(3, fromPage: 3, toPage: 6);
      expect(await _days(), 1);
      expect(await s.getStreakCount(), 1);
    });

    test('unchecking the only card takes the credit back, re-checking gives it',
        () async {
      final s = _service();
      await s.toggleJuzCompleted(1);
      expect(await _days(), 1);
      await s.toggleJuzCompleted(1);
      expect(await _days(), 0);
      await s.toggleJuzCompleted(1);
      expect(await _days(), 1);
    });
  });

  group('(v) a new day gives a new credit', () {
    test('juz one day, juz the next: days 2, streak 2', () async {
      final s = _service();
      await s.toggleJuzCompleted(1);
      _now = DateTime(2026, 11, 16, 10);
      await s.toggleJuzCompleted(2);
      expect(await _days(), 2);
      expect(await s.getStreakCount(), 2);
    });

    test('pages one day, pages the next: days 2, streak 2', () async {
      final s = _service();
      await s.creditPages(5, fromPage: 1, toPage: 6);
      _now = DateTime(2026, 11, 16, 10);
      await s.creditPages(5, fromPage: 6, toPage: 11);
      expect(await _days(), 2);
      expect(await s.getStreakCount(), 2);
    });
  });
}
