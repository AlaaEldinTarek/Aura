/// Local storage, cloud sync and the user-level actions of the Wird marker
/// (spec: docs/designs/wird-marker.md, item 3).
///
/// The pure rules live in `wird_marker_logic.dart`. This file adds persistence
/// (`wird_marker`, `wird_marker_undo`), the cloud document
/// `users/{uid}/wird/marker`, and the flows that tie a marker change to
/// today's history and streak (through [WirdService]).
///
/// Sync is a `Source.server` read, a compare, then a plain write. There is no
/// transaction and no queue; the race window is accepted (spec, Risks 3, 4, 11).
library;

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wird_marker.dart';
import 'wird_marker_logic.dart';
import 'wird_service.dart';

/// Access to the cloud document. Both methods turn every error into a result
/// value and never throw.
abstract class WirdMarkerCloud {
  /// Reads `users/{uid}/wird/marker` from the server (never the cache).
  /// Returns `invalid` for a document that fails `validateCloud(record, uid)`.
  Future<CloudRead> readServer(String uid);

  /// Plain `set()` (full replacement, no merge). Refuses a record whose
  /// `ownerId` is not [uid].
  Future<MarkerPushResult> write(String uid, WirdMarkerRecord record);
}

/// Production cloud: Firestore, 5 s timeout on each call.
class FirestoreWirdMarkerCloud implements WirdMarkerCloud {
  static const _timeout = Duration(seconds: 5);

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('wird')
          .doc('marker');

  @override
  Future<CloudRead> readServer(String uid) async {
    try {
      final snap = await _doc(uid)
          .get(const GetOptions(source: Source.server))
          .timeout(_timeout);
      if (!snap.exists) return const CloudReadAbsent();
      final record = WirdMarkerRecord.fromJson(snap.data());
      if (record == null || !validateCloud(record, uid)) {
        debugPrint('⚠️ [WIRD] Cloud marker is invalid, skipped');
        return const CloudReadInvalid();
      }
      return CloudReadPresent(record);
    } catch (e) {
      debugPrint('⚠️ [WIRD] Cloud marker read failed: $e');
      return const CloudReadFailed();
    }
  }

  @override
  Future<MarkerPushResult> write(String uid, WirdMarkerRecord record) async {
    if (record.ownerId != uid) return const MarkerPushFailed();
    try {
      await _doc(uid).set(record.toJson()).timeout(_timeout);
      return const MarkerPushed();
    } catch (e) {
      debugPrint('⚠️ [WIRD] Cloud marker write failed: $e');
      return const MarkerPushFailed();
    }
  }
}

class WirdMarkerService {
  static const markerKey = 'wird_marker';
  static const undoKey = 'wird_marker_undo';

  final WirdMarkerCloud _cloud;
  final WirdService _wird;
  final DateTime Function() _now;
  final String? Function() _uid;

  WirdMarkerService._({
    required WirdMarkerCloud cloud,
    required WirdService wird,
    required DateTime Function() now,
    required String? Function() uid,
  })  : _cloud = cloud,
        _wird = wird,
        _now = now,
        _uid = uid;

  /// Constructor with injectable parts: fakes for the cloud, the Wird service,
  /// the clock and the uid reader. Tests use it, and so does `WirdNotifier`
  /// when it is given a uid source or a cloud object. Tests never touch
  /// [instance].
  WirdMarkerService.forTesting({
    required WirdMarkerCloud cloud,
    required WirdService wird,
    DateTime Function()? now,
    String? Function()? uid,
  })  : _cloud = cloud,
        _wird = wird,
        _now = now ?? DateTime.now,
        _uid = uid ?? _defaultUid;

  static final WirdMarkerService instance = WirdMarkerService._(
    cloud: FirestoreWirdMarkerCloud(),
    wird: WirdService.instance,
    now: DateTime.now,
    uid: _defaultUid,
  );

  /// Raised after every local change of the marker or undo record, whoever
  /// caused it, so the provider can reload.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// The signed-in uid, or null for a guest, no user, or no Firebase.
  static String? _defaultUid() {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      return (uid == null || uid == 'guest_user') ? null : uid;
    } catch (_) {
      return null;
    }
  }

  String _today() {
    final n = _now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  // ── Local storage ────────────────────────────────────────────────────────

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// The local record, or null when there is none or it is unusable.
  Future<WirdMarkerRecord?> load() async {
    final prefs = await _prefs;
    final raw = prefs.getString(markerKey);
    if (raw == null) return null;
    try {
      final record = WirdMarkerRecord.fromJson(jsonDecode(raw));
      if (record == null || !validate(record)) {
        debugPrint('⚠️ [WIRD] Local marker is invalid, ignored');
        return null;
      }
      return record;
    } catch (_) {
      debugPrint('⚠️ [WIRD] Local marker is unreadable, ignored');
      return null;
    }
  }

  Future<void> save(WirdMarkerRecord record) async {
    final prefs = await _prefs;
    final encoded = jsonEncode(record.toJson());
    if (prefs.getString(markerKey) == encoded) return;
    await prefs.setString(markerKey, encoded);
    revision.value++;
  }

  /// Removes the local record (bumps [revision] only if there was one).
  Future<void> clear() async {
    final prefs = await _prefs;
    if (!prefs.containsKey(markerKey)) return;
    await prefs.remove(markerKey);
    revision.value++;
  }

  Future<WirdUndoRecord?> loadUndo() async {
    final prefs = await _prefs;
    final raw = prefs.getString(undoKey);
    if (raw == null) return null;
    try {
      return WirdUndoRecord.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUndo(WirdUndoRecord undo) async {
    final prefs = await _prefs;
    final encoded = jsonEncode(undo.toJson());
    if (prefs.getString(undoKey) == encoded) return;
    await prefs.setString(undoKey, encoded);
    revision.value++;
  }

  /// Removes the undo record (bumps [revision] only if there was one).
  Future<void> clearUndo() async {
    final prefs = await _prefs;
    if (!prefs.containsKey(undoKey)) return;
    await prefs.remove(undoKey);
    revision.value++;
  }

  /// Khatma count of the local record. 0 with no record. No cloud call.
  Future<int> khatmaCountLocal() async => (await load())?.khatmaCount ?? 0;

  /// Derived page total of the local record. 0 with no record. No cloud call.
  Future<int> progressTotalLocal() async => progressTotal(await load());

  // ── Cloud ────────────────────────────────────────────────────────────────

  /// Reads the cloud record and validates it, whatever the cloud class did.
  Future<CloudRead> _readCloud(String uid) async {
    try {
      final read = await _cloud.readServer(uid);
      if (read is CloudReadPresent && !validateCloud(read.record, uid)) {
        return const CloudReadInvalid();
      }
      return read;
    } catch (e) {
      debugPrint('⚠️ [WIRD] Cloud marker read threw: $e');
      return const CloudReadFailed();
    }
  }

  Future<MarkerPushResult> _writeCloud(String uid, WirdMarkerRecord r) async {
    try {
      return await _cloud.write(uid, r);
    } catch (e) {
      debugPrint('⚠️ [WIRD] Cloud marker write threw: $e');
      return const MarkerPushFailed();
    }
  }

  /// One `Source.server` read, a compare, then a plain write. Used by undo.
  Future<MarkerPushResult> pushIfNewer(
      String uid, WirdMarkerRecord record) async {
    if (record.ownerId != uid) return const MarkerPushFailed();
    final read = await _readCloud(uid);
    switch (read) {
      case CloudReadFailed():
      case CloudReadInvalid():
        return const MarkerPushFailed();
      case CloudReadPresent(record: final cloud):
        if (compare(record, cloud) <= 0) return MarkerNotNewer(cloud);
      case CloudReadAbsent():
        break;
    }
    return _writeCloud(uid, record);
  }

  /// Reconciles the local record with the cloud. Never throws.
  Future<MarkerSyncResult> syncMarker() async {
    try {
      final uid = _uid();
      if (uid == null) return const MarkerSyncResult.localOnly();

      final cloudRead = await _readCloud(uid);
      // Loaded after the read, so a move saved meanwhile is seen.
      final local = await load();
      final decision = decideSync(local, cloudRead, uid);
      MarkerPushResult? push;

      switch (decision) {
        case MarkerSyncDecision.push:
          push = await _writeCloud(uid, local!);
        case MarkerSyncDecision.claimAndPush:
          final claimed = local!.copyWith(ownerId: uid);
          await save(claimed);
          push = await _writeCloud(uid, claimed);
        case MarkerSyncDecision.applyCloud:
          final cloud = (cloudRead as CloudReadPresent).record;
          await save(cloud);
          final undo = await loadUndo();
          if (undo != null &&
              (undo.cycle != cloud.cycle ||
                  undo.versionAfterMove != cloud.version)) {
            await clearUndo();
          }
        case MarkerSyncDecision.discardLocal:
          await clear();
          await clearUndo();
        case MarkerSyncDecision.nothing:
        case MarkerSyncDecision.skipReadFailed:
        case MarkerSyncDecision.skipInvalidCloud:
          break;
      }
      debugPrint('🔄 [WIRD] Marker sync: ${decision.name}');
      return MarkerSyncResult(decision: decision, push: push);
    } catch (e) {
      debugPrint('⚠️ [WIRD] Marker sync failed: $e');
      return const MarkerSyncResult(push: MarkerPushFailed());
    }
  }

  void _syncInBackground() {
    unawaited(syncMarker().then<void>((_) {}, onError: (Object e) {
      debugPrint('⚠️ [WIRD] Marker sync failed: $e');
    }));
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Places the marker on [page] (setup). Works only with no marker.
  Future<PlaceOutcome> placeMarker(int page, int color) async {
    final result = applySetup(await load(), page, color, _uid());
    switch (result) {
      case Err(failure: final f):
        return PlaceFailed(f);
      case Ok(value: final r):
        // A record that would not load back (page outside 1..604) is refused.
        if (!validate(r)) return const PlaceFailed(MarkerFailure.outOfRange);
        await save(r);
        await clearUndo();
        _syncInBackground();
        return const Placed();
    }
  }

  /// Moves the marker forward to [target] and credits the pages.
  Future<MoveOutcome> moveMarker(int target) async {
    final before = await load();
    final result = applyMove(before, target, _today());
    switch (result) {
      case Err(failure: final f):
        return MoveFailed(f);
      case Ok(value: final v):
        final fromPage = before!.markerPage!;
        await save(v.record);
        final credit = await _wird.creditPages(v.pagesAdded,
            fromPage: fromPage, toPage: target);
        await saveUndo(WirdUndoRecord(
          previousPage: fromPage,
          pagesAdded: v.pagesAdded,
          dateKey: _today(),
          grantedStreakCredit: credit.grantedStreakCredit,
          cycle: v.record.cycle,
          versionAfterMove: v.record.version,
        ));
        _syncInBackground();
        return Moved(
          pagesAdded: v.pagesAdded,
          markerPage: target,
          grantedStreakCredit: credit.grantedStreakCredit,
        );
    }
  }

  /// "Yes" on the close-on-604 prompt: counts the pages to 604 and starts a
  /// new cycle. Not undoable.
  Future<KhatmaOutcome> completeKhatma() async {
    final before = await load();
    final result = applyKhatma(before, _today());
    switch (result) {
      case Err(failure: final f):
        return KhatmaFailed(f);
      case Ok(value: final v):
        final legacy = await _wird.getKhatmCount();
        await save(v.record);
        await _wird.creditPages(v.pagesAdded,
            fromPage: before!.markerPage!, toPage: 1);
        await clearUndo();
        _syncInBackground();
        return Completed(
          pagesAdded: v.pagesAdded,
          khatmCount: legacy + v.record.khatmaCount,
        );
    }
  }

  /// Undoes the last move. A signed-in user needs the cloud (the push comes
  /// first); a guest undoes locally.
  Future<UndoOutcome> undoMove() async {
    final before = await load();
    final undo = await loadUndo();
    final today = _today();
    final result = applyUndo(before, undo, today);
    final MarkerFailure? failure =
        result is Err<WirdMarkerRecord> ? result.failure : null;
    if (failure != null) return UndoFailed(failure);
    final undone = (result as Ok<WirdMarkerRecord>).value;

    final uid = _uid();
    if (uid != null) {
      if (before!.ownerId != null && before.ownerId != uid) {
        return const UndoFailed(MarkerFailure.staleRecord);
      }
      if (before.ownerId == uid) {
        final pushed = await pushIfNewer(uid, undone);
        switch (pushed) {
          case MarkerNotNewer(cloudRecord: final cloud):
            await save(cloud);
            await clearUndo();
            return const UndoCloudNewer();
          case MarkerPushFailed():
            return const UndoNeedsConnection();
          case MarkerPushed():
            break;
        }
      }
    }

    final todayProgress = await _wird.getTodayProgress();
    final goal = (await _wird.getSettings()).dailyPageGoal;
    final pagesAfter = (todayProgress?.pagesRead ?? 0) - undo!.pagesAdded;
    await save(undone);
    await _wird.removePages(
      undo.pagesAdded,
      dateKey: today,
      removeCredit: shouldRemoveStreakCredit(undo, pagesAfter, goal),
      restoreCurrentPage: undo.previousPage,
    );
    await clearUndo();
    return const UndoDone();
  }

  /// Restart Wird: clears the marker, its total and khatmas, and raises the
  /// cycle. Streak, history and juz data are untouched.
  Future<void> restartWird() async {
    await save(applyRestart(await load(), _uid()));
    await clearUndo();
    _syncInBackground();
  }

  /// Reset All Progress: wipes streak, totals, history, juz and legacy khatma
  /// data (any mode), then saves a restarted record. Always raises the cycle.
  Future<void> resetAll() async {
    await _wird.resetAllProgress();
    await save(applyRestart(await load(), _uid()));
    await clearUndo();
    _syncInBackground();
  }
}
