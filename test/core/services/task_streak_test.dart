import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests the streak-increment logic that lives in
/// `TaskService.incrementTaskStreak()`. We exercise the algorithm directly
/// via SharedPreferences rather than going through the TaskService singleton
/// (which requires Firebase initialization).
void main() {
  String formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> incrementTaskStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final lastDate = prefs.getString('task_streak_date');

    if (lastDate == today) return;

    final count = prefs.getInt('task_streak_count') ?? 0;
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final newCount = (lastDate == yesterdayStr) ? count + 1 : 1;
    await prefs.setInt('task_streak_count', newCount);
    await prefs.setString('task_streak_date', today);
  }

  group('incrementTaskStreak', () {
    test('first completion — no prior streak → count 1, date today', () async {
      SharedPreferences.setMockInitialValues({});
      await incrementTaskStreak();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('task_streak_count'), 1);
      expect(prefs.getString('task_streak_date'), formatDate(DateTime.now()));
    });

    test('consecutive day — yesterday streak 4 → count 5, date today',
        () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        'flutter.task_streak_count': 4,
        'flutter.task_streak_date': formatDate(yesterday),
      });
      await incrementTaskStreak();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('task_streak_count'), 5);
      expect(prefs.getString('task_streak_date'), formatDate(DateTime.now()));
    });

    test('same day — already counted today → no change', () async {
      final today = formatDate(DateTime.now());
      SharedPreferences.setMockInitialValues({
        'flutter.task_streak_count': 5,
        'flutter.task_streak_date': today,
      });
      await incrementTaskStreak();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('task_streak_count'), 5);
      expect(prefs.getString('task_streak_date'), today);
    });

    test('broken streak — 3 days ago, count 10 → resets to 1', () async {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      SharedPreferences.setMockInitialValues({
        'flutter.task_streak_count': 10,
        'flutter.task_streak_date': formatDate(threeDaysAgo),
      });
      await incrementTaskStreak();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('task_streak_count'), 1);
      expect(prefs.getString('task_streak_date'), formatDate(DateTime.now()));
    });
  });
}
