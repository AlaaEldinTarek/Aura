# F4 — Move achievement notification IDs out of the 7100–8099 range (overlaps Jumu'ah 8001)

*   **Author:** Alaa Eldin Tarek
*   **Status:** Draft, not approved. Docs only: no code is written until the owner says "approve phase P1".
*   **Level:** C (production code in `lib/`, contract doc in `.project-docs/contracts/`).
*   **Branch:** `fix/f4-achievement-ids`, from `origin/main` (5e4fc77).
*   **Date:** 2026-11-23
*   **Source:** finding F4 (`.project-docs/reference/findings.md`), rated HIGH on 2026-11-23, **downgraded to MEDIUM** on 2026-11-23 (latent: no achievement maps to 8001 today). Still fixed now.

Labels: VERIFIED = read in code or computed, UNVERIFIED = not run on a device, UNKNOWN = not checked.

---

## 1. Findings (read-only)

### 1.1 The achievement ID formula (VERIFIED)

*   `lib/core/services/notification_service.dart:1195`:
    `final id = 7100 + (achievement.id.hashCode.abs() % 1000);` → range 7100–8099.
*   The notification is **shown immediately** with `_notifications.show(id, …)` (`:1208`), never scheduled. So no alarm
    exists in the old range.
*   Single caller: `lib/features/main/main_wrapper_screen.dart:199` (Android/mobile path; desktop uses
    `DesktopNotificationService.showAchievementNotification`, which has no notification ID).
*   Channel `achievement_unlocked`; payload `achievement:<id>`; not ongoing, no timeout set.

### 1.1b Windows desktop toast (VERIFIED, independent)

`DesktopNotificationService.showAchievementNotification` is an empty no-op (`desktop_notification_service.dart:336`,
"Achievement toast is already shown by MainWrapperScreen"). The desktop path shows the in-app toast
(`_showAchievementToast`) and passes only names and emoji; it never uses a notification ID. The Android system
notification (and so these IDs) is used only when the app is **not** in the foreground
(`main_wrapper_screen.dart:194`, `inForeground` → in-app toast, else system notification). The F4 change touches
only the Android `NotificationService` path.

### 1.2 Does any achievement hash to exactly 8001 today? (VERIFIED, computed — no)

Computed with Dart SDK 3.10.7 (`windows_x64`, the same VM family as the release build) over **all 41** achievement ids
in `lib/core/models/achievement.dart`: none maps to 8001, and there are no duplicates among the 41. Closest values are
8052 (`streak_7`), 8056 (`dhikr_50`), 8079 (`on_time_50`), 8083 (`dhikr_first`), 8087 (`tasks_25`).

So the HIGH rating is for a **latent** collision, not one that fires today:

*   `String.hashCode` is not guaranteed stable across Dart SDK versions (UNVERIFIED how this app's pinned SDK behaves
    after an upgrade). A Flutter upgrade or one new achievement can land on 8001.
*   If it does land: the achievement card (shown when unlocked) **replaces** the Jumu'ah card if it is showing, and the
    Jumu'ah card replaces the achievement card. Any `cancel(8001)` would also remove it.
*   Hash collisions *between* achievements are possible too (41 ids in 1000 slots: roughly 55% chance of at least one
    pair somewhere; none today). Harmless — a card replaces another — and not part of this finding.

### 1.3 Does anything cancel achievement IDs by range? (VERIFIED, no)

*   No `cancel` call in `lib/` or `android/` takes an achievement ID or a 7100–8099 range.
*   `cancelAllNotifications()` (`notification_service.dart:936`, `_notifications.cancelAll()`) exists, but has **no
    caller** (grep over `lib/`).
*   Result: no one-time cleanup of scheduled IDs is needed. Already-posted achievement cards in the tray are plain
    (non-ongoing) cards that the user dismisses; their old IDs are not re-used by anything after this fix.

### 1.4 The "remind again" overlaps in the ID table (all NOT live)

| Overlap in the table | Verdict | Evidence |
| --- | --- | --- |
| 1–6 → 5001–5006 (`NativeReminderCard.remindAgainNotificationId = id + 5000`; Dart `scheduleRemindMeAgain` `_getNotificationId + 5000`, `:434`) | **Code exists, no live producer** (VERIFIED) | The native "Remind Me Again" button only appears when the card has a `prayerName` (`hasButtons`, `NativeReminderCard.kt:60`). The only Dart caller passing `prayerName` is `schedulePrayerNotification` (`:377`), reached only from `scheduleDailyPrayers` (`:417`), which has **no caller** in `lib/` or `test/`. Dart's own `remind_again` action (`:355`, handler `:116`) hangs off the same dead path. So IDs 1–6 are never armed, and no 5001–5006 card is produced. |
| 1001–1006 → 6001–6006 | **Not a path** (VERIFIED) | 1001–1006 are `PrayerAlarmReceiver` cards, not `NativeNotificationReceiver` cards, so they never go through `remindAgainNotificationId`. 6001–6006 are the post-check cards (own "Remind Later" via `PostCheckActions`, which re-arms its own alarm, not via +5000). |
| 4000–4999 → 9000–9999 | **Not live** (VERIFIED) | Task reminders use `TaskReminderReceiver` (own "Remind Later", `ACTION_SNOOZE`, same id), not `NativeNotificationReceiver`, and task cards carry no `prayerName`, so `hasButtons` is false. The +5000 branch can only be reached with a prayer name. |
| Wird 5100–5119 → 10100–10119 | **Not live** (VERIFIED) | Same reason: wird cards carry no `prayerName`. Also outside every other range. |

Conclusion: the table's "+5000 offset" row describes code that cannot run today. It stays a dormant risk (if the dead
Dart pre-prayer path is ever revived, 5001–5006 must be checked against 5100+ and the Flutter prayer IDs). No code
change for it in this spec; it is recorded in the contract file.

---

## 2. Goal

Achievement IDs can never equal, or fall inside, any ID or range another feature uses — by construction and by a test.
Keep 8001 and every other existing ID unchanged (contracts). Behavior otherwise identical: same title, body, channel,
payload, shown the moment an achievement unlocks.

## 3. Design

**New range: 20000–20999.** Chosen because (VERIFIED by grep over `lib/` and `android/.../kotlin`):

*   Every ID in use is below 10000, and the highest offset-derived value is 10119 (wird +5000, not live).
*   No literal ≥ 10000 is used as a notification ID or notification request code anywhere in `lib/` or the Kotlin sources.
*   It keeps the existing `% 1000` shape, so the change is one base constant, and `hashCode` behavior (same slot per
    achievement within the block) is preserved.

**One pure helper**, new file `lib/core/utils/achievement_notification_id.dart`. `String.hashCode` is replaced by a
deterministic FNV-1a 32-bit hash over `codeUnits`, so an ID depends only on the achievement id (not on the Dart SDK):

```dart
const int kAchievementNotificationIdBase = 20000;
const int kAchievementNotificationIdSlots = 1000; // 20000–20999

/// FNV-1a 32-bit over the UTF-16 code units. Stable across Dart SDK versions and platforms (VM).
int _fnv1a32(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

int achievementNotificationId(String achievementId) =>
    kAchievementNotificationIdBase + _fnv1a32(achievementId) % kAchievementNotificationIdSlots;
```

`NotificationService.showAchievementNotification` calls it instead of the inline formula. Title, body, channel and
payload are unchanged. (The multiply stays below 2^56, so it is exact on the Dart VM; the app has no web target.)

Computed with Dart 3.10.7 over the 41 ids: all values fall in 20000–20999 and none hits a reserved ID. The slots are
not unique: `early_bird` and `wird_pages_300` share slot 20678. Two cards with
the same ID replace each other, which is harmless and is the same property the old hash had; this is not part of F4.

**No cleanup code.** Shown, never scheduled (§1.3), and nothing cancels the old range. The only residue is an
achievement card already in the tray from an older build; it is dismissible and no longer shares an ID with anything
once a new card is shown. (Reasoning for not adding a `cancel` loop over 7100–8099: it would cancel 7001-adjacent and
8001 Jumu'ah cards — the exact bug being fixed.)

**Contract file** `.project-docs/contracts/notification-ids.md`: the `7100–8099` row becomes `20000–20999`
("Achievement unlocked, `20000 + hash % 1000`; moved from 7100–8099 by F4; 7100–8099 now unused, reserved — do not
reuse"), the 8001 row loses its overlap note, and the `+5000 offset` row gains "no live producer today (F4 §1.4)". Same
commit as the code.

## 4. Tests first (P1)

1. `test/core/utils/achievement_notification_id_test.dart`
    *   Every one of the 41 achievement ids → value in 20000–20999.
    *   Fuzz: 10 000 generated strings (fixed seed) → always in range.
    *   Pinned values, so any hash change is caught: `first_prayer` → 20333, `streak_7` → 20249,
        `first_task` → 20063, `wird_khatma` → 20772 (computed with the helper above on Dart 3.10.7).
    *   Reserved set guard: build the reserved list from the contract (`1–6`, `1001–1006`, `2000–2006`, `2101–2106`,
        `3000–3006`, `3999`, `4000–4999`, `5001–5006`, `5100–5119`, `5996–5999`, `6001–6006`, `7001`, `8001`,
        `9000–9006`, `9100–9102`, `9999`, plus every `+5000` image of 1–6 / 4000–4999 / 5100–5119 → up to 10119): the
        achievement block does not intersect any of it, checked as a range-versus-range test, not by sampling.
2. `test/core/utils/no_inline_achievement_id_test.dart` (T5-style text guard over `lib/`): no `7100 +` and no inline
   achievement `hashCode` formula, and no `String.hashCode` use in `achievement_notification_id.dart` outside `achievement_notification_id.dart`; `showAchievementNotification`
   must reference `achievementNotificationId(`.
3. Existing tests unchanged; run full `flutter test` and `flutter analyze` (baseline 407 issues, 0 errors).

Red first: both test files fail on `main` (helper missing / old formula), then pass after P1.

## 5. Phases

*   **P1 (code + tests + contract, one commit):** helper, call site, two test files, contract doc. No push.
*   **P2 (device, tomorrow, after F70 merges and the build is installed):** §6.

## 6. Device checks for P2 (nova 5T)

1. **Trigger.** VERIFIED: there is no developer tile or other way to fake an unlock (`profile_version_tile.dart` has
   only the digest test; unlocks come from `checkAndAward`, run after a prayer is tracked (`prayer_tracking_service.dart:134`)
   or a task is completed (`task_service.dart:536`), and `checkJuzAchievements` for Wird). The system card appears only
   when the app is **not** in the foreground, so the unlock must land while the app is backgrounded: complete the
   action (e.g. track a prayer or complete a task that earns `first_prayer` / `first_task`), then press Home at once;
   the check runs asynchronously right after. An already-earned achievement cannot be re-earned, so this depends on
   which are still locked on the owner's account (UNKNOWN until the Achievements screen is checked). No dev tile is
   added (that would be a new feature, not in this spec). If no unlock can be triggered, P2 reports that the device
   card check is BLOCKED and the unit tests stand alone. Then run
   `adb shell dumpsys notification --noredact | grep -E "id=20[0-9]{3}"` — expect the card's `id=` inside 20000–20999,
   and none in 7100–8099.
2. Jumu'ah coexistence: on a Friday with the 8001 card showing, unlock an achievement; both cards stay
   (`id=8001` and `id=20xxx`). Off Friday, UNVERIFIED by natural run; the Test Jumu'ah path, if present, can stand in.
3. Regression: the card text, channel `achievement_unlocked` and tap payload are unchanged.

## 7. Risks

*   The ID no longer depends on the SDK (FNV-1a over code units); the pinned-value test fails if the function changes.
*   A future feature taking 20000–20999 is the new overlap risk; the contract row and the range-versus-range test cover it.
*   Old-range cards already in the tray are cosmetic only (§3).

## Related (to log in the day's docs commit; not part of this PR)

*   The `+5000` remind-again branch and Dart `scheduleDailyPrayers` / `scheduleRemindMeAgain` are dead code (no caller);
    logged as a **P6 cleanup finding** in the day's docs commit (owner decision 2026-11-23). Not removed in F4.
*   `show(0, …)` at `notification_service.dart:958` uses ID 0 (a test notification); not in the table, not touched.
