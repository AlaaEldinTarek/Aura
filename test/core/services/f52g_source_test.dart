// Spec: docs/designs/fix-f52g.md — F52g Wird sync data loss.
// Source-text tests pin the guard structure so a logic inversion or missing
// field is caught without a Firestore mock. Unit tests exercise the pure helper
// and the applyCloudData overwrite path via SharedPreferences.
import 'dart:io';
import 'package:aura_app/core/models/wird.dart';
import 'package:aura_app/core/services/wird_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final src = File('lib/core/services/wird_service.dart').readAsStringSync();

  // ── Source-text tests ────────────────────────────────────────────────────

  // T1: local-timestamp prefs key declared
  test('T1: _localUpdatedAtKey declared as wird_local_updated_at_ms', () {
    expect(src, contains("'wird_local_updated_at_ms'"),
        reason: '_localUpdatedAtKey constant missing or renamed');
  });

  // T2: helpers exported (visibleForTesting)
  test('T2: cloudIsNewer and applyCloudData are present', () {
    expect(src, contains('cloudIsNewer'),
        reason: 'cloudIsNewer helper missing');
    expect(src, contains('applyCloudData'),
        reason: 'applyCloudData helper missing');
  });

  // T3: syncFromFirestore uses the guard with negation and delegates to applyCloudData
  test('T3: syncFromFirestore guard negates cloudIsNewer and calls applyCloudData', () {
    expect(src, contains('!WirdService.cloudIsNewer'),
        reason: 'skip-overwrite guard missing or inverted in syncFromFirestore');
    expect(src, contains('await applyCloudData(data, prefs)'),
        reason: 'applyCloudData not called on the cloud-wins branch');
  });

  // T4: syncToFirestore pushes both new fields
  test('T4: syncToFirestore includes localUpdatedAt and progressHistory', () {
    expect(src, contains("'localUpdatedAt'"),
        reason: 'localUpdatedAt field missing from syncToFirestore doc.set');
    expect(src, contains("'progressHistory'"),
        reason: 'progressHistory field missing from syncToFirestore doc.set');
  });

  // T5: _pushToCloud sets _localUpdatedAtKey after uid check
  test('T5: _pushToCloud sets _localUpdatedAtKey for logged-in users', () {
    expect(src, contains('_localUpdatedAtKey, DateTime.now().millisecondsSinceEpoch'),
        reason: '_pushToCloud does not set _localUpdatedAtKey');
  });

  // ── Unit tests ───────────────────────────────────────────────────────────

  // T6–T8: cloudIsNewer pure logic
  test('T6: cloudIsNewer — tie: cloud wins', () {
    expect(WirdService.cloudIsNewer(100, 100), isTrue);
  });

  test('T7: cloudIsNewer — cloud newer: cloud wins', () {
    expect(WirdService.cloudIsNewer(100, 200), isTrue);
  });

  test('T8: cloudIsNewer — local newer: local wins (guard fires)', () {
    expect(WirdService.cloudIsNewer(200, 100), isFalse);
  });

  // T9–T12: applyCloudData behaviour via SharedPreferences mock
  group('applyCloudData', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    // T9: scalar fields are written
    test('T9: applies streakCount from cloud data', () async {
      final s = WirdService.forTesting();
      final prefs = await SharedPreferences.getInstance();
      await s.applyCloudData({'streakCount': 7}, prefs);
      expect(prefs.getInt('wird_streak_count'), 7);
    });

    // T10: Reset All Progress scenario — streakCount 0 from cloud overwrites local
    test('T10: applies streakCount 0 (Reset All Progress scenario)', () async {
      SharedPreferences.setMockInitialValues({'wird_streak_count': 5});
      final s = WirdService.forTesting();
      final prefs = await SharedPreferences.getInstance();
      await s.applyCloudData({'streakCount': 0}, prefs);
      expect(prefs.getInt('wird_streak_count'), 0);
    });

    // T11: progressHistory is written to prefs
    test('T11: applies progressHistory from cloud data', () async {
      final s = WirdService.forTesting();
      final prefs = await SharedPreferences.getInstance();
      final entry = WirdProgress(
        date: DateTime(2026, 11, 20),
        pagesRead: 5,
        startPage: 1,
        currentPage: 6,
        isCompleted: true,
      );
      await s.applyCloudData({
        'progressHistory': [entry.toJson()],
      }, prefs);
      // The history key must now be set in prefs
      expect(prefs.getString('wird_progress_history'), isNotNull);
      expect(prefs.getString('wird_progress_history'), contains('2026-11-20'));
    });

    // T12: empty progressHistory clears local history (Reset All Progress)
    test('T12: empty progressHistory clears local history', () async {
      SharedPreferences.setMockInitialValues({
        'wird_progress_history':
            '[{"date":"2026-11-20","pagesRead":5,"startPage":1,"currentPage":6,"isCompleted":true,"juzCompletedToday":[]}]',
      });
      final s = WirdService.forTesting();
      final prefs = await SharedPreferences.getInstance();
      await s.applyCloudData({'progressHistory': <dynamic>[]}, prefs);
      expect(prefs.getString('wird_progress_history'), equals('[]'));
    });
  });
}
