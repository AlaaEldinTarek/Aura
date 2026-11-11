import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime clampInitialDate(DateTime? selectedDueDate, DateTime now) {
    return (selectedDueDate != null && selectedDueDate.isAfter(now))
        ? selectedDueDate
        : now;
  }

  group('Date picker initialDate clamp', () {
    test('past due date → clamped to today', () {
      final now = DateTime(2026, 11, 11);
      final yesterday = DateTime(2026, 11, 10);
      expect(clampInitialDate(yesterday, now), now);
    });

    test('future due date → unchanged', () {
      final now = DateTime(2026, 11, 11);
      final tomorrow = DateTime(2026, 11, 12);
      expect(clampInitialDate(tomorrow, now), tomorrow);
    });

    test('null due date → falls back to today', () {
      final now = DateTime(2026, 11, 11);
      expect(clampInitialDate(null, now), now);
    });
  });
}
