/// Pure functions for the Wird marker (spec: docs/designs/wird-marker.md, item 2).
///
/// No SharedPreferences, no Firebase and no `DateTime.now()`: callers pass the
/// date as a `YYYY-MM-DD` string, so tests control the clock. The section
/// "Behavior when there is no marker" in the spec is the contract for a null
/// record and for a record whose `markerPage` is null.
library;

import '../models/wird.dart';
import '../models/wird_marker.dart';

/// Last page of the mushaf. The one definition of the number 604.
const int kLastQuranPage = 604;

final RegExp _dateKeyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
const int _maxColor = 0xFFFFFFFF;

/// A record with nothing in it: no marker, no owner, cycle 0, version 0.
WirdMarkerRecord empty() => const WirdMarkerRecord();

/// Orders two records by (cycle, version). A null record is the lowest.
/// Returns -1, 0 or 1.
int compare(WirdMarkerRecord? a, WirdMarkerRecord? b) {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  if (a.cycle != b.cycle) return a.cycle < b.cycle ? -1 : 1;
  if (a.version != b.version) return a.version < b.version ? -1 : 1;
  return 0;
}

/// True when every field of [r] is in range. Does not check the owner.
bool validate(WirdMarkerRecord r) {
  final page = r.markerPage;
  if (page != null) {
    if (page < 1 || page > kLastQuranPage) return false;
    if (r.startPage < 1 || r.startPage > page) return false;
  }
  if (r.runningTotal < 0 || r.khatmaCount < 0) return false;
  if (r.cycle < 0 || r.version < 0) return false;
  for (final d in r.khatmaDates) {
    if (!_dateKeyPattern.hasMatch(d)) return false;
  }
  final color = r.color;
  if (color != null && (color < 0 || color > _maxColor)) return false;
  return true;
}

/// [validate] plus: the record belongs to [uid].
bool validateCloud(WirdMarkerRecord r, String uid) =>
    validate(r) && r.ownerId == uid;

/// Pages read in total, derived from the record. 0 with no record.
int progressTotal(WirdMarkerRecord? r) {
  if (r == null) return 0;
  final page = r.markerPage;
  if (page == null) return r.runningTotal;
  return r.runningTotal + (page - r.startPage);
}

/// Places the marker on [page]. Works only when no marker exists (no record,
/// or a record whose marker page is null, which is the state after Restart).
MarkerResult<WirdMarkerRecord> applySetup(
    WirdMarkerRecord? r, int page, int color, String? ownerId) {
  if (r != null && r.markerPage != null) {
    return const Err(MarkerFailure.markerExists);
  }
  final base = r ?? empty();
  return Ok(base.copyWith(
    markerPage: page,
    startPage: page,
    color: color,
    ownerId: ownerId,
    clearOwnerId: ownerId == null,
    version: base.version + 1,
  ));
}

/// Moves the marker forward to [target]. [today] is part of the contract so
/// every function takes the date the same way; a move does not use it.
MarkerResult<({WirdMarkerRecord record, int pagesAdded})> applyMove(
    WirdMarkerRecord? r, int target, String today) {
  final page = r?.markerPage;
  if (r == null || page == null) return const Err(MarkerFailure.noMarker);
  if (target <= page) return const Err(MarkerFailure.notForward);
  if (target > kLastQuranPage) return const Err(MarkerFailure.outOfRange);
  return Ok((
    record: r.copyWith(markerPage: target, version: r.version + 1),
    pagesAdded: target - page,
  ));
}

/// True when a move adds more pages than the daily goal (ask first).
bool needsBigMoveConfirm(int pagesAdded, int dailyGoal) =>
    pagesAdded > dailyGoal;

/// Pages the "Complete khatma?" prompt counts: from the marker page to 604.
int khatmaPages(WirdMarkerRecord r) => kLastQuranPage - (r.markerPage ?? 0) + 1;

/// Completes a khatma: the marker returns to page 1 and a new cycle starts.
/// The color is kept. [pagesAdded] is the page count of the closing move.
MarkerResult<({WirdMarkerRecord record, int pagesAdded})> applyKhatma(
    WirdMarkerRecord? r, String today) {
  if (r == null || r.markerPage == null) {
    return const Err(MarkerFailure.noMarker);
  }
  return Ok((
    record: r.copyWith(
      markerPage: 1,
      startPage: 1,
      runningTotal: r.runningTotal + (kLastQuranPage - r.startPage + 1),
      khatmaCount: r.khatmaCount + 1,
      khatmaDates: [...r.khatmaDates, today],
      cycle: r.cycle + 1,
      version: r.version + 1,
    ),
    pagesAdded: khatmaPages(r),
  ));
}

/// Restart Wird and Reset All Progress. Never fails and always bumps the cycle
/// and the version, even when the record is already empty. With no record it
/// returns a tombstone at cycle 1 owned by [ownerId].
WirdMarkerRecord applyRestart(WirdMarkerRecord? r, String? ownerId) {
  final base = r ?? empty().copyWith(ownerId: ownerId);
  return base.copyWith(
    clearMarkerPage: true,
    clearColor: true,
    runningTotal: 0,
    khatmaCount: 0,
    khatmaDates: const [],
    cycle: base.cycle + 1,
    version: base.version + 1,
  );
}

/// Undoes the last move if the live record is still the one the move made.
MarkerResult<WirdMarkerRecord> applyUndo(
    WirdMarkerRecord? r, WirdUndoRecord? undo, String today) {
  if (undo == null) return const Err(MarkerFailure.noUndo);
  if (r == null || r.markerPage == null) {
    return const Err(MarkerFailure.staleRecord);
  }
  if (undo.dateKey != today) return const Err(MarkerFailure.staleDay);
  if (r.cycle != undo.cycle || r.version != undo.versionAfterMove) {
    return const Err(MarkerFailure.staleRecord);
  }
  return Ok(r.copyWith(markerPage: undo.previousPage, version: r.version + 1));
}

/// Remove today's streak credit on undo only when that move granted it and
/// today is now below the goal.
bool shouldRemoveStreakCredit(
        WirdUndoRecord? undo, int todayPagesAfter, int dailyGoal) =>
    undo != null && undo.grantedStreakCredit && todayPagesAfter < dailyGoal;

/// What `syncMarker` should do with this local record and this cloud read.
MarkerSyncDecision decideSync(
    WirdMarkerRecord? local, CloudRead cloudRead, String uid) {
  switch (cloudRead) {
    case CloudReadFailed():
      return MarkerSyncDecision.skipReadFailed;
    case CloudReadInvalid():
      return MarkerSyncDecision.skipInvalidCloud;
    case CloudReadAbsent():
      if (local == null) return MarkerSyncDecision.nothing;
      if (local.ownerId == null) return MarkerSyncDecision.claimAndPush;
      if (local.ownerId != uid) return MarkerSyncDecision.discardLocal;
      return MarkerSyncDecision.push;
    case CloudReadPresent(record: final cloud):
      if (local == null || local.ownerId != uid) {
        return MarkerSyncDecision.applyCloud;
      }
      return compare(local, cloud) > 0
          ? MarkerSyncDecision.push
          : MarkerSyncDecision.applyCloud;
  }
}

/// Legacy (juz-mode) khatmas plus the record's, dates sorted ascending.
({int count, List<String> dates}) mergeKhatmas(
    int legacyCount, List<String> legacyDates, WirdMarkerRecord? r) {
  final dates = [...legacyDates, ...?r?.khatmaDates]..sort();
  return (count: legacyCount + (r?.khatmaCount ?? 0), dates: dates);
}

/// Average pages (page mode) or juz (juz mode) per completed day. 0.0 when no
/// day is completed.
double averagePerCompletedDay({
  required WirdUnit unit,
  required int progressTotal,
  required int juzKhatmCount,
  required int checkedJuzCount,
  required int totalDaysCompleted,
}) {
  if (totalDaysCompleted <= 0) return 0.0;
  final amount = unit == WirdUnit.page
      ? progressTotal
      : juzKhatmCount * 30 + checkedJuzCount;
  return amount / totalDaysCompleted;
}

/// Builds the state the UI shows from the service state, the marker record and
/// the undo record. An undo record that is not for today or not for the live
/// record is dropped, so the UI never offers an undo that cannot run.
WirdState composeWirdState(WirdState base, WirdMarkerRecord? record,
    WirdUndoRecord? undo, String today) {
  final validUndo = (undo != null &&
          record != null &&
          undo.dateKey == today &&
          undo.cycle == record.cycle &&
          undo.versionAfterMove == record.version)
      ? undo
      : null;
  final merged = mergeKhatmas(base.khatmCount, base.khatmDates, record);
  return base.copyWith(
    marker: record,
    clearMarker: record == null,
    undo: validUndo,
    clearUndo: validUndo == null,
    juzKhatmCount: base.khatmCount,
    totalPagesRead: progressTotal(record),
    khatmCount: merged.count,
    khatmDates: merged.dates,
  );
}
