/// True when [pendingIds] (the ids flutter_local_notifications still has scheduled) contains the daily task digest.
///
/// The digest is now delivered by the native receiver (same id 4001). Older builds scheduled it with
/// flutter_local_notifications, so a leftover alarm may still be armed. Cancelling by id would also remove a digest card
/// that is showing, so it is only cancelled when such a leftover really exists (once, then never again).
bool hasLegacyDigestAlarm(Iterable<int> pendingIds, int digestId) => pendingIds.contains(digestId);
