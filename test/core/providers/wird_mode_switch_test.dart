// Spec: docs/designs/mode-separation.md, M2: decisions A, B, D, K, L.
// The Juz -> Pages switch: check first, then empty the cards, then set the unit.
import 'dart:async';
import 'dart:convert';

import 'package:aura_app/core/models/wird.dart';
import 'package:aura_app/core/models/wird_marker.dart';
import 'package:aura_app/core/providers/wird_provider.dart';
import 'package:aura_app/core/services/wird_marker_service.dart';
import 'package:aura_app/core/services/wird_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Cloud implements WirdMarkerCloud {
  @override
  Future<CloudRead> readServer(String uid) async => const CloudReadAbsent();
  @override
  Future<MarkerPushResult> write(String uid, WirdMarkerRecord record) async =>
      const MarkerPushed();
}

/// Records the order of the three steps; never touches Firestore.
class _LogWird extends WirdService {
  _LogWird(this.log, DateTime Function() now) : super.forTesting(now: now);
  final List<String> log;

  @override
  Future<void> syncFromFirestore(String userId) async {}

  @override
  Future<void> emptyJuzData() async {
    log.add('empty');
    return super.emptyJuzData();
  }

  @override
  Future<void> updateSettings(WirdSettings settings) async {
    log.add('unit:${settings.wirdUnit.name}');
    return super.updateSettings(settings);
  }
}

final _clock = DateTime(2026, 11, 15, 10);
late List<String> log;
late List<Map<String, Object>> checkCalls;
late WirdService wird;
late WirdMarkerService marker;
String? uid;

Map<String, Object> _juzPrefs({bool juz = true}) => {
      'wird_settings': jsonEncode(WirdSettings(
              wirdUnit: juz ? WirdUnit.juz : WirdUnit.page)
          .toJson()),
      'wird_completed_juz': jsonEncode([1, 2, 3, 4, 5]),
      'wird_khatm_count': 1,
      'wird_khatm_dates': jsonEncode(['2026-06-01']),
      'wird_streak_count': 4,
      'wird_streak_date': '2026-11-15',
      'wird_total_days_completed': 9,
    };

Future<ProviderContainer> _build(
  Map<String, Object> prefs, {
  Future<void> Function(String, int, int)? check,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  log = [];
  checkCalls = [];
  uid = 'u1';
  wird = _LogWird(log, () => _clock);
  marker = WirdMarkerService.forTesting(
      cloud: _Cloud(), wird: wird, now: () => _clock, uid: () => uid);
  final c = ProviderContainer(overrides: [
    wirdStateProvider.overrideWith((ref) => WirdNotifier(
          wird: wird,
          marker: marker,
          uid: () => uid,
          juzCheck: ({
            required String userId,
            required int juzKhatmCount,
            required int checkedJuz,
          }) async {
            log.add('check');
            checkCalls.add({
              'userId': userId,
              'khatmas': juzKhatmCount,
              'checked': checkedJuz,
              'cardsAtCheck': (await wird.getCompletedJuz()).length,
            });
            if (check != null) await check(userId, juzKhatmCount, checkedJuz);
          },
        )),
  ]);
  addTearDown(c.dispose);
  c.listen(wirdStateProvider, (_, __) {});
  await pumpEventQueue(times: 60);
  log.clear();
  return c;
}

WirdNotifier _n(ProviderContainer c) => c.read(wirdStateProvider.notifier);
WirdState _s(ProviderContainer c) => c.read(wirdStateProvider).requireValue;

void main() {
  group('switchToPageMode (Juz -> Pages)', () {
    test('order: check first, then empty the cards, then set the unit',
        () async {
      final c = await _build(_juzPrefs());
      await _n(c).switchToPageMode();
      expect(log, ['check', 'empty', 'unit:page']);
    });

    test('the check sees the full cards and the captured values', () async {
      final c = await _build(_juzPrefs());
      await _n(c).switchToPageMode();
      expect(checkCalls.single,
          {'userId': 'u1', 'khatmas': 1, 'checked': 5, 'cardsAtCheck': 5});
    });

    test('result: cards empty, unit page, history/streak/days/khatma kept',
        () async {
      final c = await _build(_juzPrefs());
      await _n(c).switchToPageMode();
      final st = _s(c);
      expect(st.settings.wirdUnit, WirdUnit.page);
      expect(st.allCompletedJuz, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('wird_khatm_count'), 1);
      expect(prefs.getString('wird_khatm_dates'), jsonEncode(['2026-06-01']));
      expect(prefs.getInt('wird_streak_count'), 4);
      expect(prefs.getInt('wird_total_days_completed'), 9);
    });

    test('guest: check gets guest_user, cards are still emptied', () async {
      final c = await _build(_juzPrefs());
      uid = null;
      await _n(c).switchToPageMode();
      expect(checkCalls.single['userId'], 'guest_user');
      expect(_s(c).allCompletedJuz, isEmpty);
      expect(_s(c).settings.wirdUnit, WirdUnit.page);
    });

    test('offline: a check that never answers does not block emptying',
        () async {
      final never = Completer<void>();
      final c = await _build(_juzPrefs(), check: (_, __, ___) => never.future);
      await _n(c)
          .switchToPageMode(checkTimeout: const Duration(milliseconds: 50));
      expect(log, ['check', 'empty', 'unit:page']);
      expect(_s(c).allCompletedJuz, isEmpty);
    });

    test('a check that throws still empties the cards', () async {
      final c = await _build(_juzPrefs(),
          check: (_, __, ___) async => throw Exception('offline'));
      await _n(c).switchToPageMode();
      expect(log, ['check', 'empty', 'unit:page']);
      expect(_s(c).allCompletedJuz, isEmpty);
    });

    test('already in page mode: does nothing (no check, no emptying)',
        () async {
      final c = await _build(_juzPrefs(juz: false));
      await _n(c).switchToPageMode();
      expect(log, isEmpty);
      expect(_s(c).allCompletedJuz, [1, 2, 3, 4, 5]);
    });
  });

  group('Page -> Juz (decision A)', () {
    test('setWirdUnit(juz) changes only the unit and empties nothing',
        () async {
      final c = await _build(_juzPrefs(juz: false));
      await _n(c).setWirdUnit(WirdUnit.juz);
      expect(log, ['unit:juz']);
      expect(checkCalls, isEmpty);
      expect(_s(c).settings.wirdUnit, WirdUnit.juz);
      expect(_s(c).allCompletedJuz, [1, 2, 3, 4, 5]);
    });
  });

  group('Cancelled switch', () {
    test('without a call to switchToPageMode nothing changes', () async {
      // The dialog is M3 (UI). Its Cancel path must simply not call
      // switchToPageMode; this pins that the state is untouched until then.
      final c = await _build(_juzPrefs());
      expect(log, isEmpty);
      expect(_s(c).settings.wirdUnit, WirdUnit.juz);
      expect(_s(c).allCompletedJuz, [1, 2, 3, 4, 5]);
    });
  });
}
