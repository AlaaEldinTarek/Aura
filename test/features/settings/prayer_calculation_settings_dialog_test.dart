import 'dart:io';

import 'package:aura_app/features/settings/prayer_calculation_settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Radio row for [value] inside the dialog.
Finder _radio(String value) =>
    find.byWidgetPredicate((w) => w is Radio<String> && w.value == value,
        description: 'Radio<String>($value)');

/// The radio's selected value.
String? _groupValue(WidgetTester tester, String value) =>
    // ignore: deprecated_member_use
    tester.widget<Radio<String>>(_radio(value)).groupValue;

/// Opens the dialog through `show()` on a 360 × 640 surface (nova 5T width).
Future<void> _openDialog(
  WidgetTester tester, {
  required Locale locale,
  required List<String> methodCalls,
  required List<String> madhabCalls,
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
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => PrayerCalculationSettingsDialog.show(
              context: context,
              currentMethod: 'MuslimWorldLeague',
              currentMadhab: 'Shafi',
              onMethodChanged: methodCalls.add,
              onMadhabChanged: madhabCalls.add,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder get _dialogScrollable =>
    find.descendant(of: find.byType(Dialog), matching: find.byType(Scrollable));

/// Loads the app's bundled fonts so text has real widths (the default test
/// font draws every glyph as a full em square, which overflows rows that fit
/// on a device).
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

  for (final locale in const [Locale('en'), Locale('ar')]) {
    group('small screen (${locale.languageCode})', () {
      testWidgets('Hanafi can be reached, tapped and shows as selected',
          (tester) async {
        final methodCalls = <String>[];
        final madhabCalls = <String>[];
        await _openDialog(tester,
            locale: locale, methodCalls: methodCalls, madhabCalls: madhabCalls);

        await tester.scrollUntilVisible(_radio('Hanafi'), 100,
            scrollable: _dialogScrollable);
        await tester.tap(_radio('Hanafi'));
        await tester.pump();

        expect(madhabCalls, ['Hanafi']);
        expect(methodCalls, isEmpty);
        expect(_groupValue(tester, 'Hanafi'), 'Hanafi');
        expect(tester.takeException(), isNull);
      });

      testWidgets('a method row can be tapped and shows as selected',
          (tester) async {
        final methodCalls = <String>[];
        final madhabCalls = <String>[];
        await _openDialog(tester,
            locale: locale, methodCalls: methodCalls, madhabCalls: madhabCalls);

        await tester.scrollUntilVisible(_radio('Singapore'), 100,
            scrollable: _dialogScrollable);
        await tester.tap(_radio('Singapore'));
        await tester.pump();

        expect(methodCalls, ['Singapore']);
        expect(madhabCalls, isEmpty);
        expect(_groupValue(tester, 'Singapore'), 'Singapore');
        expect(tester.takeException(), isNull);
      });
    });
  }
}
