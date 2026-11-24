import 'dart:math';

import 'package:aura_app/core/models/achievement.dart';
import 'package:aura_app/core/utils/achievement_notification_id.dart';
import 'package:flutter_test/flutter_test.dart';

/// F4: achievement notification IDs live in 20000-20999 and can never touch an ID another feature uses.
/// Reserved IDs come from `.project-docs/contracts/notification-ids.md`.
const _reserved = <(int, int)>[
  (1, 6), (1001, 1006), (2000, 2006), (2101, 2106), (3000, 3006), (3999, 3999),
  (4000, 4999), (5001, 5006), (5100, 5119), (5996, 5999), (6001, 6006),
  (7001, 7001), (7100, 8099), (8001, 8001), (9000, 9006), (9100, 9102),
  (9999, 9999),
  // +5000 "remind again" images (dormant, F4 spec 1.4): 1-6, 4000-4999, 5100-5119
  (5001, 5006), (9000, 9999), (10100, 10119),
];

void main() {
  const lo = kAchievementNotificationIdBase;
  const hi =
      kAchievementNotificationIdBase + kAchievementNotificationIdSlots - 1;

  test('block is 20000-20999 and intersects no reserved id or range', () {
    expect(lo, 20000);
    expect(hi, 20999);
    for (final (a, b) in _reserved) {
      expect(hi < a || lo > b, isTrue, reason: 'overlaps reserved $a-$b');
    }
  });

  test('every achievement id maps into the block', () {
    expect(AchievementDefinitions.all.length, 41);
    for (final a in AchievementDefinitions.all) {
      final id = achievementNotificationId(a.id);
      expect(id, inInclusiveRange(lo, hi), reason: a.id);
    }
  });

  test('10000 fuzzed strings map into the block', () {
    final rnd = Random(4);
    for (var i = 0; i < 10000; i++) {
      final s = String.fromCharCodes(
          List.generate(rnd.nextInt(30), (_) => rnd.nextInt(0x600)));
      expect(achievementNotificationId(s), inInclusiveRange(lo, hi));
    }
  });

  test('pinned values: a hash change is caught', () {
    expect(achievementNotificationId('first_prayer'), 20333);
    expect(achievementNotificationId('streak_7'), 20249);
    expect(achievementNotificationId('first_task'), 20063);
    expect(achievementNotificationId('wird_khatma'), 20772);
  });
}
