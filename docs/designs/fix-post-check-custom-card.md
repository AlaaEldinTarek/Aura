# Post-check card as its own custom notification (Option B)

Status: **Draft, not approved** (Level A doc). Branch `fix/post-check-custom-card`, from `fix/post-check-remind-later` (f510d2d).
Fallback: PR #60 stays untouched; if this fails on the phone, drop this branch and go back to PR #60.
Parent spec: `docs/designs/fix-post-check-remind-later.md`.

## Why
On the nova 5T the PR #60 card (VISIBILITY_PUBLIC) still did not show on the lock screen before face match; only the Next
Prayer card did (REPORTED, 2026-11-18). Cause UNKNOWN. Two things differ from the Next Prayer card and are VERIFIED in code:
(1) the post-check card posts on channel `prayer_tracking`, IMPORTANCE_DEFAULT (shared with the daily summary);
(2) it is not ongoing. This change fixes (1) and keeps (2) as the owner decided. Whether it is enough is UNKNOWN until the phone check.

## Phases (owner decision 2026-11-18: one change at a time)
| Phase | Content | Status |
| --- | --- | --- |
| P1 | New channel `post_prayer_check` (IMPORTANCE_HIGH, created in `PrayerAlarmReceiver` and `MainActivity`) + `notification-ids.md`. CURRENT card layout kept (collapsed corner Remind Later, expanded Done/Late/Missed). Nothing else. | Approved ("approve phase P1") |
| P2 | The 4-button layout (four layouts, all buttons visible; design points 2-3 below). Only after the owner checks P1 on the phone and decides P2 is still needed. | Not approved |

Owner answers: heads-up popup OK (Q1). Keep the four old layouts and the swipe-hint code until the phone check passes; delete later in a separate step (Q2).
The sections below describe the full design; P1 implements only points 1, 4, 5, 6 with the existing layout.

## Scope (owner decision 2026-11-18)
- Own notification, same notification ID as today (6001-6006, `getPostCheckNotificationId`). No ID change.
- Foreground notification, vibration buttons and iqama countdown: untouched.
- Windows toast path: no change.

## Design
1. **New channel** `post_prayer_check`, name "Prayer Check", IMPORTANCE_HIGH, description "Asks if you prayed after prayer time passes".
   Created in Kotlin before the first post (like `prayer_tracking` today), because the receiver can fire with the app closed.
   Also created in `MainActivity.kt` next to `prayer_tracking` (:157-180) so it exists after the first app start. Sound/vibration:
   channel defaults (same as `prayer_tracking` today). New channel means a fresh user setting (old `prayer_tracking` mute does not carry over).
   `prayer_tracking` stays for the daily summary. Name check: Dart `prayer_check` (dead path, no Android caller, notification-ids.md) is a different ID; no Dart reference to the new ID is needed.
2. **Layout**: one card, all four buttons visible without expanding: Done, Late, Missed, Remind Later (labels via `PostCheckActions.label`, Arabic/English as today).
   Four files (light/dark x LTR/RTL) like `notification_actions*.xml`, new names `notification_post_check_card*.xml`; same explicit left/right + forced-LTR root rule as today's files.
   The same RemoteViews is used for collapsed and expanded (`setCustomContentView` and `setCustomBigContentView`), so there is no swipe-down hint.
   Two rows: icon + question on top, four buttons below. Height target about 64 dp (collapsed limit). The old four `notification_post_check*.xml` layouts stay for the popup/R1e fallback until the owner decides to delete them.
3. **Buttons**: `setOnClickPendingIntent` with `PostCheckCard.actionPending` (same actions, same request codes id+1..+4). Body tap: unchanged (`popupPending`, id+5, small popup). No new actions, no new prefs keys, no new intent extras.
4. **Flags**: VISIBILITY_PUBLIC, not ongoing, `setAutoCancel(false)` as now (swipe-away works).
5. **CATEGORY: keep `CATEGORY_REMINDER`.** It describes the card truthfully (a reminder to log a prayer) and lets the user's Do Not Disturb "Reminders" exception treat it like other reminders. `CATEGORY_ALARM` would bypass DND for a non-alarm, `CATEGORY_MESSAGE`/`CALL` would be wrong. The owner says the lock-screen cause is unknown; category is not a known cause. Not changing it keeps one variable per test.
6. **Heads-up**: IMPORTANCE_HIGH will pop the card over the screen when it fires (the old default-importance card did not). Behavior change by design; confirm it is wanted.

## Files touched (proposal)
- `PrayerAlarmReceiver.kt` (`showPostPrayerCheckNotification` only; "edit carefully" file, change limited to channel + builder)
- `PostCheckCard.kt` (layout picker, new constant for the channel ID)
- `MainActivity.kt` (channel creation)
- `res/layout/notification_post_check_card{,_dark,_rtl,_dark_rtl}.xml` (new)
- `PostCheckActions.kt`: only if label/ID helpers need adding; tests in `PostCheckActionsTest.kt`
- Docs: this file, `.project-docs/contracts/notification-ids.md` (channels table + 6001-6006 row), log, STATE.

## Contracts touched (one commit with the code)
- `notification-ids.md`: new channel `post_prayer_check` (Kotlin only); row 6001-6006 updated (channel, four-button layout).
- `method-channels.md`, `intent-extras.md`, `prefs-keys.md`: no change expected (to be confirmed by diff). Log tags unchanged (`[POST_CHECK]`).

## Tests first
- Kotlin unit test: channel ID constant, layout picker maps the 4 theme/language combos to 4 distinct layouts, and the button list is Done/Late/Missed/Remind Later with request codes id+1..+4 (extend `PostCheckActionsTest.kt`).
- Then: `flutter test`, `flutter analyze`, `./gradlew :app:testDebugUnitTest`, release APK build. Report pass/fail only.

## Risks
- Lock screen may still hide the card on EMUI (GUESS: custom RemoteViews or non-ongoing). If so, this branch fails and PR #60 is the answer.
- R1d (reverted) showed that a compact 63 dp collapsed layout with a button row broke the lock-screen display in Arabic. This design is the same shape, so that is a known risk; the new channel is the new variable.
- Four buttons in one row on a narrow card in Arabic (text length, large font): needs the owner's visual check.
- New channel: users who muted the old one are not carried over. Existing installs keep the old `prayer_tracking` channel (used by the daily summary).
- Heads-up popup at the post-check time (point 6).

## Owner's phone check (nova 5T, owner-observed is enough)
1. Card on the lock screen before unlock.
2. All four buttons visible; each button works from the lock screen.
3. Arabic and English, dark and light look right.

## Open questions
- Q1: Is the heads-up popup (IMPORTANCE_HIGH) wanted? (Proposal: yes, it is what you asked for.)
- Q2: Delete the old four layouts and the swipe-hint code in this branch, or keep until the phone check passes? (Proposal: keep.)
