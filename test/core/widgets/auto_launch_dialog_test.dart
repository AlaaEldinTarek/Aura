// Spec: docs/designs/fix-boot-start-service.md, section 3a and phase P1b. The
// explanation dialog the "App launch" tile and the permissions-page hint open.
// Without EasyLocalization the keys are shown as text, so the tests look for keys.
import 'package:aura_app/core/widgets/auto_launch_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _title = 'auto_launch_dialog_title';
const _body = 'auto_launch_dialog_body';
const _openDetails = 'auto_launch_dialog_open_details';

Future<void> _pump(
  WidgetTester tester, {
  required Future<void> Function() openDetails,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () =>
                showAutoLaunchDialog(context, openDetails: openDetails),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the title, the body and both buttons', (tester) async {
    await _pump(tester, openDetails: () async {});
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(_title), findsOneWidget);
    expect(find.text(_body), findsOneWidget);
    expect(find.text(_openDetails), findsOneWidget);
    expect(find.text('ok'), findsOneWidget);
  });

  testWidgets('Open app details calls the callback once and keeps the dialog',
      (tester) async {
    var opened = 0;
    await _pump(tester, openDetails: () async => opened++);
    await tester.tap(find.text(_openDetails));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.byType(AlertDialog), findsOneWidget,
        reason: 'the text must stay readable after coming back');
  });

  testWidgets('OK closes the dialog without opening anything', (tester) async {
    var opened = 0;
    await _pump(tester, openDetails: () async => opened++);
    await tester.tap(find.text('ok'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(opened, 0);
  });

  testWidgets('fits 360 dp in Arabic (RTL) without overflow', (tester) async {
    await _pump(tester,
        openDetails: () async {}, locale: const Locale('ar'));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
