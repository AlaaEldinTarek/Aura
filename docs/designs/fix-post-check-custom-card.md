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
| P1 result | Owner phone test 2026-11-19 22:41 (logcat `logcat/P1-postcheck-test.txt`): card posted on `post_prayer_check` (importance 4, vis PUBLIC, not ongoing), heads-up shown and sound played (VERIFIED in log), but NOT on the lock screen before unlock (owner screenshot, only Next Prayer shown). SystemUI log has no add of 6001 on wake. Lock-screen cause UNKNOWN; the remaining difference from the working foreground card is ongoing + PRIORITY_MAX + CATEGORY_ALARM + plain LinearLayout. | Done (not enough) |
| P2b | Copy the foreground card that DOES show on the EMUI lock screen (owner screenshot 22:45: Zuhr / Stop Vibration / Keep Vibration, buttons work): `setOngoing(true)`, `PRIORITY_MAX`, VISIBILITY_PUBLIC, channel `post_prayer_check`; plain LinearLayout in the `notification_actions*.xml` style (4 files light/dark x LTR/RTL, `notification_post_check_card*.xml`); icon + question on the left, the 4 buttons as a 2x2 grid on the right (about 64 dp, same height as the foreground card); same view collapsed and expanded; buttons via `setOnClickPendingIntent` to the existing actions, request codes id+1..+4; `setTimeoutAfter(30 min)`. Own notification 6001-6006; foreground card untouched. | Approved ("approve phase P2b") |
| P2b result | Owner phone test 2026-11-19 23:03-23:08 (4 screenshots): the card IS on the EMUI lock screen in all four combinations (English/Arabic x light/dark): PASS. Log `logcat/P2b-postcheck-test.txt`: Remind Later reached the receiver 4 times (`Re-scheduled for Fajr in 15 min`, 23:02:07, 23:04:16, 23:07:16, 23:08:29; alarm req=3001 armed each time) and the card was removed each time (5 removals of id 6001 in the log). Done / Late / Missed were not pressed (0 `Marked ...` lines): UNKNOWN on the phone, cancel is VERIFIED in code only. | Done (PASS on the lock screen) |
| P2c | (1) live refresh of a showing post-check card on theme/language change; (2) Remind Later = transparent fill, gold border and text in all 4 layouts; (3) Arabic layouts mirrored (icon on the right, text right-aligned, buttons on the left; Done right / Late left, Missed right / Remind Later left). English unchanged. See "P2c decisions". | Approved ("approve phase P2c") |
| P2 | The 4-button layout (four layouts, all buttons visible; design points 2-3 below). Only after the owner checks P1 on the phone and decides P2 is still needed. | Not approved |

Owner answers: heads-up popup OK (Q1). Keep the four old layouts and the swipe-hint code until the phone check passes; delete later in a separate step (Q2).
The sections below describe the full design; P1 implements only points 1, 4, 5, 6 with the existing layout.

## P2b decisions
- **Timeout 30 min** (`PostCheckActions.TIMEOUT_MS`): an ongoing card cannot be swiped away, so it must not get stuck. 30 min = two Remind Later cycles (15 min), and it will not sit there until the next prayer. After the timeout nothing is recorded (same as swiping the old card away).
- **Cancel paths (VERIFIED in code, `PrayerAlarmReceiver.handlePostPrayerCheckAction`):** Done, Late, Missed and Remind Later each call `cancel(notificationId)`. The body tap opens the popup, whose buttons send the same actions (same cancel). Closing the popup by tapping outside leaves the card until the timeout (known).
- **Category: keep `CATEGORY_REMINDER`**, not ALARM. ALARM is what the foreground card uses, but Do Not Disturb lets alarms through by default, so a "did you pray?" card would sound at night/DND. The lock-screen cause is not known to be the category. If P2b still fails on the lock screen, ALARM is the next single change to try (one-line).
- The foreground card uses `setOnlyAlertOnce(true)`; not copied (the card is posted once per event and the heads-up is wanted).

## P2c decisions
**Aura notifications that can be on screen (VERIFIED in code, `grep` of Builder users):**
| Notification | Custom themed view? | Refreshes on theme/language change? |
| --- | --- | --- |
| Foreground Next Prayer / vibration card (9999, `PrayerForegroundService`) | yes (`notification_large*`, `notification_actions*`) | Yes, but on its own tick: re-reads `language` and `theme_mode` every 60 s (every 1 s in adhan mode) and re-posts. Not instant (up to 60 s). Left untouched (owner: do not touch the foreground card). |
| Post-check card (6001-6006) | yes (`notification_post_check_card*`) | **No** (posted once). P2c adds it. |
| Focus Mode service, daily summary, pre-prayer reminder, Jumu'ah, azkar, task reminders, wird/achievement (`FocusModeService`, `DailySummaryReceiver`, `PrayerAlarmReceiver` reminder, `JumuahReminderReceiver`, `AzkarAlarmReceiver`, `TaskReminderReceiver`, `NativeNotificationReceiver`) | no (system-styled, no theme of ours) | No. Their text is built in the language at post time from data that is not stored; re-posting needs per-notification data. NOT done in P2c; owner to decide if wanted. |

**How the change reaches native (no new prefs key, no new channel, no new method):** `setThemeMode` and `setLanguage` in `preferences_provider.dart` already call `PrayerWidgetService.savePrayerTimes` (when prayer times are loaded), which invokes the existing MethodChannel call `updatePrayerWidgets`; the native handler (`MainActivity.kt`) writes `language` into `aura_prayer_times` (the theme is read from `FlutterPrefs` `theme_mode`, already written by Dart before the call). P2c adds one native call after that write: `PostCheckCard.refreshShowing(context)`. It looks at the active notifications (`NotificationManager.activeNotifications`), and for each post-check id (6001-6006) whose layout differs from the layout the current theme/language would pick, re-posts it with the new look. Caveat: only runs when prayer times are loaded in the app (same condition the widgets already have).
- Re-post keeps the same id, same actions and request codes, `setOnlyAlertOnce(true)` (no sound, no heads-up again), and the original `when`; the timeout is the REMAINING time (`when + 30 min - now`, `PostCheckActions.remainingTimeoutMs`); if it is already over, the card is cancelled instead. The prayer name, Arabic name and prayer time needed for the rebuild are stored in the notification's own extras (no prefs).
- Theme "system"/"amoled": the existing `PostCheckActions.isDark` rule decides (unchanged).

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
