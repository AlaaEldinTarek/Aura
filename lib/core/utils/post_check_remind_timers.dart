import 'dart:async';

/// One-shot "Remind Later" timers for the Windows post-prayer check toast
/// (docs/designs/fix-post-check-remind-later.md). One pending timer per prayer: a second tap
/// replaces the first. Kept apart from the adhan / reminder timers so rescheduling those never
/// cancels a pending Remind Later.
class PostCheckRemindTimers {
  static const Duration defaultDelay = Duration(minutes: 15);

  final Duration delay;
  final Map<String, Timer> _timers = {};

  PostCheckRemindTimers({this.delay = defaultDelay});

  int get pendingCount => _timers.length;

  /// Starts (or restarts) the timer for [prayerKey]; [onFire] runs once after [delay].
  void schedule(String prayerKey, void Function() onFire) {
    _timers.remove(prayerKey)?.cancel();
    _timers[prayerKey] = Timer(delay, () {
      _timers.remove(prayerKey);
      onFire();
    });
  }

  void cancelAll() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }
}
