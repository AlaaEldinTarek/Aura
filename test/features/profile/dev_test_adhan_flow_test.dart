import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dev_test_adhan_harness.dart';

Future<void> _openDialog(WidgetTester tester) async {
  await tapVersion(tester, 7);
  await tester.tap(find.text(kFireTitle));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping the dev tile opens the confirm dialog', (tester) async {
    final fired = <String>[];
    await pumpTile(tester, fire: (n) async => fired.add(n));
    await _openDialog(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('dev_test_adhan_dialog_title'), findsOneWidget);
    expect(find.text('dev_test_adhan_dialog_body'), findsOneWidget);
    expect(fired, isEmpty, reason: 'opening the dialog must not fire');
  });

  testWidgets('Cancel closes the dialog and fires nothing', (tester) async {
    final fired = <String>[];
    await pumpTile(tester, fire: (n) async => fired.add(n));
    await _openDialog(tester);
    await tester.tap(find.text('cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(fired, isEmpty);
  });

  testWidgets('Fire calls fireTestAdhan once with Zuhr and shows the snackbar',
      (tester) async {
    final fired = <String>[];
    await pumpTile(tester, fire: (n) async => fired.add(n));
    await _openDialog(tester);
    await tester.tap(find.text('dev_test_adhan_fire'));
    await tester.pumpAndSettle();
    expect(fired, ['Zuhr']);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('dev_test_adhan_scheduled'), findsOneWidget);
  });
}
