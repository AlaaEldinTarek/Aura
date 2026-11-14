// Spec: docs/designs/wird-marker.md item 27 and "Top-bar Wird icon (amendment
// 2026-11-14, second)". Phase P4a-3. The reader's top bar, the order of the
// icons and the tap flows inside the reader are checked on a device.
import 'package:aura_app/core/models/wird.dart';
import 'package:aura_app/core/models/wird_marker.dart';
import 'package:aura_app/features/quran/wird_marker_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _color = 0xFF1E88E5;

WirdMarkerRecord _marker({int? page = 31}) => WirdMarkerRecord(
      markerPage: page,
      startPage: page ?? 1,
      color: page == null ? null : _color,
      version: 1,
    );

WirdState _state({WirdUnit unit = WirdUnit.page, WirdMarkerRecord? marker}) =>
    WirdState(settings: WirdSettings(wirdUnit: unit), marker: marker);

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

/// The flag icon inside the button, or null when none is built.
Icon? _flag(WidgetTester t) {
  final f = find.byWidgetPredicate(
      (w) => w is Icon && (w.icon == Icons.flag || w.icon == Icons.flag_outlined));
  return f.evaluate().isEmpty ? null : t.widget<Icon>(f);
}

void main() {
  group('wirdTopBarIconSpec', () {
    test('juz mode: not visible', () {
      final s = wirdTopBarIconSpec(
          unit: WirdUnit.juz, markerPage: 31, currentPage: 31);
      expect(s.visible, isFalse);
      expect(s.action, VerseSheetMarkerAction.none);
    });

    test('page mode, no marker page: outline, neutral, set', () {
      final s = wirdTopBarIconSpec(
          unit: WirdUnit.page, markerPage: null, currentPage: 12);
      expect(s.visible, isTrue);
      expect(s.filled, isFalse);
      expect(s.useMarkerColor, isFalse);
      expect(s.tooltipKey, 'wird_marker_set_here');
      expect(s.action, VerseSheetMarkerAction.set);
    });

    test('on the marker page: filled, marker color, info only', () {
      final s = wirdTopBarIconSpec(
          unit: WirdUnit.page, markerPage: 31, currentPage: 31);
      expect(s.visible, isTrue);
      expect(s.filled, isTrue);
      expect(s.useMarkerColor, isTrue);
      expect(s.tooltipKey, 'wird_marker_page_label');
      expect(s.action, VerseSheetMarkerAction.none);
    });

    test('behind the marker: outline, marker color, info only', () {
      final s = wirdTopBarIconSpec(
          unit: WirdUnit.page, markerPage: 31, currentPage: 5);
      expect(s.filled, isFalse);
      expect(s.useMarkerColor, isTrue);
      expect(s.tooltipKey, 'wird_marker_page_label');
      expect(s.action, VerseSheetMarkerAction.none);
    });

    test('ahead of the marker: outline, marker color, move', () {
      final s = wirdTopBarIconSpec(
          unit: WirdUnit.page, markerPage: 31, currentPage: 36);
      expect(s.filled, isFalse);
      expect(s.useMarkerColor, isTrue);
      expect(s.tooltipKey, 'wird_marker_move_here');
      expect(s.action, VerseSheetMarkerAction.move);
    });

    test('marker on 604: never move', () {
      for (final p in [1, 300, 603, 604]) {
        expect(
            wirdTopBarIconSpec(
                    unit: WirdUnit.page, markerPage: 604, currentPage: p)
                .action,
            isNot(VerseSheetMarkerAction.move));
      }
    });

    test('the action always matches verseSheetMarkerAction', () {
      for (final m in [null, 1, 31, 604]) {
        for (final c in [1, 31, 32, 604]) {
          expect(
              wirdTopBarIconSpec(
                      unit: WirdUnit.page, markerPage: m, currentPage: c)
                  .action,
              verseSheetMarkerAction(
                  unit: WirdUnit.page, markerPage: m, ayahPage: c));
        }
      }
    });
  });

  group('WirdMarkerTopBarButton', () {
    testWidgets('is not built in juz mode', (t) async {
      await t.pumpWidget(_host(WirdMarkerTopBarButton(
          state: _state(unit: WirdUnit.juz, marker: _marker()),
          currentPage: 31,
          onTap: (_) {})));
      expect(find.byType(IconButton), findsNothing);
      expect(_flag(t), isNull);
    });

    testWidgets('is not built before the Wird state is loaded', (t) async {
      await t.pumpWidget(_host(WirdMarkerTopBarButton(
          state: null, currentPage: 31, onTap: (_) {})));
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('no marker: neutral outline flag and the set tooltip', (t) async {
      await t.pumpWidget(_host(WirdMarkerTopBarButton(
          state: _state(), currentPage: 12, onTap: (_) {})));
      final icon = _flag(t)!;
      expect(icon.icon, Icons.flag_outlined);
      expect(icon.color, isNot(const Color(_color)));
      expect(find.byTooltip('wird_marker_set_here'), findsOneWidget);
    });

    testWidgets('on the marker page: filled flag in the marker color', (t) async {
      await t.pumpWidget(_host(WirdMarkerTopBarButton(
          state: _state(marker: _marker(page: 31)),
          currentPage: 31,
          onTap: (_) {})));
      final icon = _flag(t)!;
      expect(icon.icon, Icons.flag);
      expect(icon.color, const Color(_color));
      expect(find.byTooltip('wird_marker_page_label'), findsOneWidget);
    });

    testWidgets('on another page: outline flag in the marker color', (t) async {
      await t.pumpWidget(_host(WirdMarkerTopBarButton(
          state: _state(marker: _marker(page: 31)),
          currentPage: 36,
          onTap: (_) {})));
      final icon = _flag(t)!;
      expect(icon.icon, Icons.flag_outlined);
      expect(icon.color, const Color(_color));
      expect(find.byTooltip('wird_marker_move_here'), findsOneWidget);
    });

    testWidgets('a tap passes the action for the current page', (t) async {
      final taps = <VerseSheetMarkerAction>[];
      Future<void> pump(WirdState s, int page) async {
        taps.clear();
        await t.pumpWidget(_host(WirdMarkerTopBarButton(
            state: s, currentPage: page, onTap: taps.add)));
        await t.tap(find.byType(IconButton));
      }

      await pump(_state(), 12);
      expect(taps, [VerseSheetMarkerAction.set]);
      await pump(_state(marker: _marker(page: 31)), 36);
      expect(taps, [VerseSheetMarkerAction.move]);
      await pump(_state(marker: _marker(page: 31)), 31);
      expect(taps, [VerseSheetMarkerAction.none]);
    });

    testWidgets('the tap target is at least 48 by 48', (t) async {
      await t.pumpWidget(_host(WirdMarkerTopBarButton(
          state: _state(), currentPage: 12, onTap: (_) {})));
      final size = t.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('WirdMoveSheet', () {
    Future<List<bool?>> open(WidgetTester t) async {
      t.view.physicalSize = const Size(400, 800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      final results = <bool?>[];
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  results.add(await WirdMoveSheet.show(context, page: 36)),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      return results;
    }

    testWidgets('shows the title and the two buttons', (t) async {
      await open(t);
      expect(find.text('wird_move_sheet_title'), findsOneWidget);
      expect(find.text('wird_marker_move_here'), findsOneWidget);
      expect(find.text('cancel'), findsOneWidget);
    });

    testWidgets('Move Wird marker here returns true', (t) async {
      final results = await open(t);
      await t.tap(find.text('wird_marker_move_here'));
      await t.pumpAndSettle();
      expect(results, [true]);
    });

    testWidgets('Cancel does not confirm', (t) async {
      final results = await open(t);
      await t.tap(find.text('cancel'));
      await t.pumpAndSettle();
      expect(results.single, isNot(true));
    });

    testWidgets('dismissing does not confirm', (t) async {
      final results = await open(t);
      await t.tapAt(const Offset(200, 20)); // the barrier above the sheet
      await t.pumpAndSettle();
      expect(results.single, isNot(true));
    });
  });
}
