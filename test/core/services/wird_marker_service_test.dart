// Spec: docs/designs/wird-marker.md item 16. The numbered comments match the
// numbered cases there (1-32). Extra flow cases follow at the end.
import 'dart:convert';

import 'package:aura_app/core/models/wird_marker.dart';
import 'package:aura_app/core/services/wird_marker_service.dart';
import 'package:aura_app/core/services/wird_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _today = '2026-11-13';

/// Fake cloud: holds one record. Returns what it holds without validating it,
/// so tests can store invalid records and prove the service rejects them.
class FakeCloud implements WirdMarkerCloud {
  WirdMarkerRecord? stored;
  bool failRead = false;
  bool failWrite = false;
  bool throwOnRead = false;
  bool throwOnWrite = false;
  Future<void> Function()? onRead;
  int reads = 0;
  int writes = 0;

  @override
  Future<CloudRead> readServer(String uid) async {
    reads++;
    if (throwOnRead) throw StateError('read boom');
    if (onRead != null) await onRead!();
    if (failRead) return const CloudReadFailed();
    final s = stored;
    return s == null ? const CloudReadAbsent() : CloudReadPresent(s);
  }

  @override
  Future<MarkerPushResult> write(String uid, WirdMarkerRecord record) async {
    if (throwOnWrite) throw StateError('write boom');
    if (failWrite) return const MarkerPushFailed();
    writes++;
    stored = record;
    return const MarkerPushed();
  }
}

WirdMarkerRecord _rec({
  int? markerPage = 31,
  int startPage = 31,
  int runningTotal = 0,
  int khatmaCount = 0,
  List<String> khatmaDates = const [],
  int cycle = 0,
  int version = 1,
  String? ownerId = 'u1',
  int? color = 0xFF1E88E5,
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
      color: color,
    );

late FakeCloud cloud;
late DateTime clock;
String? uid;
late WirdService wird;
late WirdMarkerService svc;

Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

void _build({Map<String, Object> prefs = const {}}) {
  SharedPreferences.setMockInitialValues(prefs);
  cloud = FakeCloud();
  clock = DateTime(2026, 11, 13, 10);
  uid = null;
  wird = WirdService.forTesting(now: () => clock);
  svc = WirdMarkerService.forTesting(
    cloud: cloud,
    wird: wird,
    now: () => clock,
    uid: () => uid,
  );
}

void main() {
  setUp(() => _build());

  group('sync: read, push, retry', () {
    test('1. read failure: SKIP_READ_FAILED and the local record is unchanged',
        () async {
      uid = 'u1';
      final local = _rec(version: 2);
      await svc.save(local);
      cloud.failRead = true;
      final r = await svc.syncMarker();
      expect(r.decision, MarkerSyncDecision.skipReadFailed);
      expect(await svc.load(), local);
      expect(cloud.writes, 0);
    });

    test(
        '2. retry: after a read failure a later sync with a working cloud writes the local record',
        () async {
      uid = 'u1';
      final local = _rec(version: 2);
      await svc.save(local);
      cloud.failRead = true;
      await svc.syncMarker();
      cloud.failRead = false;
      final r = await svc.syncMarker();
      expect(r.decision, MarkerSyncDecision.push);
      expect(cloud.stored, local);
    });

    test('3. failed write: local unchanged, the next sync writes it', () async {
      uid = 'u1';
      final local = _rec(version: 2);
      await svc.save(local);
      cloud.failWrite = true;
      final r = await svc.syncMarker();
      expect(r.decision, MarkerSyncDecision.push);
      expect(r.push, isA<MarkerPushFailed>());
      expect(await svc.load(), local);
      expect(cloud.stored, isNull);
      cloud.failWrite = false;
      await svc.syncMarker();
      expect(cloud.stored, local);
    });
  });

  group('pushIfNewer', () {
    test(
        '4. an equal or newer cloud record returns notNewer(cloud) and writes nothing',
        () async {
      cloud.stored = _rec(cycle: 1, version: 5);
      final equal = await svc.pushIfNewer('u1', _rec(cycle: 1, version: 5));
      expect(equal, isA<MarkerNotNewer>());
      expect((equal as MarkerNotNewer).cloudRecord, cloud.stored);
      final newer = await svc.pushIfNewer('u1', _rec(cycle: 0, version: 99));
      expect(newer, isA<MarkerNotNewer>());
      expect(cloud.writes, 0);
    });

    test('4b. an older cloud record is replaced', () async {
      cloud.stored = _rec(version: 1);
      final mine = _rec(version: 2, markerPage: 40);
      final r = await svc.pushIfNewer('u1', mine);
      expect(r, isA<MarkerPushed>());
      expect(cloud.stored, mine);
    });

    test('4c. an absent cloud record is written', () async {
      final r = await svc.pushIfNewer('u1', _rec());
      expect(r, isA<MarkerPushed>());
      expect(cloud.writes, 1);
    });

    test(
        '5. a failed read, or an invalid cloud record, returns failed and writes nothing',
        () async {
      cloud.failRead = true;
      expect(await svc.pushIfNewer('u1', _rec(version: 9)),
          isA<MarkerPushFailed>());
      cloud.failRead = false;
      cloud.stored = _rec(markerPage: 700, startPage: 1);
      expect(await svc.pushIfNewer('u1', _rec(version: 9)),
          isA<MarkerPushFailed>());
      expect(cloud.writes, 0);
    });

    test('5b. a failed write returns failed', () async {
      cloud.failWrite = true;
      expect(await svc.pushIfNewer('u1', _rec()), isA<MarkerPushFailed>());
    });

    test(
        '5c. a record owned by another uid is refused and nothing is read or written',
        () async {
      expect(await svc.pushIfNewer('u1', _rec(ownerId: 'other')),
          isA<MarkerPushFailed>());
      expect(await svc.pushIfNewer('u1', _rec(ownerId: null)),
          isA<MarkerPushFailed>());
      expect(cloud.writes, 0);
    });
  });

  group('sync: several devices', () {
    test(
        '6. undo path: a notNewer result saves the cloud record, clears the undo and returns CloudNewer',
        () async {
      uid = 'u1';
      final live = _rec(markerPage: 36, version: 2);
      await svc.save(live);
      await svc.saveUndo(const WirdUndoRecord(
          previousPage: 31,
          pagesAdded: 5,
          dateKey: _today,
          grantedStreakCredit: false,
          cycle: 0,
          versionAfterMove: 2));
      cloud.stored = _rec(
          markerPage: 36,
          version: 3); // equal to the undone record (version 3): not newer
      final out = await svc.undoMove();
      expect(out, isA<UndoCloudNewer>());
      expect(await svc.load(), cloud.stored);
      expect(await svc.loadUndo(), isNull);
    });

    test(
        '7. equal pair: both devices end with the cloud record, one move is dropped',
        () async {
      uid = 'u1';
      // Device A moved to 36 (version 2) and syncs first.
      await svc.save(_rec(markerPage: 36, version: 2));
      await svc.syncMarker();
      expect(cloud.stored!.markerPage, 36);
      // Device B moved to 40 (also version 2) while offline, then syncs.
      await svc.save(_rec(markerPage: 40, version: 2));
      await svc.syncMarker();
      expect((await svc.load())!.markerPage, 36,
          reason: 'cloud wins on an equal pair');
      expect(cloud.stored!.markerPage, 36);
    });

    test(
        '8. stale device: an older cycle with many moves pulls the newer cycle and keeps none of its moves',
        () async {
      uid = 'u1';
      await svc.save(_rec(cycle: 0, version: 10, markerPage: 300));
      cloud.stored = _rec(cycle: 1, version: 1, markerPage: null, color: null);
      final r = await svc.syncMarker();
      expect(r.decision, MarkerSyncDecision.applyCloud);
      expect(await svc.load(), cloud.stored);
    });

    test('9. restart on A, then a move on B: the higher cycle wins on both',
        () async {
      uid = 'u1';
      // Device A restarts: cycle 1.
      await svc.save(_rec(cycle: 1, version: 2, markerPage: null, color: null));
      await svc.syncMarker();
      // Device B (still cycle 0) made a move: version 3.
      await svc.save(_rec(cycle: 0, version: 3, markerPage: 50));
      await svc.syncMarker();
      final b = await svc.load();
      expect(b!.cycle, 1);
      expect(b.markerPage, isNull);
      expect(cloud.stored!.cycle, 1);
    });
  });

  group('sync: owner and guest', () {
    test(
        '10. guest claim with an empty cloud: saved with ownerId = uid, then written',
        () async {
      uid = 'u1';
      await svc.save(_rec(ownerId: null, version: 3));
      final r = await svc.syncMarker();
      expect(r.decision, MarkerSyncDecision.claimAndPush);
      final local = await svc.load();
      expect(local!.ownerId, 'u1');
      expect(cloud.stored, local);
    });

    test('11. guest marker with a cloud record: the cloud record replaces it',
        () async {
      uid = 'u1';
      await svc.save(_rec(ownerId: null, version: 50, markerPage: 500));
      cloud.stored = _rec(version: 1, markerPage: 10, startPage: 10);
      final r = await svc.syncMarker();
      expect(r.decision, MarkerSyncDecision.applyCloud);
      expect(await svc.load(), cloud.stored);
      expect(cloud.writes, 0);
    });

    test(
        '12. owner change: a local record of another owner is discarded, the cloud record applies',
        () async {
      uid = 'u1';
      await svc.save(_rec(ownerId: 'other', version: 50));
      cloud.stored = _rec(version: 1);
      expect((await svc.syncMarker()).decision, MarkerSyncDecision.applyCloud);
      expect(await svc.load(), cloud.stored);
    });

    test('12b. owner change with an empty cloud: the local record is discarded',
        () async {
      uid = 'u1';
      await svc.save(_rec(ownerId: 'other'));
      expect(
          (await svc.syncMarker()).decision, MarkerSyncDecision.discardLocal);
      expect(await svc.load(), isNull);
      expect(cloud.writes, 0);
    });

    test(
        '13. CLAIM_AND_PUSH then a failed write keeps ownerId = uid, so the next sync uses PUSH',
        () async {
      uid = 'u1';
      await svc.save(_rec(ownerId: null, version: 3));
      cloud.failWrite = true;
      expect(
          (await svc.syncMarker()).decision, MarkerSyncDecision.claimAndPush);
      expect((await svc.load())!.ownerId, 'u1');
      cloud.failWrite = false;
      final r = await svc.syncMarker();
      expect(r.decision, MarkerSyncDecision.push);
      expect(cloud.stored!.ownerId, 'u1');
    });
  });

  group('validation', () {
    test(
        '14. invalid cloud record: SKIP_INVALID_CLOUD, local kept, cloud not overwritten',
        () async {
      uid = 'u1';
      final local = _rec(version: 9);
      final bad = <WirdMarkerRecord>[
        _rec(markerPage: 700, startPage: 1),
        _rec(khatmaDates: ['13/11/2026']),
        _rec(khatmaCount: -1),
      ];
      for (final b in bad) {
        await svc.save(local);
        cloud.stored = b;
        final r = await svc.syncMarker();
        expect(r.decision, MarkerSyncDecision.skipInvalidCloud, reason: '$b');
        expect(await svc.load(), local);
        expect(cloud.stored, b, reason: 'never overwritten');
      }
      expect(cloud.writes, 0);
    });

    test('15. a cloud record with another ownerId is invalid', () async {
      uid = 'u1';
      await svc.save(_rec(version: 9));
      cloud.stored = _rec(ownerId: 'other');
      expect((await svc.syncMarker()).decision,
          MarkerSyncDecision.skipInvalidCloud);
      expect(cloud.writes, 0);
    });

    test('16. an invalid local string loads as no record', () async {
      _build(prefs: {'wird_marker': 'not json at all'});
      expect(await svc.load(), isNull);
      _build(prefs: {
        'wird_marker': jsonEncode({'markerPage': 900, 'startPage': 1})
      });
      expect(await svc.load(), isNull, reason: 'out of range');
      _build(prefs: {
        'wird_marker': jsonEncode([1, 2])
      });
      expect(await svc.load(), isNull, reason: 'not a map');
    });

    test('16b. with an invalid local string, a valid cloud record is applied',
        () async {
      _build(prefs: {'wird_marker': 'garbage'});
      uid = 'u1';
      cloud.stored = _rec(version: 4);
      expect((await svc.syncMarker()).decision, MarkerSyncDecision.applyCloud);
      expect(await svc.load(), cloud.stored);
    });
  });

  group('sync: ordering and safety', () {
    test(
        '17. the local record is loaded after the cloud read, so a move saved during the read is seen',
        () async {
      uid = 'u1';
      await svc.save(_rec(version: 1));
      cloud.stored = _rec(version: 1);
      cloud.onRead = () async => svc.save(_rec(version: 2, markerPage: 40));
      final r = await svc.syncMarker();
      expect(r.decision, MarkerSyncDecision.push);
      expect(cloud.stored!.version, 2);
      expect((await svc.load())!.markerPage, 40);
    });

    test('18. syncMarker never throws when the cloud throws', () async {
      uid = 'u1';
      await svc.save(_rec());
      cloud.throwOnRead = true;
      final a = await svc.syncMarker();
      expect(a.decision, MarkerSyncDecision.skipReadFailed);
      cloud.throwOnRead = false;
      cloud.throwOnWrite = true;
      await svc.syncMarker();
      expect(await svc.load(), isNotNull);
    });

    test('18b. with no uid, syncMarker is local only and calls nothing',
        () async {
      await svc.save(_rec());
      final r = await svc.syncMarker();
      expect(r.localOnly, isTrue);
      expect(cloud.reads, 0);
      expect(cloud.writes, 0);
    });
  });

  group('undo', () {
    Future<void> placeAndMove() async {
      expect(await svc.placeMarker(31, 0xFF1E88E5), isA<Placed>());
      await pumpEventQueue();
      expect(await svc.moveMarker(36), isA<Moved>());
      await pumpEventQueue();
    }

    test('19. signed-in undo offline: NeedsConnection and nothing changes',
        () async {
      uid = 'u1';
      await placeAndMove();
      final before = await svc.load();
      cloud.failRead = true;
      expect(await svc.undoMove(), isA<UndoNeedsConnection>());
      expect(await svc.load(), before);
      expect(await svc.loadUndo(), isNotNull);
      expect((await wird.getTodayProgress())!.pagesRead, 5);
    });

    test(
        '20. signed-in undo with the cloud ahead: CloudNewer and the cloud record is applied',
        () async {
      uid = 'u1';
      await placeAndMove();
      cloud.stored = _rec(markerPage: 200, startPage: 31, version: 50);
      expect(await svc.undoMove(), isA<UndoCloudNewer>());
      expect(await svc.load(), cloud.stored);
      expect(await svc.loadUndo(), isNull);
    });

    test(
        '20b. signed-in undo online: pushes the undone record, then applies it locally',
        () async {
      uid = 'u1';
      await placeAndMove();
      final out = await svc.undoMove();
      expect(out, isA<UndoDone>());
      expect((await svc.load())!.markerPage, 31);
      expect(cloud.stored!.markerPage, 31);
      expect(await svc.loadUndo(), isNull);
    });

    test('21. guest undo works with no cloud call', () async {
      await placeAndMove();
      expect(await svc.undoMove(), isA<UndoDone>());
      expect((await svc.load())!.markerPage, 31);
      expect(cloud.reads, 0);
      expect(cloud.writes, 0);
    });

    test('22. undo of another account\'s marker fails STALE_RECORD', () async {
      uid = 'u1';
      await svc.save(_rec(ownerId: 'other', markerPage: 36, version: 2));
      await svc.saveUndo(const WirdUndoRecord(
          previousPage: 31,
          pagesAdded: 5,
          dateKey: _today,
          grantedStreakCredit: false,
          cycle: 0,
          versionAfterMove: 2));
      final out = await svc.undoMove();
      expect(out, isA<UndoFailed>());
      expect((out as UndoFailed).failure, MarkerFailure.staleRecord);
      expect((await svc.load())!.markerPage, 36);
    });

    test('23. midnight: an undo record from another day fails STALE_DAY',
        () async {
      await placeAndMove();
      clock = DateTime(2026, 11, 14, 0, 10);
      final out = await svc.undoMove();
      expect(out, isA<UndoFailed>());
      expect((out as UndoFailed).failure, MarkerFailure.staleDay);
    });

    test('23b. undo with no undo record fails NO_UNDO', () async {
      await svc.placeMarker(31, 0xFF1E88E5);
      final out = await svc.undoMove();
      expect((out as UndoFailed).failure, MarkerFailure.noUndo);
    });

    test('undo removes the move\'s pages and the streak credit it granted',
        () async {
      await placeAndMove(); // 5 pages = the daily goal
      final p = await _prefs();
      expect(p.getInt('wird_streak_count'), 1);
      await svc.undoMove();
      final today = await wird.getTodayProgress();
      expect(today!.pagesRead, 0);
      expect(today.isCompleted, isFalse);
      expect(today.currentPage, 31);
      expect(p.getInt('wird_streak_count'), 0);
      expect(p.getInt('wird_total_days_completed'), 0);
    });

    test('undo keeps the streak when the credit came from an earlier move',
        () async {
      await svc.placeMarker(1, 0xFF1E88E5);
      await svc.moveMarker(6); // 5 pages: credit granted here
      await svc.moveMarker(8); // 2 more pages: no credit
      await svc.undoMove();
      final p = await _prefs();
      expect(p.getInt('wird_streak_count'), 1);
      expect((await wird.getTodayProgress())!.pagesRead, 5);
    });
  });

  group('khatma, reset and restart', () {
    test('24. a khatma writes no undo record and clears an existing one',
        () async {
      await svc.placeMarker(600, 0xFF1E88E5);
      await svc.moveMarker(604);
      expect(await svc.loadUndo(), isNotNull);
      expect(await svc.completeKhatma(), isA<Completed>());
      expect(await svc.loadUndo(), isNull);
    });

    test(
        '25. completeKhatma returns the combined count (legacy juz count + record count)',
        () async {
      _build(prefs: {'wird_khatm_count': 2});
      await svc.save(
          _rec(markerPage: 590, startPage: 1, khatmaCount: 1, ownerId: null));
      final out = await svc.completeKhatma();
      expect(out, isA<Completed>());
      final c = out as Completed;
      expect(c.khatmCount, 4);
      expect(c.pagesAdded, 15);
      final r = (await svc.load())!;
      expect(r.markerPage, 1);
      expect(r.khatmaCount, 2);
      expect(r.cycle, 1);
      expect((await wird.getTodayProgress())!.pagesRead, 15);
    });

    test(
        '25b. completeKhatma without a marker fails NO_MARKER and credits nothing',
        () async {
      final out = await svc.completeKhatma();
      expect((out as KhatmaFailed).failure, MarkerFailure.noMarker);
      expect(await wird.getTodayProgress(), isNull);
    });

    test(
        '26. Reset All with no record wipes everything and saves a tombstone at cycle 1',
        () async {
      _build(prefs: {
        'wird_streak_count': 4,
        'wird_streak_date': _today,
        'wird_total_pages_read': 100,
        'wird_total_days_completed': 9,
        'wird_progress_history': jsonEncode([
          {'date': _today, 'pagesRead': 5, 'isCompleted': true}
        ]),
        'wird_completed_juz': jsonEncode([1, 2, 3]),
        'wird_khatm_count': 2,
        'wird_khatm_dates': jsonEncode(['2026-01-01', '2026-02-02']),
      });
      expect(await svc.load(), isNull);
      await svc.resetAll();
      final p = await _prefs();
      expect(p.getInt('wird_streak_count'), 0);
      expect(p.containsKey('wird_streak_date'), isFalse);
      expect(p.getInt('wird_total_pages_read'), 0);
      expect(p.getInt('wird_total_days_completed'), 0);
      expect(jsonDecode(p.getString('wird_progress_history')!), isEmpty);
      expect(jsonDecode(p.getString('wird_completed_juz')!), isEmpty);
      expect(p.getInt('wird_khatm_count'), 0);
      final r = (await svc.load())!;
      expect(r.cycle, 1);
      expect(r.markerPage, isNull);
    });

    test(
        '27. Reset All and Restart both raise the cycle, on a full and on an empty record',
        () async {
      await svc.save(_rec(cycle: 2, version: 7, markerPage: 100));
      await svc.restartWird();
      expect((await svc.load())!.cycle, 3);
      await svc.restartWird(); // already empty: still bumps
      expect((await svc.load())!.cycle, 4);
      await svc.save(_rec(cycle: 5, version: 1));
      await svc.resetAll();
      expect((await svc.load())!.cycle, 6);
      await svc.resetAll();
      expect((await svc.load())!.cycle, 7);
    });

    test('27b. Restart clears the undo record', () async {
      await svc.placeMarker(1, 0xFF1E88E5);
      await svc.moveMarker(6);
      await svc.restartWird();
      expect(await svc.loadUndo(), isNull);
    });

    test(
        '28. ownerId per flow: setup sets it, move, khatma, restart and reset keep it',
        () async {
      uid = 'u1';
      await svc.placeMarker(600, 0xFF1E88E5);
      expect((await svc.load())!.ownerId, 'u1');
      await pumpEventQueue();
      await svc.moveMarker(604);
      expect((await svc.load())!.ownerId, 'u1');
      await pumpEventQueue();
      await svc.completeKhatma();
      expect((await svc.load())!.ownerId, 'u1');
      await pumpEventQueue();
      await svc.restartWird();
      expect((await svc.load())!.ownerId, 'u1');
      await pumpEventQueue();
      await svc.resetAll();
      expect((await svc.load())!.ownerId, 'u1');
      await pumpEventQueue();
    });

    test('28b. a guest marker has a null owner in every flow', () async {
      await svc.placeMarker(600, 0xFF1E88E5);
      expect((await svc.load())!.ownerId, isNull);
      await svc.moveMarker(604);
      await svc.completeKhatma();
      await svc.restartWird();
      await svc.resetAll();
      expect((await svc.load())!.ownerId, isNull);
    });

    test('28c. Reset All with no record gives the tombstone the current uid',
        () async {
      uid = 'u1';
      await svc.resetAll();
      expect((await svc.load())!.ownerId, 'u1');
      await pumpEventQueue();
    });
  });

  group('revision and storage', () {
    test(
        '29. revision fires when a sync applies or discards a record, and not for an unchanged save',
        () async {
      uid = 'u1';
      var n = 0;
      svc.revision.addListener(() => n++);
      await svc.save(_rec(ownerId: 'u1', version: 1));
      final afterSave = n;
      expect(afterSave, greaterThan(0));
      await svc.save(_rec(ownerId: 'u1', version: 1)); // same value
      expect(n, afterSave, reason: 'unchanged save does not bump');
      cloud.stored = _rec(version: 5);
      await svc.syncMarker(); // applyCloud
      expect(n, greaterThan(afterSave));
      final afterApply = n;
      cloud.stored = null;
      await svc.save(_rec(ownerId: 'other', version: 9));
      final beforeDiscard = n;
      expect(beforeDiscard, greaterThan(afterApply));
      await svc.syncMarker(); // discardLocal
      expect(n, greaterThan(beforeDiscard));
    });

    test('29b. clearUndo bumps only when an undo record existed', () async {
      var n = 0;
      svc.revision.addListener(() => n++);
      await svc.clearUndo();
      expect(n, 0);
      await svc.saveUndo(const WirdUndoRecord(
          previousPage: 1,
          pagesAdded: 1,
          dateKey: _today,
          grantedStreakCredit: false,
          cycle: 0,
          versionAfterMove: 1));
      final after = n;
      expect(after, 1);
      await svc.clearUndo();
      expect(n, after + 1);
    });

    test(
        '30. the local map round trip keeps every field, and a missing key takes its default',
        () async {
      final full = _rec(
        markerPage: 120,
        startPage: 31,
        runningTotal: 574,
        khatmaCount: 2,
        khatmaDates: ['2026-02-01', '2026-06-01'],
        cycle: 3,
        version: 11,
        color: 0xFF964EDE,
      );
      await svc.save(full);
      expect(await svc.load(), full);
      _build(prefs: {
        'wird_marker':
            jsonEncode({'markerPage': 5, 'startPage': 5, 'version': 1}),
      });
      final r = (await svc.load())!;
      expect(r.markerPage, 5);
      expect(r.runningTotal, 0);
      expect(r.khatmaCount, 0);
      expect(r.khatmaDates, isEmpty);
      expect(r.cycle, 0);
      expect(r.ownerId, isNull);
      expect(r.color, isNull);
    });

    test(
        '31. khatmaCountLocal returns 0 with no record and the record\'s count otherwise',
        () async {
      expect(await svc.khatmaCountLocal(), 0);
      await svc.save(_rec(khatmaCount: 3));
      expect(await svc.khatmaCountLocal(), 3);
      expect(cloud.reads, 0, reason: 'local only');
    });

    test(
        '32. progressTotalLocal: 0, runningTotal, or runningTotal + (markerPage - startPage)',
        () async {
      expect(await svc.progressTotalLocal(), 0);
      await svc.save(_rec(markerPage: null, runningTotal: 574, startPage: 1));
      expect(await svc.progressTotalLocal(), 574);
      await svc.save(
          _rec(markerPage: 40, startPage: 31, runningTotal: 574, version: 2));
      expect(await svc.progressTotalLocal(), 583);
      expect(cloud.reads, 0);
    });
  });

  group('moveMarker and placeMarker', () {
    test('a move credits the pages, saves the undo record and returns Moved',
        () async {
      await svc.placeMarker(31, 0xFF1E88E5);
      final out = await svc.moveMarker(34);
      expect(out, isA<Moved>());
      final m = out as Moved;
      expect(m.pagesAdded, 3);
      expect(m.markerPage, 34);
      expect(m.grantedStreakCredit, isFalse);
      final today = await wird.getTodayProgress();
      expect(today!.pagesRead, 3);
      expect(today.startPage, 31);
      expect(today.currentPage, 34);
      final undo = (await svc.loadUndo())!;
      expect(undo.previousPage, 31);
      expect(undo.pagesAdded, 3);
      expect(undo.dateKey, _today);
      final live = (await svc.load())!;
      expect(undo.cycle, live.cycle);
      expect(undo.versionAfterMove, live.version);
    });

    test('a move that reaches the goal reports the streak credit', () async {
      await svc.placeMarker(1, 0xFF1E88E5);
      final m = await svc.moveMarker(6) as Moved;
      expect(m.grantedStreakCredit, isTrue);
      expect((await svc.loadUndo())!.grantedStreakCredit, isTrue);
    });

    test('a failed move credits nothing and writes no undo', () async {
      expect((await svc.moveMarker(10) as MoveFailed).failure,
          MarkerFailure.noMarker);
      await svc.placeMarker(31, 0xFF1E88E5);
      expect((await svc.moveMarker(31) as MoveFailed).failure,
          MarkerFailure.notForward);
      expect((await svc.moveMarker(605) as MoveFailed).failure,
          MarkerFailure.outOfRange);
      expect(await wird.getTodayProgress(), isNull);
      expect(await svc.loadUndo(), isNull);
    });

    test('placeMarker at page 604 works (604 is a legal marker page)',
        () async {
      expect(await svc.placeMarker(604, 0xFF1E88E5), isA<Placed>());
      final r = (await svc.load())!;
      expect(r.markerPage, 604);
      expect(r.startPage, 604);
      expect(await svc.progressTotalLocal(), 0);
      // From 604 there is no forward move; the khatma counts exactly one page.
      expect((await svc.moveMarker(604) as MoveFailed).failure,
          MarkerFailure.notForward);
      final k = await svc.completeKhatma() as Completed;
      expect(k.pagesAdded, 1);
    });

    test('placeMarker at page 1 works', () async {
      expect(await svc.placeMarker(1, 0xFF1E88E5), isA<Placed>());
      expect((await svc.load())!.markerPage, 1);
    });

    test('a move then undo after a manual completion keeps the credit',
        () async {
      await svc.placeMarker(31, 0xFF1E88E5);
      await wird.markDayComplete();
      await svc.moveMarker(33); // 2 pages: below the goal, no new credit
      expect((await svc.loadUndo())!.grantedStreakCredit, isFalse);
      await svc.undoMove();
      final today = (await wird.getTodayProgress())!;
      expect(today.isCompleted, isTrue);
      expect(today.manualCredit, isTrue);
      expect(today.pagesRead, 0);
      final p = await _prefs();
      expect(p.getInt('wird_streak_count'), 1);
      expect(p.getInt('wird_total_days_completed'), 1);
    });

    test('placeMarker fails MARKER_EXISTS when a marker exists', () async {
      await svc.placeMarker(31, 0xFF1E88E5);
      final out = await svc.placeMarker(50, 0xFF00838F);
      expect((out as PlaceFailed).failure, MarkerFailure.markerExists);
      expect((await svc.load())!.markerPage, 31);
    });

    test('placeMarker refuses a page outside 1..604 (it would not load back)',
        () async {
      expect((await svc.placeMarker(0, 0xFF1E88E5) as PlaceFailed).failure,
          MarkerFailure.outOfRange);
      expect((await svc.placeMarker(605, 0xFF1E88E5) as PlaceFailed).failure,
          MarkerFailure.outOfRange);
      expect(await svc.load(), isNull);
    });

    test('placeMarker works after Restart and clears the undo record',
        () async {
      await svc.placeMarker(31, 0xFF1E88E5);
      await svc.moveMarker(36);
      await svc.restartWird();
      expect(await svc.placeMarker(100, 0xFF00838F), isA<Placed>());
      expect((await svc.load())!.markerPage, 100);
      expect(await svc.loadUndo(), isNull);
    });

    test('a signed-in move starts a sync that writes the record', () async {
      uid = 'u1';
      await svc.placeMarker(31, 0xFF1E88E5);
      await pumpEventQueue();
      expect(cloud.stored!.markerPage, 31);
      await svc.moveMarker(36);
      await pumpEventQueue();
      expect(cloud.stored!.markerPage, 36);
    });

    test('a move still succeeds when the sync fails or throws', () async {
      uid = 'u1';
      cloud.throwOnRead = true;
      await svc.placeMarker(31, 0xFF1E88E5);
      expect(await svc.moveMarker(36), isA<Moved>());
      await pumpEventQueue();
    });
  });

  group('first placement from the start entry points (P4a-2)', () {
    test('placeMarker works on a fresh install: no pages counted', () async {
      expect(await svc.placeMarker(12, 0xFF00838F), isA<Placed>());
      final r = (await svc.load())!;
      expect(r.markerPage, 12);
      expect(r.startPage, 12);
      expect(r.color, 0xFF00838F);
      expect(r.cycle, 0);
      expect(r.version, 1);
      expect(await svc.progressTotalLocal(), 0);
      expect(await wird.getTodayProgress(), isNull);
    });

    test('placeMarker works after Restart: cycle kept, version raised',
        () async {
      await svc.placeMarker(31, 0xFF1E88E5);
      await svc.restartWird();
      final afterRestart = (await svc.load())!;
      expect(afterRestart.markerPage, isNull);
      final out = await svc.placeMarker(12, 0xFF00838F);
      expect(out, isA<Placed>());
      final r = (await svc.load())!;
      expect(r.markerPage, 12);
      expect(r.startPage, 12);
      expect(r.cycle, afterRestart.cycle);
      expect(r.version, afterRestart.version + 1);
      expect(r.runningTotal, 0);
    });

    test('placeMarker fails with MARKER_EXISTS when a marker exists and changes nothing',
        () async {
      await svc.placeMarker(31, 0xFF1E88E5);
      final before = await svc.load();
      final out = await svc.placeMarker(40, 0xFF00838F);
      expect((out as PlaceFailed).failure, MarkerFailure.markerExists);
      expect(await svc.load(), before);
    });

    test('placeMarker clears a stale undo record', () async {
      await svc.saveUndo(const WirdUndoRecord(
        previousPage: 5,
        pagesAdded: 2,
        dateKey: _today,
        grantedStreakCredit: false,
        cycle: 0,
        versionAfterMove: 1,
      ));
      expect(await svc.loadUndo(), isNotNull);
      await svc.placeMarker(12, 0xFF00838F);
      expect(await svc.loadUndo(), isNull);
    });

    test('a guest placement has no owner and starts no cloud write', () async {
      uid = null;
      await svc.placeMarker(12, 0xFF00838F);
      await pumpEventQueue();
      expect((await svc.load())!.ownerId, isNull);
      expect(cloud.writes, 0);
    });

    test('a signed-in placement carries the uid and starts one background push',
        () async {
      uid = 'u1';
      await svc.placeMarker(12, 0xFF00838F);
      await pumpEventQueue();
      expect((await svc.load())!.ownerId, 'u1');
      expect(cloud.writes, 1);
      expect(cloud.stored!.markerPage, 12);
    });
  });
}
