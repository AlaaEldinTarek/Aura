// Spec: docs/designs/wird-marker.md item 23 (P4b). The pure decision behind the
// three Wird achievements that used to read wird_total_pages_read.
import 'package:aura_app/core/services/achievement_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nothing below the thresholds', () {
    expect(wirdAchievementIds(khatmaCount: 0, pages: 99), isEmpty);
    expect(wirdAchievementIds(khatmaCount: 0, pages: 0), isEmpty);
  });

  test('wird_pages_100 at 100 pages', () {
    expect(wirdAchievementIds(khatmaCount: 0, pages: 100), ['wird_pages_100']);
    expect(wirdAchievementIds(khatmaCount: 0, pages: 299), ['wird_pages_100']);
  });

  test('wird_pages_300 adds to wird_pages_100 at 300 pages', () {
    expect(wirdAchievementIds(khatmaCount: 0, pages: 300),
        ['wird_pages_100', 'wird_pages_300']);
  });

  test('wird_khatma at one khatma whatever the pages are', () {
    // A khatma that started at page 31 adds only 574 pages and still counts.
    expect(wirdAchievementIds(khatmaCount: 1, pages: 0), ['wird_khatma']);
    expect(wirdAchievementIds(khatmaCount: 2, pages: 574),
        ['wird_khatma', 'wird_pages_100', 'wird_pages_300']);
  });

  test('600 pages without a khatma does not award wird_khatma', () {
    expect(wirdAchievementIds(khatmaCount: 0, pages: 603),
        isNot(contains('wird_khatma')));
  });
}
