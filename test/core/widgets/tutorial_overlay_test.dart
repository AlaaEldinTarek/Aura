import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/widgets/tutorial_overlay.dart';

// F64: on desktop the tour is drawn in the nested content navigator's
// overlay (right of the sidebar). The frame and the tooltip must be placed
// in that overlay's coordinates and size.

const _sidebarW = 200.0;
const _headerH = 100.0; // pane starts below a header, so its height < window
const _window = Size(1000, 800);

class _Harness {
  final GlobalKey target = GlobalKey();
  late BuildContext paneContext;
  bool done = false;

  /// [sidebar]: desktop-like (sidebar + header + nested navigator) or a
  /// single full-window navigator (mobile-like). [rtl]: sidebar on the right.
  Widget build({
    required Offset targetPos,
    bool sidebar = true,
    bool rtl = false,
  }) {
    Widget pane = Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (ctx) {
          paneContext = ctx;
          return Stack(children: [
            Positioned(
              left: targetPos.dx,
              top: targetPos.dy,
              child: SizedBox(key: target, width: 120, height: 60),
            ),
          ]);
        },
      ),
    );
    if (sidebar) {
      pane = Row(children: [
        const SizedBox(width: _sidebarW),
        Expanded(
          child: Column(children: [
            const SizedBox(height: _headerH),
            Expanded(child: pane),
          ]),
        ),
      ]);
    }
    return MaterialApp(
      home: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(body: pane),
      ),
    );
  }

  void start() => showTutorial(
        context: paneContext,
        steps: [
          TutorialStep(targetKey: target, titleKey: 'title', bodyKey: 'body'),
        ],
        onDone: () => done = true,
      );
}

Future<void> _show(WidgetTester tester, _Harness h, Widget app) async {
  tester.view.physicalSize = _window;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  h.start();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The frame the tour paints (the painter's targetRect).
Rect _frame(WidgetTester tester) {
  final paint = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .firstWhere((p) => p.painter.runtimeType.toString() == '_OverlayPainter');
  return (paint.painter as dynamic).targetRect as Rect;
}

/// Global rect of the nested pane (the overlay the tour is drawn in).
Rect _pane(WidgetTester tester) => tester.getRect(find.byType(Navigator).last);

/// Global rect of the tooltip card.
Rect _tooltip(WidgetTester tester) => tester.getRect(find
    .ancestor(
      of: find.text('tutorial_skip'),
      matching: find.byWidgetPredicate(
          (w) => w is Container && w.padding == const EdgeInsets.all(20)),
    )
    .first);

void main() {
  testWidgets('desktop LTR: frame is on the target in pane coordinates',
      (tester) async {
    final h = _Harness();
    await _show(tester, h, h.build(targetPos: const Offset(30, 40)));

    final target = tester.getRect(find.byKey(h.target));
    final pane = _pane(tester);
    expect(_frame(tester), target.shift(-pane.topLeft));
  });

  testWidgets('desktop RTL (sidebar on the right): frame is on the target',
      (tester) async {
    final h = _Harness();
    await _show(tester, h, h.build(targetPos: const Offset(30, 40), rtl: true));

    final target = tester.getRect(find.byKey(h.target));
    final pane = _pane(tester);
    expect(_frame(tester), target.shift(-pane.topLeft));
  });

  testWidgets('tooltip stays inside the pane at the sidebar edge',
      (tester) async {
    final h = _Harness();
    await _show(tester, h, h.build(targetPos: const Offset(0, 20)));

    final pane = _pane(tester);
    final tip = _tooltip(tester);
    expect(tip.left, greaterThanOrEqualTo(pane.left));
    expect(tip.right, lessThanOrEqualTo(pane.right));
    expect(tip.top, greaterThanOrEqualTo(pane.top));
    expect(tip.bottom, lessThanOrEqualTo(pane.bottom));
    // Placed below the target, not overlapping it.
    expect(tip.top,
        greaterThanOrEqualTo(tester.getRect(find.byKey(h.target)).bottom));
  });

  testWidgets('target near the pane bottom: tooltip above it, inside the pane',
      (tester) async {
    final h = _Harness();
    final paneH = _window.height - _headerH;
    await _show(tester, h, h.build(targetPos: Offset(0, paneH - 100)));

    final pane = _pane(tester);
    final tip = _tooltip(tester);
    final target = tester.getRect(find.byKey(h.target));
    expect(tip.top, greaterThanOrEqualTo(pane.top));
    expect(tip.bottom, lessThanOrEqualTo(pane.bottom));
    expect(tip.bottom, lessThanOrEqualTo(target.top));
  });

  testWidgets('mobile-like single overlay: frame equals the window rect',
      (tester) async {
    final h = _Harness();
    await _show(
        tester, h, h.build(targetPos: const Offset(30, 40), sidebar: false));

    expect(_frame(tester), tester.getRect(find.byKey(h.target)));
  });

  testWidgets('Skip removes the tour and calls onDone', (tester) async {
    final h = _Harness();
    await _show(tester, h, h.build(targetPos: const Offset(30, 40)));

    await tester.tap(find.text('tutorial_skip'));
    await tester.pump();
    expect(h.done, isTrue);
    expect(find.text('tutorial_skip'), findsNothing);
  });
}
