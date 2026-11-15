/// Models for the Wird marker (spec: docs/designs/wird-marker.md, item 1).
///
/// No I/O in this file. The record is stored as JSON in the local key
/// `wird_marker` and as one cloud document; the undo record is local only.
library;

/// One immutable marker record. Ordering between two records is by
/// (`cycle`, `version`), see `compare` in `wird_marker_logic.dart`.
class WirdMarkerRecord {
  /// Current marker page, 1 to 604. Null before setup and after Restart.
  final int? markerPage;

  /// Page the current cycle started on. Becomes 1 after a khatma.
  final int startPage;

  /// Pages counted in finished khatma cycles.
  final int runningTotal;

  /// Page-mode khatmas in this record.
  final int khatmaCount;

  /// One `YYYY-MM-DD` date per page-mode khatma.
  final List<String> khatmaDates;

  /// Raised only by khatma, Restart and Reset All Progress.
  final int cycle;

  /// Raised by every change.
  final int version;

  /// Account uid. Null for a guest marker.
  final String? ownerId;

  /// 32-bit ARGB value of the Wird color. Null when there is no marker.
  final int? color;

  const WirdMarkerRecord({
    this.markerPage,
    this.startPage = 1,
    this.runningTotal = 0,
    this.khatmaCount = 0,
    this.khatmaDates = const [],
    this.cycle = 0,
    this.version = 0,
    this.ownerId,
    this.color,
  });

  WirdMarkerRecord copyWith({
    int? markerPage,
    bool clearMarkerPage = false,
    int? startPage,
    int? runningTotal,
    int? khatmaCount,
    List<String>? khatmaDates,
    int? cycle,
    int? version,
    String? ownerId,
    bool clearOwnerId = false,
    int? color,
    bool clearColor = false,
  }) =>
      WirdMarkerRecord(
        markerPage: clearMarkerPage ? null : (markerPage ?? this.markerPage),
        startPage: startPage ?? this.startPage,
        runningTotal: runningTotal ?? this.runningTotal,
        khatmaCount: khatmaCount ?? this.khatmaCount,
        khatmaDates: khatmaDates ?? this.khatmaDates,
        cycle: cycle ?? this.cycle,
        version: version ?? this.version,
        ownerId: clearOwnerId ? null : (ownerId ?? this.ownerId),
        color: clearColor ? null : (color ?? this.color),
      );

  Map<String, dynamic> toJson() => {
        'markerPage': markerPage,
        'startPage': startPage,
        'runningTotal': runningTotal,
        'khatmaCount': khatmaCount,
        'khatmaDates': khatmaDates,
        'cycle': cycle,
        'version': version,
        'ownerId': ownerId,
        'color': color,
      };

  /// Tolerant decoder. A missing (or null) key takes its default, extra keys
  /// are ignored. Returns null for a non-map or a wrongly typed value. It does
  /// not repair values: range checks belong to `validate`.
  static WirdMarkerRecord? fromJson(Object? json) {
    if (json is! Map) return null;

    // Returns the int at [key], [fallback] when absent/null, or throws on a
    // wrong type (caught below).
    int intOf(String key, int fallback) {
      final v = json[key];
      if (v == null) return fallback;
      if (v is int) return v;
      throw const FormatException('wrong type');
    }

    int? nullableIntOf(String key) {
      final v = json[key];
      if (v == null) return null;
      if (v is int) return v;
      throw const FormatException('wrong type');
    }

    try {
      final datesRaw = json['khatmaDates'];
      List<String> dates;
      if (datesRaw == null) {
        dates = const [];
      } else if (datesRaw is List) {
        dates = [
          for (final d in datesRaw)
            if (d is String) d else throw const FormatException('wrong type'),
        ];
      } else {
        return null;
      }
      final owner = json['ownerId'];
      if (owner != null && owner is! String) return null;
      return WirdMarkerRecord(
        markerPage: nullableIntOf('markerPage'),
        startPage: intOf('startPage', 1),
        runningTotal: intOf('runningTotal', 0),
        khatmaCount: intOf('khatmaCount', 0),
        khatmaDates: dates,
        cycle: intOf('cycle', 0),
        version: intOf('version', 0),
        ownerId: owner as String?,
        color: nullableIntOf('color'),
      );
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is WirdMarkerRecord &&
      other.markerPage == markerPage &&
      other.startPage == startPage &&
      other.runningTotal == runningTotal &&
      other.khatmaCount == khatmaCount &&
      _sameList(other.khatmaDates, khatmaDates) &&
      other.cycle == cycle &&
      other.version == version &&
      other.ownerId == ownerId &&
      other.color == color;

  @override
  int get hashCode => Object.hash(markerPage, startPage, runningTotal,
      khatmaCount, Object.hashAll(khatmaDates), cycle, version, ownerId, color);

  @override
  String toString() =>
      'WirdMarkerRecord(page: $markerPage, start: $startPage, total: $runningTotal, '
      'khatmas: $khatmaCount, cycle: $cycle, version: $version, owner: $ownerId)';
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The one-step undo record. Local only (`wird_marker_undo`), never synced.
class WirdUndoRecord {
  final int previousPage;
  final int pagesAdded;

  /// Local date key (`YYYY-MM-DD`) of the move.
  final String dateKey;
  final bool grantedStreakCredit;
  final int cycle;

  /// `version` of the marker record right after the move. Undo is allowed only
  /// while the live record still has this `cycle` and `version`.
  final int versionAfterMove;

  const WirdUndoRecord({
    required this.previousPage,
    required this.pagesAdded,
    required this.dateKey,
    required this.grantedStreakCredit,
    required this.cycle,
    required this.versionAfterMove,
  });

  Map<String, dynamic> toJson() => {
        'previousPage': previousPage,
        'pagesAdded': pagesAdded,
        'dateKey': dateKey,
        'grantedStreakCredit': grantedStreakCredit,
        'cycle': cycle,
        'versionAfterMove': versionAfterMove,
      };

  /// Returns null for a non-map, a missing key or a wrongly typed value.
  static WirdUndoRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final previousPage = json['previousPage'];
    final pagesAdded = json['pagesAdded'];
    final dateKey = json['dateKey'];
    final granted = json['grantedStreakCredit'];
    final cycle = json['cycle'];
    final version = json['versionAfterMove'];
    if (previousPage is! int ||
        pagesAdded is! int ||
        dateKey is! String ||
        granted is! bool ||
        cycle is! int ||
        version is! int) {
      return null;
    }
    return WirdUndoRecord(
      previousPage: previousPage,
      pagesAdded: pagesAdded,
      dateKey: dateKey,
      grantedStreakCredit: granted,
      cycle: cycle,
      versionAfterMove: version,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WirdUndoRecord &&
      other.previousPage == previousPage &&
      other.pagesAdded == pagesAdded &&
      other.dateKey == dateKey &&
      other.grantedStreakCredit == grantedStreakCredit &&
      other.cycle == cycle &&
      other.versionAfterMove == versionAfterMove;

  @override
  int get hashCode => Object.hash(previousPage, pagesAdded, dateKey,
      grantedStreakCredit, cycle, versionAfterMove);
}

// ---------------------------------------------------------------------------
// Result and outcome types (spec: "Result and outcome types")
// ---------------------------------------------------------------------------

/// Why a pure function refused.
enum MarkerFailure {
  noMarker,
  markerExists,
  notForward,
  outOfRange,
  noUndo,
  staleDay,
  staleRecord,
}

/// Result of a pure function: a value or a failure.
sealed class MarkerResult<T> {
  const MarkerResult();
}

final class Ok<T> extends MarkerResult<T> {
  final T value;
  const Ok(this.value);
}

final class Err<T> extends MarkerResult<T> {
  final MarkerFailure failure;
  const Err(this.failure);
}

/// What `syncMarker` should do, returned by `decideSync`.
enum MarkerSyncDecision {
  nothing,
  claimAndPush,
  discardLocal,
  push,
  applyCloud,
  skipReadFailed,
  skipInvalidCloud,
}

/// Result of reading the cloud record (`WirdMarkerCloud.readServer`).
sealed class CloudRead {
  const CloudRead();
}

final class CloudReadFailed extends CloudRead {
  const CloudReadFailed();
}

final class CloudReadInvalid extends CloudRead {
  const CloudReadInvalid();
}

final class CloudReadAbsent extends CloudRead {
  const CloudReadAbsent();
}

final class CloudReadPresent extends CloudRead {
  final WirdMarkerRecord record;
  const CloudReadPresent(this.record);
}

/// Result of a guarded push (`WirdMarkerService.pushIfNewer`).
sealed class MarkerPushResult {
  const MarkerPushResult();
}

final class MarkerPushed extends MarkerPushResult {
  const MarkerPushed();
}

final class MarkerNotNewer extends MarkerPushResult {
  final WirdMarkerRecord cloudRecord;
  const MarkerNotNewer(this.cloudRecord);
}

/// Any error, including the 5 s timeout.
final class MarkerPushFailed extends MarkerPushResult {
  const MarkerPushFailed();
}

/// Result of `syncMarker`. [decision] is null and [localOnly] true when there
/// is no uid. [push] is null when nothing was written.
class MarkerSyncResult {
  final MarkerSyncDecision? decision;
  final MarkerPushResult? push;
  final bool localOnly;

  const MarkerSyncResult({this.decision, this.push}) : localOnly = false;
  const MarkerSyncResult.localOnly()
      : decision = null,
        push = null,
        localOnly = true;
}

sealed class MoveOutcome {
  const MoveOutcome();
}

final class Moved extends MoveOutcome {
  final int pagesAdded;
  final int markerPage;
  final bool grantedStreakCredit;
  const Moved({
    required this.pagesAdded,
    required this.markerPage,
    required this.grantedStreakCredit,
  });
}

final class MoveFailed extends MoveOutcome {
  final MarkerFailure failure;
  const MoveFailed(this.failure);
}

sealed class KhatmaOutcome {
  const KhatmaOutcome();
}

final class Completed extends KhatmaOutcome {
  final int pagesAdded;

  /// Combined total: legacy juz count plus the record's `khatmaCount`.
  final int khatmCount;
  const Completed({required this.pagesAdded, required this.khatmCount});
}

final class KhatmaFailed extends KhatmaOutcome {
  final MarkerFailure failure;
  const KhatmaFailed(this.failure);
}

sealed class PlaceOutcome {
  const PlaceOutcome();
}

final class Placed extends PlaceOutcome {
  const Placed();
}

final class PlaceFailed extends PlaceOutcome {
  final MarkerFailure failure;
  const PlaceFailed(this.failure);
}

sealed class UndoOutcome {
  const UndoOutcome();
}

final class UndoDone extends UndoOutcome {
  const UndoDone();
}

final class UndoCloudNewer extends UndoOutcome {
  const UndoCloudNewer();
}

final class UndoNeedsConnection extends UndoOutcome {
  const UndoNeedsConnection();
}

final class UndoFailed extends UndoOutcome {
  final MarkerFailure failure;
  const UndoFailed(this.failure);
}
