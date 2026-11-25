import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Source-text tests for F26 + F32c + F21 (docs/designs/fix-f26-f32c-f21.md).
/// Pins the getPrayerDisplayName call sites and the corrected surah data so
/// a future editor who reverts them sees an immediate failure — no device needed.
void main() {
  String src(String path) => File(path).readAsStringSync();

  // F26 — T1: prayer_card.dart uses getPrayerDisplayName for the name text
  test(
    'T1: prayer_card.dart calls getPrayerDisplayName and not raw prayer.nameAr for name display',
    () {
      final s = src('lib/core/widgets/prayer_card.dart');
      expect(s, contains('getPrayerDisplayName(prayer.name, isArabic: isArabic)'),
          reason: 'getPrayerDisplayName call missing from prayer_card.dart');
      expect(s, contains("import '../utils/prayer_time_rules.dart'"),
          reason: 'prayer_time_rules.dart import missing from prayer_card.dart');
      // The old raw ternary must no longer exist for the name Text widget
      expect(s, isNot(contains('isArabic ? prayer.nameAr : prayer.name')),
          reason: 'Raw prayer.nameAr ternary still present in prayer_card.dart');
    },
  );

  // F32c — T2: home_screen.dart uses getPrayerDisplayName instead of the hard-coded Arabic array
  test(
    'T2: home_screen.dart uses getPrayerDisplayName for prayer progress labels',
    () {
      final s = src('lib/features/home/home_screen.dart');
      expect(
          s,
          contains(
              "getPrayerDisplayName(trackablePrayers[i], isArabic: isArabic)"),
          reason: 'getPrayerDisplayName call missing from home_screen.dart prayer labels');
      // The hard-coded Zuhr Arabic literal used only in the old label context must be gone
      expect(s, isNot(contains("'الظهر'")),
          reason: "Hard-coded 'الظهر' still present in home_screen.dart");
    },
  );

  // F21 — T3: quran_models.dart has exactly 28 RevelationType.madani entries
  test(
    'T3: quran_models.dart has 28 madani surahs (surahs 3, 4, 5, 8 corrected)',
    () {
      final s = src('lib/core/models/quran_models.dart');
      final madaniCount =
          'RevelationType.madani'.allMatches(s).length;
      expect(madaniCount, 28,
          reason: 'Expected 28 madani entries in kSurahMetaData, got $madaniCount');
      // Spot-check: none of the four corrected surahs use makki with their page ranges
      expect(s, isNot(contains('RevelationType.makki, 50, 76')),
          reason: 'Surah 3 (Āl-ʿImrān) still marked makki');
      expect(s, isNot(contains('RevelationType.makki, 77, 106')),
          reason: 'Surah 4 (An-Nisāʾ) still marked makki');
      expect(s, isNot(contains('RevelationType.makki, 106, 127')),
          reason: 'Surah 5 (Al-Māʾidah) still marked makki');
      expect(s, isNot(contains('RevelationType.makki, 177, 186')),
          reason: 'Surah 8 (Al-Anfāl) still marked makki');
    },
  );
}
