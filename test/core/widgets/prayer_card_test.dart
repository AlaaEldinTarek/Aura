import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura_app/core/widgets/prayer_card.dart';
import 'package:aura_app/core/models/prayer_time.dart';
import 'package:aura_app/core/models/prayer_record.dart';

/// Helper to create a PrayerTime for testing
PrayerTime _makePrayer({
  String name = 'Fajr',
  String nameAr = 'الفجر',
  DateTime? time,
}) {
  return PrayerTime(
    name: name,
    nameAr: nameAr,
    time: time ?? DateTime(2026, 4, 10, 5, 30),
    isNext: false,
    isCurrent: false,
  );
}

Widget _buildTestWidget(PrayerCard card) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: card),
    ),
  );
}

void main() {
  group('PrayerCard', () {
    testWidgets('displays prayer name in English', (tester) async {
      final prayer = _makePrayer(name: 'Fajr', nameAr: 'الفجر');
      await tester.pumpWidget(_buildTestWidget(
        PrayerCard(prayer: prayer),
      ));

      expect(find.text('Fajr'), findsOneWidget);
    });

    testWidgets('displays prayer time', (tester) async {
      final prayer = _makePrayer();
      await tester.pumpWidget(_buildTestWidget(
        PrayerCard(prayer: prayer),
      ));

      expect(find.text('5:30 AM'), findsOneWidget);
    });

    testWidgets('shows correct emoji for Fajr', (tester) async {
      final prayer = _makePrayer(name: 'Fajr');
      await tester.pumpWidget(_buildTestWidget(
        PrayerCard(prayer: prayer),
      ));

      expect(find.text('🌙'), findsOneWidget);
    });

    testWidgets('shows correct emoji for Dhuhr', (tester) async {
      final prayer = _makePrayer(name: 'Dhuhr');
      await tester.pumpWidget(
        _buildTestWidget(PrayerCard(prayer: prayer)),
      );

      expect(find.text('☀️'), findsOneWidget);
    });

    testWidgets('shows correct emoji for Maghrib', (tester) async {
      final prayer = _makePrayer(name: 'Maghrib');
      await tester.pumpWidget(
        _buildTestWidget(PrayerCard(prayer: prayer)),
      );

      expect(find.text('🌇'), findsOneWidget);
    });

    testWidgets('shows chevron when no action available', (tester) async {
      final prayer = _makePrayer();
      await tester.pumpWidget(_buildTestWidget(
        PrayerCard(prayer: prayer),
      ));

      // Should have a chevron_right icon (no mark button, not next prayer)
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('shows mark prayed button when callback provided', (tester) async {
      final prayer = _makePrayer();
      await tester.pumpWidget(_buildTestWidget(
        PrayerCard(
          prayer: prayer,
          onMarkPrayed: () {},
        ),
      ));

      expect(find.text('Prayed'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('shows completed indicator with on-time status', (tester) async {
      final prayer = _makePrayer();
      await tester.pumpWidget(_buildTestWidget(
        PrayerCard(
          prayer: prayer,
          isCompleted: true,
          prayerStatus: PrayerStatus.onTime,
          wasExplicitlyMarked: true,
          onMarkPrayed: () {},
        ),
      ));

      expect(find.text('On Time'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows completed indicator with late status', (tester) async {
      final prayer = _makePrayer();
      await tester.pumpWidget(_buildTestWidget(
        PrayerCard(
          prayer: prayer,
          isCompleted: true,
          prayerStatus: PrayerStatus.late,
          wasExplicitlyMarked: true,
          onMarkPrayed: () {},
        ),
      ));

      expect(find.text('Late'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('shows completed indicator with excused status', (tester) async {
      final prayer = _makePrayer();
      await tester.pumpWidget(_buildTestWidget(
        PrayerCard(
          prayer: prayer,
          isCompleted: true,
          prayerStatus: PrayerStatus.excused,
          wasExplicitlyMarked: true,
          onMarkPrayed: () {},
        ),
      ));

      expect(find.text('Missed'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('shows NOW badge for current prayer', (tester) async {
      final prayer = _makePrayer();
      await tester.pumpWidget(_buildTestWidget(
        PrayerCard(prayer: prayer, isCurrent: true),
      ));

      expect(find.text('NOW'), findsOneWidget);
    });

    testWidgets('does not show NOW badge for non-current prayer', (tester) async {
      final prayer = _makePrayer();
      await tester.pumpWidget(_buildTestWidget(
        PrayerCard(prayer: prayer, isCurrent: false),
      ));

      expect(find.text('NOW'), findsNothing);
    });

    testWidgets('onMarkPrayed callback is triggered on tap', (tester) async {
      var tapped = false;
      final prayer = _makePrayer();
      await tester.pumpWidget(_buildTestWidget(
        PrayerCard(
          prayer: prayer,
          onMarkPrayed: () => tapped = true,
        ),
      ));

      await tester.tap(find.text('Prayed'));
      expect(tapped, isTrue);
    });
  });
}
