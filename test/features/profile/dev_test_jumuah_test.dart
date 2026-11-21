import 'package:aura_app/features/profile/profile_version_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dev_test_adhan_harness.dart';

const _kJumuahTitle = 'dev_test_jumuah_title';

Future<void> _pump(
  WidgetTester tester, {
  Future<void> Function()? fireJumuah,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    home: Scaffold(
      body: SingleChildScrollView(
        child: ProfileVersionTile(
          title: kVersionTitle,
          version: kVersionValue,
          fireTestAdhan: (_) async {},
          canScheduleExactAlarms: () async => true,
          fireJumuah: fireJumuah,
        ),
      ),
    ),
  ));
}

/// T7: "Test Jumu'ah" in the hidden dev tile (7 taps on Version): dev only, no confirm, any day of the week.
void main() {
  testWidgets('hidden before 7 taps, shown after 7', (tester) async {
    await _pump(tester, fireJumuah: () async {});
    expect(find.text(_kJumuahTitle), findsNothing);
    await tapVersion(tester, 6);
    expect(find.text(_kJumuahTitle), findsNothing);
    await tapVersion(tester, 1);
    expect(find.text(_kJumuahTitle), findsOneWidget);
  });

  testWidgets('a tap calls the function once, with no confirm dialog',
      (tester) async {
    var calls = 0;
    await _pump(tester, fireJumuah: () async => calls++);
    await tapVersion(tester, 7);
    await tester.tap(find.text(_kJumuahTitle));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('without a Jumu\'ah function the item is not shown',
      (tester) async {
    await _pump(tester);
    await tapVersion(tester, 7);
    expect(find.text(_kJumuahTitle), findsNothing);
  });

  testWidgets('fits 360 dp in Arabic (RTL) without overflow', (tester) async {
    await _pump(tester, fireJumuah: () async {}, locale: const Locale('ar'));
    await tapVersion(tester, 7);
    expect(find.text(_kJumuahTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
