// Spec: docs/designs/wird-marker.md item 24 (compose and action cases, P4a).
// The stats case (quranStatsProvider mapping) belongs to P4b.
import 'dart:convert';

import 'package:aura_app/core/models/wird.dart';
import 'package:aura_app/core/models/wird_marker.dart';
import 'package:aura_app/core/providers/wird_provider.dart';
import 'package:aura_app/core/services/wird_marker_service.dart';
import 'package:aura_app/core/services/wird_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_app/features/quran/wird_marker_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeCloud implements WirdMarkerCloud {
  WirdMarkerRecord? stored;
  @override
  Future<CloudRead> readServer(String uid) async =>
      stored == null ? const CloudReadAbsent() : CloudReadPresent(stored!);
  @override
  Future<MarkerPushResult> write(String uid, WirdMarkerRecord record) async {
    stored = record;
    return const MarkerPushed();
  }
}

/// Counts getFullState calls and never touches Firestore.
class CountingWird extends WirdService {
  CountingWird(DateTime Function() now) : super.forTesting(now: now);
  int fullStateCalls = 0;

  @override
  Future<WirdState> getFullState() {
    fullStateCalls++;
    return super.getFullState();
  }

  @override
  Future<void> syncFromFirestore(String userId) async {}
}

const _today = '2026-11-13';

late DateTime clock;
late FakeCloud cloud;
late CountingWird wird;
late WirdMarkerService marker;
String? uid;

WirdMarkerRecord _rec({
  int? markerPage = 31,
  int startPage = 31,
  int runningTotal = 0,
  int khatmaCount = 0,
  List<String> khatmaDates = const [],
  int cycle = 0,
  int version = 1,
  String? ownerId,
}) =>
    WirdMarkerRecord(
      markerPage: markerPage,
      startPage: startPage,
      runningTotal: runningTotal,
      khatmaCount: khatmaCount,
      khatmaDates: khatmaDates,
      cycle: cycle,
      version: version,
      ownerId: ownerId,
      color: markerPage == null ? null : 0xFF1E88E5,
    );

void _build({Map<String, Object> prefs = const {}}) {
  SharedPreferences.setMockInitialValues(prefs);
  clock = DateTime(2026, 11, 13, 10);
  cloud = FakeCloud();
  uid = null;
  wird = CountingWird(() => clock);
  marker = WirdMarkerService.forTesting(
      cloud: cloud, wird: wird, now: () => clock, uid: () => uid);
}

Future<void> _settle() => pumpEventQueue(times: 60);

Future<ProviderContainer> _container() async {
  final c = ProviderContainer(overrides: [
    wirdStateProvider.overrideWith(
        (ref) => WirdNotifier(wird: wird, marker: marker, uid: () => uid)),
  ]);
  addTearDown(c.dispose);
  c.listen(wirdStateProvider, (_, __) {});
  await _settle();
  return c;
}

WirdState _state(ProviderContainer c) => c.read(wirdStateProvider).requireValue;
WirdNotifier _notifier(ProviderContainer c) =>
    c.read(wirdStateProvider.notifier);

void main() {
  setUp(_build);

  test('initial state loads with no marker', () async {
    final c = await _container();
    final s = _state(c);
    expect(s.marker, isNull);
    expect(s.undo, isNull);
    expect(s.totalPagesRead, 0);
  });

  group('revision listener', () {
    test(
        'there is one listener: a revision bump reloads once, also after refresh()',
        () async {
      final c = await _container();
      await _notifier(c).refresh();
      await _settle();
      final before = wird.fullStateCalls;
      marker.revision.value++;
      await _settle();
      expect(wird.fullStateCalls, before + 1);
    });

    test('a bump reloads the state from the stored record', () async {
      final c = await _container();
      expect(_state(c).marker, isNull);
      await marker.save(_rec(ownerId: null, version: 2));
      await _settle();
      expect(_state(c).marker!.markerPage, 31);
    });

    test('a sync that applies the cloud record reloads the state', () async {
      uid = 'u1';
      cloud.stored =
          _rec(ownerId: 'u1', markerPage: 77, startPage: 70, version: 4);
      final c = await _container();
      await _settle();
      expect(_state(c).marker!.markerPage, 77);
    });

    test('the listener is removed on dispose (a later bump does not throw)',
        () async {
      final c = await _container();
      c.dispose();
      marker.revision.value++;
      await _settle();
    });
  });

  group('actions reload the state', () {
    test('placeMarker, moveMarker, undoMove', () async {
      final c = await _container();
      final n = _notifier(c);
      expect(await n.placeMarker(31, 0xFF1E88E5), isA<Placed>());
      expect(_state(c).marker!.markerPage, 31);

      expect(await n.moveMarker(36), isA<Moved>());
      var s = _state(c);
      expect(s.marker!.markerPage, 36);
      expect(s.todayProgress!.pagesRead, 5);
      expect(s.undo, isNotNull);
      expect(s.totalPagesRead, 5, reason: 'derived total: 36 - 31');

      expect(await n.undoMove(), isA<UndoDone>());
      s = _state(c);
      expect(s.marker!.markerPage, 31);
      expect(s.undo, isNull);
      expect(s.todayProgress!.pagesRead, 0);
      expect(s.totalPagesRead, 0);
    });

    test('completeKhatma updates the combined khatma values', () async {
      _build(prefs: {'wird_khatm_count': 2});
      await marker.save(_rec(markerPage: 600, startPage: 1, version: 1));
      final c = await _container();
      expect(_state(c).khatmCount, 2);
      final out = await _notifier(c).completeKhatma();
      expect(out, isA<Completed>());
      final s = _state(c);
      expect(s.juzKhatmCount, 2);
      expect(s.khatmCount, 3);
      expect(s.khatmDates, [_today]);
      expect(s.marker!.markerPage, 1);
      expect(s.totalPagesRead, 604, reason: 'runningTotal 604 + (1 - 1)');
    });

    test('restartWird clears the marker in the state', () async {
      final c = await _container();
      final n = _notifier(c);
      await n.placeMarker(31, 0xFF1E88E5);
      await n.restartWird();
      final s = _state(c);
      expect(s.marker!.markerPage, isNull);
      expect(s.marker!.cycle, 1);
      expect(s.undo, isNull);
    });

    test('markComplete and undoComplete reload the state', () async {
      final c = await _container();
      final n = _notifier(c);
      await n.markComplete();
      expect(_state(c).todayProgress!.manualCredit, isTrue);
      await n.undoComplete();
      expect(_state(c).todayProgress!.manualCredit, isFalse);
      expect(_state(c).todayProgress!.isCompleted, isFalse);
    });

    test('toggleJuzCompleted reloads the state', () async {
      final c = await _container();
      await _notifier(c).toggleJuzCompleted(3);
      expect(_state(c).allCompletedJuz, [3]);
    });
  });

  group('resetAllProgress', () {
    test('with no record leaves a tombstone record and clears history',
        () async {
      _build(prefs: {
        'wird_streak_count': 3,
        'wird_streak_date': _today,
        'wird_total_days_completed': 5,
        'wird_progress_history': jsonEncode([
          {'date': _today, 'pagesRead': 5, 'isCompleted': true}
        ]),
        'wird_completed_juz': jsonEncode([1, 2]),
        'wird_khatm_count': 1,
      });
      final c = await _container();
      expect(_state(c).marker, isNull);
      await _notifier(c).resetAllProgress();
      final s = _state(c);
      expect(s.marker, isNotNull);
      expect(s.marker!.cycle, 1);
      expect(s.marker!.markerPage, isNull);
      expect(s.streakCount, 0);
      expect(s.todayProgress, isNull);
      expect(s.allCompletedJuz, isEmpty);
      expect(s.khatmCount, 0);
      expect(s.totalDaysCompleted, 0);
    });
  });

  group('composeWirdState through the provider', () {
    test('drops an undo record from another day', () async {
      await marker.save(_rec(markerPage: 36, version: 2));
      await marker.saveUndo(const WirdUndoRecord(
          previousPage: 31,
          pagesAdded: 5,
          dateKey: '2026-11-12',
          grantedStreakCredit: false,
          cycle: 0,
          versionAfterMove: 2));
      final c = await _container();
      expect(_state(c).undo, isNull);
    });

    test('drops an undo record for another version of the record', () async {
      await marker.save(_rec(markerPage: 36, version: 3));
      await marker.saveUndo(const WirdUndoRecord(
          previousPage: 31,
          pagesAdded: 5,
          dateKey: _today,
          grantedStreakCredit: false,
          cycle: 0,
          versionAfterMove: 2));
      final c = await _container();
      expect(_state(c).undo, isNull);
    });

    test('keeps a valid undo record', () async {
      await marker.save(_rec(markerPage: 36, version: 2));
      await marker.saveUndo(const WirdUndoRecord(
          previousPage: 31,
          pagesAdded: 5,
          dateKey: _today,
          grantedStreakCredit: false,
          cycle: 0,
          versionAfterMove: 2));
      final c = await _container();
      expect(_state(c).undo, isNotNull);
    });

    test('totalPagesRead is the derived total, not wird_total_pages_read',
        () async {
      _build(prefs: {'wird_total_pages_read': 999});
      await marker.save(
          _rec(markerPage: 40, startPage: 31, runningTotal: 574, version: 2));
      final c = await _container();
      expect(_state(c).totalPagesRead, 583);
    });

    test('switching to juz mode keeps the marker in the state', () async {
      await marker.save(_rec(version: 2));
      final c = await _container();
      await _notifier(c).setWirdUnit(WirdUnit.juz);
      expect(_state(c).marker, isNotNull);
      expect(_state(c).settings.wirdUnit, WirdUnit.juz);
      await _notifier(c).setWirdUnit(WirdUnit.page);
      expect(_state(c).marker!.markerPage, 31);
    });
  });

  test('wirdServiceProvider returns the production singleton by default', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(wirdServiceProvider), same(WirdService.instance));
  });

  test('wirdServiceProvider can be overridden', () {
    final c = ProviderContainer(
        overrides: [wirdServiceProvider.overrideWithValue(wird)]);
    addTearDown(c.dispose);
    expect(c.read(wirdServiceProvider), same(wird));
  });

  group('first placement through the provider (P4a-2)', () {
    test('placeMarker shows the marker in the state and N follows it', () async {
      final c = await _container();
      final n = c.read(wirdStateProvider.notifier);
      expect(startSheetPage(c.read(wirdStateProvider).value!, null), 1);
      expect(await n.placeMarker(12, 0xFF00838F), isA<Placed>());
      final state = c.read(wirdStateProvider).value!;
      expect(state.marker!.markerPage, 12);
      // After "Start here" the reader opens on the marker page.
      expect(startSheetPage(state, null), 12);
    });
  });
}
