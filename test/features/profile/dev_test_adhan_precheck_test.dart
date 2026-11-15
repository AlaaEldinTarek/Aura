import 'package:flutter_test/flutter_test.dart';

import 'dev_test_adhan_harness.dart';

Future<void> _fire(WidgetTester tester) async {
  await tapVersion(tester, 7);
  await tester.tap(find.text(kFireTitle));
  await tester.pumpAndSettle();
  await tester.tap(find.text('dev_test_adhan_fire'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without exact-alarm permission: no fire, shows the message',
      (tester) async {
    final fired = <String>[];
    await pumpTile(
      tester,
      fire: (n) async => fired.add(n),
      canSchedule: () async => false,
    );
    await _fire(tester);
    expect(fired, isEmpty);
    expect(find.text('dev_test_adhan_no_exact_alarm'), findsOneWidget);
    expect(find.text('dev_test_adhan_scheduled'), findsNothing);
  });

  testWidgets('with permission: checks first, then fires once', (tester) async {
    final order = <String>[];
    await pumpTile(
      tester,
      fire: (n) async => order.add('fire:$n'),
      canSchedule: () async {
        order.add('check');
        return true;
      },
    );
    await _fire(tester);
    expect(order, ['check', 'fire:Zuhr']);
    expect(find.text('dev_test_adhan_no_exact_alarm'), findsNothing);
  });
}
