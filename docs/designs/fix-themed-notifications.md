# Themed notifications: every Aura notification follows the app theme and language

Status: **Draft, not approved** (Level A doc). Branch `fix/themed-notifications`, from main e687be0. No code until the owner says "approve phase <name>".
Pattern to reuse: the post-check card, `docs/designs/fix-post-check-custom-card.md` (shared helper, 4 layouts light/dark x LTR/RTL, live refresh, `setOnlyAlertOnce`, remaining timeout kept).

## Labels
`VERIFIED` = read in code (file named). `UNKNOWN` = not checked or not checkable by reading. Lock screen is VERIFIED on the device only for the foreground card and the post-check card (owner, 2026-11-19); every other lock-screen cell is UNKNOWN.

## 1. Inventory: Android notifications (VERIFIED in code, 2026-11-20)
Columns: **Theme** = custom layout light/dark by the APP `theme_mode` (not the phone). **Style** = app gold `0xFFF5B301` + app/prayer icons. **Lang** = language from the app setting; (RTL = Arabic layout mirrored; Num = Arabic numerals). **Live** = re-posted when theme/language changes while showing. **Buttons**: count, system `addAction` (max 3) or custom RemoteViews.

| # | Notification | File : builder | IDs / request codes | Channel | Theme | Style | Lang (RTL / Num) | Live | Buttons | Lock screen |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Foreground Next Prayer card, normal / adhan / reminder modes (iqama countdown, pre-prayer reminder, legacy "did you pray") | `PrayerForegroundService.createNotification` (:438), custom views `notification_large*.xml` | 9999 (ongoing, MAX, ALARM, PUBLIC) | `prayer_foreground_channel_v4` | yes (4 layouts, `isDarkTheme()` reads `FlutterPrefs theme_mode`) | yes (`setColor` gold, clock/prayer/mosque icons) | yes: app language; RTL layouts yes; Num yes (`toEasternArabic`) | partly: own 60 s tick (1 s in adhan mode) re-reads language and theme; not instant | 0 | PASS on device |
| 2 | Foreground card, vibration-window variant (Stop / Keep Vibration) | same builder, `buildContentView` (:668), `notification_actions*.xml` | 9999 (same notification) | same | yes (4 layouts) | yes | yes (RTL yes) | same 60 s tick | 2, custom | PASS on device (buttons work) |
| 3 | Post-check card | `PostCheckCard.show` | 6001-6006 (ongoing, MAX, REMINDER, PUBLIC, 30 min timeout) | `post_prayer_check` | yes | yes | yes (RTL mirrored; no digits on the card) | yes (`refreshShowing`, instant) | 4, custom | PASS on device |
| 4 | Adhan full-screen trigger | `PrayerAlarmReceiver.showPrayerNotification` (:854-924) | 1001-1006 (`getNotificationId`), fullScreenIntent, auto-dismiss 3 s | `prayer_times` | no (system style) | no (`ic_notification` only) | text language yes; RTL system; Num n/a | no | 0 | UNKNOWN (exists to launch the full-screen activity) |
| 5 | "Azan stopped" notification (after Stop) | `StopAdhanReceiver.updateNotificationAfterStop` (:52-93) | 1001-1006 (replaces #4), not ongoing, PUBLIC | `prayer_times` | no | no | language yes; no names via `getPrayerDisplayName` (own `when`, no Jumu'ah) | no | 0 | UNKNOWN |
| 6 | Azkar trigger | `AzkarAlarmReceiver` (:137) | 9001-9006 (request codes 3001-3006), fullScreenIntent, `setTimeoutAfter` 60 s | `azkar_reminder` | no | no (`mipmap/ic_launcher` small icon) | language yes; Num n/a | no | 0 | UNKNOWN |
| 7 | Daily prayer summary | `DailySummaryReceiver` (:137-148) | 7001 | `prayer_tracking` | no | no | language yes; **Arabic count is a raw int `$count` (CLAUDE.md Arabic numerals rule not followed)** | no | 0 | UNKNOWN |
| 8 | Jumu'ah weekly reminder | `JumuahReminderReceiver.showNotification` (:135) | 8001 | `jumuah_reminder` | no | no | language yes | no | 0 | UNKNOWN |
| 9 | Task reminder | `TaskReminderReceiver` (:135-147) | per task (`EXTRA_NOTIFICATION_ID`), snooze request code id+2, tap id+1 | `task_reminders` | no | no | text from Dart (language at schedule time); button label language yes | no | 1 system action (Remind Later) | UNKNOWN |
| 10 | Wird reminders, daily task digest, (legacy prayer reminder with 2 buttons) | `NativeNotificationReceiver` (:157-197) | wird 5100+i, digest 3999, remind-again +5000; button request codes id+1..+3 | `wird_reminder`, `task_reminders`, `prayer_times` (extra `channel_id`) | no | no | text from Dart; "Prayer in 5 minutes" Arabic digit hard-coded | no | 0 (wird, digest) or 2 system actions (Mark as Prayed / Remind Me Again, only when `prayerName` is sent; Dart caller `schedulePrayerNotification` has no caller per STATE F12, so the 2-button case is UNKNOWN in use) | UNKNOWN |
| 11 | Achievement unlocked | Dart `NotificationService.showAchievementNotification` (flutter_local_notifications `show`, :1169) | 7100 + hash % 1000 | `achievement_unlocked` | no | no | language yes (Dart) | no | 0 | UNKNOWN |
| 12 | Focus Mode service | `FocusModeService.startForeground` (:392) | 5998 (ongoing, MAX, ALARM) | `focus_mode_service` | no | no (`mipmap/ic_launcher`) | **title is English in both branches (`if (isArabic) "Focus Mode Active" else "Focus Mode Active"`)** | no | 0 | UNKNOWN |
| 13 | Focus Mode relaunch (full-screen escape) | `FocusModeService` (:357-368) | 5996 (ongoing, MAX, fullScreenIntent) | `focus_mode_service` | no | no | language yes | no | 0 | UNKNOWN |
| 14 | Focus Mode receiver | `FocusModeReceiver` | 5999 (only cancels; channel `focus_mode` is created, no builder found) | `focus_mode` | n/a | n/a | n/a | n/a | n/a | n/a |
| 15 | Rescheduling prayers (foreground service) | `PrayerRescheduleService` (:96) | 2000 (ongoing, LOW) | `prayer_reschedule` | no | no | **text English only ("Rescheduling Prayers")** | no | 0 | UNKNOWN |
| 16 | Silent mode | none: the separate silent-mode notification (8100) was replaced by the buttons inside #2; `MainActivity` deletes the orphan channel | - | - | - | - | - | - | - | - |
| 17 | Debug / test: "Test notification", `showPrayerTimeNotification` (Dart, from `prayer_alarm_service.dart:54`) | `NotificationService` | various | `prayer_times` | no | no | yes | no | 0 | UNKNOWN |
| 18 | Widgets | not notifications | - | - | - | - | - | - | - | - |

Pre-prayer reminder (S05, PR #56) is not a separate notification: it is the reminder mode of #1 (`reminder_kind == "pre"`), alarms 2101-2106.
UNKNOWN: whether Dart's `NotificationService` still posts anything else on Android through `flutter_local_notifications` (all `zonedSchedule` calls found sit behind Android native branches or on other platforms; `show` is used by #11 and #17 only).

### Full-screen activities (screens, not notifications; no plan)
| Activity | Follows app language | Follows app theme |
|---|---|---|
| `AdhanFullScreenActivity` | yes (`language` pref; time format `Locale("ar")` when Arabic) | no: no `theme_mode` read found (VERIFIED by grep), fixed look |
| `AzkarFullScreenActivity` | yes (`language` pref) | no: fixed gold text colors, no `theme_mode` read |
| `FocusModeActivity` | yes (intent extra `language`; Arabic numerals via its own `toArabicNumerals`) | no: no `theme_mode` read |

## 2. Windows toasts (separate, no plan yet)
Source: `lib/core/services/desktop_notification_service.dart` through `local_notifier` ^0.1.6 (`LocalNotification` with title, body, actions, identifier; `_showSystemToast`). Toasts: generic `show`, pre-prayer, post-prayer check (Prayed / Late / Missed / Remind Later buttons), adhan (Prayed, Stop Adhan), task, wird, task reminder, daily task digest. Achievement toast is an in-app card on desktop.
- Can take (what the code uses and what `local_notifier` exposes, UNVERIFIED beyond the code read): title, body, a list of text buttons, an identifier, silent flag. Text is in the app language because Aura builds it.
- Cannot take (UNVERIFIED, from how Windows toasts and this plugin work, plugin source not read): custom layouts, app gold colors, light/dark by the app theme (Windows draws toasts by the Windows setting), RTL mirroring control, custom button styling or icons per prayer. A fully themed toast would need the native toast XML API instead of `local_notifier` (not planned).

## 3. Reusable pattern (from the post-check card)
`PostCheckCard` is the model: one object per notification family with `show(...)` (build + post), `cardLayoutId(dark, arabic)` (4 layouts), `isDark(context)` (app `theme_mode` via `FlutterPrefs`, `PostCheckActions.isDark` rule: dark/amoled -> dark, light -> light, system -> phone), `isArabic(context)` (prefs `language` in `aura_prayer_times`), icon helper, and `refreshShowing(context)` (called from the `updatePrayerWidgets` handler in `MainActivity.kt`, which Dart already calls on theme and language change).
Proposed shared helper `ThemedNotification` (Kotlin, new file): `isDark`, `isArabic`, `pickLayout(dark, arabic, light, dark, lightRtl, darkRtl)`, `iconBitmap(prayerName)` (move of `PostCheckCard.iconBitmap` + `PostCheckActions.iconKey`), and a small registry `refreshAll(context)` that each phase adds one entry to. Live refresh keeps: same id, `setOnlyAlertOnce(true)`, original `when`, remaining timeout.
Raw data for a rebuild (prayer name, count, title, body) is stored in the notification's own `extras` (no prefs key), as the post-check card does.

Limits that apply to every phase:
- **Theme** can always be re-applied live. **Language** can be re-applied live only when the text is built in Kotlin from structured data (post-check, daily summary, azkar, Jumu'ah, azan-stopped). Task, wird and digest text arrives from Dart already translated at schedule time; after a language change it only follows when Dart reschedules (whether it does: UNKNOWN, check before that phase).
- **Lock screen**: the working pattern on this EMUI phone is ongoing + PRIORITY_MAX + VISIBILITY_PUBLIC + a plain LinearLayout. P1 of the post-check work showed a NON-ongoing HIGH/PUBLIC notification is hidden on the lock screen before face match. Whether dismissible themed reminders show there is UNKNOWN until each is checked with the phone ALREADY LOCKED when it fires (see section 8: the P1 test fired while unlocked, so it did not prove they are hidden). They stay dismissible; only if one is hidden does it become ongoing with a timeout.
- **Buttons**: system `addAction` shows max 3 and EMUI does not color them; themed buttons need custom RemoteViews (as the post-check card).
- Only 2 notification IDs/channels exist per family already; **no notification ID changes** anywhere. Channels: reuse the existing channel unless a phase says otherwise (importance cannot be raised later; a new channel is a contract change: Kotlin + Dart if Dart references it + `.project-docs/contracts/notification-ids.md` in one commit).

## 4. Phases (proposal, ordered by how often the owner sees them; each needs its own "approve phase")
| Phase | Notification(s) | Work | Contract impact | Notes |
|---|---|---|---|---|
| T0 | shared helper | Add `ThemedNotification` (theme, language, layout pick, icons, `refreshAll`), make `PostCheckCard` use it; no behavior change | none | Tests: layout pick for the 4 combos, `isDark` rule, remaining timeout (already unit-tested for post-check) |
| T1 (with T0) | #1/#2 foreground card | Instant refresh on theme/language change (today up to 60 s): `refreshAll` calls `PrayerForegroundService.getInstance()?.refreshNotification()`. Everything else on the card unchanged | none: the existing static instance is used, no new intent action (owner pre-approved one; not needed); no new channel, no prefs key | Optional: the card already themes itself. "Edit carefully" area; owner said earlier not to touch the vibration buttons and the iqama countdown, so only the trigger is added |
| T2 | #9 task reminder | Custom 4-layout card, Remind Later as a custom button, snooze action and request codes (id+2) unchanged; tap id+1 unchanged | none if the channel stays `task_reminders`; ongoing + timeout decision for the lock screen | Live language: text from Dart (see limits) |
| T3 | #7 daily summary | Custom card; fix the Arabic count with `withArabicNumerals`-equivalent in Kotlin (rule in CLAUDE.md); tap route unchanged | none | Language live: yes (count + language stored in extras) |
| T4 | #10 wird reminders + task digest (+ legacy prayer reminder with 2 buttons if still reachable) | Custom card; buttons only if `prayerName` is present | none | Text from Dart |
| T5 | #5 "Azan stopped" | Custom card (stays in the shade, not auto-dismissed), uses `getPrayerDisplayName` for Jumu'ah | none | |
| T6 | #6 Azkar trigger | Custom card (shown up to 60 s, full-screen intent keeps working) | none | Lower value: the azkar screen is the real UI |
| T7 | #8 Jumu'ah weekly | Custom card | none | Weekly |
| T8 | #11 achievements | Needs a native path (Dart cannot send RemoteViews): new MethodChannel method = contract, or leave plain | **new method** (stop and ask before doing it) | **DEFERRED (owner 2026-11-20): later, not now** |
| T9 | #12 Focus Mode service, #14 reschedule service | Language only (app language, Arabic text, Arabic numerals), no theming | none (text only) | One small separate phase, last. Fixes the English-only titles |

### Not worth theming (and why)
- **#4 Adhan full-screen trigger**: shown 3 s and auto-dismissed; it only exists to launch the full-screen activity. Theming it adds risk to the azan path (CLAUDE.md: edit `PrayerAlarmReceiver.kt` carefully) for something nobody sees.
- **#15 Rescheduling prayers**: ephemeral LOW foreground-service notification of a background job. Only worth fixing its English-only text (language), not theming.
- **#12 Focus Mode service / #13 relaunch**: the screen is locked by the Focus Mode activity during the session, so the notification is rarely seen; title is English-only in Arabic (bug, one-line fix, can ride on any phase). Theme optional, last.
- **#14, #16, #18**: no notification posted.
- **#17 test notifications**: dev only.
- **Windows toasts**: out of scope for now (section 2).

## 5. Risks
- Lock screen on EMUI: a themed dismissible notification may be hidden before face match (UNKNOWN; the P1 evidence was a card fired while the phone was unlocked). Each phase's phone check fires it with the phone already locked.
- Re-posting on theme change touches notifications that carry timeouts, alarms or full-screen intents: refresh must keep id, `when` and the remaining timeout, and must never re-fire sound or full-screen (`setOnlyAlertOnce`, no `setFullScreenIntent` on refresh).
- `PrayerAlarmReceiver.kt`, `DailySummaryReceiver.kt` are "edit carefully" files (CLAUDE.md). Azan path: never launch MainActivity.
- Language after a language change for Dart-built text (T2, T4) depends on Dart rescheduling: UNKNOWN.
- Dart `_jumuahNotificationId = 7001` equals the Kotlin daily summary id 7001; the Dart Jumu'ah path is only a legacy cancel on Android (VERIFIED `scheduleJumuahReminder`), so no live clash found, but not proven for old scheduled alarms (UNKNOWN).

## 6. Tests (per phase, tests first where possible)
Pure Kotlin unit tests (no Robolectric in the project): layout id per theme/language combo, `isDark` rule, remaining-timeout math (exists), Arabic numeral helper, extras round trip where it can be pure. Then `flutter test`, `flutter analyze`, gradle unit tests, release APK build (pass/fail only).

## 7. Owner's phone check per phase (owner-observed is enough)
For each themed notification: it shows in light and dark (set the app theme, not the phone), English and Arabic (Arabic mirrored, Arabic digits), the buttons work and the notification goes away, it updates live when theme/language changes while showing, and whether it appears on the lock screen before face match. Plus the specific look of that card (icon, gold accents).

## 8. Owner answers (2026-11-20) and workflow
1. **Dismissible reminders stay dismissible (not ongoing) for now.** Correction to the P1 conclusion in section 3 and the risks: in the post-check P1 test the card fired while the phone was UNLOCKED (heads-up first), and the owner's 22:45 screenshot shows a normal non-ongoing card of another app (Instagram) on the EMUI lock screen. So non-ongoing notifications can show there; P1 did not prove otherwise. **In every phase the owner's phone check fires the notification while the phone is ALREADY LOCKED.** Only if a themed reminder is still hidden that way, that one is made ongoing with a timeout, as a follow-up of that phase.
2. **T1 instant refresh of the foreground card: yes.** The owner approved a new intent action as a contract change (Kotlin + Dart + contracts in one commit). Finding while building T1: the service already exposes `PrayerForegroundService.getInstance()` (static instance), so T1 refreshes it with a direct call and needs NO new intent action; contract files unchanged by T1 (confirmed by diff in the T1 PR). No ID or channel change.
3. **T8 (achievements): deferred**, later, not now.
4. **Focus Mode service title (#12) and the reschedule notification (#14): fix only the language** (app language, Arabic text, Arabic numerals), no theming, as one small separate phase at the end: **T9**.

### Workflow (one phase at a time)
- This branch (`fix/themed-notifications`) keeps only this spec (docs).
- Each phase gets its own branch from the latest main (`fix/themed-t1`, `fix/themed-t2`, ...) and its own PR with base = main. Never stack a phase on another phase's branch.
- The owner tests each phase on the phone. Good: the owner merges its PR, then the next phase starts from the new main. Not good: drop that branch, main stays untouched.
- T0 (helper) has nothing to see on its own, so T0 + T1 are built together on `fix/themed-t1` as the first phase.
- Do not start the next phase until the previous PR is merged.

## 9. Phase results
| Phase | Result | Branch / commit | Notes |
| --- | --- | --- | --- |
| T0 + T1 | **PASS** (owner-observed on the nova 5T, 2026-11-20): the foreground card changes instantly on theme and language change in normal mode and with the vibration buttons showing, and it still shows on the lock screen; looks right | `fix/themed-t1`, commit 5a9f6d4 (build installed 2026-11-20 01:34:40) | Real runs before the phone check: gradle unit tests pass, `flutter test` 840 passed, `flutter analyze` 408 issues (0 errors, = main), release APK built. No new intent action, channel, prefs key or ID (the service already had `getInstance()`); no contract file changed. PR and merge: owner |
| T2 | **PASS** (owner-observed, 3 screenshots 02:25-02:27, 2026-11-20): the locked screen shows only "Aura - Task reminder" with no task title; after unlock the full card shows the title and Remind Later; live theme and language change works; Arabic mirrored layout OK | `fix/themed-t2`, commits 2f34a23 (card), ab6bba1 (PRIVATE + public version) | VISIBILITY_PRIVATE with a public version (owner decision) |
| T2b | see "T2b" below | `fix/themed-t2` | Done button, body language, logo, Remind Later delay, reminder rules |
| T3 onward | not started | | Starts only after the owner says "merged" for the previous phase |

### T2b (owner, 2026-11-20): changes on `fix/themed-t2` before the merge
1. **Logo**: the card used `@mipmap/ic_launcher` (legacy icon with a colored square background, white on the dark card). Now `@drawable/ic_launcher_foreground` (transparent "A" logo, the adaptive-icon foreground that exists in `drawable-*dpi`), 40 dp, in all 4 layouts and the public version. Note: the foreground Next Prayer card header does not show the Aura logo, it shows the prayer / mosque icons, so there was no "header logo" to copy; no new PNG was needed.
2. **Body language**: Dart now also sends `bodyKind` (`before` / `due_now` / `today`) and `bodyMinutes` to `scheduleNativeTaskReminder` (new args on an existing method: contract, `method-channels.md`, `intent-extras.md`). Kotlin builds the body in the app language and re-builds it on a live language change. Remind Later re-arms with kind `pending`. An alarm scheduled before this change has no kind, so its ready-made text is kept. Final texts: due now "Task is due now" / "حان موعد المهمة الآن"; before "Task due in X minutes" / "موعد المهمة بعد X دقيقة" (X in Arabic numerals, e.g. ٣٠); today "You have a task due today" / "لديك مهمة مستحقة اليوم"; still pending "Your task is still pending" / "لا تزال المهمة معلقة"; public title "Aura - Task reminder" / "هالة - تذكير بمهمة"; buttons "Done" / "إتمام", "Remind Later" / "ذكرني لاحقاً". The wording is the old Dart wording (the "دقيقة" is singular for every X, as in Dart); owner reviews.
3. **Done button**: Done above Remind Later (same 84 dp width, post-check button style, mirrored in Arabic); the public lock-screen version has no buttons. Path chosen: the Tasks widget hand-off (`pending_complete_task_id` through `FlutterPrefs`, applied in `main_wrapper_screen.dart` `_handleWidgetIntent`); no better path exists because native code cannot write the task store (Firestore or the guest task list live in Dart). Changes: the pref may hold several ids (comma separated, so a second Done does not overwrite the first); Dart now calls `toggleTaskCompletion(onlyComplete: true)`, which leaves an already completed task alone, so it only completes and never un-completes. Side effect: the same handler serves the Tasks widget, so a stale widget tap on a task that is already done no longer un-completes it (before: it toggled it back to open).
   - **When the task is completed**: not at the press. The press removes the card, cancels any pending Remind Later alarm and removes `task_snoozed_until_<id>` at once; the task itself is completed when the app is next opened or resumed (`_handleWidgetIntent` runs at start and on resume). Until then it still shows as open in the app and in the widget count.
   - **On completion** (same code as the old Dart "Mark Done", `toggleTaskCompletion` -> `updateTask`): the reminder is cancelled again; `AchievementService.checkAndAward` runs; a recurring task is completed and the next occurrence is created; guest tasks are updated in the local list, signed-in tasks in Firestore; the task list providers are invalidated so the widget count follows. **The task streak is NOT bumped**: `incrementTaskStreak` is called only by the Home and Tasks screens, not by `toggleTaskCompletion`, so the old Dart Done and the widget never counted for the streak either. Open decision for the owner: count it for the streak?
4. **Remind Later delay**: reads `task_reminder_minutes` through `FlutterPrefs.getInt` when the button is pressed (default 30, invalid values fall back to 30); `SNOOZE_MINUTES = 30` is gone. Kotlin did not read this key before: noted in `prefs-keys.md`. The Dart `_handleTaskDone` / `_handleTaskSnooze` (fixed 30) are not reachable on Android: the Android branch of `scheduleTaskReminder` returns after scheduling the native alarm, and the `task_done_` / `task_snooze_` actions exist only on the non-Android notification below it (VERIFIED by reading). Left unchanged.
5. **Reminder rules** (VERIFIED = read in code, not run on the phone):
   | Rule | Result |
   |---|---|
   | Fires once at the reminder time | VERIFIED: one exact alarm per task (`TaskReminderReceiver.schedule`), the receiver never re-arms except for Remind Later. Dart's bulk re-arm (app open, every 6 h) replaces the same alarm id and skips reminders whose time has passed |
   | Remind Later: card removed, fires again after X minutes, every press | VERIFIED: cancel card, re-arm `now + task_reminder_minutes`, each press repeats. **Gap found and fixed:** the native snooze did not write `task_snoozed_until_<id>`, so a Dart re-arm after the app was opened could replace the snooze alarm with the original due-time alarm (when the reminder time had passed but the due time had not). Now the native Remind Later writes the key (existing key, now also native-written, `prefs-keys.md`) and Dart reloads the prefs before checking it |
   | Done: completed, card removed, pending snooze cancelled, no more reminders | VERIFIED for card removed, snooze alarm cancelled (same request code as the original alarm) and no repeat; completion itself happens on the next app open (see above) |
   | Swipe away / ignore: no repeat | VERIFIED: no delete intent, nothing re-arms |
   | Completing or deleting the task in the app cancels a pending snooze | VERIFIED: `TaskService._cancelReminder` (complete via `updateTask`, delete) -> `cancelTaskNotification` -> `cancelNativeTaskReminder` -> `TaskReminderReceiver.cancel` cancels the alarm with request code = notification id (the snooze re-uses it) and removes `task_snoozed_until_<id>`. Two tasks can share an id (`4000 + hash % 1000`): pre-existing, unchanged |
