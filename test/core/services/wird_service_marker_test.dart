// P3 cases only: the clock seam, creditPages and removePages. The cases for
// markDayComplete, undoComplete, toggleJuzCompleted (P4a) and for the end of
// the wird_total_pages_read mirror (P4b) are added in those phases.
import 'dart:convert';

import 'package:aura_app/core/models/wird.dart';
import 'package:aura_app/core/services/wird_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime _clock = DateTime(2026, 11, 13, 10);

WirdService _service() => WirdService.forTesting(now: () => _clock);

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _today = '2026-11-13';
const _yesterday = '2026-11-12';

Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

Future<List<Map<String, dynamic>>> _history() async {
  final p = await _prefs();
  final s = p.getString('wird_progress_history');
  if (s == null) return [];
  return (jsonDecode(s) as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}

Future<Map<String, dynamic>?> _todayEntry() async {
  final h = await _history();
  for (final e in h) {
    if (e['date'] == _today) return e;
  }
  return null;
}

Map<String, Object> _entry({
  String date = _today,
  int pagesRead = 0,
  int startPage = 1,
  int currentPage = 1,
  bool isCompleted = false,
  bool manualCredit = false,
}) =>
    {
      'date': date,
      'pagesRead': pagesRead,
      'startPage': startPage,
      'currentPage': currentPage,
      'isCompleted': isCompleted,
      'juzCompletedToday': <int>[],
      if (manualCredit) 'manualCredit': true,
    };

void _seed(Map<String, Object> values) =>
    SharedPreferences.setMockInitialValues(values);

void main() {
  setUp(() {
    _clock = DateTime(2026, 11, 13, 10);
    SharedPreferences.setMockInitialValues({});
  });

  group('clock seam', () {
    test('forTesting reads today from the injected clock', () async {
      _seed({
        'wird_progress_history': jsonEncode([_entry(pagesRead: 2)]),
      });
      final s = _service();
      expect((await s.getTodayProgress())?.pagesRead, 2);
      _clock = DateTime(2026, 11, 14, 0, 5);
      expect(await s.getTodayProgress(), isNull,
          reason: 'after midnight there is no entry for the new day');
    });

    test('the production singleton still exists', () {
      expect(WirdService.instance, isA<WirdService>());
    });
  });

  group('creditPages', () {
    test('first credit below the goal creates the entry from fromPage/toPage',
        () async {
      final s = _service();
      final r = await s.creditPages(3, fromPage: 31, toPage: 34);
      expect(r.grantedStreakCredit, isFalse);
      expect(r.progress.pagesRead, 3);
      expect(r.progress.startPage, 31);
      expect(r.progress.currentPage, 34);
      expect(r.progress.isCompleted, isFalse);
      final e = await _todayEntry();
      expect(e!['pagesRead'], 3);
      expect(e['startPage'], 31);
      expect(e['currentPage'], 34);
      final p = await _prefs();
      expect(p.getInt('wird_streak_count') ?? 0, 0);
      expect(p.getInt('wird_total_days_completed') ?? 0, 0);
    });

    test('reaching the goal completes the day and raises the streak once',
        () async {
      final s = _service();
      final r = await s.creditPages(5, fromPage: 31, toPage: 36);
      expect(r.grantedStreakCredit, isTrue);
      expect(r.progress.isCompleted, isTrue);
      final p = await _prefs();
      expect(p.getInt('wird_streak_count'), 1);
      expect(p.getString('wird_streak_date'), _today);
      expect(p.getInt('wird_total_days_completed'), 1);
    });

    test('crossing the goal over two moves grants the credit on the second',
        () async {
      final s = _service();
      final a = await s.creditPages(3, fromPage: 31, toPage: 34);
      final b = await s.creditPages(3, fromPage: 34, toPage: 37);
      expect(a.grantedStreakCredit, isFalse);
      expect(b.grantedStreakCredit, isTrue);
      expect(b.progress.pagesRead, 6);
    });

    test('a second move on a completed day does not raise the streak again',
        () async {
      final s = _service();
      await s.creditPages(5, fromPage: 31, toPage: 36);
      final b = await s.creditPages(2, fromPage: 36, toPage: 38);
      expect(b.grantedStreakCredit, isFalse);
      expect(b.progress.pagesRead, 7);
      final p = await _prefs();
      expect(p.getInt('wird_streak_count'), 1);
      expect(p.getInt('wird_total_days_completed'), 1);
    });

    test(
        'startPage comes from fromPage on the first entry only; currentPage follows toPage',
        () async {
      final s = _service();
      await s.creditPages(1, fromPage: 31, toPage: 32);
      final b = await s.creditPages(1, fromPage: 32, toPage: 33);
      expect(b.progress.startPage, 31);
      expect(b.progress.currentPage, 33);
    });

    test('an existing entry keeps its startPage', () async {
      _seed({
        'wird_progress_history':
            jsonEncode([_entry(pagesRead: 1, startPage: 7, currentPage: 8)]),
      });
      final s = _service();
      final r = await s.creditPages(1, fromPage: 100, toPage: 101);
      expect(r.progress.startPage, 7);
      expect(r.progress.currentPage, 101);
    });

    test('the streak continues from yesterday', () async {
      _seed({'wird_streak_count': 3, 'wird_streak_date': _yesterday});
      final s = _service();
      await s.creditPages(5, fromPage: 1, toPage: 6);
      final p = await _prefs();
      expect(p.getInt('wird_streak_count'), 4);
      expect(p.getString('wird_streak_date'), _today);
    });

    test('the streak restarts at 1 after a gap', () async {
      _seed({'wird_streak_count': 3, 'wird_streak_date': '2026-11-01'});
      final s = _service();
      await s.creditPages(5, fromPage: 1, toPage: 6);
      expect((await _prefs()).getInt('wird_streak_count'), 1);
    });

    test('a manually credited day stays completed and gets no second credit',
        () async {
      _seed({
        'wird_progress_history':
            jsonEncode([_entry(isCompleted: true, manualCredit: true)]),
        'wird_streak_count': 1,
        'wird_streak_date': _today,
        'wird_total_days_completed': 1,
      });
      final s = _service();
      final r = await s.creditPages(2, fromPage: 1, toPage: 3);
      expect(r.grantedStreakCredit, isFalse);
      expect(r.progress.isCompleted, isTrue);
      expect(r.progress.manualCredit, isTrue);
      expect(r.progress.pagesRead, 2);
      final p = await _prefs();
      expect(p.getInt('wird_streak_count'), 1);
      expect(p.getInt('wird_total_days_completed'), 1);
    });

    test('the saved entry equals the returned progress', () async {
      final s = _service();
      final r = await s.creditPages(4, fromPage: 10, toPage: 14);
      final saved = await s.getTodayProgress();
      expect(saved!.pagesRead, r.progress.pagesRead);
      expect(saved.currentPage, r.progress.currentPage);
      expect(saved.startPage, r.progress.startPage);
    });

    test('a different day starts a new entry', () async {
      final s = _service();
      await s.creditPages(5, fromPage: 1, toPage: 6);
      _clock = DateTime(2026, 11, 14, 9);
      final r = await s.creditPages(1, fromPage: 6, toPage: 7);
      expect(r.progress.pagesRead, 1);
      expect(r.progress.startPage, 6);
      expect((await _history()).length, 2);
    });

    group('wird_total_pages_read mirror (until P4b)', () {
      test('adds the pages when the day is not complete before the call',
          () async {
        final s = _service();
        await s.creditPages(3, fromPage: 1, toPage: 4);
        expect((await _prefs()).getInt('wird_total_pages_read'), 3);
        await s.creditPages(4, fromPage: 4, toPage: 8);
        expect((await _prefs()).getInt('wird_total_pages_read'), 7,
            reason: 'the move that completes the day is still added');
      });

      test('does not add when the day was already complete', () async {
        final s = _service();
        await s.creditPages(5, fromPage: 1, toPage: 6);
        await s.creditPages(4, fromPage: 6, toPage: 10);
        expect((await _prefs()).getInt('wird_total_pages_read'), 5);
      });
    });

    test('does not throw when the cloud push cannot run', () async {
      // No Firebase in unit tests: the push fails inside, and is only logged.
      final s = _service();
      await s.creditPages(1, fromPage: 1, toPage: 2);
      await pumpEventQueue();
    });
  });

  group('removePages', () {
    test('rolls back completion, streak, streakDate and the day count',
        () async {
      final s = _service();
      await s.creditPages(5, fromPage: 31, toPage: 36);
      await s.removePages(5,
          dateKey: _today, removeCredit: true, restoreCurrentPage: 31);
      final e = await _todayEntry();
      expect(e!['pagesRead'], 0);
      expect(e['isCompleted'], isFalse);
      expect(e['currentPage'], 31);
      expect(e['startPage'], 31, reason: 'startPage is unchanged');
      final p = await _prefs();
      expect(p.getInt('wird_streak_count'), 0);
      expect(p.containsKey('wird_streak_date'), isFalse);
      expect(p.getInt('wird_total_days_completed'), 0);
    });

    test('a streak of 3 goes back to 2 and streakDate to yesterday', () async {
      _seed({'wird_streak_count': 2, 'wird_streak_date': _yesterday});
      final s = _service();
      await s.creditPages(5, fromPage: 1, toPage: 6);
      expect((await _prefs()).getInt('wird_streak_count'), 3);
      await s.removePages(5,
          dateKey: _today, removeCredit: true, restoreCurrentPage: 1);
      final p = await _prefs();
      expect(p.getInt('wird_streak_count'), 2);
      expect(p.getString('wird_streak_date'), _yesterday);
    });

    test('removeCredit false: the day becomes incomplete but the streak stays',
        () async {
      final s = _service();
      await s.creditPages(5, fromPage: 1, toPage: 6);
      await s.removePages(5,
          dateKey: _today, removeCredit: false, restoreCurrentPage: 1);
      final e = await _todayEntry();
      expect(e!['isCompleted'], isFalse);
      final p = await _prefs();
      expect(p.getInt('wird_streak_count'), 1);
      expect(p.getInt('wird_total_days_completed'), 1);
    });

    test('the day stays complete while pages still reach the goal', () async {
      final s = _service();
      await s.creditPages(10, fromPage: 1, toPage: 11);
      await s.removePages(5,
          dateKey: _today, removeCredit: true, restoreCurrentPage: 6);
      final e = await _todayEntry();
      expect(e!['pagesRead'], 5);
      expect(e['isCompleted'], isTrue);
      final p = await _prefs();
      expect(p.getInt('wird_streak_count'), 1);
      expect(p.getInt('wird_total_days_completed'), 1);
    });

    test('a manually credited day stays complete and keeps its streak',
        () async {
      _seed({
        'wird_progress_history': jsonEncode([
          _entry(
              pagesRead: 3,
              currentPage: 4,
              isCompleted: true,
              manualCredit: true)
        ]),
        'wird_streak_count': 1,
        'wird_streak_date': _today,
        'wird_total_days_completed': 1,
      });
      final s = _service();
      await s.removePages(3,
          dateKey: _today, removeCredit: true, restoreCurrentPage: 1);
      final e = await _todayEntry();
      expect(e!['pagesRead'], 0);
      expect(e['isCompleted'], isTrue);
      expect(e['manualCredit'], isTrue);
      final p = await _prefs();
      expect(p.getInt('wird_streak_count'), 1);
      expect(p.getInt('wird_total_days_completed'), 1);
    });

    test('a missing entry changes nothing', () async {
      _seed({
        'wird_streak_count': 2,
        'wird_streak_date': _today,
        'wird_total_days_completed': 2,
        'wird_total_pages_read': 40,
      });
      final s = _service();
      await s.removePages(5,
          dateKey: _today, removeCredit: true, restoreCurrentPage: 1);
      final p = await _prefs();
      expect(p.getInt('wird_streak_count'), 2);
      expect(p.getInt('wird_total_days_completed'), 2);
      expect(p.getInt('wird_total_pages_read'), 40);
      expect(await _history(), isEmpty);
    });

    test('an entry for another date is not touched', () async {
      _seed({
        'wird_progress_history': jsonEncode(
            [_entry(date: _yesterday, pagesRead: 5, isCompleted: true)]),
      });
      final s = _service();
      await s.removePages(5,
          dateKey: _today, removeCredit: true, restoreCurrentPage: 1);
      final h = await _history();
      expect(h.single['pagesRead'], 5);
    });

    test('pages never go below zero', () async {
      final s = _service();
      await s.creditPages(2, fromPage: 1, toPage: 3);
      await s.removePages(5,
          dateKey: _today, removeCredit: false, restoreCurrentPage: 1);
      expect((await _todayEntry())!['pagesRead'], 0);
      expect((await _prefs()).getInt('wird_total_pages_read'), 0,
          reason: 'the mirror is floored at 0');
    });

    test('the day count never goes below zero', () async {
      _seed({
        'wird_progress_history': jsonEncode(
            [_entry(pagesRead: 5, currentPage: 6, isCompleted: true)]),
        'wird_streak_count': 1,
        'wird_streak_date': _today,
        'wird_total_days_completed': 0,
      });
      final s = _service();
      await s.removePages(5,
          dateKey: _today, removeCredit: true, restoreCurrentPage: 1);
      expect((await _prefs()).getInt('wird_total_days_completed'), 0);
    });

    test('the streak is rolled back only when streakDate is today', () async {
      _seed({
        'wird_progress_history': jsonEncode(
            [_entry(pagesRead: 5, currentPage: 6, isCompleted: true)]),
        'wird_streak_count': 3,
        'wird_streak_date': _yesterday,
        'wird_total_days_completed': 4,
      });
      final s = _service();
      await s.removePages(5,
          dateKey: _today, removeCredit: true, restoreCurrentPage: 1);
      final p = await _prefs();
      expect(p.getInt('wird_streak_count'), 3,
          reason: 'guard: streakDate != today');
      expect(p.getString('wird_streak_date'), _yesterday);
      expect(p.getInt('wird_total_days_completed'), 3,
          reason: 'the day count is decremented by the caller path regardless');
    });

    test('mirror: subtracts the pages from wird_total_pages_read', () async {
      final s = _service();
      await s.creditPages(3, fromPage: 1, toPage: 4);
      await s.removePages(3,
          dateKey: _today, removeCredit: false, restoreCurrentPage: 1);
      expect((await _prefs()).getInt('wird_total_pages_read'), 0);
    });

    test('does not throw when the cloud push cannot run', () async {
      final s = _service();
      await s.creditPages(1, fromPage: 1, toPage: 2);
      await s.removePages(1,
          dateKey: _today, removeCredit: false, restoreCurrentPage: 1);
      await pumpEventQueue();
    });
  });

  test('helper sanity: _key formats like WirdProgress.dateKey', () {
    expect(_key(DateTime(2026, 1, 5)),
        WirdProgress(date: DateTime(2026, 1, 5)).dateKey);
  });
}
