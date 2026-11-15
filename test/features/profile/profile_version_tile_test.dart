import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dev_test_adhan_harness.dart';

void main() {
  testWidgets('shows the version and hides the dev tile and chevron',
      (tester) async {
    await pumpTile(tester);
    expect(find.text(kVersionTitle), findsOneWidget);
    expect(find.text(kVersionValue), findsOneWidget);
    expect(find.text(kFireTitle), findsNothing);
    // The Version tile had no chevron before the tap counter; keep it so.
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });

  testWidgets('6 taps do not reveal the tile', (tester) async {
    await pumpTile(tester);
    await tapVersion(tester, 6);
    expect(find.text(kFireTitle), findsNothing);
  });

  testWidgets('7 taps reveal the tile; more taps keep exactly one',
      (tester) async {
    await pumpTile(tester);
    await tapVersion(tester, 7);
    expect(find.text(kFireTitle), findsOneWidget);
    await tapVersion(tester, 3);
    expect(find.text(kFireTitle), findsOneWidget);
  });

  testWidgets('a rebuilt tile (new visit) is hidden again', (tester) async {
    await pumpTile(tester, tileKey: const ValueKey('a'));
    await tapVersion(tester, 7);
    expect(find.text(kFireTitle), findsOneWidget);
    await pumpTile(tester, tileKey: const ValueKey('b'));
    expect(find.text(kFireTitle), findsNothing);
  });

  testWidgets('unlocked tile fits 360 dp in Arabic (RTL) without overflow',
      (tester) async {
    await pumpTile(tester, locale: const Locale('ar'));
    await tapVersion(tester, 7);
    expect(find.text(kFireTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
