import 'package:aura_app/core/utils/legacy_jumuah.dart';
import 'package:flutter_test/flutter_test.dart';

/// T1-T4 (F7): id 7001 is the native Daily Prayer Reminder card. A leftover flutter_local_notifications alarm with that
/// id (armed by a build older than 1.1.0) is cancelled only when it really is pending; otherwise nothing is cancelled,
/// so the showing card survives an app start and both Jumu'ah toggles.
void main() {
  const id = 7001;

  test('T1: 7001 not pending: cancel is never called, returns false', () async {
    final cancelled = <int>[];
    final result = await cancelLegacyJumuahAlarmIfPending(
      pendingIds: () async => [1, 5100, 4001],
      cancel: (i) async => cancelled.add(i),
      id: id,
    );
    expect(result, isFalse);
    expect(cancelled, isEmpty);
  });

  test('T2: 7001 pending: cancelled once with 7001, returns true', () async {
    final cancelled = <int>[];
    final result = await cancelLegacyJumuahAlarmIfPending(
      pendingIds: () async => [1, 7001, 5100],
      cancel: (i) async => cancelled.add(i),
      id: id,
    );
    expect(result, isTrue);
    expect(cancelled, [7001]);
  });

  test(
      'T3: a failing lookup or cancel does not throw and cancels nothing extra',
      () async {
    final cancelled = <int>[];
    final lookupFails = await cancelLegacyJumuahAlarmIfPending(
      pendingIds: () async => throw StateError('plugin not ready'),
      cancel: (i) async => cancelled.add(i),
      id: id,
    );
    expect(lookupFails, isFalse);
    expect(cancelled, isEmpty);

    final cancelFails = await cancelLegacyJumuahAlarmIfPending(
      pendingIds: () async => [7001],
      cancel: (i) async => throw StateError('cancel failed'),
      id: id,
    );
    expect(cancelFails, isFalse);
  });

  test(
      'T4: app start, toggle on, toggle off with nothing pending: cancel is never called',
      () async {
    final cancelled = <int>[];
    for (var i = 0; i < 3; i++) {
      await cancelLegacyJumuahAlarmIfPending(
        pendingIds: () async => <int>[],
        cancel: (x) async => cancelled.add(x),
        id: id,
      );
    }
    expect(cancelled, isEmpty);
  });

  test('hasLegacyJumuahAlarm matches only the exact id', () {
    expect(hasLegacyJumuahAlarm([7001], 7001), isTrue);
    expect(hasLegacyJumuahAlarm([7000, 7002, 8001], 7001), isFalse);
  });
}
