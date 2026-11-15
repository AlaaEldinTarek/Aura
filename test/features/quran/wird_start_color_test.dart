// Spec: docs/designs/wird-marker.md item 29 and "Start sheet remembers the color
// (amendment 2026-11-14, fourth)". Phase P4a-5. The three call sites inside
// wird_tab.dart and quran_reader_screen.dart and the Reset All clear are checked
// on a device; this file covers the sheet parameters, the provider and the helper.
import 'dart:async';

import 'package:aura_app/core/providers/auth_provider.dart';
import 'package:aura_app/core/providers/wird_provider.dart';
import 'package:aura_app/features/quran/wird_marker_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A signed-in user with only a uid (the provider reads nothing else).
class _FakeUser implements User {
  _FakeUser(this.uid);

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Host {
  StartSheetResult? result;
  bool returned = false;
}

Future<void> _bigScreen(WidgetTester t) async {
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

Finder _swatches() => find.byWidgetPredicate((w) {
      final k = w.key;
      return k is ValueKey<String> && k.value.startsWith('wird_start_swatch_');
    });

/// Indexes of the swatches drawn as selected (the selected one has a border).
List<int> _selectedIndexes(WidgetTester t) {
  final out = <int>[];
  for (var i = 0; i < kWirdMarkerPalette.length; i++) {
    final box = find.descendant(
        of: find.byKey(ValueKey('wird_start_swatch_$i')),
        matching: find.byType(Container));
    final deco = t.widget<Container>(box.first).decoration as BoxDecoration;
    if (deco.border != null) out.add(i);
  }
  return out;
}

bool _enabled(WidgetTester t, String label) {
  final button = find.ancestor(
      of: find.text(label), matching: find.bySubtype<ButtonStyleButton>());
  return t.widget<ButtonStyleButton>(button).onPressed != null;
}

/// Opens the bare sheet (no Riverpod) with the two new parameters.
Future<_Host> _openSheet(
  WidgetTester t, {
  required bool readingMode,
  Color? initialColor,
  ValueChanged<Color>? onColorPicked,
}) async {
  await _bigScreen(t);
  final host = _Host();
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            host.result = await WirdStartSheet.show(
              context,
              page: 7,
              readingMode: readingMode,
              initialColor: initialColor,
              onColorPicked: onColorPicked,
            );
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

ProviderContainer _container({Stream<User?>? auth}) {
  final c = ProviderContainer(overrides: [
    authStateProvider
        .overrideWith((ref) => auth ?? const Stream<User?>.empty()),
  ]);
  addTearDown(c.dispose);
  return c;
}

/// A button that opens the remembered sheet through the helper. Opening can be
/// repeated; each result is appended to [results].
Future<void> _pumpHelperHost(
  WidgetTester t,
  ProviderContainer container,
  List<StartSheetResult?> results, {
  required bool Function() readingMode,
}) async {
  await _bigScreen(t);
  await t.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async {
              results.add(await showWirdStartSheetRemembered(context, ref,
                  page: 7, readingMode: readingMode()));
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
}

Future<void> _open(WidgetTester t) async {
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

void main() {
  for (final readingMode in [true, false]) {
    final mode = readingMode ? 'Start Reading mode' : 'reader mode';

    group('WirdStartSheet initialColor and onColorPicked, $mode', () {
      testWidgets(
          'a palette initialColor is shown selected and enabled at once',
          (t) async {
        final host = await _openSheet(t,
            readingMode: readingMode, initialColor: kWirdMarkerPalette[3]);
        expect(_selectedIndexes(t), [3]);
        expect(_enabled(t, 'wird_start_here'), isTrue);
        await t.tap(find.text('wird_start_here'));
        await t.pumpAndSettle();
        expect(host.result, isA<StartHere>());
        expect((host.result as StartHere).color, kWirdMarkerPalette[3]);
      });

      testWidgets('no initialColor: blank and Start here disabled', (t) async {
        await _openSheet(t, readingMode: readingMode);
        expect(_selectedIndexes(t), isEmpty);
        expect(_enabled(t, 'wird_start_here'), isFalse);
      });

      testWidgets('an initialColor outside the palette starts blank',
          (t) async {
        final picks = <Color>[];
        await _openSheet(t,
            readingMode: readingMode,
            initialColor: const Color(0xFF123456),
            onColorPicked: picks.add);
        expect(_selectedIndexes(t), isEmpty);
        expect(_enabled(t, 'wird_start_here'), isFalse);
        expect(picks, isEmpty); // the stale value is not reported back
      });

      testWidgets('each swatch tap calls onColorPicked and moves the selection',
          (t) async {
        final picks = <Color>[];
        final host = await _openSheet(t,
            readingMode: readingMode, onColorPicked: picks.add);
        await t.tap(_swatches().at(2));
        await t.pump();
        expect(picks, [kWirdMarkerPalette[2]]);
        expect(_selectedIndexes(t), [2]);
        await t.tap(_swatches().at(9));
        await t.pump();
        expect(picks, [kWirdMarkerPalette[2], kWirdMarkerPalette[9]]);
        expect(_selectedIndexes(t), [9]);
        await t.tap(find.text('wird_start_here'));
        await t.pumpAndSettle();
        expect((host.result as StartHere).color, kWirdMarkerPalette[9]);
      });

      testWidgets('a remembered color can be changed before Start here',
          (t) async {
        final picks = <Color>[];
        final host = await _openSheet(t,
            readingMode: readingMode,
            initialColor: kWirdMarkerPalette[1],
            onColorPicked: picks.add);
        await t.tap(_swatches().at(4));
        await t.pump();
        expect(picks, [kWirdMarkerPalette[4]]);
        await t.tap(find.text('wird_start_here'));
        await t.pumpAndSettle();
        expect((host.result as StartHere).color, kWirdMarkerPalette[4]);
      });

      testWidgets('the pick is reported before any exit that carries no color',
          (t) async {
        // Exit buttons that return no color: the pick must already be recorded.
        final exits = readingMode
            ? ['wird_choose_another_page', 'wird_just_read']
            : ['cancel'];
        for (final label in exits) {
          final picks = <Color>[];
          await _openSheet(t,
              readingMode: readingMode, onColorPicked: picks.add);
          await t.tap(_swatches().at(6));
          await t.pump();
          await t.tap(find.text(label));
          await t.pumpAndSettle();
          expect(picks, [kWirdMarkerPalette[6]], reason: label);
        }
      });

      testWidgets('the pick is reported before a dismiss', (t) async {
        final picks = <Color>[];
        final host = await _openSheet(t,
            readingMode: readingMode, onColorPicked: picks.add);
        await t.tap(_swatches().at(0));
        await t.pump();
        await t.tapAt(const Offset(200, 20)); // the barrier above the sheet
        await t.pumpAndSettle();
        expect(host.returned, isTrue);
        expect(host.result, isNull);
        expect(picks, [kWirdMarkerPalette[0]]);
      });
    });
  }

  group('wirdStartColorProvider', () {
    test('starts null', () {
      final c = _container();
      expect(c.read(wirdStartColorProvider), isNull);
    });

    test('keeps a value between reads', () {
      final c = _container();
      c.read(wirdStartColorProvider.notifier).state =
          kWirdMarkerPalette[2].toARGB32();
      expect(c.read(wirdStartColorProvider), kWirdMarkerPalette[2].toARGB32());
    });

    test('ref.invalidate returns it to null (Reset All Progress)', () {
      final c = _container();
      c.read(wirdStartColorProvider.notifier).state =
          kWirdMarkerPalette[2].toARGB32();
      c.invalidate(wirdStartColorProvider);
      expect(c.read(wirdStartColorProvider), isNull);
    });

    test('a uid change resets it (sign-out and account switch)', () async {
      final auth = StreamController<User?>();
      addTearDown(auth.close);
      final c = _container(auth: auth.stream);
      c.listen(wirdStartColorProvider, (_, __) {}); // keep it alive

      auth.add(_FakeUser('u1'));
      await Future<void>.delayed(Duration.zero);
      c.read(wirdStartColorProvider.notifier).state =
          kWirdMarkerPalette[5].toARGB32();
      expect(c.read(wirdStartColorProvider), kWirdMarkerPalette[5].toARGB32());

      auth.add(null); // sign-out
      await Future<void>.delayed(Duration.zero);
      expect(c.read(wirdStartColorProvider), isNull);
    });

    test('the same uid emitted again does not reset it', () async {
      final auth = StreamController<User?>();
      addTearDown(auth.close);
      final c = _container(auth: auth.stream);
      c.listen(wirdStartColorProvider, (_, __) {});

      auth.add(_FakeUser('u1'));
      await Future<void>.delayed(Duration.zero);
      c.read(wirdStartColorProvider.notifier).state =
          kWirdMarkerPalette[5].toARGB32();
      auth.add(_FakeUser('u1')); // e.g. a refreshed user object, same account
      await Future<void>.delayed(Duration.zero);
      expect(c.read(wirdStartColorProvider), kWirdMarkerPalette[5].toARGB32());
    });
  });

  group('showWirdStartSheetRemembered', () {
    testWidgets('the first open is blank and a tap writes the provider',
        (t) async {
      final c = _container();
      final results = <StartSheetResult?>[];
      await _pumpHelperHost(t, c, results, readingMode: () => true);
      await _open(t);
      expect(_selectedIndexes(t), isEmpty);
      expect(_enabled(t, 'wird_start_here'), isFalse);
      await t.tap(_swatches().at(5));
      await t.pump();
      expect(c.read(wirdStartColorProvider), kWirdMarkerPalette[5].toARGB32());
    });

    testWidgets(
        'device sequence: pick, "Choose another page", open again: pre-selected',
        (t) async {
      final c = _container();
      final results = <StartSheetResult?>[];
      var reading = true;
      await _pumpHelperHost(t, c, results, readingMode: () => reading);

      await _open(t); // Start Reading
      await t.tap(_swatches().at(5));
      await t.pump();
      await t.tap(find.text('wird_choose_another_page'));
      await t.pumpAndSettle();
      expect(results.single, isA<ChooseAnotherPage>());

      reading = false; // the reader's flag, a different entry point
      await _open(t);
      expect(_selectedIndexes(t), [5]);
      expect(_enabled(t, 'wird_start_here'), isTrue);
      await t.tap(find.text('wird_start_here'));
      await t.pumpAndSettle();
      expect(results.last, isA<StartHere>());
      expect((results.last as StartHere).color, kWirdMarkerPalette[5]);
    });

    testWidgets('a second pick replaces the first', (t) async {
      final c = _container();
      final results = <StartSheetResult?>[];
      await _pumpHelperHost(t, c, results, readingMode: () => false);

      await _open(t);
      await t.tap(_swatches().at(1));
      await t.pump();
      await t.tap(find.text('cancel'));
      await t.pumpAndSettle();
      expect(c.read(wirdStartColorProvider), kWirdMarkerPalette[1].toARGB32());

      await _open(t);
      expect(_selectedIndexes(t), [1]);
      await t.tap(_swatches().at(8));
      await t.pump();
      await t.tap(find.text('cancel'));
      await t.pumpAndSettle();
      expect(c.read(wirdStartColorProvider), kWirdMarkerPalette[8].toARGB32());
    });

    testWidgets('after invalidate the next open is blank again', (t) async {
      final c = _container();
      final results = <StartSheetResult?>[];
      await _pumpHelperHost(t, c, results, readingMode: () => false);

      await _open(t);
      await t.tap(_swatches().at(1));
      await t.pump();
      await t.tap(find.text('cancel'));
      await t.pumpAndSettle();

      c.invalidate(wirdStartColorProvider);
      await _open(t);
      expect(_selectedIndexes(t), isEmpty);
      expect(_enabled(t, 'wird_start_here'), isFalse);
    });

    testWidgets(
        'a provider value outside the palette opens blank, not rewritten',
        (t) async {
      final c = _container();
      c.read(wirdStartColorProvider.notifier).state = 0xFF123456;
      final results = <StartSheetResult?>[];
      await _pumpHelperHost(t, c, results, readingMode: () => false);

      await _open(t);
      expect(_selectedIndexes(t), isEmpty);
      expect(_enabled(t, 'wird_start_here'), isFalse);
      await t.tap(find.text('cancel'));
      await t.pumpAndSettle();
      expect(c.read(wirdStartColorProvider), 0xFF123456);
    });
  });
}
