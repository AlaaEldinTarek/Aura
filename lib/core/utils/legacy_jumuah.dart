import 'package:flutter/foundation.dart';

/// True when [pendingIds] (the ids flutter_local_notifications still has scheduled) contains [id].
///
/// Id 7001 is the native Daily Prayer Reminder card. Builds older than 1.1.0 scheduled the Jumu'ah reminder through
/// flutter_local_notifications under the same id, so a leftover alarm may still be armed. Cancelling by id would also
/// remove the native card while it is showing, so it is only cancelled when such a leftover really is pending.
bool hasLegacyJumuahAlarm(Iterable<int> pendingIds, int id) =>
    pendingIds.contains(id);

/// Cancels the leftover plugin alarm with [id] only if [pendingIds] lists it. Never throws; returns true only when a
/// cancel was issued. `pendingNotificationRequests()` lists plugin-scheduled entries only, never the native card.
Future<bool> cancelLegacyJumuahAlarmIfPending({
  required Future<Iterable<int>> Function() pendingIds,
  required Future<void> Function(int id) cancel,
  required int id,
}) async {
  try {
    final pending = await pendingIds();
    if (!hasLegacyJumuahAlarm(pending, id)) return false;
    await cancel(id);
    return true;
  } catch (e) {
    debugPrint('⚠️ [JUMUA] Legacy alarm cleanup skipped: $e');
    return false;
  }
}
