// Spec: docs/designs/mode-separation.md, M3 (a), (b), (c): the Juz -> Pages
// dialog, Pages -> Juz with no dialog, and the marker suggestion hand-off
// (decisions A, F, G). The strings show as their keys (no EasyLocalization).
import 'dart:convert';

import 'package:aura_app/core/models/wird.dart';
import 'package:aura_app/core/models/wird_marker.dart';
import 'package:aura_app/core/providers/wird_provider.dart';
import 'package:aura_app/core/services/wird_marker_service.dart';
import 'package:aura_app/core/services/wird_service.dart';
import 'package:aura_app/features/quran/wird_mode_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Cloud implements WirdMarkerCloud {
  @override
  Future<CloudRead> readServer(String uid) async => const CloudReadAbsent();
  @override
  Future<MarkerPushResult> write(String uid, WirdMarkerRecord record) async =>
      const MarkerPushed();
}

class _NoCloudWird extends WirdService {
  _NoCloudWird(DateTime Function() now) : super.forTesting(now: now);
  @override
  Future<void> syncFromFirestore(String userId) async {}
}

class SpyWirdNotifier extends WirdNotifier {
  SpyWirdNotifier(
      {required super.wird, required super.marker, required super.uid})
      : super(
            juzCheck: ({
          required String userId,
          required int juzKhatmCount,
          required int checkedJuz,
        }) async {});
  int switchCalls = 0;

  @override
  Future<void> switchToPageMode({Duration? checkTimeout}) {
    switchCalls++;
    return checkTimeout == null
        ? super.switchToPageMode()
        : super.switchToPageMode(checkTimeout: checkTimeout);
  }
}

final _clock = DateTime(2026, 11, 15, 10);
late SpyWirdNotifier spy;
late ProviderContainer container;

Map<String, Object> _prefs({required bool juz, List<int> cards = const []}) => {
      'wird_settings': jsonEncode(
          WirdSettings(wirdUnit: juz ? WirdUnit.juz : WirdUnit.page).toJson()),
      'wird_completed_juz': jsonEncode(cards),
    };

Future<void> _pump(
  WidgetTester t,
  Map<String, Object> prefs, {
  int? markerPage,
}) async {
  t.view.physicalSize = const Size(600, 1200);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final wird = _NoCloudWird(() => _clock);
  final marker = WirdMarkerService.forTesting(
      cloud: _Cloud(), wird: wird, now: () => _clock, uid: () => null);
  if (markerPage != null) {
    await marker.save(WirdMarkerRecord(
      markerPage: markerPage,
      startPage: markerPage,
      color: 0xFF1E88E5,
      version: 1,
    ));
  }
  spy = SpyWirdNotifier(wird: wird, marker: marker, uid: () => null);
  container = ProviderContainer(
      overrides: [wirdStateProvider.overrideWith((ref) => spy)]);
  addTearDown(container.dispose);
  container.listen(wirdStateProvider, (_, __) {});
  await t.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => Column(children: [
            TextButton(
              onPressed: () =>
                  changeWirdUnit(context, ref, WirdUnit.page, lang: 'en'),
              child: const Text('go-page'),
            ),
            TextButton(
              onPressed: () =>
                  changeWirdUnit(context, ref, WirdUnit.juz, lang: 'en'),
              child: const Text('go-juz'),
            ),
          ]),
        ),
      ),
    ),
  ));
  await t.runAsync(() => pumpEventQueue(times: 60));
  await t.pump();
}

WirdState _st() => container.read(wirdStateProvider).requireValue;

Future<void> _tap(WidgetTester t, String text) async {
  await t.tap(find.text(text));
  await t.pump();
  await t.runAsync(() => pumpEventQueue(times: 60));
  await t.pumpAndSettle();
}

Finder _swatch(int i) => find.byKey(ValueKey('wird_start_swatch_$i'));

void main() {
  group('Juz -> Pages dialog', () {
    testWidgets('shows title, body, Switch and the existing Cancel', (t) async {
      await _pump(t, _prefs(juz: true, cards: [1, 2]));
      await _tap(t, 'go-page');
      expect(find.text('wird_mode_switch_title'), findsOneWidget);
      expect(find.text('wird_mode_switch_body'), findsOneWidget);
      expect(find.text('wird_mode_switch_confirm'), findsOneWidget);
      expect(find.text('cancel'), findsOneWidget);
    });

    testWidgets('Cancel changes nothing and does not call switchToPageMode',
        (t) async {
      await _pump(t, _prefs(juz: true, cards: [1, 2, 3]));
      await _tap(t, 'go-page');
      await _tap(t, 'cancel');
      expect(spy.switchCalls, 0);
      expect(_st().settings.wirdUnit, WirdUnit.juz);
      expect(_st().allCompletedJuz, [1, 2, 3]);
      expect(find.text('wird_mode_switch_title'), findsNothing);
      expect(find.text('wird_start_here'), findsNothing);
    });

    testWidgets('Confirm calls switchToPageMode once and empties the cards',
        (t) async {
      await _pump(t, _prefs(juz: true, cards: [1, 2, 3]));
      await _tap(t, 'go-page');
      await _tap(t, 'wird_mode_switch_confirm');
      expect(spy.switchCalls, 1);
      expect(_st().settings.wirdUnit, WirdUnit.page);
      expect(_st().allCompletedJuz, isEmpty);
    });
  });

  group('Pages -> Juz', () {
    testWidgets('no dialog, switches at once, empties nothing', (t) async {
      await _pump(t, _prefs(juz: false, cards: [1, 2, 3]));
      await _tap(t, 'go-juz');
      expect(find.text('wird_mode_switch_title'), findsNothing);
      expect(spy.switchCalls, 0);
      expect(_st().settings.wirdUnit, WirdUnit.juz);
      expect(_st().allCompletedJuz, [1, 2, 3]);
    });
  });

  group('Marker suggestion after a confirmed switch', () {
    testWidgets('cards 1 to 4: the start sheet opens and places page 82',
        (t) async {
      await _pump(t, _prefs(juz: true, cards: [1, 2, 3, 4]));
      await _tap(t, 'go-page');
      await _tap(t, 'wird_mode_switch_confirm');
      expect(find.text('wird_start_sheet_title'), findsOneWidget);
      await t.tap(_swatch(0));
      await t.pump();
      await _tap(t, 'wird_start_here');
      expect(_st().marker?.markerPage, 82);
      expect(_st().settings.wirdUnit, WirdUnit.page);
    });

    testWidgets('Cancel on the sheet places no marker', (t) async {
      await _pump(t, _prefs(juz: true, cards: [1, 2, 3, 4]));
      await _tap(t, 'go-page');
      await _tap(t, 'wird_mode_switch_confirm');
      await _tap(t, 'cancel');
      expect(_st().marker?.markerPage, isNull);
      expect(_st().allCompletedJuz, isEmpty);
    });

    testWidgets('a marker already exists: no sheet (decision G)', (t) async {
      await _pump(t, _prefs(juz: true, cards: [1, 2, 3, 4]), markerPage: 31);
      await _tap(t, 'go-page');
      await _tap(t, 'wird_mode_switch_confirm');
      expect(find.text('wird_start_sheet_title'), findsNothing);
      expect(_st().marker?.markerPage, 31);
    });

    testWidgets('no card checked: no sheet', (t) async {
      await _pump(t, _prefs(juz: true));
      await _tap(t, 'go-page');
      await _tap(t, 'wird_mode_switch_confirm');
      expect(find.text('wird_start_sheet_title'), findsNothing);
    });

    testWidgets('all 30 checked: no sheet', (t) async {
      await _pump(
          t, _prefs(juz: true, cards: [for (var i = 1; i <= 30; i++) i]));
      await _tap(t, 'go-page');
      await _tap(t, 'wird_mode_switch_confirm');
      expect(find.text('wird_start_sheet_title'), findsNothing);
    });

    testWidgets('Pages -> Juz never opens the sheet', (t) async {
      await _pump(t, _prefs(juz: false, cards: [1, 2, 3, 4]));
      await _tap(t, 'go-juz');
      expect(find.text('wird_start_sheet_title'), findsNothing);
    });
  });
}
