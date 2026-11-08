import 'dart:io';

import 'package:aura_app/features/quran/quran_reader_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps the bar at the bottom of a 360 × 640 surface (nova 5T width).
Future<void> _pumpBar(
  WidgetTester tester, {
  required Locale locale,
  required int currentPage,
  VoidCallback? onGoToPrevious,
  VoidCallback? onGoToNext,
  VoidCallback? onZoomOut,
  VoidCallback? onZoomIn,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    locale: locale,
    theme:
        ThemeData(fontFamily: locale.languageCode == 'ar' ? 'Cairo' : 'Roboto'),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: QuranReaderBottomBar(
          currentPage: currentPage,
          totalPages: 604,
          lang: locale.languageCode,
          onGoToPrevious: onGoToPrevious,
          onGoToNext: onGoToNext,
          onZoomOut: onZoomOut,
          onZoomIn: onZoomIn,
        ),
      ),
    ),
  ));
  await tester.pump();
}

/// The IconButton holding [icon].
IconButton _iconButton(WidgetTester tester, IconData icon) =>
    tester.widget<IconButton>(find.ancestor(
        of: find.byIcon(icon), matching: find.byType(IconButton)));

/// Loads the app's bundled fonts so text has real widths.
Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _loadFont('Roboto',
        ['assets/fonts/Roboto-Regular.ttf', 'assets/fonts/Roboto-Bold.ttf']);
    await _loadFont('Cairo',
        ['assets/fonts/Cairo-Regular.ttf', 'assets/fonts/Cairo-Bold.ttf']);
  });

  testWidgets('shows the page counter (Western digits in English)',
      (tester) async {
    await _pumpBar(tester, locale: const Locale('en'), currentPage: 122);
    expect(find.text('122 / 604'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the page counter with Arabic-Indic digits in Arabic',
      (tester) async {
    await _pumpBar(tester, locale: const Locale('ar'), currentPage: 122);
    expect(find.text('١٢٢ / ٦٠٤'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('arrows fire their callbacks', (tester) async {
    var prev = 0, next = 0;
    await _pumpBar(tester,
        locale: const Locale('en'),
        currentPage: 122,
        onGoToPrevious: () => prev++,
        onGoToNext: () => next++);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.tap(find.byIcon(Icons.arrow_forward));
    expect(prev, 1);
    expect(next, 1);
  });

  testWidgets('first page: previous disabled; last page: next disabled',
      (tester) async {
    await _pumpBar(tester,
        locale: const Locale('en'), currentPage: 1, onGoToNext: () {});
    expect(_iconButton(tester, Icons.arrow_back).onPressed, isNull);
    expect(_iconButton(tester, Icons.arrow_forward).onPressed, isNotNull);

    await _pumpBar(tester,
        locale: const Locale('en'), currentPage: 604, onGoToPrevious: () {});
    expect(_iconButton(tester, Icons.arrow_back).onPressed, isNotNull);
    expect(_iconButton(tester, Icons.arrow_forward).onPressed, isNull);
  });

  group('zoom buttons (F58)', () {
    testWidgets('without zoom callbacks (desktop) no A−/A+ is shown',
        (tester) async {
      await _pumpBar(tester, locale: const Locale('en'), currentPage: 122);
      expect(find.text('A'), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.remove), findsNothing);
    });

    testWidgets('A− and A+ fire their own callback once', (tester) async {
      var zoomOut = 0, zoomIn = 0;
      await _pumpBar(tester,
          locale: const Locale('en'),
          currentPage: 122,
          onZoomOut: () => zoomOut++,
          onZoomIn: () => zoomIn++);

      expect(find.text('A'), findsNWidgets(2));
      await tester.tap(find.byIcon(Icons.remove));
      expect(zoomOut, 1);
      expect(zoomIn, 0);
      await tester.tap(find.byIcon(Icons.add));
      expect(zoomOut, 1);
      expect(zoomIn, 1);
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets(
          '360 dp (${locale.languageCode}): all five controls fit, '
          'order ← A− counter A+ →', (tester) async {
        await _pumpBar(tester,
            locale: locale,
            currentPage: 122,
            onGoToPrevious: () {},
            onGoToNext: () {},
            onZoomOut: () {},
            onZoomIn: () {});
        expect(tester.takeException(), isNull);

        final counter = locale.languageCode == 'ar' ? '١٢٢ / ٦٠٤' : '122 / 604';
        final xs = [
          find.byIcon(Icons.arrow_back),
          find.byIcon(Icons.remove),
          find.text(counter),
          find.byIcon(Icons.add),
          find.byIcon(Icons.arrow_forward),
        ].map((f) => tester.getCenter(f).dx).toList();
        for (final x in xs) {
          expect(x, inInclusiveRange(0, 360));
        }
        // LTR reads left to right; RTL mirrors the whole row.
        final ordered = locale.languageCode == 'ar' ? xs.reversed.toList() : xs;
        for (var i = 1; i < ordered.length; i++) {
          expect(ordered[i], greaterThan(ordered[i - 1]));
        }
      });
    }
  });
}
