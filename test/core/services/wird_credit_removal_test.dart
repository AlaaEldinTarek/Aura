// Spec: docs/designs/mode-separation.md, decision M and the credit-removal rule
// (owner, 2026-11-15, "yes fix"): a mode may take back the day's credit only if
// the day was not also completed by the other mode, or by Mark Complete.
import 'package:aura_app/core/models/wird.dart';
import 'package:aura_app/core/services/wird_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 11, 15, 10);
const _today = '2026-11-15';

WirdService _service() => WirdService.forTesting(now: () => _now);

const _page = WirdSettings(wirdUnit: WirdUnit.page, dailyPageGoal: 5);
const _juz = WirdSettings(wirdUnit: WirdUnit.juz, dailyJuzGoal: 1);
// Both goals in one settings object (the unit is what differs between modes).
const _bothPage =
    WirdSettings(wirdUnit: WirdUnit.page, dailyPageGoal: 5, dailyJuzGoal: 1);

Future<int> _days() async =>
    (await SharedPreferences.getInstance())
        .getInt('wird_total_days_completed') ??
    0;

Future<void> _undoPages(WirdService s, int pages, {int restoreTo = 1}) =>
    s.removePages(pages,
        dateKey: _today, removeCredit: true, restoreCurrentPage: restoreTo);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('(i) pages complete the day, then a juz card is checked and unchecked',
      () {
    test('days and streak are unchanged', () async {
      final s = _service();
      await s.updateSettings(_bothPage);
      await s.creditPages(5, fromPage: 1, toPage: 6);
      await s.toggleJuzCompleted(1);
      await s.toggleJuzCompleted(1);
      expect(await _days(), 1);
      expect(await s.getStreakCount(), 1);
    });
  });

  group('(ii) page undo after a juz-completed day', () {
    test('cards emptied by the switch, 2 pages undone: credit stays', () async {
      final s = _service();
      await s.updateSettings(_bothPage);
      await s.creditPages(2, fromPage: 1, toPage: 3);
      await s.toggleJuzCompleted(1);
      expect(await _days(), 1);
      await s.emptyJuzData();
      await _undoPages(s, 2);
      expect(await _days(), 1);
      expect(await s.getStreakCount(), 1);
    });

    test('cards still checked, pages 5 undone: credit stays', () async {
      final s = _service();
      await s.updateSettings(_bothPage);
      await s.toggleJuzCompleted(1);
      await s.creditPages(5, fromPage: 1, toPage: 6);
      await _undoPages(s, 5);
      expect(await _days(), 1);
      expect(await s.getStreakCount(), 1);
    });
  });

  group('(iii) a day completed only by juz', () {
    test('unchecking the card still takes the credit back', () async {
      final s = _service();
      await s.updateSettings(_juz);
      await s.toggleJuzCompleted(1);
      expect(await _days(), 1);
      await s.toggleJuzCompleted(1);
      expect(await _days(), 0);
      expect(await s.getStreakCount(), 0);
    });
  });

  group('(iv) a day completed only by pages', () {
    test('the page undo still takes the credit back', () async {
      final s = _service();
      await s.updateSettings(_page);
      await s.creditPages(5, fromPage: 1, toPage: 6);
      expect(await _days(), 1);
      await _undoPages(s, 5);
      expect(await _days(), 0);
      expect(await s.getStreakCount(), 0);
    });
  });

  group('(v) both modes completed the day', () {
    test('undo pages: credit stays; then uncheck juz: credit goes', () async {
      final s = _service();
      await s.updateSettings(_bothPage);
      await s.toggleJuzCompleted(1);
      await s.creditPages(5, fromPage: 1, toPage: 6);
      expect(await _days(), 1);
      await _undoPages(s, 5);
      expect(await _days(), 1, reason: 'juz still completes the day');
      await s.toggleJuzCompleted(1);
      expect(await _days(), 0, reason: 'the second undo takes it back');
      expect(await s.getStreakCount(), 0);
    });

    test('uncheck juz: credit stays; then undo pages: credit goes', () async {
      final s = _service();
      await s.updateSettings(_bothPage);
      await s.creditPages(5, fromPage: 1, toPage: 6);
      await s.toggleJuzCompleted(1);
      await s.toggleJuzCompleted(1);
      expect(await _days(), 1, reason: 'pages still complete the day');
      await _undoPages(s, 5);
      expect(await _days(), 0);
      expect(await s.getStreakCount(), 0);
    });
  });

  group('(vi) Mark Complete keeps the credit', () {
    test('juz check and uncheck do not remove it', () async {
      final s = _service();
      await s.updateSettings(_bothPage);
      await s.markDayComplete();
      await s.toggleJuzCompleted(1);
      await s.toggleJuzCompleted(1);
      expect(await _days(), 1);
    });

    test('a page undo does not remove it', () async {
      final s = _service();
      await s.updateSettings(_bothPage);
      await s.creditPages(2, fromPage: 1, toPage: 3);
      await s.markDayComplete();
      await _undoPages(s, 2);
      expect(await _days(), 1);
    });

    test(
        'undoing Mark Complete keeps the credit while juz work completes '
        'the day (unit Pages)', () async {
      final s = _service();
      await s.updateSettings(_bothPage);
      await s.markDayComplete();
      await s.toggleJuzCompleted(1);
      await s.undoComplete();
      expect(await _days(), 1);
      expect(await s.getStreakCount(), 1);
    });

    test('undoing Mark Complete with no other work takes the credit back',
        () async {
      final s = _service();
      await s.updateSettings(_bothPage);
      await s.markDayComplete();
      await s.undoComplete();
      expect(await _days(), 0);
    });
  });
}
