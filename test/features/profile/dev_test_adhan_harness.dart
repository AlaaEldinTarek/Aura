import 'package:aura_app/features/profile/profile_version_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared host for the dev-test-adhan widget tests (docs/designs/dev-test-adhan.md).
const kVersionTitle = 'Version';
const kVersionValue = '1.1.0+60';
const kFireTitle = 'dev_test_adhan_title';

/// Hosts [ProfileVersionTile] on a 360 x 640 surface (nova 5T width).
Future<void> pumpTile(
  WidgetTester tester, {
  Future<void> Function(String)? fire,
  Future<bool> Function()? canSchedule,
  Locale locale = const Locale('en'),
  Key? tileKey,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    home: Scaffold(
      body: SingleChildScrollView(
        child: ProfileVersionTile(
          key: tileKey,
          title: kVersionTitle,
          version: kVersionValue,
          fireTestAdhan: fire ?? (_) async {},
          canScheduleExactAlarms: canSchedule ?? () async => true,
        ),
      ),
    ),
  ));
}

Future<void> tapVersion(WidgetTester tester, int times) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.text(kVersionTitle));
    await tester.pump();
  }
}

/// Hosts the tile with the post-check dev item (docs/designs/fix-post-check-remind-later.md).
Future<void> pumpTileWithPostCheck(
  WidgetTester tester, {
  required Future<void> Function() firePostCheck,
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
          firePostCheck: firePostCheck,
        ),
      ),
    ),
  ));
}
