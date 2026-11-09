import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/utils/window_size.dart';
import 'package:aura_app/features/main/desktop_shell_layout.dart';

// F65: below 800 px the desktop sidebar is a 72-px icon rail and ☰ opens the
// full sidebar as an overlay; the content never moves and the item scale
// (from the window size) never changes.

const _contentKey = ValueKey('content');

class _Probe {
  int itemTaps = 0;
  int userToggles = 0;
  final List<double> scales = [];
}

Widget _app({
  required _Probe probe,
  bool rtl = false,
  bool sidebarVisible = true,
  bool userCollapsed = false,
  double compactBelow = kCompactSidebarBelow,
}) {
  return MaterialApp(
    home: Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: DesktopShellLayout(
          sidebarVisible: sidebarVisible,
          userCollapsed: userCollapsed,
          onToggleCollapsed: () => probe.userToggles++,
          compactBelow: compactBelow,
          dividerColor: Colors.white10,
          sidebarBuilder: (collapsed, onToggle, onItemSelected) => Container(
            key: ValueKey(collapsed ? 'rail' : 'full'),
            color: Colors.grey,
            child: Column(children: [
              IconButton(
                key: ValueKey(collapsed ? 'rail-toggle' : 'full-toggle'),
                icon: const Icon(Icons.menu),
                onPressed: onToggle,
              ),
              if (!collapsed)
                TextButton(
                  key: const ValueKey('item'),
                  onPressed: () {
                    probe.itemTaps++;
                    onItemSelected();
                  },
                  child: const Text('Prayer'),
                ),
            ]),
          ),
          content: Builder(builder: (ctx) {
            final size = MediaQuery.of(ctx).size;
            probe.scales.add(desktopTextScale(size.width, size.height));
            return const SizedBox.expand(key: _contentKey);
          }),
        ),
      ),
    ),
  );
}

Future<void> _setWindow(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Rect _rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

void main() {
  const narrow = Size(597, 929);
  const wide = Size(1200, 900);

  test('threshold is 800 logical px', () {
    expect(useCompactSidebar(799), isTrue);
    expect(useCompactSidebar(800), isFalse);
  });

  testWidgets('compact LTR: rail at the left; overlay does not move content',
      (tester) async {
    await _setWindow(tester, narrow);
    final p = _Probe();
    await tester.pumpWidget(_app(probe: p));

    final rail = _rect(tester, const ValueKey('rail'));
    expect(rail.left, 0);
    expect(rail.width, 72);
    final content = _rect(tester, _contentKey);
    expect(content.width, narrow.width - 73);

    await tester.tap(find.byKey(const ValueKey('rail-toggle')));
    await tester.pumpAndSettle();
    final full = _rect(tester, const ValueKey('full'));
    expect(full.left, 0);
    expect(full.width, 260);
    expect(_rect(tester, _contentKey), content); // not pushed

    // Scrim closes it.
    await tester.tapAt(Offset(narrow.width - 20, narrow.height / 2));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('full')), findsNothing);
  });

  testWidgets('compact: item tap and Esc close the overlay', (tester) async {
    await _setWindow(tester, narrow);
    final p = _Probe();
    await tester.pumpWidget(_app(probe: p));

    await tester.tap(find.byKey(const ValueKey('rail-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('item')));
    await tester.pumpAndSettle();
    expect(p.itemTaps, 1);
    expect(find.byKey(const ValueKey('full')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('rail-toggle')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('full')), findsNothing);

    // ☰ in the expanded header closes it too.
    await tester.tap(find.byKey(const ValueKey('rail-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('full-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('full')), findsNothing);
  });

  testWidgets('compact RTL: rail and overlay on the right edge',
      (tester) async {
    await _setWindow(tester, narrow);
    final p = _Probe();
    await tester.pumpWidget(_app(probe: p, rtl: true));

    expect(_rect(tester, const ValueKey('rail')).right, narrow.width);
    final content = _rect(tester, _contentKey);

    await tester.tap(find.byKey(const ValueKey('rail-toggle')));
    await tester.pumpAndSettle();
    final full = _rect(tester, const ValueKey('full'));
    expect(full.right, narrow.width);
    expect(full.width, 260);
    expect(_rect(tester, _contentKey), content);
  });

  testWidgets('wide: inline sidebar as today; toggle collapses inline',
      (tester) async {
    await _setWindow(tester, wide);
    final p = _Probe();
    await tester.pumpWidget(_app(probe: p));
    await tester.pumpAndSettle();

    expect(_rect(tester, const ValueKey('full')).width, 260);
    expect(_rect(tester, _contentKey).width, wide.width - 261);
    await tester.tap(find.byKey(const ValueKey('full-toggle')));
    expect(p.userToggles, 1);

    await tester.pumpWidget(_app(probe: p, userCollapsed: true));
    await tester.pumpAndSettle();
    expect(_rect(tester, const ValueKey('rail')).width, 72);
    expect(_rect(tester, _contentKey).width, wide.width - 73);
  });

  testWidgets('overlay closes when the window becomes wide', (tester) async {
    await _setWindow(tester, narrow);
    final p = _Probe();
    await tester.pumpWidget(_app(probe: p));
    await tester.tap(find.byKey(const ValueKey('rail-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('full')), findsOneWidget);

    tester.view.physicalSize = wide;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('full')), findsOneWidget); // inline now
    expect(_rect(tester, _contentKey).width, wide.width - 261);

    tester.view.physicalSize = narrow;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('full')), findsNothing); // not reopened
  });

  testWidgets('sidebar hidden: no rail, no overlay, content full width',
      (tester) async {
    await _setWindow(tester, narrow);
    final p = _Probe();
    await tester.pumpWidget(_app(probe: p, sidebarVisible: false));

    expect(find.byKey(const ValueKey('rail')), findsNothing);
    expect(find.byKey(const ValueKey('full')), findsNothing);
    expect(_rect(tester, _contentKey).width, narrow.width);
  });

  testWidgets('item scale is the same with rail, inline sidebar and overlay',
      (tester) async {
    await _setWindow(tester, narrow);
    final today = _Probe();
    await tester.pumpWidget(_app(probe: today, compactBelow: 0)); // inline 260
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('full')), findsOneWidget);
    final todayScale = today.scales.last;

    final rail = _Probe();
    await tester.pumpWidget(_app(probe: rail));
    await tester.pumpAndSettle();
    expect(rail.scales.last, todayScale);

    await tester.tap(find.byKey(const ValueKey('rail-toggle')));
    await tester.pumpAndSettle();
    expect(rail.scales.last, todayScale);
    expect(todayScale, closeTo(1.19, 0.01));
  });
}
