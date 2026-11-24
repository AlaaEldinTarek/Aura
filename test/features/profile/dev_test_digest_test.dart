import 'package:aura_app/features/profile/profile_version_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dev_test_adhan_harness.dart';

const _kDigestTitle = 'dev_test_digest_title';

Future<void> _pump(
  WidgetTester tester, {
  Future<void> Function()? fireDigest,
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
          fireDigest: fireDigest,
        ),
      ),
    ),
  ));
}

/// T4: "Test digest" in the hidden dev tile (7 taps on Version), like "Test post-check": dev only, no confirm.
void main() {
  testWidgets('hidden before 7 taps, shown after 7', (tester) async {
    await _pump(tester, fireDigest: () async {});
    expect(find.text(_kDigestTitle), findsNothing);
    await tapVersion(tester, 6);
    expect(find.text(_kDigestTitle), findsNothing);
    await tapVersion(tester, 1);
    expect(find.text(_kDigestTitle), findsOneWidget);
  });

  testWidgets('a tap calls the function once, with no confirm dialog',
      (tester) async {
    var calls = 0;
    await _pump(tester, fireDigest: () async => calls++);
    await tapVersion(tester, 7);
    await tester.tap(find.text(_kDigestTitle));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('without a digest function the item is not shown',
      (tester) async {
    await _pump(tester);
    await tapVersion(tester, 7);
    expect(find.text(_kDigestTitle), findsNothing);
  });

  testWidgets('fits 360 dp in Arabic (RTL) without overflow', (tester) async {
    await _pump(tester, fireDigest: () async {}, locale: const Locale('ar'));
    await tapVersion(tester, 7);
    expect(find.text(_kDigestTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
