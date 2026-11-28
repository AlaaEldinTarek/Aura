# Fix spec: 23 failing tests on main

Status: Draft — awaiting `approve phase P1`

Branch: `fix/test-failures` (from main 859f117). Behavior-preserving: no UI, prefs,
Firestore, notification or channel change.

## Finding

`flutter test` on main 859f117 gives 971 passed, 23 failed (VERIFIED, run 2026-11-28).
The same 23 fail on `fix/f48a`, so none comes from the Qibla work. Three causes:

| Group | Tests | Cause (VERIFIED from failure output and git history) |
| --- | --- | --- |
| G1 | 21: `wird_marker_service_test.dart` (19), `wird_provider_test.dart` (2) | Commit b09687b (F52h, 2026-11-26) added `AchievementService.instance.checkAndAward(...)` to `WirdMarkerService.moveMarker` and `completeKhatma` (lines 349, 374). `AchievementService` has the field `FirebaseFirestore.instance`, so the first call throws `[core/no-app]` in tests, which never initialise Firebase. Tests could not inject it. |
| G2 | 1: `wird_mode_switch_strings_test.dart` "the three new keys are the last three" | Commit 7f17c93 (F43b+F46b, 2026-11-26) appended `onboarding_slide_full_3_f1..f3` to both JSON files. The three `wird_mode_switch_*` keys (positions 572 to 574 in both files) are no longer last. Texts, order and parity are still correct. |
| G3 | 1: `f30b_source_test.dart` T1 | Commit b09687b (F52n) rewrote `_applySort` to split pinned and unpinned lists, so the pattern `a.isPinned ? -1 : 1` now appears 7 times (one per dated section), not 8. Behavior is intended; covered by `f52n_source_test.dart`. |

## Fix (phase P1, one commit per group)

**G1 — inject the achievement call (lib + 2 test files)**
- `lib/core/services/wird_marker_service.dart`: add an optional field
  `Future<void> Function(String userId) _awardAchievements`. The private
  constructor and `instance` default to
  `(id) => AchievementService.instance.checkAndAward(userId: id)`.
  `forTesting` gets an optional named parameter `awardAchievements`, same default.
  The two call sites call the field instead of the singleton, still unawaited with
  the same `_uid() ?? 'guest_user'` argument. Production behavior is identical.
- `test/core/services/wird_marker_service_test.dart` and
  `test/core/providers/wird_provider_test.dart`: pass a no-op `awardAchievements`
  (the first one also records the user ids so one test can assert the call
  happens on a move and on a khatma, with `'guest_user'` for a guest).
- `WirdNotifier` (`lib/core/providers/wird_provider.dart:94`) is not changed; it
  keeps the default.

**G2 — `wird_mode_switch_strings_test.dart`**
Replace "the last three" with "the three keys are consecutive and in the same
order in both files": find the index of `wird_mode_switch_title` in each file and
expect the next three keys to equal the wanted list. Update the test name and the
comment above it.

**G3 — `f30b_source_test.dart`**
Expect `>= 7` (one per dated section) instead of `>= 8`; update the header comment,
the test name and the failure reason to say `_applySort` no longer uses the pattern
(F52n partitions pinned and unpinned lists).

## Files changed

| File | Change |
| --- | --- |
| `lib/core/services/wird_marker_service.dart` | injectable `awardAchievements`, default = current behavior |
| `test/core/services/wird_marker_service_test.dart` | pass a fake `awardAchievements`; add call-recording test |
| `test/core/providers/wird_provider_test.dart` | pass a fake `awardAchievements` |
| `test/features/dhikl/f52hl_source_test.dart` | found while implementing G1: its source-text check for the literal `AchievementService.instance.checkAndAward` in `moveMarker` and `completeKhatma` now looks for `_awardAchievements(` there, plus one check that the default is the real call |
| `test/features/quran/wird_mode_switch_strings_test.dart` | consecutive-keys check |
| `test/features/tasks/f30b_source_test.dart` | expect 7 |

Not touched: `AchievementService`, the translation JSON files, `tasks_screen.dart`,
prefs keys, Firestore paths, notification IDs. `wird_marker_service.dart` is not on
the "edit carefully" list in CLAUDE.md, and this change alters no key, channel or path.

## Verification

1. `flutter analyze`: 0 errors, 0 warnings (info lints unchanged).
2. `flutter test`: 994 passed, 0 failed on this branch.
3. Not device-checked: no runtime behavior changes (the default achievement call is
   the same one that runs today).

## Risks

- G1 touches production code. Risk is a wrong default; it is covered by the new
  recording test and by the unchanged default path used by `instance`.
- If the owner prefers not to touch `lib/`, the fallback is a Firebase fake in the
  tests (new test dependency, needs approval level B for `pubspec`/test infra).
