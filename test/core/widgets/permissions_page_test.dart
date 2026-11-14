// Spec: docs/designs/permissions-status-screen.md (phase PS1). The page in both modes.
// Without EasyLocalization `.tr()` shows the key, so tests look for keys; the page's
// older English literals ('Enable', 'Granted', 'Later', ...) are matched as they are.
import 'package:aura_app/core/widgets/permission_dialog.dart';
import 'package:aura_app/core/widgets/permission_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import 'fake_permission_probe.dart';


/// flutter_test draws text with the Ahem font, whose glyphs are as wide as they are
/// tall (about twice a real font), so long labels overflow a 360 dp row. Half scale
/// gives realistic widths. A real-font check is device-only.
void _realisticText(WidgetTester tester) {
  tester.platformDispatcher.textScaleFactorTestValue = 0.5;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Opens the show-everything page through the public wrapper, with [p] as the probe.
Future<void> _openAll(
  WidgetTester tester,
  FakePermissionProbe p, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(360, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  _realisticText(tester);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showPermissionsStatusPage(context, probe: p),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Pushes the popup-mode page (only the missing rows) for [p].
Future<void> _openPopup(
  WidgetTester tester,
  FakePermissionProbe p, {
  bool hint = false,
}) async {
  tester.view.physicalSize = const Size(360, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  _realisticText(tester);
  final rows = (await tester.runAsync(() => buildPermissionRows(p, showAll: false)))!;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PermissionsPage(rows: rows, showAutoLaunchHint: hint),
              fullscreenDialog: true,
            )),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _resume(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

void main() {
  group('show-everything mode', () {
    testWidgets('has a back arrow, the page title, and one row per applicable permission',
        (tester) async {
      final p = FakePermissionProbe()..battery = false;
      await _openAll(tester, p);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.text('permissions_page_title_all'), findsOneWidget);
      expect(find.text('Later'), findsNothing);
      // Six readable rows: battery missing, the other five granted.
      expect(find.text('Granted'), findsNWidgets(5));
      expect(find.text('Enable'), findsOneWidget);
    });

    testWidgets('summary: all set, with no check-by-hand row', (tester) async {
      await _openAll(tester, FakePermissionProbe());
      expect(find.text('permissions_all_set'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('summary: all set plus one item to check by hand on EMUI', (tester) async {
      await _openAll(tester, FakePermissionProbe()..emui = true);
      expect(find.text('permissions_all_set_plus_hand'), findsOneWidget);
      expect(find.text('permissions_all_set'), findsNothing);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('summary: some permissions are missing', (tester) async {
      await _openAll(tester, FakePermissionProbe()..location = false);
      expect(find.text('permissions_some_missing'), findsOneWidget);
      expect(find.text('Enable All'), findsOneWidget);
    });

    testWidgets('the Auto-launch row says check by hand, is never Granted, opens the guide',
        (tester) async {
      final p = FakePermissionProbe()..emui = true;
      await _openAll(tester, p);
      expect(find.text('permissions_check_by_hand'), findsOneWidget);
      expect(find.text('Granted'), findsNWidgets(6), reason: 'six readable rows only');
      await tester.tap(find.text('permissions_check_by_hand_button'));
      await tester.pumpAndSettle();
      expect(p.calls.where((c) => c == 'showAutoLaunchGuide'), hasLength(1));
    });

    testWidgets('no Auto-launch row off EMUI', (tester) async {
      await _openAll(tester, FakePermissionProbe());
      expect(find.text('permissions_check_by_hand'), findsNothing);
      expect(find.text('auto_launch_title'), findsNothing);
    });

    testWidgets('resume rechecks every row: granted can become missing and back',
        (tester) async {
      final p = FakePermissionProbe();
      await _openAll(tester, p);
      expect(find.text('Enable'), findsNothing);
      p.notifications = false;
      await _resume(tester);
      expect(find.text('Enable'), findsOneWidget);
      expect(find.text('permissions_some_missing'), findsOneWidget);
      p.notifications = true;
      await _resume(tester);
      expect(find.text('Enable'), findsNothing);
      expect(find.text('permissions_all_set'), findsOneWidget);
    });

    testWidgets('Enable that ends not granted opens app settings and shows the denied hint',
        (tester) async {
      final p = FakePermissionProbe()
        ..notifications = false
        ..notificationRequestResult = PermissionStatus.permanentlyDenied;
      await _openAll(tester, p);
      expect(find.text('permissions_denied_hint'), findsNothing,
          reason: 'not before an attempt');
      await tester.tap(find.text('Enable'));
      await tester.pump();
      // The page waits 1 s after opening settings before it rechecks.
      await tester.pump(const Duration(seconds: 2));
      expect(p.calls, ['requestNotification', 'openAppSettings']);
      expect(find.text('permissions_denied_hint'), findsOneWidget);
    });

    testWidgets('Enable that grants shows no denied hint', (tester) async {
      final p = FakePermissionProbe()
        ..location = false
        ..locationRequestResult = PermissionStatus.granted;
      await _openAll(tester, p);
      await tester.tap(find.text('Enable'));
      await tester.pumpAndSettle();
      expect(p.calls, ['requestLocation']);
      expect(find.text('permissions_denied_hint'), findsNothing);
      expect(find.text('Enable'), findsNothing);
    });

    testWidgets('a granted row never shows the denied hint', (tester) async {
      await _openAll(tester, FakePermissionProbe());
      expect(find.text('permissions_denied_hint'), findsNothing);
    });

    testWidgets('fits 360 dp in Arabic (RTL) without overflow', (tester) async {
      await _openAll(tester, FakePermissionProbe()..emui = true..location = false,
          locale: const Locale('ar'));
      expect(find.byType(PermissionsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('popup mode (unchanged behavior)', () {
    testWidgets('keeps its title, header text, no back arrow, and the Later button',
        (tester) async {
      final p = FakePermissionProbe()..exactAlarm = false..battery = false;
      await _openPopup(tester, p);
      expect(find.byType(BackButton), findsNothing);
      expect(find.text('Required Permissions'), findsOneWidget);
      expect(find.text('Aura needs these permissions to work properly'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Enable All'), findsOneWidget);
      expect(find.text('permissions_page_title_all'), findsNothing);
    });

    testWidgets('resume only rechecks rows that are not granted yet', (tester) async {
      final p = FakePermissionProbe()..battery = false..dnd = false;
      await _openPopup(tester, p);
      expect(find.text('Enable'), findsNWidgets(2));
      p.battery = true; // the user granted it in system settings
      await _resume(tester);
      expect(find.text('Granted'), findsOneWidget);
      p.battery = false; // revoked again: a granted row is not rechecked in popup mode
      await _resume(tester);
      expect(find.text('Granted'), findsOneWidget);
    });

    testWidgets('the Auto-launch hint row still shows when asked', (tester) async {
      final p = FakePermissionProbe()..battery = false;
      await _openPopup(tester, p, hint: true);
      expect(find.text('auto_launch_title'), findsOneWidget);
    });
  });
}
