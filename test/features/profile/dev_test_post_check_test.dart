import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dev_test_adhan_harness.dart';

const _kPostCheckTitle = 'dev_test_post_check_title';

/// Spec: docs/designs/fix-post-check-remind-later.md (Test post-check in the hidden dev tile,
/// same visibility rule as the test adhan: 7 taps, release builds included, no confirm dialog).
void main() {
  testWidgets('hidden before 7 taps, shown after 7 (same rule as the test adhan)',
      (tester) async {
    await pumpTileWithPostCheck(tester, firePostCheck: () async {});
    expect(find.text(_kPostCheckTitle), findsNothing);
    await tapVersion(tester, 6);
    expect(find.text(_kPostCheckTitle), findsNothing);
    await tapVersion(tester, 1);
    expect(find.text(_kPostCheckTitle), findsOneWidget);
    expect(find.text(kFireTitle), findsOneWidget);
  });

  testWidgets('a tap calls the function once, with no confirm dialog',
      (tester) async {
    var calls = 0;
    await pumpTileWithPostCheck(tester, firePostCheck: () async => calls++);
    await tapVersion(tester, 7);
    await tester.tap(find.text(_kPostCheckTitle));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('without a post-check function the item is not shown',
      (tester) async {
    await pumpTile(tester);
    await tapVersion(tester, 7);
    expect(find.text(_kPostCheckTitle), findsNothing);
    expect(find.text(kFireTitle), findsOneWidget);
  });

  testWidgets('fits 360 dp in Arabic (RTL) without overflow', (tester) async {
    await pumpTileWithPostCheck(tester,
        firePostCheck: () async {}, locale: const Locale('ar'));
    await tapVersion(tester, 7);
    expect(find.text(_kPostCheckTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
