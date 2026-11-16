// Spec: docs/designs/mode-separation.md, decisions H, J, K, L and "Check before
// emptying". Pure functions plus an injected store: no Firebase.
import 'dart:async';

import 'package:aura_app/core/models/achievement.dart';
import 'package:aura_app/core/services/achievement_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Store {
  _Store(
      {this.earned = const {}, this.failLoad = false, this.failAward = false});
  final Set<String> earned;
  final bool failLoad;
  final bool failAward;
  final awarded = <String>[];
  int loads = 0;

  Future<Set<String>> load() async {
    loads++;
    if (failLoad) throw Exception('offline');
    return earned;
  }

  Future<void> award(String id) async {
    if (failAward) throw Exception('write failed');
    awarded.add(id);
  }
}

Future<List<String>> _run(
  _Store s, {
  String userId = 'u1',
  int khatmas = 0,
  int checked = 0,
  Duration timeout = const Duration(milliseconds: 200),
  Future<Set<String>> Function()? load,
}) =>
    awardJuzAchievementsBeforeEmptying(
      userId: userId,
      juzKhatmCount: khatmas,
      checkedJuz: checked,
      loadEarnedIds: load ?? s.load,
      award: s.award,
      timeout: timeout,
    );

void main() {
  group('wirdJuzAchievementIds (decision H: khatmas x 30 + checked cards)', () {
    test('nothing at 0 and at 4', () {
      expect(wirdJuzAchievementIds(juzKhatmCount: 0, checkedJuz: 0), isEmpty);
      expect(wirdJuzAchievementIds(juzKhatmCount: 0, checkedJuz: 4), isEmpty);
    });

    test('wird_juz_5 at 5 and up to 14', () {
      expect(wirdJuzAchievementIds(juzKhatmCount: 0, checkedJuz: 5),
          ['wird_juz_5']);
      expect(wirdJuzAchievementIds(juzKhatmCount: 0, checkedJuz: 14),
          ['wird_juz_5']);
    });

    test('wird_juz_15 joins at 15 and stays below 30 cards', () {
      expect(wirdJuzAchievementIds(juzKhatmCount: 0, checkedJuz: 15),
          ['wird_juz_5', 'wird_juz_15']);
      expect(wirdJuzAchievementIds(juzKhatmCount: 0, checkedJuz: 29),
          ['wird_juz_5', 'wird_juz_15']);
    });

    test('30 checked cards and no khatma: no wird_juz_khatma', () {
      expect(wirdJuzAchievementIds(juzKhatmCount: 0, checkedJuz: 30),
          ['wird_juz_5', 'wird_juz_15']);
    });

    test('one khatma with empty cards: all three (30 juz in total)', () {
      expect(wirdJuzAchievementIds(juzKhatmCount: 1, checkedJuz: 0),
          ['wird_juz_5', 'wird_juz_15', 'wird_juz_khatma']);
    });

    test('derived total counts leftover cards on top of khatmas', () {
      expect(wirdJuzAchievementIds(juzKhatmCount: 1, checkedJuz: 3),
          ['wird_juz_5', 'wird_juz_15', 'wird_juz_khatma']);
    });

    test('negative inputs are treated as zero', () {
      expect(wirdJuzAchievementIds(juzKhatmCount: -1, checkedJuz: -5), isEmpty);
    });

    test(
        'a page-mode user is unchanged: page ids ignore juz data and juz ids '
        'ignore pages', () {
      expect(wirdAchievementIds(khatmaCount: 1, pages: 300),
          ['wird_khatma', 'wird_pages_100', 'wird_pages_300']);
      expect(wirdAchievementIds(khatmaCount: 0, pages: 99), isEmpty);
      // A page user has no juz data: the juz ids are empty.
      expect(wirdJuzAchievementIds(juzKhatmCount: 0, checkedJuz: 0), isEmpty);
      for (final id in wirdAchievementIds(khatmaCount: 5, pages: 9999)) {
        expect(id, isNot(startsWith('wird_juz_')));
      }
    });
  });

  group('definitions', () {
    test(
        'the three juz achievements exist in the Quran group with the '
        'owner-reviewed names', () {
      Achievement byId(String id) =>
          AchievementDefinitions.all.firstWhere((a) => a.id == id);
      for (final id in ['wird_juz_5', 'wird_juz_15', 'wird_juz_khatma']) {
        expect(byId(id).category, AchievementCategory.quran);
      }
      expect(byId('wird_juz_5').nameAr, 'خمسة أجزاء');
      expect(byId('wird_juz_15').nameAr, 'نصف القرآن');
      expect(byId('wird_juz_khatma').nameAr, 'ختمة بالأجزاء');
      expect(byId('wird_juz_5').nameEn, 'Five Juz');
      expect(byId('wird_juz_5').descriptionAr, 'اقرأ 5 أجزاء عبر الورد');
    });

    test('ids are unique', () {
      final ids = AchievementDefinitions.all.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('awardJuzAchievementsBeforeEmptying (decisions K, L)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('5 cards, nothing earned: awards wird_juz_5', () async {
      final s = _Store();
      expect(await _run(s, checked: 5), ['wird_juz_5']);
      expect(s.awarded, ['wird_juz_5']);
    });

    test('4 cards: nothing awarded', () async {
      final s = _Store();
      expect(await _run(s, checked: 4), isEmpty);
      expect(s.awarded, isEmpty);
    });

    test('already earned ids are not awarded again', () async {
      final s = _Store(earned: {'wird_juz_5'});
      expect(await _run(s, checked: 15), ['wird_juz_15']);
      expect(s.awarded, ['wird_juz_15']);
    });

    test('the award uses the captured values, not prefs read afterwards',
        () async {
      // Prefs already hold empty cards and no khatma, as after emptying.
      SharedPreferences.setMockInitialValues(
          {'flutter.wird_completed_juz': '[]', 'flutter.wird_khatm_count': 0});
      final s = _Store();
      expect(await _run(s, checked: 5), ['wird_juz_5']);
    });

    test('guest: returns at once, no store call at all', () async {
      final s = _Store();
      expect(await _run(s, userId: 'guest_user', checked: 30, khatmas: 2),
          isEmpty);
      expect(s.loads, 0);
      expect(s.awarded, isEmpty);
    });

    test('the earned-list read throws: no exception, nothing awarded',
        () async {
      final s = _Store(failLoad: true);
      expect(await _run(s, checked: 15), isEmpty);
      expect(s.awarded, isEmpty);
    });

    test('an award throws: no exception reaches the caller', () async {
      final s = _Store(failAward: true);
      await expectLater(_run(s, checked: 15), completes);
    });

    test('the store never answers: the call ends after the bounded wait',
        () async {
      final s = _Store();
      final sw = Stopwatch()..start();
      final r = await _run(
        s,
        checked: 15,
        timeout: const Duration(milliseconds: 100),
        load: () => Completer<Set<String>>().future,
      );
      sw.stop();
      expect(r, isEmpty);
      expect(sw.elapsedMilliseconds, lessThan(2000));
      expect(s.awarded, isEmpty);
    });

    test('an award that never completes also ends after the bounded wait',
        () async {
      final r = await awardJuzAchievementsBeforeEmptying(
        userId: 'u1',
        juzKhatmCount: 0,
        checkedJuz: 5,
        loadEarnedIds: () async => <String>{},
        award: (_) => Completer<void>().future,
        timeout: const Duration(milliseconds: 100),
      );
      expect(r, isEmpty);
    });

    test('the wait length is one named constant, a few seconds', () {
      expect(kJuzSwitchCheckTimeout,
          greaterThanOrEqualTo(const Duration(seconds: 1)));
      expect(kJuzSwitchCheckTimeout,
          lessThanOrEqualTo(const Duration(seconds: 10)));
    });
  });
}
