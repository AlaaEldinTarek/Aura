// Spec: docs/designs/permissions-status-screen.md (phase PS1). The pure rules: which
// rows exist in which mode, their states, the recheck, and the summary.
import 'package:aura_app/core/widgets/permission_rows.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_permission_probe.dart';

List<PermId> _ids(List<PermRow> rows) => rows.map((r) => r.id).toList();

PermRow _row(List<PermRow> rows, PermId id) => rows.firstWhere((r) => r.id == id);

void main() {
  group('popup mode (showAll: false), unchanged from today', () {
    test('empty when the four checks are all granted', () async {
      final p = FakePermissionProbe();
      expect(await buildPermissionRows(p, showAll: false), isEmpty);
    });

    test('only the missing ones of exact alarm, battery, DND, overlay', () async {
      final p = FakePermissionProbe()
        ..exactAlarm = false
        ..battery = false
        ..dnd = false
        ..overlay = false;
      final rows = await buildPermissionRows(p, showAll: false);
      expect(_ids(rows),
          [PermId.exactAlarm, PermId.battery, PermId.dnd, PermId.overlay]);
      expect(rows.every((r) => r.state == PermState.missing), isTrue);
    });

    test('never lists Notifications, Location or Auto-launch', () async {
      final p = FakePermissionProbe()
        ..notifications = false
        ..location = false
        ..emui = true;
      expect(await buildPermissionRows(p, showAll: false), isEmpty);
    });

    test('the overlay row is skipped in prayer_only mode and off Android', () async {
      final p = FakePermissionProbe()..overlay = false;
      p.mode = 'prayer_only';
      expect(await buildPermissionRows(p, showAll: false), isEmpty);
      p.mode = 'both';
      p.isAndroid = false;
      expect(await buildPermissionRows(p, showAll: false), isEmpty);
      p.isAndroid = true;
      expect(_ids(await buildPermissionRows(p, showAll: false)), [PermId.overlay]);
    });
  });

  group('show-everything mode (showAll: true)', () {
    test('lists every applicable row, granted or not, and no other id', () async {
      final p = FakePermissionProbe()..emui = true;
      final rows = await buildPermissionRows(p, showAll: true);
      expect(_ids(rows), [
        PermId.exactAlarm,
        PermId.battery,
        PermId.dnd,
        PermId.overlay,
        PermId.notifications,
        PermId.location,
        PermId.autoLaunch,
      ]);
      // No full-screen-intent and no storage row exist at all.
      expect(PermId.values.length, 7);
    });

    test('the exact-alarm row is always built; it reads granted when the probe does',
        () async {
      // Below Android 12 the native check returns true, so the row reads Granted.
      final p = FakePermissionProbe()..exactAlarm = true;
      final rows = await buildPermissionRows(p, showAll: true);
      expect(_row(rows, PermId.exactAlarm).state, PermState.granted);
      p.exactAlarm = false;
      final rows2 = await buildPermissionRows(p, showAll: true);
      expect(_row(rows2, PermId.exactAlarm).state, PermState.missing);
    });

    test('each row state follows its probe value', () async {
      final p = FakePermissionProbe()
        ..battery = false
        ..dnd = false
        ..overlay = true
        ..notifications = false
        ..location = true;
      final rows = await buildPermissionRows(p, showAll: true);
      expect(_row(rows, PermId.battery).state, PermState.missing);
      expect(_row(rows, PermId.dnd).state, PermState.missing);
      expect(_row(rows, PermId.overlay).state, PermState.granted);
      expect(_row(rows, PermId.notifications).state, PermState.missing);
      expect(_row(rows, PermId.location).state, PermState.granted);
    });

    test('Location is hidden in tasks_only mode, Overlay in prayer_only mode',
        () async {
      final p = FakePermissionProbe()..mode = 'tasks_only';
      var ids = _ids(await buildPermissionRows(p, showAll: true));
      expect(ids.contains(PermId.location), isFalse);
      expect(ids.contains(PermId.overlay), isTrue);
      expect(ids.contains(PermId.notifications), isTrue);
      p.mode = 'prayer_only';
      ids = _ids(await buildPermissionRows(p, showAll: true));
      expect(ids.contains(PermId.location), isTrue);
      expect(ids.contains(PermId.overlay), isFalse);
      p.mode = 'both';
      ids = _ids(await buildPermissionRows(p, showAll: true));
      expect(ids.contains(PermId.location), isTrue);
      expect(ids.contains(PermId.overlay), isTrue);
    });

    test('the Auto-launch row exists only on EMUI and is never granted', () async {
      final p = FakePermissionProbe()..emui = false;
      expect(_ids(await buildPermissionRows(p, showAll: true)).contains(PermId.autoLaunch),
          isFalse);
      p.emui = true;
      final row = _row(await buildPermissionRows(p, showAll: true), PermId.autoLaunch);
      expect(row.state, PermState.checkByHand);
      expect(await row.recheck(), PermState.checkByHand);
    });

    test('the DND row sits in Focus Mode when tasks are in the mode, else Prayer',
        () async {
      final p = FakePermissionProbe();
      var rows = await buildPermissionRows(p, showAll: true);
      expect(_row(rows, PermId.dnd).group, PermGroup.focusMode);
      p.mode = 'prayer_only';
      rows = await buildPermissionRows(p, showAll: true);
      expect(_row(rows, PermId.dnd).group, PermGroup.prayer);
    });

    test('only Notifications and Location explain a permanent denial', () async {
      final p = FakePermissionProbe()..emui = true;
      final rows = await buildPermissionRows(p, showAll: true);
      for (final r in rows) {
        expect(r.explainsDenial,
            r.id == PermId.notifications || r.id == PermId.location,
            reason: r.id.name);
      }
    });
  });

  group('recheck', () {
    test('a row re-reads its probe value', () async {
      final p = FakePermissionProbe()..notifications = false;
      final row = _row(await buildPermissionRows(p, showAll: true), PermId.notifications);
      expect(row.state, PermState.missing);
      p.notifications = true;
      expect(await row.recheck(), PermState.granted);
      p.notifications = false;
      expect(await row.recheck(), PermState.missing);
    });
  });

  group('summary', () {
    test('all granted gives allSet', () {
      expect(summarizePermissions([PermState.granted, PermState.granted]),
          PermSummary.allSet);
      expect(summarizePermissions([]), PermSummary.allSet);
    });

    test('all granted plus a check-by-hand row gives allSetPlusHand', () {
      expect(
          summarizePermissions(
              [PermState.granted, PermState.checkByHand, PermState.granted]),
          PermSummary.allSetPlusHand);
    });

    test('a check-by-hand row alone never gives allSet', () {
      expect(summarizePermissions([PermState.checkByHand]),
          PermSummary.allSetPlusHand);
    });

    test('any missing row wins', () {
      expect(
          summarizePermissions(
              [PermState.granted, PermState.missing, PermState.checkByHand]),
          PermSummary.someMissing);
    });
  });
}
