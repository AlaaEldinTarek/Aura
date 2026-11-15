import 'package:aura_app/core/models/wird.dart';
import 'package:aura_app/core/models/wird_marker.dart';
import 'package:aura_app/core/services/wird_marker_logic.dart';
import 'package:flutter_test/flutter_test.dart';

const _today = '2026-11-13';

WirdMarkerRecord _rec({
  int? markerPage = 31,
  int startPage = 31,
  int runningTotal = 0,
  int khatmaCount = 0,
  List<String> khatmaDates = const [],
  int cycle = 0,
  int version = 1,
  String? ownerId,
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

/// A record with no marker (the state after Restart).
WirdMarkerRecord _noMarker({
  int runningTotal = 0,
  int khatmaCount = 0,
  List<String> khatmaDates = const [],
  int cycle = 1,
  int version = 1,
  String? ownerId,
}) =>
    WirdMarkerRecord(
      markerPage: null,
      startPage: 1,
      runningTotal: runningTotal,
      khatmaCount: khatmaCount,
      khatmaDates: khatmaDates,
      cycle: cycle,
      version: version,
      ownerId: ownerId,
      color: null,
    );

T _ok<T>(MarkerResult<T> r) {
  expect(r, isA<Ok<T>>(), reason: 'expected Ok, got $r');
  return (r as Ok<T>).value;
}

void _err<T>(MarkerResult<T> r, MarkerFailure f) {
  expect(r, isA<Err<T>>(), reason: 'expected Err($f), got $r');
  expect((r as Err<T>).failure, f);
}

WirdUndoRecord _undo({
  int previousPage = 31,
  int pagesAdded = 5,
  String dateKey = _today,
  bool granted = false,
  int cycle = 0,
  int versionAfterMove = 2,
}) =>
    WirdUndoRecord(
      previousPage: previousPage,
      pagesAdded: pagesAdded,
      dateKey: dateKey,
      grantedStreakCredit: granted,
      cycle: cycle,
      versionAfterMove: versionAfterMove,
    );

void main() {
  test('kLastQuranPage is 604', () {
    expect(kLastQuranPage, 604);
  });

  group('empty()', () {
    test('is all zero with no marker and no owner', () {
      final e = empty();
      expect(e.markerPage, isNull);
      expect(e.startPage, 1);
      expect(e.runningTotal, 0);
      expect(e.khatmaCount, 0);
      expect(e.khatmaDates, isEmpty);
      expect(e.cycle, 0);
      expect(e.version, 0);
      expect(e.ownerId, isNull);
      expect(e.color, isNull);
    });
  });

  group('compare', () {
    test('cycle is compared before version', () {
      final a = _rec(cycle: 2, version: 1);
      final b = _rec(cycle: 1, version: 99);
      expect(compare(a, b), 1);
      expect(compare(b, a), -1);
    });
    test('same cycle compares version', () {
      expect(compare(_rec(version: 3), _rec(version: 2)), 1);
      expect(compare(_rec(version: 2), _rec(version: 3)), -1);
    });
    test('equal pair is 0', () {
      expect(
          compare(_rec(cycle: 1, version: 4), _rec(cycle: 1, version: 4)), 0);
    });
    test('null is lowest; two nulls are equal', () {
      expect(compare(null, _rec(cycle: 0, version: 0)), -1);
      expect(compare(_rec(cycle: 0, version: 0), null), 1);
      expect(compare(null, null), 0);
    });
  });

  group('progressTotal', () {
    test('no record is 0', () {
      expect(progressTotal(null), 0);
    });
    test('null marker page is runningTotal', () {
      expect(progressTotal(_noMarker(runningTotal: 574)), 574);
    });
    test('marker set: runningTotal + (markerPage - startPage)', () {
      expect(
          progressTotal(_rec(markerPage: 36, startPage: 31, runningTotal: 10)),
          15);
    });
    test('marker on start page adds nothing', () {
      expect(progressTotal(_rec(markerPage: 31, startPage: 31)), 0);
    });
  });

  group('applySetup', () {
    test('null record starts from empty(): cycle 0, version 1', () {
      final r = _ok(applySetup(null, 31, 0xFF1E88E5, 'u1'));
      expect(r.markerPage, 31);
      expect(r.startPage, 31);
      expect(r.color, 0xFF1E88E5);
      expect(r.ownerId, 'u1');
      expect(r.cycle, 0);
      expect(r.version, 1);
      expect(r.runningTotal, 0);
    });
    test('guest setup has a null owner', () {
      final r = _ok(applySetup(null, 5, 0xFF00838F, null));
      expect(r.ownerId, isNull);
    });
    test('works after Restart and keeps total, khatma data and cycle', () {
      final after = _noMarker(
        runningTotal: 0,
        khatmaCount: 0,
        cycle: 3,
        version: 7,
      );
      final r = _ok(applySetup(after, 100, 0xFF827717, 'u1'));
      expect(r.markerPage, 100);
      expect(r.startPage, 100);
      expect(r.cycle, 3);
      expect(r.version, 8);
    });
    test('keeps runningTotal and khatma data of a record without marker', () {
      final base = _noMarker(
        runningTotal: 574,
        khatmaCount: 1,
        khatmaDates: ['2026-10-01'],
        cycle: 2,
        version: 4,
      );
      final r = _ok(applySetup(base, 10, 0xFF1E88E5, 'u1'));
      expect(r.runningTotal, 574);
      expect(r.khatmaCount, 1);
      expect(r.khatmaDates, ['2026-10-01']);
      expect(r.cycle, 2);
    });
    test('fails MARKER_EXISTS when a marker exists', () {
      _err(applySetup(_rec(), 5, 0xFF1E88E5, 'u1'), MarkerFailure.markerExists);
    });
  });

  group('applyMove', () {
    test('forward move adds target - marker pages and bumps version', () {
      final res = _ok(applyMove(_rec(markerPage: 31, version: 1), 36, _today));
      expect(res.pagesAdded, 5);
      expect(res.record.markerPage, 36);
      expect(res.record.version, 2);
      expect(res.record.cycle, 0);
      expect(res.record.startPage, 31);
    });
    test('equal target fails NOT_FORWARD', () {
      _err(applyMove(_rec(markerPage: 31), 31, _today),
          MarkerFailure.notForward);
    });
    test('backward target fails NOT_FORWARD', () {
      _err(applyMove(_rec(markerPage: 31), 30, _today),
          MarkerFailure.notForward);
    });
    test('604 is allowed', () {
      final res = _ok(applyMove(_rec(markerPage: 600), 604, _today));
      expect(res.pagesAdded, 4);
      expect(res.record.markerPage, 604);
    });
    test('605 fails OUT_OF_RANGE', () {
      _err(applyMove(_rec(markerPage: 600), 605, _today),
          MarkerFailure.outOfRange);
    });
    test('marker already on 604 fails NOT_FORWARD', () {
      _err(applyMove(_rec(markerPage: 604), 604, _today),
          MarkerFailure.notForward);
    });
    test('null record fails NO_MARKER', () {
      _err(applyMove(null, 10, _today), MarkerFailure.noMarker);
    });
    test('null marker page fails NO_MARKER', () {
      _err(applyMove(_noMarker(), 10, _today), MarkerFailure.noMarker);
    });
  });

  group('needsBigMoveConfirm', () {
    test('at the goal: no confirmation', () {
      expect(needsBigMoveConfirm(5, 5), isFalse);
    });
    test('goal plus one: confirmation', () {
      expect(needsBigMoveConfirm(6, 5), isTrue);
    });
    test('below the goal: no confirmation', () {
      expect(needsBigMoveConfirm(1, 5), isFalse);
    });
  });

  group('khatmaPages / applyKhatma', () {
    test('marker 590 counts 15 pages', () {
      expect(khatmaPages(_rec(markerPage: 590)), 15);
    });
    test('marker 604 counts 1 page', () {
      expect(khatmaPages(_rec(markerPage: 604)), 1);
    });
    test('marker 1 counts 604 pages', () {
      expect(khatmaPages(_rec(markerPage: 1, startPage: 1)), 604);
    });
    test(
        'from start 1: runningTotal + 604, marker back to 1, cycle and version up',
        () {
      final res = _ok(applyKhatma(
          _rec(
              markerPage: 604,
              startPage: 1,
              runningTotal: 0,
              cycle: 0,
              version: 5,
              color: 0xFFAA0000),
          _today));
      final r = res.record;
      expect(res.pagesAdded, 1);
      expect(r.markerPage, 1);
      expect(r.startPage, 1);
      expect(r.runningTotal, 604);
      expect(r.khatmaCount, 1);
      expect(r.khatmaDates, [_today]);
      expect(r.cycle, 1);
      expect(r.version, 6);
      expect(r.color, 0xFFAA0000, reason: 'color is kept by a khatma');
    });
    test('from start 31: runningTotal grows by 574', () {
      final res = _ok(applyKhatma(
          _rec(markerPage: 604, startPage: 31, runningTotal: 0), _today));
      expect(res.record.runningTotal, 574);
    });
    test(
        'marker 590 credits 15 pages for the move but 604-start+1 to the total',
        () {
      final res = _ok(applyKhatma(
          _rec(markerPage: 590, startPage: 1, runningTotal: 100), _today));
      expect(res.pagesAdded, 15);
      expect(res.record.runningTotal, 704);
    });
    test('appends to existing dates', () {
      final res = _ok(applyKhatma(
          _rec(
              markerPage: 604,
              startPage: 1,
              khatmaCount: 1,
              khatmaDates: ['2026-01-01']),
          _today));
      expect(res.record.khatmaCount, 2);
      expect(res.record.khatmaDates, ['2026-01-01', _today]);
    });
    test('null record fails NO_MARKER', () {
      _err(applyKhatma(null, _today), MarkerFailure.noMarker);
    });
    test('null marker page fails NO_MARKER', () {
      _err(applyKhatma(_noMarker(), _today), MarkerFailure.noMarker);
    });
  });

  group('applyRestart', () {
    test(
        'full record: clears marker, color, total and khatmas; bumps cycle and version',
        () {
      final r = applyRestart(
        _rec(
          markerPage: 300,
          startPage: 31,
          runningTotal: 574,
          khatmaCount: 1,
          khatmaDates: ['2026-10-01'],
          cycle: 2,
          version: 9,
          ownerId: 'u1',
        ),
        'ignored',
      );
      expect(r.markerPage, isNull);
      expect(r.color, isNull);
      expect(r.runningTotal, 0);
      expect(r.khatmaCount, 0);
      expect(r.khatmaDates, isEmpty);
      expect(r.cycle, 3);
      expect(r.version, 10);
      expect(r.ownerId, 'u1', reason: 'the record keeps its owner');
    });
    test('null record gives a tombstone at cycle 1 with the given owner', () {
      final r = applyRestart(null, 'u1');
      expect(r.markerPage, isNull);
      expect(r.cycle, 1);
      expect(r.version, 1);
      expect(r.ownerId, 'u1');
    });
    test('null record, guest: owner null', () {
      expect(applyRestart(null, null).ownerId, isNull);
    });
    test('an already empty record still bumps cycle and version', () {
      final r = applyRestart(_noMarker(cycle: 4, version: 6), null);
      expect(r.cycle, 5);
      expect(r.version, 7);
    });
    test('result is a valid record', () {
      expect(validate(applyRestart(null, 'u1')), isTrue);
      expect(validate(applyRestart(_rec(), 'u1')), isTrue);
    });
  });

  group('applyUndo', () {
    final live = _rec(markerPage: 36, startPage: 31, cycle: 0, version: 2);

    test('success restores the previous page and bumps version', () {
      final r = _ok(applyUndo(
          live, _undo(previousPage: 31, versionAfterMove: 2), _today));
      expect(r.markerPage, 31);
      expect(r.version, 3);
      expect(r.cycle, 0);
    });
    test('no undo record fails NO_UNDO', () {
      _err(applyUndo(live, null, _today), MarkerFailure.noUndo);
    });
    test('null record with an undo fails STALE_RECORD', () {
      _err(applyUndo(null, _undo(), _today), MarkerFailure.staleRecord);
    });
    test('null record without an undo fails NO_UNDO', () {
      _err(applyUndo(null, null, _today), MarkerFailure.noUndo);
    });
    test('null marker page fails STALE_RECORD', () {
      _err(applyUndo(_noMarker(), _undo(), _today), MarkerFailure.staleRecord);
    });
    test('another day (midnight) fails STALE_DAY', () {
      _err(applyUndo(live, _undo(dateKey: '2026-11-12'), _today),
          MarkerFailure.staleDay);
    });
    test('version changed since the move fails STALE_RECORD', () {
      _err(
          applyUndo(_rec(markerPage: 36, version: 3),
              _undo(versionAfterMove: 2), _today),
          MarkerFailure.staleRecord);
    });
    test('cycle changed since the move fails STALE_RECORD', () {
      _err(
          applyUndo(_rec(markerPage: 36, cycle: 1, version: 2),
              _undo(cycle: 0, versionAfterMove: 2), _today),
          MarkerFailure.staleRecord);
    });
  });

  group('shouldRemoveStreakCredit', () {
    test('null undo is false', () {
      expect(shouldRemoveStreakCredit(null, 0, 5), isFalse);
    });
    test('granted credit and pages after below the goal: remove', () {
      expect(shouldRemoveStreakCredit(_undo(granted: true), 4, 5), isTrue);
    });
    test('granted credit but still at the goal: keep', () {
      expect(shouldRemoveStreakCredit(_undo(granted: true), 5, 5), isFalse);
    });
    test('credit came from an earlier move: never remove', () {
      expect(shouldRemoveStreakCredit(_undo(granted: false), 0, 5), isFalse);
    });
    test('does not depend on the marker page (manual credit case: grant false)',
        () {
      expect(
          shouldRemoveStreakCredit(_undo(granted: false, pagesAdded: 5), 0, 5),
          isFalse);
    });
  });

  group('validate / validateCloud', () {
    test('accepts a normal record, an empty record and a no-marker record', () {
      expect(validate(_rec()), isTrue);
      expect(validate(empty()), isTrue);
      expect(validate(_noMarker()), isTrue);
    });
    test('markerPage 1 and 604 accepted; 0 and 605 rejected', () {
      expect(validate(_rec(markerPage: 1, startPage: 1)), isTrue);
      expect(validate(_rec(markerPage: 604, startPage: 1)), isTrue);
      expect(validate(_rec(markerPage: 0, startPage: 1)), isFalse);
      expect(validate(_rec(markerPage: 605, startPage: 1)), isFalse);
    });
    test('startPage must be 1..markerPage when a marker is set', () {
      expect(validate(_rec(markerPage: 31, startPage: 31)), isTrue);
      expect(validate(_rec(markerPage: 31, startPage: 32)), isFalse);
      expect(validate(_rec(markerPage: 31, startPage: 0)), isFalse);
    });
    test('startPage is not checked when markerPage is null', () {
      expect(validate(_rec(markerPage: null, startPage: 500, color: null)),
          isTrue);
    });
    test('negative counts rejected', () {
      expect(validate(_rec(runningTotal: -1)), isFalse);
      expect(validate(_rec(khatmaCount: -1)), isFalse);
      expect(validate(_rec(cycle: -1)), isFalse);
      expect(validate(_rec(version: -1)), isFalse);
    });
    test('zero counts accepted', () {
      expect(
          validate(_rec(runningTotal: 0, khatmaCount: 0, cycle: 0, version: 0)),
          isTrue);
    });
    test('khatma dates must be YYYY-MM-DD', () {
      expect(validate(_rec(khatmaDates: ['2026-11-13'])), isTrue);
      expect(validate(_rec(khatmaDates: ['13/11/2026'])), isFalse);
      expect(validate(_rec(khatmaDates: ['2026-1-3'])), isFalse);
      expect(validate(_rec(khatmaDates: ['2026-11-13', 'bad'])), isFalse);
      expect(validate(_rec(khatmaDates: [''])), isFalse);
    });
    test('color must be null or fit 32 bits', () {
      expect(validate(_rec(color: null)), isTrue);
      expect(validate(_rec(color: 0xFF1E88E5)), isTrue);
      expect(validate(_rec(color: 0x1FFFFFFFF)), isFalse);
      expect(validate(_rec(color: -1)), isFalse);
    });
    test('validateCloud also requires the owner to equal the uid', () {
      expect(validateCloud(_rec(ownerId: 'u1'), 'u1'), isTrue);
      expect(validateCloud(_rec(ownerId: 'u2'), 'u1'), isFalse);
      expect(validateCloud(_rec(ownerId: null), 'u1'), isFalse);
    });
    test('validateCloud rejects an invalid record with the right owner', () {
      expect(
          validateCloud(_rec(ownerId: 'u1', markerPage: 700), 'u1'), isFalse);
    });
  });

  group('decideSync', () {
    const uid = 'u1';
    CloudRead cloudPresent(WirdMarkerRecord r) => CloudReadPresent(r);

    test('read failed -> SKIP_READ_FAILED', () {
      expect(decideSync(_rec(ownerId: uid), const CloudReadFailed(), uid),
          MarkerSyncDecision.skipReadFailed);
    });
    test('invalid cloud -> SKIP_INVALID_CLOUD', () {
      expect(decideSync(_rec(ownerId: uid), const CloudReadInvalid(), uid),
          MarkerSyncDecision.skipInvalidCloud);
    });
    test('failed and invalid win even when local is null', () {
      expect(decideSync(null, const CloudReadFailed(), uid),
          MarkerSyncDecision.skipReadFailed);
      expect(decideSync(null, const CloudReadInvalid(), uid),
          MarkerSyncDecision.skipInvalidCloud);
    });

    group('cloud absent', () {
      test('no local -> NOTHING', () {
        expect(decideSync(null, const CloudReadAbsent(), uid),
            MarkerSyncDecision.nothing);
      });
      test('guest local -> CLAIM_AND_PUSH', () {
        expect(decideSync(_rec(ownerId: null), const CloudReadAbsent(), uid),
            MarkerSyncDecision.claimAndPush);
      });
      test('local owned by another uid -> DISCARD_LOCAL', () {
        expect(decideSync(_rec(ownerId: 'other'), const CloudReadAbsent(), uid),
            MarkerSyncDecision.discardLocal);
      });
      test('local owned by this uid -> PUSH', () {
        expect(decideSync(_rec(ownerId: uid), const CloudReadAbsent(), uid),
            MarkerSyncDecision.push);
      });
    });

    group('cloud present', () {
      final cloud = _rec(ownerId: uid, cycle: 1, version: 5);
      test('no local -> APPLY_CLOUD', () {
        expect(decideSync(null, cloudPresent(cloud), uid),
            MarkerSyncDecision.applyCloud);
      });
      test('guest local -> APPLY_CLOUD', () {
        expect(
            decideSync(_rec(ownerId: null, cycle: 9, version: 9),
                cloudPresent(cloud), uid),
            MarkerSyncDecision.applyCloud);
      });
      test('other owner local -> APPLY_CLOUD', () {
        expect(
            decideSync(_rec(ownerId: 'other', cycle: 9, version: 9),
                cloudPresent(cloud), uid),
            MarkerSyncDecision.applyCloud);
      });
      test('local higher version -> PUSH', () {
        expect(
            decideSync(_rec(ownerId: uid, cycle: 1, version: 6),
                cloudPresent(cloud), uid),
            MarkerSyncDecision.push);
      });
      test('local higher cycle, lower version -> PUSH', () {
        expect(
            decideSync(_rec(ownerId: uid, cycle: 2, version: 1),
                cloudPresent(cloud), uid),
            MarkerSyncDecision.push);
      });
      test('equal pair -> APPLY_CLOUD (cloud wins)', () {
        expect(
            decideSync(_rec(ownerId: uid, cycle: 1, version: 5),
                cloudPresent(cloud), uid),
            MarkerSyncDecision.applyCloud);
      });
      test('local lower version -> APPLY_CLOUD', () {
        expect(
            decideSync(_rec(ownerId: uid, cycle: 1, version: 4),
                cloudPresent(cloud), uid),
            MarkerSyncDecision.applyCloud);
      });
      test('local lower cycle, higher version -> APPLY_CLOUD', () {
        expect(
            decideSync(_rec(ownerId: uid, cycle: 0, version: 99),
                cloudPresent(cloud), uid),
            MarkerSyncDecision.applyCloud);
      });
    });
  });

  group('mergeKhatmas', () {
    test('no record: legacy values only', () {
      final m = mergeKhatmas(2, ['2026-01-01', '2026-02-01'], null);
      expect(m.count, 2);
      expect(m.dates, ['2026-01-01', '2026-02-01']);
    });
    test('record without marker still contributes its khatmas', () {
      final m = mergeKhatmas(
          0, const [], _noMarker(khatmaCount: 1, khatmaDates: ['2026-03-01']));
      expect(m.count, 1);
      expect(m.dates, ['2026-03-01']);
    });
    test('sums counts and sorts the union of dates', () {
      final m = mergeKhatmas(1, ['2026-05-01'],
          _rec(khatmaCount: 2, khatmaDates: ['2026-06-01', '2026-02-01']));
      expect(m.count, 3);
      expect(m.dates, ['2026-02-01', '2026-05-01', '2026-06-01']);
    });
    test('count and date list of different lengths are kept as they are', () {
      final m = mergeKhatmas(
          3, ['2026-01-01'], _rec(khatmaCount: 1, khatmaDates: const []));
      expect(m.count, 4);
      expect(m.dates, ['2026-01-01']);
    });
    test('does not modify the legacy list', () {
      final legacy = ['2026-05-01'];
      mergeKhatmas(
          0, legacy, _rec(khatmaCount: 1, khatmaDates: ['2026-01-01']));
      expect(legacy, ['2026-05-01']);
    });
  });

  group('averagePerCompletedDay', () {
    test('page mode: progressTotal / days', () {
      expect(
          averagePerCompletedDay(
              unit: WirdUnit.page,
              progressTotal: 30,
              juzKhatmCount: 5,
              checkedJuzCount: 9,
              totalDaysCompleted: 4),
          7.5);
    });
    test('juz mode: (khatmas * 30 + checked) / days', () {
      expect(
          averagePerCompletedDay(
              unit: WirdUnit.juz,
              progressTotal: 999,
              juzKhatmCount: 1,
              checkedJuzCount: 10,
              totalDaysCompleted: 8),
          5.0);
    });
    test('zero days gives 0.0 in both modes', () {
      for (final u in WirdUnit.values) {
        expect(
            averagePerCompletedDay(
                unit: u,
                progressTotal: 100,
                juzKhatmCount: 2,
                checkedJuzCount: 3,
                totalDaysCompleted: 0),
            0.0);
      }
    });
  });

  group('composeWirdState', () {
    const base = WirdState(
      streakCount: 3,
      totalPagesRead: 999, // legacy value, replaced by the derived total
      totalDaysCompleted: 7,
      khatmCount: 2, // legacy juz khatmas
      khatmDates: ['2026-01-01', '2026-03-01'],
    );

    test('no record: derived total 0, legacy khatmas kept, no marker, no undo',
        () {
      final s = composeWirdState(base, null, null, _today);
      expect(s.marker, isNull);
      expect(s.undo, isNull);
      expect(s.totalPagesRead, 0);
      expect(s.juzKhatmCount, 2);
      expect(s.khatmCount, 2);
      expect(s.khatmDates, ['2026-01-01', '2026-03-01']);
      expect(s.streakCount, 3, reason: 'other base fields pass through');
      expect(s.totalDaysCompleted, 7);
    });

    test('derived total and combined khatmas (lists of different lengths)', () {
      final rec = _rec(
        markerPage: 36,
        startPage: 31,
        runningTotal: 574,
        khatmaCount: 3,
        khatmaDates: ['2026-02-01'],
        version: 2,
      );
      final s = composeWirdState(base, rec, null, _today);
      expect(s.marker, rec);
      expect(s.totalPagesRead, 579);
      expect(s.juzKhatmCount, 2);
      expect(s.khatmCount, 5);
      expect(s.khatmDates, ['2026-01-01', '2026-02-01', '2026-03-01']);
    });

    test('keeps a valid undo record', () {
      final rec = _rec(markerPage: 36, cycle: 0, version: 2);
      final u = _undo(versionAfterMove: 2, cycle: 0);
      expect(composeWirdState(base, rec, u, _today).undo, u);
    });

    test('drops an undo from another day', () {
      final rec = _rec(markerPage: 36, version: 2);
      final u = _undo(dateKey: '2026-11-12', versionAfterMove: 2);
      expect(composeWirdState(base, rec, u, _today).undo, isNull);
    });

    test('drops an undo whose version no longer matches', () {
      final rec = _rec(markerPage: 36, version: 3);
      expect(
          composeWirdState(base, rec, _undo(versionAfterMove: 2), _today).undo,
          isNull);
    });

    test('drops an undo whose cycle no longer matches', () {
      final rec = _rec(markerPage: 36, cycle: 1, version: 2);
      expect(
          composeWirdState(
                  base, rec, _undo(cycle: 0, versionAfterMove: 2), _today)
              .undo,
          isNull);
    });

    test('drops an undo when there is no record', () {
      expect(composeWirdState(base, null, _undo(), _today).undo, isNull);
    });

    test('does not carry marker or undo from the base state', () {
      final stale = base.copyWith(marker: _rec(), undo: _undo());
      final s = composeWirdState(stale, null, null, _today);
      expect(s.marker, isNull);
      expect(s.undo, isNull);
    });
  });
}
