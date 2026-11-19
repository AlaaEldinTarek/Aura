# Post-check card: own ongoing notification that shows on the lock screen (F72 follow-up)

Base: `main`. Branch: `fix/post-check-custom-card` (it contains the commits of PR #60; merge #60 first, or this PR carries them).
Spec: `docs/designs/fix-post-check-custom-card.md` (Draft). Log: `.project-docs/log/2026-11-19.md`.

## What
- The post-prayer check ("Did you pray X?") is now its own ongoing notification (ids 6001-6006 unchanged) on a new channel `post_prayer_check` (IMPORTANCE_HIGH), built like the foreground card that already shows on the EMUI lock screen: PRIORITY_MAX, PUBLIC, plain LinearLayout, same view collapsed and expanded.
- Four buttons always visible in a 2x2 grid: Done, Late, Missed, Remind Later (same actions and request codes id+1..+4). Arabic is mirrored. Per-prayer icon like the Next Prayer card. Auto-removed after 30 min (it cannot be swiped away).
- A showing card updates live when the app theme or language changes (re-post, same id, no new sound, remaining timeout kept), through the existing `updatePrayerWidgets` bridge.
- Heads-up popup and sound when it fires (owner decision).

## Contracts
- `notification-ids.md`: new channel `post_prayer_check` (Kotlin only), updated 6001-6006 row. No new prefs key, MethodChannel method, intent extra or notification ID. Windows toast path unchanged.

## Tests (real runs)
- gradle unit tests pass, `flutter test` 840 passed, `flutter analyze` 408 issues (0 errors, same as main), release APK built.
- Phone (nova 5T, EMUI, Android 10, owner-observed 2026-11-19): card on the lock screen before unlock in EN/AR x light/dark; Remind Later pressed 4 times (log: reached the receiver, alarm re-armed, card removed); live refresh on theme and language; equal buttons; icons.
- Not tested: Done / Late / Missed on the phone, other devices, a real Fajr post-check on the locked phone (owner check 2026-11-20).

## Known limits
- Closing the popup by tapping outside leaves the card until the 30 min timeout or an answer.
- The old four post-check layouts and the swipe-hint code are still in the branch (cleanup is a separate step).
- Plain notifications (reminders, summary, azkar, tasks, ...) are not refreshed on language change.

## PRs
Builds on #60 (R1 to R1e: Remind Later, popup, dev tile, Windows toast button).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
