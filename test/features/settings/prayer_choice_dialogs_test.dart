import 'dart:io';

import 'package:aura_app/core/widgets/aura_button.dart';
import 'package:aura_app/features/settings/asr_madhab_dialog.dart';
import 'package:aura_app/features/settings/calculation_method_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Radio row for [value] inside the dialog.
Finder _radio(String value) =>
    find.byWidgetPredicate((w) => w is Radio<String> && w.value == value,
        description: 'Radio<String>($value)');

/// The dialog's selected value.
String? _selected(WidgetTester tester) => tester
    .widget<RadioGroup<String>>(
        find.byWidgetPredicate((w) => w is RadioGroup<String>))
    .groupValue;

Finder get _dialogScrollable =>
    find.descendant(of: find.byType(Dialog), matching: find.byType(Scrollable));

/// Result holder: [done] is set once `show()` completes.
class _Result {
  bool done = false;
  String? value;
}

/// Opens a dialog through [open] on a 360 × 640 surface (nova 5T width).
Future<_Result> _openDialog(
  WidgetTester tester, {
  required Locale locale,
  required Future<String?> Function(BuildContext) open,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final result = _Result();
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
            onPressed: () async {
              result.value = await open(context);
              result.done = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

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

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final lang = locale.languageCode;

    group('CalculationMethodDialog ($lang)', () {
      Future<_Result> open(WidgetTester tester) => _openDialog(tester,
          locale: locale,
          open: (c) => CalculationMethodDialog.show(c,
              currentMethod: 'MuslimWorldLeague'));

      testWidgets('shows the current method and no madhab options',
          (tester) async {
        await open(tester);
        expect(_selected(tester), 'MuslimWorldLeague');
        expect(_radio('Shafi'), findsNothing);
        expect(_radio('Hanafi'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a tap moves the radio and returns nothing yet',
          (tester) async {
        final result = await open(tester);
        await tester.scrollUntilVisible(_radio('Singapore'), 100,
            scrollable: _dialogScrollable);
        await tester.tap(_radio('Singapore'));
        await tester.pump();

        expect(_selected(tester), 'Singapore');
        expect(result.done, isFalse);
        expect(find.byType(Dialog), findsOneWidget);
      });

      testWidgets('Done returns the chosen method once and closes',
          (tester) async {
        final result = await open(tester);
        await tester.scrollUntilVisible(_radio('Singapore'), 100,
            scrollable: _dialogScrollable);
        await tester.tap(_radio('Singapore'));
        await tester.pump();
        await tester.tap(find.byType(AuraButton));
        await tester.pumpAndSettle();

        expect(result.done, isTrue);
        expect(result.value, 'Singapore');
        expect(find.byType(Dialog), findsNothing);
      });

      testWidgets('close (X) returns null and closes', (tester) async {
        final result = await open(tester);
        await tester.tap(_radio('Egyptian'));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(result.done, isTrue);
        expect(result.value, isNull);
        expect(find.byType(Dialog), findsNothing);
      });

      testWidgets('the method list scrolls on a small screen (F49c)',
          (tester) async {
        await open(tester);
        expect(_dialogScrollable, findsOneWidget);
        await tester.scrollUntilVisible(_radio('Singapore'), 100,
            scrollable: _dialogScrollable);
        expect(_radio('Singapore'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('AsrMadhabDialog ($lang)', () {
      Future<_Result> open(WidgetTester tester) => _openDialog(tester,
          locale: locale,
          open: (c) => AsrMadhabDialog.show(c, currentMadhab: 'Shafi'));

      testWidgets('shows the current madhab and no methods', (tester) async {
        await open(tester);
        expect(_selected(tester), 'Shafi');
        expect(_radio('Hanafi'), findsOneWidget);
        expect(_radio('MuslimWorldLeague'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a tap moves the radio and returns nothing yet',
          (tester) async {
        final result = await open(tester);
        await tester.tap(_radio('Hanafi'));
        await tester.pump();

        expect(_selected(tester), 'Hanafi');
        expect(result.done, isFalse);
        expect(find.byType(Dialog), findsOneWidget);
      });

      testWidgets('Done returns the chosen madhab once and closes',
          (tester) async {
        final result = await open(tester);
        await tester.tap(_radio('Hanafi'));
        await tester.pump();
        await tester.tap(find.byType(AuraButton));
        await tester.pumpAndSettle();

        expect(result.done, isTrue);
        expect(result.value, 'Hanafi');
        expect(find.byType(Dialog), findsNothing);
      });

      testWidgets('close (X) returns null and closes', (tester) async {
        final result = await open(tester);
        await tester.tap(_radio('Hanafi'));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(result.done, isTrue);
        expect(result.value, isNull);
        expect(find.byType(Dialog), findsNothing);
      });
    });
  }
}
