// Spec: docs/designs/wird-marker.md item 26 and "Start entry points (amendment
// 2026-11-14)". Phase P4a-2. The Wird tab and reader screens themselves are
// checked on a device; this file covers the helpers and the start sheet.
import 'package:aura_app/core/models/wird.dart';
import 'package:aura_app/core/models/wird_marker.dart';
import 'package:aura_app/features/quran/wird_marker_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WirdMarkerRecord _marker({int? page = 31}) => WirdMarkerRecord(
      markerPage: page,
      startPage: page ?? 1,
      color: page == null ? null : 0xFF1E88E5,
      version: 1,
    );

WirdState _state({WirdUnit unit = WirdUnit.page, WirdMarkerRecord? marker}) =>
    WirdState(settings: WirdSettings(wirdUnit: unit), marker: marker);

WirdProgress _progress({int start = 1, int current = 1}) => WirdProgress(
      date: DateTime(2026, 11, 14),
      startPage: start,
      currentPage: current,
    );

/// Opens the sheet from a button and records what it returned.
class _Host {
  StartSheetResult? result;
  bool returned = false;
}

Future<_Host> _open(WidgetTester t, {required bool readingMode, int page = 7}) async {
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  final host = _Host();
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            host.result =
                await WirdStartSheet.show(context, page: page, readingMode: readingMode);
            host.returned = true;
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return host;
}

Finder _swatches() => find.byWidgetPredicate((w) {
      final k = w.key;
      return k is ValueKey<String> && k.value.startsWith('wird_start_swatch_');
    });

bool _enabled(WidgetTester t, String label) {
  final button = find.ancestor(
      of: find.text(label), matching: find.bySubtype<ButtonStyleButton>());
  return t.widget<ButtonStyleButton>(button).onPressed != null;
}

void main() {
  group('verseSheetMarkerAction', () {
    test('page mode with no record or no marker page: set', () {
      expect(
          verseSheetMarkerAction(
              unit: WirdUnit.page, markerPage: null, ayahPage: 12),
          VerseSheetMarkerAction.set);
    });
    test('page mode, tapped page ahead of the marker: move', () {
      expect(
          verseSheetMarkerAction(
              unit: WirdUnit.page, markerPage: 31, ayahPage: 36),
          VerseSheetMarkerAction.move);
    });
    test('page mode, tapped page equal to or behind the marker: none', () {
      expect(
          verseSheetMarkerAction(
              unit: WirdUnit.page, markerPage: 31, ayahPage: 31),
          VerseSheetMarkerAction.none);
      expect(
          verseSheetMarkerAction(
              unit: WirdUnit.page, markerPage: 31, ayahPage: 5),
          VerseSheetMarkerAction.none);
    });
    test('marker on 604: none for every page', () {
      for (final p in [1, 300, 603, 604]) {
        expect(
            verseSheetMarkerAction(
                unit: WirdUnit.page, markerPage: 604, ayahPage: p),
            VerseSheetMarkerAction.none);
      }
    });
    test('juz mode: none in every case', () {
      for (final m in [null, 31, 604]) {
        expect(
            verseSheetMarkerAction(
                unit: WirdUnit.juz, markerPage: m, ayahPage: 100),
            VerseSheetMarkerAction.none);
      }
    });
  });

  group('startSheetPage (N)', () {
    test('no marker and no progress: page 1', () {
      expect(startSheetPage(_state(), null), 1);
    });
    test('a record with no marker page and no progress: page 1', () {
      expect(startSheetPage(_state(marker: _marker(page: null)), null), 1);
    });
    test('no marker with today\'s progress: the page the reader would open at',
        () {
      expect(
          startSheetPage(_state(), _progress(start: 10, current: 14)), 14);
    });
    test('a marker: the marker page', () {
      expect(startSheetPage(_state(marker: _marker(page: 31)), null), 31);
      expect(
          startSheetPage(
              _state(marker: _marker(page: 36)), _progress(start: 31, current: 34)),
          36);
    });
  });

  group('startSheetTitle', () {
    const template = 'Start your Wird from page %d?';
    test('English keeps Western digits', () {
      expect(startSheetTitle(template, 7, 'en'), 'Start your Wird from page 7?');
    });
    test('Arabic uses Arabic numerals', () {
      expect(startSheetTitle(template, 604, 'ar'),
          'Start your Wird from page ٦٠٤?');
    });
  });

  group('WirdStartSheet, Start Reading mode', () {
    testWidgets('shows 12 swatches and three buttons', (t) async {
      await _open(t, readingMode: true);
      expect(_swatches(), findsNWidgets(12));
      expect(find.text('wird_start_here'), findsOneWidget);
      expect(find.text('wird_choose_another_page'), findsOneWidget);
      expect(find.text('wird_just_read'), findsOneWidget);
      expect(find.text('cancel'), findsNothing);
    });

    testWidgets('Start here is disabled until a color is picked, then returns it',
        (t) async {
      final host = await _open(t, readingMode: true);
      expect(_enabled(t, 'wird_start_here'), isFalse);
      await t.tap(_swatches().at(3));
      await t.pump();
      expect(_enabled(t, 'wird_start_here'), isTrue);
      await t.tap(find.text('wird_start_here'));
      await t.pumpAndSettle();
      expect(host.returned, isTrue);
      expect(host.result, isA<StartHere>());
      expect((host.result as StartHere).color, kWirdMarkerPalette[3]);
    });

    testWidgets('Choose another page returns ChooseAnotherPage', (t) async {
      final host = await _open(t, readingMode: true);
      await t.tap(find.text('wird_choose_another_page'));
      await t.pumpAndSettle();
      expect(host.result, isA<ChooseAnotherPage>());
    });

    testWidgets('Just read returns JustRead', (t) async {
      final host = await _open(t, readingMode: true);
      await t.tap(find.text('wird_just_read'));
      await t.pumpAndSettle();
      expect(host.result, isA<JustRead>());
    });

    testWidgets('dismissing returns null', (t) async {
      final host = await _open(t, readingMode: true);
      await t.tapAt(const Offset(200, 20)); // the barrier above the sheet
      await t.pumpAndSettle();
      expect(host.returned, isTrue);
      expect(host.result, isNull);
    });
  });

  group('WirdStartSheet, reader mode', () {
    testWidgets('shows only Start here and Cancel', (t) async {
      await _open(t, readingMode: false);
      expect(_swatches(), findsNWidgets(12));
      expect(find.text('wird_start_here'), findsOneWidget);
      expect(find.text('cancel'), findsOneWidget);
      expect(find.text('wird_choose_another_page'), findsNothing);
      expect(find.text('wird_just_read'), findsNothing);
    });

    testWidgets('Start here returns the chosen color', (t) async {
      final host = await _open(t, readingMode: false);
      await t.tap(_swatches().at(0));
      await t.pump();
      await t.tap(find.text('wird_start_here'));
      await t.pumpAndSettle();
      expect((host.result as StartHere).color, kWirdMarkerPalette[0]);
    });

    testWidgets('Cancel returns null', (t) async {
      final host = await _open(t, readingMode: false);
      await t.tap(find.text('cancel'));
      await t.pumpAndSettle();
      expect(host.returned, isTrue);
      expect(host.result, isNull);
    });
  });
}
