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
- **Lock screen**: the working pattern on this EMUI phone is ongoing + PRIORITY_MAX + VISIBILITY_PUBLIC + a plain LinearLayout. P1 of the post-check work showed a NON-ongoing HIGH/PUBLIC notification is hidden on the lock screen before face match. Dismissible reminders themed the same way will probably not show there unless they are also made ongoing with a timeout (UNKNOWN until each is checked on the phone). Each phase states which choice it makes; the owner decides.
- **Buttons**: system `addAction` shows max 3 and EMUI does not color them; themed buttons need custom RemoteViews (as the post-check card).
- Only 2 notification IDs/channels exist per family already; **no notification ID changes** anywhere. Channels: reuse the existing channel unless a phase says otherwise (importance cannot be raised later; a new channel is a contract change: Kotlin + Dart if Dart references it + `.project-docs/contracts/notification-ids.md` in one commit).

## 4. Phases (proposal, ordered by how often the owner sees them; each needs its own "approve phase")
| Phase | Notification(s) | Work | Contract impact | Notes |
|---|---|---|---|---|
| T0 | shared helper | Add `ThemedNotification` (theme, language, layout pick, icons, `refreshAll`), make `PostCheckCard` use it; no behavior change | none | Tests: layout pick for the 4 combos, `isDark` rule, remaining timeout (already unit-tested for post-check) |
| T1 | #1/#2 foreground card | Instant refresh on theme/language change (today up to 60 s): call the same `refreshAll` hook; the service rebuilds on an intent. Everything else on the card unchanged | new intent action to the service = contract (`intent-extras.md`); no new channel, no prefs key | Optional: the card already themes itself. "Edit carefully" area; owner said earlier not to touch the vibration buttons and the iqama countdown, so only the trigger is added |
| T2 | #9 task reminder | Custom 4-layout card, Remind Later as a custom button, snooze action and request codes (id+2) unchanged; tap id+1 unchanged | none if the channel stays `task_reminders`; ongoing + timeout decision for the lock screen | Live language: text from Dart (see limits) |
| T3 | #7 daily summary | Custom card; fix the Arabic count with `withArabicNumerals`-equivalent in Kotlin (rule in CLAUDE.md); tap route unchanged | none | Language live: yes (count + language stored in extras) |
| T4 | #10 wird reminders + task digest (+ legacy prayer reminder with 2 buttons if still reachable) | Custom card; buttons only if `prayerName` is present | none | Text from Dart |
| T5 | #5 "Azan stopped" | Custom card (stays in the shade, not auto-dismissed), uses `getPrayerDisplayName` for Jumu'ah | none | |
| T6 | #6 Azkar trigger | Custom card (shown up to 60 s, full-screen intent keeps working) | none | Lower value: the azkar screen is the real UI |
| T7 | #8 Jumu'ah weekly | Custom card | none | Weekly |
| T8 | #11 achievements | Needs a native path (Dart cannot send RemoteViews): new MethodChannel method = contract, or leave plain | **new method** (stop and ask before doing it) | Lowest priority |

### Not worth theming (and why)
- **#4 Adhan full-screen trigger**: shown 3 s and auto-dismissed; it only exists to launch the full-screen activity. Theming it adds risk to the azan path (CLAUDE.md: edit `PrayerAlarmReceiver.kt` carefully) for something nobody sees.
- **#15 Rescheduling prayers**: ephemeral LOW foreground-service notification of a background job. Only worth fixing its English-only text (language), not theming.
- **#12 Focus Mode service / #13 relaunch**: the screen is locked by the Focus Mode activity during the session, so the notification is rarely seen; title is English-only in Arabic (bug, one-line fix, can ride on any phase). Theme optional, last.
- **#14, #16, #18**: no notification posted.
- **#17 test notifications**: dev only.
- **Windows toasts**: out of scope for now (section 2).

## 5. Risks
- Lock screen on EMUI: a themed dismissible notification may be hidden before face match (P1 evidence). Each phase's phone check includes the lock screen.
- Re-posting on theme change touches notifications that carry timeouts, alarms or full-screen intents: refresh must keep id, `when` and the remaining timeout, and must never re-fire sound or full-screen (`setOnlyAlertOnce`, no `setFullScreenIntent` on refresh).
- `PrayerAlarmReceiver.kt`, `DailySummaryReceiver.kt` are "edit carefully" files (CLAUDE.md). Azan path: never launch MainActivity.
- Language after a language change for Dart-built text (T2, T4) depends on Dart rescheduling: UNKNOWN.
- Dart `_jumuahNotificationId = 7001` equals the Kotlin daily summary id 7001; the Dart Jumu'ah path is only a legacy cancel on Android (VERIFIED `scheduleJumuahReminder`), so no live clash found, but not proven for old scheduled alarms (UNKNOWN).

## 6. Tests (per phase, tests first where possible)
Pure Kotlin unit tests (no Robolectric in the project): layout id per theme/language combo, `isDark` rule, remaining-timeout math (exists), Arabic numeral helper, extras round trip where it can be pure. Then `flutter test`, `flutter analyze`, gradle unit tests, release APK build (pass/fail only).

## 7. Owner's phone check per phase (owner-observed is enough)
For each themed notification: it shows in light and dark (set the app theme, not the phone), English and Arabic (Arabic mirrored, Arabic digits), the buttons work and the notification goes away, it updates live when theme/language changes while showing, and whether it appears on the lock screen before face match. Plus the specific look of that card (icon, gold accents).

## 8. Open questions for the owner
1. Dismissible reminders (T2-T7): make them ongoing with a timeout so they show on the lock screen (like the post-check card), or keep them dismissible and accept that they may not show there?
2. T1: is an instant refresh of the foreground card wanted, or is the 60 s tick fine?
3. T8 (achievements) needs a new native method; do it later or never?
4. The Focus Mode English-only title and the reschedule service English-only text: fix the language as a small side change in the phases that touch those files, or separately?
