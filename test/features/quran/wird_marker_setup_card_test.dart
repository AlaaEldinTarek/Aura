// Spec: docs/designs/wird-marker.md item 28 and "Wird tab on a completed day
// (amendment 2026-11-14, third)". Phase P4a-4. The Wird tab itself (the banner
// with the card under it, the start sheet opening from the tab, the snackbar)
// is checked on a device.
import 'package:aura_app/core/models/wird.dart';
import 'package:aura_app/features/quran/wird_marker_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldShowMarkerSetupCard', () {
    test('page mode, no marker page, completed day: shown', () {
      expect(
          shouldShowMarkerSetupCard(
              unit: WirdUnit.page, markerPage: null, dayCompleted: true),
          isTrue);
    });

    test('page mode, no marker, day not completed: not shown (the action block handles it)',
        () {
      expect(
          shouldShowMarkerSetupCard(
              unit: WirdUnit.page, markerPage: null, dayCompleted: false),
          isFalse);
    });

    test('a marker exists: not shown, completed or not', () {
      for (final done in [true, false]) {
        expect(
            shouldShowMarkerSetupCard(
                unit: WirdUnit.page, markerPage: 31, dayCompleted: done),
            isFalse);
      }
    });

    test('juz mode: not shown in any case', () {
      for (final m in [null, 31]) {
        for (final done in [true, false]) {
          expect(
              shouldShowMarkerSetupCard(
                  unit: WirdUnit.juz, markerPage: m, dayCompleted: done),
              isFalse);
        }
      }
    });
  });

  group('WirdMarkerSetupCard', () {
    Widget host(WirdMarkerSetupCard card) =>
        MaterialApp(home: Scaffold(body: SingleChildScrollView(child: card)));

    testWidgets('shows the hint and both buttons', (t) async {
      await t.pumpWidget(host(WirdMarkerSetupCard(
          onSetMarker: () {}, onAddFromBookmarks: () {})));
      expect(find.text('wird_no_marker_hint'), findsOneWidget);
      expect(find.text('wird_set_marker'), findsOneWidget);
      expect(find.text('wird_add_from_bookmarks'), findsOneWidget);
    });

    testWidgets('each button calls its own callback', (t) async {
      var set = 0, add = 0;
      await t.pumpWidget(host(WirdMarkerSetupCard(
          onSetMarker: () => set++, onAddFromBookmarks: () => add++)));
      await t.tap(find.text('wird_set_marker'));
      expect([set, add], [1, 0]);
      await t.tap(find.text('wird_add_from_bookmarks'));
      expect([set, add], [1, 1]);
    });
  });
}
