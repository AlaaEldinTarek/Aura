import 'package:aura_app/core/utils/post_check_remind_timers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec: docs/designs/fix-post-check-remind-later.md, Windows part (Remind Later on the toast).
void main() {
  testWidgets(
      'Remind Later starts one 15-minute timer and then calls back once',
      (tester) async {
    {
      final timers = PostCheckRemindTimers();
      var fired = 0;
      timers.schedule('Zuhr', () => fired++);
      expect(timers.pendingCount, 1);
      await tester.pump(const Duration(minutes: 14, seconds: 59));
      expect(fired, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(fired, 1);
      expect(timers.pendingCount, 0);
    }
  });

  testWidgets('a second tap for the same prayer replaces the pending timer',
      (tester) async {
    {
      final timers = PostCheckRemindTimers();
      var first = 0;
      var second = 0;
      timers.schedule('Asr', () => first++);
      await tester.pump(const Duration(minutes: 5));
      timers.schedule('Asr', () => second++);
      expect(timers.pendingCount, 1);
      await tester.pump(const Duration(minutes: 16));
      expect(first, 0);
      expect(second, 1);
    }
  });

  testWidgets('different prayers keep separate timers; cancelAll clears them',
      (tester) async {
    {
      final timers = PostCheckRemindTimers();
      var a = 0;
      var b = 0;
      timers.schedule('Asr', () => a++);
      timers.schedule('Maghrib', () => b++);
      expect(timers.pendingCount, 2);
      timers.cancelAll();
      expect(timers.pendingCount, 0);
      await tester.pump(const Duration(minutes: 20));
      expect(a + b, 0);
    }
  });

  testWidgets('the delay is a parameter (default 15 minutes)', (tester) async {
    {
      final timers = PostCheckRemindTimers(delay: const Duration(minutes: 1));
      var fired = 0;
      timers.schedule('Isha', () => fired++);
      await tester.pump(const Duration(minutes: 1, seconds: 1));
      expect(fired, 1);
      expect(PostCheckRemindTimers.defaultDelay, const Duration(minutes: 15));
    }
  });
}
