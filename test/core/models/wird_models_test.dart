// P2 cases only. The WirdSettings legacy-field cases (linkedBookmarkColor,
// countedBookmarkPages) belong to P5 and are not here.
import 'dart:convert';

import 'package:aura_app/core/models/wird.dart';
import 'package:aura_app/core/models/wird_marker.dart';
import 'package:aura_app/core/services/wird_marker_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WirdProgress.manualCredit', () {
    test('defaults to false', () {
      expect(WirdProgress(date: DateTime(2026, 11, 13)).manualCredit, isFalse);
    });

    test('a history entry without the key reads as false', () {
      final p = WirdProgress.fromJson({
        'date': '2026-11-13',
        'pagesRead': 5,
        'startPage': 1,
        'currentPage': 6,
        'isCompleted': true,
        'juzCompletedToday': <int>[],
      });
      expect(p.manualCredit, isFalse);
    });

    test('true survives a JSON round trip', () {
      final p = WirdProgress(
          date: DateTime(2026, 11, 13), isCompleted: true, manualCredit: true);
      final back = WirdProgress.fromJson(
          jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(back.manualCredit, isTrue);
    });

    test('false round trips as false', () {
      final p = WirdProgress(date: DateTime(2026, 11, 13), pagesRead: 3);
      final back = WirdProgress.fromJson(
          jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(back.manualCredit, isFalse);
    });

    test('copyWith keeps it and can change it', () {
      final p = WirdProgress(date: DateTime(2026, 11, 13), manualCredit: true);
      expect(p.copyWith(pagesRead: 2).manualCredit, isTrue);
      expect(p.copyWith(manualCredit: false).manualCredit, isFalse);
    });

    test('an entry with no manualCredit serializes as before (key omitted)',
        () {
      final json = WirdProgress(date: DateTime(2026, 11, 13)).toJson();
      expect(json.containsKey('manualCredit'), isFalse);
    });
  });

  group('WirdState new fields', () {
    test('defaults: no marker, no undo, juzKhatmCount 0', () {
      const s = WirdState();
      expect(s.marker, isNull);
      expect(s.undo, isNull);
      expect(s.juzKhatmCount, 0);
    });

    test('copyWith sets and clears marker and undo', () {
      const rec = WirdMarkerRecord(markerPage: 5);
      const u = WirdUndoRecord(
          previousPage: 1,
          pagesAdded: 4,
          dateKey: '2026-11-13',
          grantedStreakCredit: false,
          cycle: 0,
          versionAfterMove: 1);
      final s =
          const WirdState().copyWith(marker: rec, undo: u, juzKhatmCount: 2);
      expect(s.marker, rec);
      expect(s.undo, u);
      expect(s.juzKhatmCount, 2);
      final cleared = s.copyWith(clearMarker: true, clearUndo: true);
      expect(cleared.marker, isNull);
      expect(cleared.undo, isNull);
      expect(cleared.juzKhatmCount, 2);
    });

    test('copyWith without the new arguments keeps them', () {
      const rec = WirdMarkerRecord(markerPage: 5);
      final s =
          const WirdState().copyWith(marker: rec).copyWith(streakCount: 4);
      expect(s.marker, rec);
    });
  });

  group('WirdMarkerRecord JSON', () {
    test('every field survives a round trip', () {
      const r = WirdMarkerRecord(
        markerPage: 120,
        startPage: 31,
        runningTotal: 574,
        khatmaCount: 2,
        khatmaDates: ['2026-02-01', '2026-06-01'],
        cycle: 3,
        version: 11,
        ownerId: 'uid-1',
        color: 0xFF1E88E5,
      );
      final back =
          WirdMarkerRecord.fromJson(jsonDecode(jsonEncode(r.toJson())));
      expect(back, r);
    });

    test('null marker page and null owner and color survive', () {
      const r = WirdMarkerRecord(markerPage: null, cycle: 1, version: 1);
      expect(WirdMarkerRecord.fromJson(jsonDecode(jsonEncode(r.toJson()))), r);
    });

    test('toJson writes nulls explicitly and has nine keys', () {
      final json = const WirdMarkerRecord().toJson();
      expect(json.keys.toSet(), {
        'markerPage',
        'startPage',
        'runningTotal',
        'khatmaCount',
        'khatmaDates',
        'cycle',
        'version',
        'ownerId',
        'color',
      });
      expect(json['markerPage'], isNull);
      expect(json['ownerId'], isNull);
      expect(json['color'], isNull);
    });

    test('missing keys take their defaults', () {
      final r = WirdMarkerRecord.fromJson(<String, dynamic>{})!;
      expect(r.markerPage, isNull);
      expect(r.startPage, 1);
      expect(r.runningTotal, 0);
      expect(r.khatmaCount, 0);
      expect(r.khatmaDates, isEmpty);
      expect(r.cycle, 0);
      expect(r.version, 0);
      expect(r.ownerId, isNull);
      expect(r.color, isNull);
    });

    test('extra keys are ignored', () {
      final r = WirdMarkerRecord.fromJson({
        'markerPage': 3,
        'updatedAt': 'x',
        'other': [1]
      })!;
      expect(r.markerPage, 3);
    });

    test('non-map input returns null', () {
      expect(WirdMarkerRecord.fromJson(null), isNull);
      expect(WirdMarkerRecord.fromJson('text'), isNull);
      expect(WirdMarkerRecord.fromJson([1, 2]), isNull);
      expect(WirdMarkerRecord.fromJson(7), isNull);
    });

    test('wrongly typed values return null', () {
      expect(WirdMarkerRecord.fromJson({'markerPage': '5'}), isNull);
      expect(WirdMarkerRecord.fromJson({'startPage': 1.5}), isNull);
      expect(WirdMarkerRecord.fromJson({'khatmaDates': 'x'}), isNull);
      expect(
          WirdMarkerRecord.fromJson({
            'khatmaDates': [1]
          }),
          isNull);
      expect(WirdMarkerRecord.fromJson({'ownerId': 5}), isNull);
      expect(WirdMarkerRecord.fromJson({'color': 'red'}), isNull);
    });

    test(
        'a marker page outside 1..604 loads (fromJson does not repair) and validate rejects it',
        () {
      final low = WirdMarkerRecord.fromJson({'markerPage': 0, 'startPage': 1})!;
      final high =
          WirdMarkerRecord.fromJson({'markerPage': 605, 'startPage': 1})!;
      expect(low.markerPage, 0);
      expect(high.markerPage, 605);
      expect(validate(low), isFalse);
      expect(validate(high), isFalse);
    });

    test('copyWith clear flags clear the nullable fields', () {
      const r = WirdMarkerRecord(markerPage: 5, ownerId: 'u', color: 1);
      final c = r.copyWith(
          clearMarkerPage: true, clearOwnerId: true, clearColor: true);
      expect(c.markerPage, isNull);
      expect(c.ownerId, isNull);
      expect(c.color, isNull);
    });

    test('equality compares the date list by value', () {
      const a = WirdMarkerRecord(khatmaDates: ['2026-01-01']);
      final b = WirdMarkerRecord(khatmaDates: List.of(['2026-01-01']));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == const WirdMarkerRecord(khatmaDates: ['2026-01-02']), isFalse);
    });
  });

  group('WirdUndoRecord JSON', () {
    test('round trip', () {
      const u = WirdUndoRecord(
          previousPage: 31,
          pagesAdded: 5,
          dateKey: '2026-11-13',
          grantedStreakCredit: true,
          cycle: 1,
          versionAfterMove: 4);
      expect(WirdUndoRecord.fromJson(jsonDecode(jsonEncode(u.toJson()))), u);
    });

    test('missing or wrongly typed fields return null', () {
      expect(WirdUndoRecord.fromJson(<String, dynamic>{}), isNull);
      expect(WirdUndoRecord.fromJson(null), isNull);
      expect(
          WirdUndoRecord.fromJson({
            'previousPage': '31',
            'pagesAdded': 5,
            'dateKey': '2026-11-13',
            'grantedStreakCredit': true,
            'cycle': 0,
            'versionAfterMove': 1,
          }),
          isNull);
    });
  });

  group('combined khatma values through composeWirdState', () {
    test(
        'legacy and record data together, count and dates of different lengths',
        () {
      const base = WirdState(khatmCount: 2, khatmDates: ['2026-01-01']);
      const rec = WirdMarkerRecord(
        markerPage: 10,
        khatmaCount: 3,
        khatmaDates: ['2026-02-01', '2026-03-01'],
        cycle: 1,
        version: 1,
      );
      final s = composeWirdState(base, rec, null, '2026-11-13');
      expect(s.juzKhatmCount, 2);
      expect(s.khatmCount, 5);
      expect(s.khatmDates, ['2026-01-01', '2026-02-01', '2026-03-01']);
    });

    test('legacy only (no record)', () {
      const base = WirdState(khatmCount: 4, khatmDates: ['2026-01-01']);
      final s = composeWirdState(base, null, null, '2026-11-13');
      expect(s.khatmCount, 4);
      expect(s.khatmDates, ['2026-01-01']);
    });

    test('record only (no legacy)', () {
      const rec = WirdMarkerRecord(
          markerPage: 2,
          khatmaCount: 1,
          khatmaDates: ['2026-05-05'],
          version: 1);
      final s = composeWirdState(const WirdState(), rec, null, '2026-11-13');
      expect(s.khatmCount, 1);
      expect(s.khatmDates, ['2026-05-05']);
    });
  });
}
