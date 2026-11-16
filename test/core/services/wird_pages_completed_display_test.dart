// Spec: docs/designs/mode-separation.md, decision M (owner, 2026-11-15):
// the credit (streak, days completed) stays shared between the modes, but the
// Pages screen shows "completed today" only from page progress.
import 'package:aura_app/core/models/wird.dart';
import 'package:aura_app/core/services/wird_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _clock = DateTime(2026, 11, 15, 10);

WirdService _service() => WirdService.forTesting(now: () => _clock);

const _pageSettings = WirdSettings(wirdUnit: WirdUnit.page, dailyPageGoal: 5);
const _juzSettings = WirdSettings(wirdUnit: WirdUnit.juz, dailyJuzGoal: 1);

Future<int> _days() async =>
    (await SharedPreferences.getInstance())
        .getInt('wird_total_days_completed') ??
    0;

Future<int> _streak(WirdService s) => s.getStreakCount();

/// Completed today by juz only (goal 1), then Juz -> Pages as the app does it.
Future<WirdService> _completedByJuzThenPages() async {
  final s = _service();
  await s.updateSettings(_juzSettings);
  await s.toggleJuzCompleted(3);
  await s.emptyJuzData();
  await s.updateSettings(_pageSettings);
  return s;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('(i) completed by juz only, then Pages mode', () {
    test('the Pages state is NOT completed', () async {
      final s = await _completedByJuzThenPages();
      final today = await s.getTodayProgress();
      expect(today, isNotNull);
      expect(today!.isCompletedIn(_pageSettings), isFalse);
    });

    test('streak and days completed are unchanged by the switch', () async {
      final s = _service();
      await s.updateSettings(_juzSettings);
      await s.toggleJuzCompleted(3);
      final streakBefore = await _streak(s);
      final daysBefore = await _days();
      expect(streakBefore, 1);
      expect(daysBefore, 1);
      await s.emptyJuzData();
      await s.updateSettings(_pageSettings);
      expect(await _streak(s), streakBefore);
      expect(await _days(), daysBefore);
    });
  });


  group('(ii) then page progress completes the same day: at most one credit',
      () {
    test('all pages in one move', () async {
      final s = await _completedByJuzThenPages();
      final r = await s.creditPages(5, fromPage: 1, toPage: 6);
      expect(r.progress.isCompletedIn(_pageSettings), isTrue);
      expect(await _days(), 1);
      expect(await _streak(s), 1);
    });

    test('pages in two moves: below the goal first, then reaching it',
        () async {
      final s = await _completedByJuzThenPages();
      final first = await s.creditPages(2, fromPage: 1, toPage: 3);
      expect(first.progress.isCompletedIn(_pageSettings), isFalse);
      expect(await _days(), 1, reason: 'no new credit below the goal');
      final second = await s.creditPages(3, fromPage: 3, toPage: 6);
      expect(second.progress.isCompletedIn(_pageSettings), isTrue);
      expect(await _days(), 1, reason: 'today already had its one credit');
      expect(await _streak(s), 1);
    });
  });

  group('(iii) completed by pages only', () {
    test('the Pages state is completed, one credit', () async {
      final s = _service();
      await s.updateSettings(_pageSettings);
      final r = await s.creditPages(5, fromPage: 1, toPage: 6);
      expect(r.grantedStreakCredit, isTrue);
      expect(r.progress.isCompletedIn(_pageSettings), isTrue);
      expect(await _days(), 1);
      expect(await _streak(s), 1);
    });
  });

  group('(iv) page mode with no juz involvement is unchanged', () {
    test('below the goal: not completed', () async {
      final s = _service();
      await s.updateSettings(_pageSettings);
      final r = await s.creditPages(3, fromPage: 1, toPage: 4);
      expect(r.progress.isCompletedIn(_pageSettings), isFalse);
      expect(await _days(), 0);
    });

    test('Mark Complete still shows completed in Pages mode', () async {
      final s = _service();
      await s.updateSettings(_pageSettings);
      await s.markDayComplete();
      final today = await s.getTodayProgress();
      expect(today!.isCompletedIn(_pageSettings), isTrue);
      expect(await _days(), 1);
      expect(await _streak(s), 1);
    });

    test('a second move on a completed day gives no second credit', () async {
      final s = _service();
      await s.updateSettings(_pageSettings);
      await s.creditPages(5, fromPage: 1, toPage: 6);
      final r = await s.creditPages(2, fromPage: 6, toPage: 8);
      expect(r.grantedStreakCredit, isFalse);
      expect(await _days(), 1);
    });
  });
}
