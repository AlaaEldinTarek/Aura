/// Notification id block for "achievement unlocked" cards: 20000-20999 (F4). Nothing else uses an id at or above
/// 10000 (see `.project-docs/contracts/notification-ids.md`). The old block 7100-8099 overlapped the Jumu'ah
/// reminder 8001 and is now unused.
const int kAchievementNotificationIdBase = 20000;
const int kAchievementNotificationIdSlots = 1000;

/// FNV-1a 32-bit over the UTF-16 code units. Unlike `String.hashCode` it does not change between Dart SDK versions,
/// so an id depends only on the achievement id. The multiply stays below 2^56, exact on the Dart VM.
int _fnv1a32(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

int achievementNotificationId(String achievementId) =>
    kAchievementNotificationIdBase +
    _fnv1a32(achievementId) % kAchievementNotificationIdSlots;
