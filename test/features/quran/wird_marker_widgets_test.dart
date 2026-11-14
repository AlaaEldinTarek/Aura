// Short widget and logic tests for wird_marker_widgets.dart (spec item 9).
import 'package:aura_app/core/models/quran_models.dart';
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

const _undo = WirdUndoRecord(
  previousPage: 31,
  pagesAdded: 5,
  dateKey: '2026-11-13',
  grantedStreakCredit: false,
  cycle: 0,
  versionAfterMove: 1,
);

WirdState _state({
  WirdUnit unit = WirdUnit.page,
  WirdMarkerRecord? marker,
  WirdUndoRecord? undo,
}) =>
    WirdState(
      settings: WirdSettings(wirdUnit: unit),
      marker: marker,
      undo: undo,
    );

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

QuranBookmark _bm(String id, int page, DateTime at,
        {String ar = 'ar', String en = 'en'}) =>
    QuranBookmark(
      id: id,
      suraNo: 1,
      ayaNo: 1,
      page: page,
      suraNameAr: ar,
      suraNameEn: en,
      ayaText: '',
      createdAt: at,
    );

void main() {
  group('ribbon shows only on the marker page', () {
    Widget layer(WirdState s, int currentPage) => _host(Stack(children: [
          WirdMarkerRibbonLayer(state: s, currentPage: currentPage, top: 0),
        ]));

    testWidgets('shown on the marker page in page mode', (t) async {
      await t.pumpWidget(layer(_state(marker: _marker(page: 31)), 31));
      expect(find.byType(WirdMarkerRibbon), findsOneWidget);
    });

    testWidgets('hidden on any other page', (t) async {
      await t.pumpWidget(layer(_state(marker: _marker(page: 31)), 30));
      expect(find.byType(WirdMarkerRibbon), findsNothing);
      await t.pumpWidget(layer(_state(marker: _marker(page: 31)), 32));
      expect(find.byType(WirdMarkerRibbon), findsNothing);
    });

    testWidgets('hidden with no marker or a null marker page', (t) async {
      await t.pumpWidget(layer(_state(), 31));
      expect(find.byType(WirdMarkerRibbon), findsNothing);
      await t.pumpWidget(layer(_state(marker: _marker(page: null)), 1));
      expect(find.byType(WirdMarkerRibbon), findsNothing);
    });

    testWidgets('hidden in juz mode even on the marker page', (t) async {
      await t.pumpWidget(
          layer(_state(unit: WirdUnit.juz, marker: _marker(page: 31)), 31));
      expect(find.byType(WirdMarkerRibbon), findsNothing);
    });

    testWidgets(
        'is 14 x 30 dp and sits at the given top, 8 dp from the right edge',
        (t) async {
      await t.pumpWidget(_host(Stack(children: [
        WirdMarkerRibbonLayer(
            state: _state(marker: _marker(page: 7)), currentPage: 7, top: 56),
      ])));
      final box = t.getRect(find.byType(WirdMarkerRibbon));
      expect(box.width, 14);
      expect(box.height, 30);
      expect(box.top, 56);
      final screen = t.getSize(find.byType(Scaffold));
      expect(screen.width - box.right, 8);
    });

    test('shouldShowWirdRibbon', () {
      expect(
          shouldShowWirdRibbon(
              unit: WirdUnit.page, markerPage: 5, currentPage: 5),
          isTrue);
      expect(
          shouldShowWirdRibbon(
              unit: WirdUnit.page, markerPage: 5, currentPage: 6),
          isFalse);
      expect(
          shouldShowWirdRibbon(
              unit: WirdUnit.page, markerPage: null, currentPage: 5),
          isFalse);
      expect(
          shouldShowWirdRibbon(
              unit: WirdUnit.juz, markerPage: 5, currentPage: 5),
          isFalse);
    });
  });

  group('Undo last move button', () {
    Widget button(WirdState s,
            {bool offline = false, VoidCallback? onPressed}) =>
        _host(WirdUndoMoveButton(
            state: s, offline: offline, onPressed: onPressed ?? () {}));

    testWidgets('appears only with a valid undo record in page mode',
        (t) async {
      await t.pumpWidget(button(_state(marker: _marker(), undo: _undo)));
      expect(find.text('wird_undo_last_move'), findsOneWidget);
    });

    testWidgets('hidden with no undo record', (t) async {
      await t.pumpWidget(button(_state(marker: _marker())));
      expect(find.byIcon(Icons.undo), findsNothing);
    });

    testWidgets('hidden in juz mode', (t) async {
      await t.pumpWidget(
          button(_state(unit: WirdUnit.juz, marker: _marker(), undo: _undo)));
      expect(find.byIcon(Icons.undo), findsNothing);
    });

    testWidgets('label is "Connect to undo" while offline and signed in',
        (t) async {
      await t.pumpWidget(
          button(_state(marker: _marker(), undo: _undo), offline: true));
      expect(find.text('wird_undo_connect'), findsOneWidget);
      expect(find.text('wird_undo_last_move'), findsNothing);
    });

    testWidgets('a tap calls onPressed in both labels', (t) async {
      var taps = 0;
      await t.pumpWidget(button(_state(marker: _marker(), undo: _undo),
          onPressed: () => taps++));
      await t.tap(find.byIcon(Icons.undo));
      await t.pumpWidget(button(_state(marker: _marker(), undo: _undo),
          offline: true, onPressed: () => taps++));
      await t.tap(find.byIcon(Icons.undo));
      expect(taps, 2);
    });
  });

  group('Restart Wird tile', () {
    Widget tile(WirdState s) =>
        _host(WirdRestartTile(state: s, onPressed: () {}));

    testWidgets('appears in page mode with a marker', (t) async {
      await t.pumpWidget(tile(_state(marker: _marker())));
      expect(find.text('wird_restart'), findsOneWidget);
    });

    testWidgets('hidden with no marker or after a restart (null marker page)',
        (t) async {
      await t.pumpWidget(tile(_state()));
      expect(find.text('wird_restart'), findsNothing);
      await t.pumpWidget(tile(_state(marker: _marker(page: null))));
      expect(find.text('wird_restart'), findsNothing);
    });

    testWidgets('hidden in juz mode even with a kept marker', (t) async {
      await t.pumpWidget(tile(_state(unit: WirdUnit.juz, marker: _marker())));
      expect(find.text('wird_restart'), findsNothing);
    });
  });

  group('bookmark pick rows', () {
    test('one row per page, earliest createdAt wins, sorted by page', () {
      final rows = bookmarkPickRows([
        _bm('c', 300, DateTime(2026, 1, 3)),
        _bm('a2', 10, DateTime(2026, 1, 5), en: 'later'),
        _bm('a1', 10, DateTime(2026, 1, 2), en: 'earlier'),
        _bm('b', 50, DateTime(2026, 1, 1)),
      ]);
      expect(rows.map((b) => b.page).toList(), [10, 50, 300]);
      expect(rows.first.id, 'a1');
    });

    test('empty list gives no rows', () {
      expect(bookmarkPickRows(const []), isEmpty);
    });
  });

  group('undo outcome message', () {
    test('maps every outcome to its string key', () {
      expect(undoOutcomeMessageKey(const UndoDone()), 'wird_undo_done');
      expect(undoOutcomeMessageKey(const UndoCloudNewer()),
          'wird_undo_cloud_newer');
      expect(undoOutcomeMessageKey(const UndoNeedsConnection()),
          'wird_undo_connect');
      for (final f in [
        MarkerFailure.noUndo,
        MarkerFailure.staleDay,
        MarkerFailure.staleRecord,
        MarkerFailure.noMarker,
      ]) {
        expect(undoOutcomeMessageKey(UndoFailed(f)), 'wird_undo_stale');
      }
    });
  });

  group('wirdReadingPage', () {
    test('opens at the marker page when a marker exists', () {
      expect(wirdReadingPage(_state(marker: _marker(page: 31)), 5, 1), 31);
    });
    test('falls back to progress page without a marker page', () {
      expect(wirdReadingPage(_state(marker: _marker(page: null)), 5, 1), 5);
      expect(wirdReadingPage(_state(), 5, 1), 5);
    });
    test('falls back to the start page with nothing', () {
      expect(wirdReadingPage(_state(), null, 1), 1);
    });
  });

  group('wirdRangeStart', () {
    test('uses the marker page when there is no progress today', () {
      expect(wirdRangeStart(_state(marker: _marker(page: 31)), null), 31);
    });
    test('progress start page wins once a move happened today', () {
      expect(wirdRangeStart(_state(marker: _marker(page: 36)), 31), 31);
    });
    test('falls back to page 1 with neither', () {
      expect(wirdRangeStart(_state(), null), 1);
      expect(wirdRangeStart(_state(marker: _marker(page: null)), null), 1);
    });
  });

  group('showMarkerMovedSnackBar', () {
    Future<ScaffoldMessengerState> host(WidgetTester t) async {
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      return ScaffoldMessenger.of(t.element(find.byType(Scaffold)));
    }

    testWidgets('shows message and Undo, then disappears by itself', (t) async {
      final m = await host(t);
      showMarkerMovedSnackBar(m, message: 'moved 8', undoLabel: 'Undo', onUndo: () {});
      await t.pump();
      expect(find.text('moved 8'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      await t.pump(const Duration(seconds: 1)); // entrance animation, starts the timer
      await t.pump(const Duration(seconds: 6));
      await t.pumpAndSettle();
      expect(find.text('moved 8'), findsNothing);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('a new move replaces the old snackbar instead of queueing', (t) async {
      final m = await host(t);
      showMarkerMovedSnackBar(m, message: 'moved 8', undoLabel: 'Undo', onUndo: () {});
      await t.pump();
      showMarkerMovedSnackBar(m, message: 'moved 11', undoLabel: 'Undo', onUndo: () {});
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('moved 8'), findsNothing);
      expect(find.text('moved 11'), findsOneWidget);
      await t.pump(const Duration(seconds: 1)); // entrance animation, starts the timer
      await t.pump(const Duration(seconds: 6));
      await t.pumpAndSettle();
      expect(find.text('moved 8'), findsNothing);
    });

    testWidgets('Undo calls onUndo', (t) async {
      final m = await host(t);
      var called = 0;
      showMarkerMovedSnackBar(m, message: 'x', undoLabel: 'Undo', onUndo: () => called++);
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      await t.tap(find.text('Undo'));
      expect(called, 1);
    });
  });
}
