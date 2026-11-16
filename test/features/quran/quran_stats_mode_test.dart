// Spec: docs/designs/mode-separation.md, decision E (M3): the stats screen shows
// only the active mode's numbers. Strings show as their keys (no
// EasyLocalization); the numbers are checked as text.
import 'package:aura_app/core/models/wird.dart';
import 'package:aura_app/core/providers/wird_provider.dart';
import 'package:aura_app/features/quran/quran_stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

QuranStatsData _data(WirdUnit unit) => QuranStatsData(
      weeklyPages: const [0, 0, 0, 0, 0, 0, 0],
      weeklyJuz: const [0, 0, 0, 0, 0, 0, 0],
      totalPages: 583,
      totalDays: 4,
      currentStreak: 2,
      bestStreak: 3,
      averageDaily: 1.0,
      khatmCount: 7,
      allCompletedJuz: const [1, 2, 3],
      wirdUnit: unit,
    );

Future<void> _pump(WidgetTester t, WirdUnit unit) async {
  t.view.physicalSize = const Size(600, 2400);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [
      quranStatsProvider.overrideWith((ref) async => _data(unit)),
    ],
    child: const MaterialApp(home: QuranStatsScreen()),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('page mode: pages and the khatma count, no juz progress',
      (t) async {
    await _pump(t, WirdUnit.page);
    expect(find.text('583'), findsOneWidget);
    expect(find.text('quran_stats_header_pages'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('quran_stats_khatm_progress'), findsNothing);
    expect(find.text('3/30'), findsNothing);
  });

  testWidgets('juz mode: checked cards and the khatma count, no pages total',
      (t) async {
    await _pump(t, WirdUnit.juz);
    expect(find.text('583'), findsNothing);
    expect(find.text('quran_stats_header_pages'), findsNothing);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('quran_stats_khatm_progress'), findsOneWidget);
    expect(find.text('3/30'), findsOneWidget);
  });

  testWidgets('streak and days stay in both modes (decision D)', (t) async {
    for (final unit in WirdUnit.values) {
      await _pump(t, unit);
      expect(find.text('quran_stats_current_streak'), findsOneWidget);
      expect(find.text('quran_stats_best_streak'), findsOneWidget);
      expect(find.text('quran_stats_days_active'), findsOneWidget);
    }
  });
}
