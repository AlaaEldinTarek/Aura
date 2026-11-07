# Findings — investigate, do not fix (without an approved spec)
Created 2026-11-06 from analyzer run at 75d38b9 and the CLAUDE.md relocation.

## F1 — equal_keys_in_map — VERIFIED harmless
- `lib/core/services/location_service.dart:327, 356` — `'Istanbul'` twice in `cityTranslations`, identical values →
  no behavior change; lint only.

## F2 — depend_on_referenced_packages — UNVERIFIED
- `lib/core/services/auth_service.dart:7` — imports `crypto`, which is not a direct dependency (transitive only).

## F3 — use_build_context_synchronously ×19 — UNVERIFIED (possible use-after-dispose after await)
- `lib/features/onboarding/preference_screen.dart:236` (unrelated `mounted` check)
- `lib/features/quran/quran_reader_screen.dart:355` (unrelated `mounted` check)
- `lib/features/quran/wird_tab.dart:588, 589, 638, 639` (unrelated `mounted` check)
- `lib/features/settings/adhan_downloads_screen.dart:338, 692` (no guard)
- `lib/features/settings/adhan_downloads_screen.dart:373, 397, 421, 652, 653, 678, 679` (unrelated `mounted` check)
- `lib/features/tasks/task_form_screen.dart:148, 158, 199, 209` (no guard)

## F4 — Notification ID range overlap — range VERIFIED, collision UNVERIFIED
- `notification_service.dart:1171`: `7100 + (achievement.id.hashCode.abs() % 1000)` → 7100–8099 contains Jumu'ah 8001
  (`JumuahReminderReceiver.kt:19`). A collision needs an achievement id with `hashCode % 1000 == 901`; not computed
  (Dart `String.hashCode` stability across runs is not guaranteed by spec).

## F5 — MethodChannel `com.aura.hala/app_control` — VERIFIED (Kotlin side), no Dart caller found
- `MainActivity.kt:225–227`: single method `openUrl`. No Dart reference to the channel name. See F10.

## F6 — Stale KDoc in `PrayerForegroundService.kt:842-846` — UNVERIFIED
- Comment says "Request Flutter to recalculate prayer times by launching MainActivity briefly" but sits above
  `getDisplayPrayerName()`; the real `requestFlutterUpdate()` (line 857) recalculates natively. Misleading; Level C to fix.

## F7 — ID 7001 used by both Dart Jumu'ah (legacy) and native Daily Summary — code VERIFIED, impact UNVERIFIED
- **Tag: likely user-visible bug → fix track** (needs an approved spec; do not fix during refactor phases).
- `notification_service.dart:57` `_jumuahNotificationId = 7001`; `scheduleJumuahReminder()`/`cancelJumuahReminder()`
  call `_notifications.cancel(7001)` (:1390, :1401) as "legacy cleanup". Native `DailySummaryReceiver.kt:20` posts 7001.
  Same package + null tag → calling either Dart method while the daily summary is shown would dismiss it.

## F8 — Task digest 4001 inside task-reminder hash range 4000–4999 — code VERIFIED, impact UNVERIFIED
- `notification_service.dart:1021` (digest 4001) vs `:669` (`4000 + taskId.hashCode.abs() % 1000`). A task whose hash
  maps to 1 would replace/cancel the digest (or vice versa).

## F9 — Dart channel `com.aura.hala/silent_mode` has no Kotlin handler — VERIFIED (static)
- `silent_mode_service.dart:14` invokes `setEnabled`/`setDuration`/`cancelAll`; no Kotlin registers `silent_mode`
  (calls would throw `MissingPluginException`, caught). No importer of `silent_mode_service.dart` found in `lib/`/`test/`
  → likely dead code (UNVERIFIED; "not found" ≠ unused). Silent mode works natively via prefs (contracts/prefs-keys.md).

## F10 — Kotlin handlers with no Dart caller found — UNVERIFIED (possibly dead)
- `ringer_mode`: `getRingerMode`, `setRingerMode` (`MainActivity.kt:206,210`); `app_control`: `openUrl` (:227);
  `focus_mode`: `isAccessibilityServiceEnabled`, `requestAccessibilityPermission` (:767,:771) — likely leftovers of the
  accessibility service removed in bc765f6.
- `BackgroundServiceHandler.kt` duplicates the `background_service` handler; no instantiation found (MainActivity
  registers its own at :638).

## F11 — Dart handler `onPrayerAlarmTriggered` has no Kotlin sender — UNVERIFIED
- `prayer_alarm_service.dart:42`; Kotlin only calls `invokeMethod` on the navigation channel (`MainActivity.kt:66–102`).

## F12 — `NotificationService.schedulePostPrayerCheck` has no caller found — UNVERIFIED
- `notification_service.dart:1265` schedules 6001–6006 from Dart; the only caller found uses
  `PrayerAlarmService.instance.schedulePostPrayerCheck` (`prayer_times_provider.dart:269`) → native path.

## F13 — MainActivity reads picker intent extras that nothing writes — UNVERIFIED
- `open_reminder_picker`, `update_prayer_status`, `open_post_prayer_picker` (+ payload extras) read at
  `MainActivity.kt:71–102`; no `putExtra` or constant found in Kotlin. Post-prayer actions may be handled by receivers
  instead; device scenario S09 records actual tap behavior.

## F15 — Dart writes `zuhr_time` into native `aura_prayer_times` — code VERIFIED, impact UNVERIFIED
- **Tag: likely user-visible bug → fix track** (with F7; needs an approved spec; do not fix during refactor phases).
- `prayer_times_provider.dart:370` builds `'${p.name.toLowerCase()}_time'` → `zuhr_time` and sends it via
  `BackgroundServiceManager.updatePrayerTimes`; `MainActivity.kt:656–679` → `PrayerForegroundService.kt:108` stores every
  map key as-is. Kotlin readers use `dhuhr_time` (`PrayerAlarmReceiver.kt:619`, `JumuahReminderReceiver.kt:32`), which
  only `NativePrayerCalculator.kt:63` writes. Result: orphan `zuhr_time` key, and `dhuhr_time` is not refreshed by this
  Dart path. Breaks the CLAUDE.md rule "prefs key always `dhuhr_time`". Found during EGM batch 2.

## F16 — Offline queue is never populated — VERIFIED (static)
- `OfflineQueueService.enqueue()` (`offline_queue_service.dart:55`) has no caller in `lib/`; `SyncService` replay
  (`sync_service.dart:33–66`, triggered by `connectivity_provider.dart`) only ever pushes Wird. Offline writes rely on
  the Firestore SDK cache instead (UNVERIFIED — device scenario **S19** offline task create → sync). Replay also uses
  `.add()` (non-idempotent). Not a bug yet. If S19 passes on device, `OfflineQueueService` + queue replay = dead code → P6 cleanup.

## F17 — Desktop IP location code is never called → Mecca default — code VERIFIED; DECISION: deliberate (not a bug)
- `_updateIpLocationInBackground` / `_getIpLocation` (`location_service.dart:131–170`) have no callers, so
  `desktop_ip_*` is never written; `getBestLocation` (`:182–192`) falls back to Mecca unless a manual location is set.
  Comment there says "user can set actual location in Settings".
- **Decision (user, 2026-11-06): deliberate for now** — desktop users set their location manually. Not a bug; the unused
  IP-location helpers stay until a phase decides to remove or re-enable them.

## F18 — Desktop in-app notification stream never emits — VERIFIED (static)
- `DesktopNotificationService._notifController` (`desktop_notification_service.dart:39`) is never `add`ed to, but
  `main_wrapper_screen.dart:175` subscribes to `notificationStream` → in-app banners never show on desktop.
- Decision (user): dead code → **P6 cleanup**.

## F19 — Cleanup deletes prayers marked within 20 min of adhan — code VERIFIED, impact UNVERIFIED
- **Tag: likely user-visible bug → fix track** (with F7, F15; needs an approved spec; do not fix during refactor phases).
- `cleanupFuturePrayerRecords` (`prayer_tracking_service.dart:716–741`) deletes today's records with
  `prayedAt < adhan + 20 min`. Desktop adhan toast "Prayed ✓" records `prayedAt: now` at adhan time
  (`desktop_notification_service.dart:158–162`); `NotificationService._handleMarkPrayed` (`notification_service.dart:541`)
  does the same. Such records would be deleted on the next app start that day.

## F20 — Scout-reported issues in lib/core/services
Verified 2026-11-06 (read-only, user picked these three):
- **F20a streak counts missed/excused prayers — VERIFIED.** `_streakFromRecords` (`prayer_tracking_service.dart:477–500`)
  and `_calculateBestStreak` (`:524–544`) count distinct `prayerName` per day (`>= 5`) with no status filter.
  **Tag: likely user-visible bug → fix track** (with F7, F15, F19; needs an approved spec; do not fix during refactor phases).
- **F20b recurring-task duplicates — NOT CONFIRMED (toggle path).** Guest `_completeRecurringTask`
  (`task_service.dart:560–590`) skips the existing-child check, but un-completing runs `_deleteChildTasks` (`:519–523`)
  first, so repeated toggles leave one next instance. Concurrent double-tap race: UNVERIFIED.
- **F20c daily task digest never repeats on its own — VERIFIED.** `scheduleDailyTaskDigest`
  (`notification_service.dart:1040–1068`) is a one-shot `zonedSchedule` (no `matchDateTimeComponents`); it is re-armed
  only by `PrayerTimesNotifier.loadPrayerTimes` side effects (once per date per app process), so days without an app
  start get no digest and counts are frozen at schedule time.
  **Tag: likely user-visible bug → fix track** (with F7, F15, F19; needs an approved spec; do not fix during refactor phases).

### FX-1 — Prayer status ignored/misread in prayer counting (fix item linking F20a + F25)
- Shared root: missed-vs-excused semantics are not applied consistently when counting prayers (VERIFIED in code).
- Distinct sub-causes, must be fixed together: F20a — streak functions ignore status entirely (even `missed` counts);
  F25 — in-app "Missed" writes `excused`, which summary / Prayer screen / statistics treat as not-missed. Fixing F20a
  alone (exclude `missed`) would still count in-app "Missed" as prayed.
- Priority: HIGH. Needs a spec deciding the meaning of existing `excused` records.

**UNVERIFIED backlog** — check only when a phase touches that area:
- notification_service: task snooze uses plugin path on Android and skips `cancelNativeTaskReminder` (:606–654);
  digest channel `task_digest` not pre-created, raw digits in Arabic (:1016–1070);
  `prayer_check` channel created twice (:166, :212); `cancelAllNotifications` leaves native alarms (:920);
  enabling a prayer in `togglePrayerNotification` doesn't reschedule (:1205); unguarded `int.parse` on wird times (:1088).
- prayer_tracking_service: best streak reads the oldest
  5000 records (:517); `deletePrayerRecord` fetches all records of a prayer (:646); no guest branch in `watchDay` /
  `getStatistics` (:227, :302).
- task_service: recurring child drops subtasks/focus fields
  (:581); recurring completion skips achievements (:519); `scheduleDailyTaskSummary` called on desktop (:730);
  migrated tasks keep reminders under old local ids (:104).
- wird_service: pages read past goal not counted (:100–112); juz-mode undo subtracts pages (:176, :204).
- achievement_service: dhikr 100/200 effectively need sessions within 30 days (:190–204).
- desktop: tray actions may fire twice (`desktop_tray_service.dart:86–145`); "Stop Adhan" item hidden right after
  play starts (`desktop_prayer_scheduler.dart:86`); adhan/post-check toasts ignore notify flags (:83, :98).
- auth_service: desktop OAuth has no `state` param and no loopback timeout (:144–179); email logged (:101).
- quran_svg_service: partial download served as cached page (:41–44). rating_service: doc says khatm/records rule,
  code checks only 7-day install age (:8, :33).

## F21 — Wrong revelation type for 4 surahs — data VERIFIED, user-visible
- `kSurahMetaData` (`lib/core/models/quran_models.dart:187–189, 192`) marks Āl-ʿImrān (3), An-Nisāʾ (4), Al-Māʾidah (5)
  and Al-Anfāl (8) as `RevelationType.makki`; they are Madani. File has 24 `madani` entries vs the standard 28.
  Shown in the surah list (`lib/features/quran/quran_screen.dart:280`). Content fix (data only).
- **Tag: likely user-visible bug → fix track, LOW priority.**

## F22 — Model-layer scout backlog (lib/core/models) — UNVERIFIED
Check only when a phase touches the area:
- Mixed date formats: `UserData` uses `Timestamp`, all other models ISO strings; hard `as String` / `as Timestamp`
  casts throw on the other format or on null (`task.dart:105`, `user_data.dart:34`, `dhikr.dart:31`).
- `Task.fromFirestore` sets missing `createdAt` to `now()` → unstable ordering (`task.dart:109`); `as int?` casts throw on
  doubles (`task.dart:119`); `nextRecurrenceDate` ignores interval ≤ 0 (`task.dart:287`).
- Unknown `PrayerStatus` string silently becomes `onTime` (`prayer_record.dart:115`).
- `AzkarState.doneCount` counts stale ids (`azkar.dart:226`); `DhikrSession.isCompleted` true when target 0 (`dhikr.dart:49`).
- `copyWith` cannot clear several nullable fields (`Task.description/tags`, `PrayerRecord.notes`, `PrayerTime.iqamaTime`,
  `UserData.displayName/photoUrl`, `WirdState.todayProgress/streakDate`, `DhikrSession.completedAt`).

## F23 — `flutter/vibration` channel has no native handler — VERIFIED (static)
- `HapticFeedback.notify()` (`lib/core/utils/haptic_feedback.dart:14, :90–92`) invokes `vibrate` on
  `MethodChannel('flutter/vibration')`; no handler in `android/` (grep), and it is not a Flutter engine channel →
  `MissingPluginException` swallowed, `notify()` is a no-op. Dead code candidate (P6) unless a phase wires it.

## F24 — Utils scout backlog (lib/core/utils) — UNVERIFIED
Check only when a phase touches the area:
- `HijriDate.toHijri` approximation: epoch 1948439 vs civil 1948440 (possible off-by-one day), `day` can be 0 at year
  boundary (`hijri_date.dart:20, :30–58`).
- Raw Western digits returned for Arabic by `formatDate`, `formatDateWithMonth`, `formatTimeRange`, `HijriDate.formatAr`
  (`date_formatter.dart:9–29`, `hijri_date.dart:107`) — callers must wrap with `NumberFormatter` (CLAUDE.md rule).
- `canMarkPrayer` Arabic SnackBar interpolates the English prayer key, not `getPrayerDisplayName` (`prayer_time_rules.dart:50`).
- `getPrayerDisplayName` uses today's weekday, not the displayed date → Jumu'ah label wrong when viewing other days
  or after midnight before Fajr on Saturday (`prayer_time_rules.dart:78`).
- `TimeFormatter.parseTime` ignores AM/PM and Arabic digits (`time_formatter.dart:86`).

## F25 — In-app "Missed" is stored as `excused` and counted as prayed — code VERIFIED, likely user-visible
- `showPrayerStatusDialog` "Missed" / لم أصلّ option returns `PrayerStatus.excused`
  (`lib/core/widgets/prayer_status_dialog.dart:57, :63`; callers `home_screen.dart:1640`, `prayer_screen.dart:246`,
  `prayer_tracking_screen.dart:608`). Notification / desktop paths store `missed` (`notification_service.dart:125`,
  `desktop_notification_service.dart:256`, `prayer_alarm_service.dart:332`) → same user action, two stored values.
- Effects of `excused`: `prayer_screen.dart:796` treats it as completed; `PrayerTrackingService.getStatistics` does not count
  it as missed (`prayer_tracking_service.dart:344–348`); `DailyPrayerSummary.completedCount` counts it as completed
  (`prayer_record.dart:148`); streaks count it (F20a); `PrayerCard` still shows a red "Missed" badge.
- Fixing it touches stored data semantics (existing `excused` records) → needs spec + user decision.
- **Tag: likely user-visible bug → fix track, HIGH priority.** Linked with F20a as one fix item **FX-1** (below).

## F26 — Prayer screen list does not show Jumu'ah on Fridays — code VERIFIED
- `prayer_screen.dart:805` passes `PrayerTime` to `PrayerCard`, which renders `nameAr` / `name` directly
  (`lib/core/widgets/prayer_card.dart:121`); `prayer_screen.dart` never calls `getPrayerDisplayName`
  (home_screen does, `:652`). Breaks the CLAUDE.md rule "display names only via `getPrayerDisplayName`".
  `PrayerTimeCard` has the same gap but no user was found outside its own file (dead code candidate, P6).

## F27 — Widgets scout backlog (lib/core/widgets) — UNVERIFIED
Check only when a phase touches the area:
- `CircularCountdownTimer` shows negative values after completion until `targetTime` changes (`circular_countdown.dart:69–85`);
  Arabic `mm:ss` not zero-padded (`:218, :341`).
- `TaskCard` raw Western digits in Arabic for dates/subtasks/estimates (`task_card.dart:583, :591, :641, :661`); accent bar
  and swipe backgrounds not mirrored in RTL (`:267–303`).
- `showDesktopLocationDialog`: dismissing after auto-detect loses the previous manual location (`desktop_location_dialog.dart:120–125`).
- `TutorialOverlay` clamp can throw on short windows; double skip can remove the overlay twice (`tutorial_overlay.dart:104, :279–318`).
- `ConnectivityWrapper` changes its tree on connectivity change → child state lost (`offline_banner.dart:90–102`).
- `permission_dialog.dart`: iOS not excluded; exact-alarm/battery entries shown in `tasks_only` mode (`:42–109`).
- Many hardcoded EN/AR strings without `.tr()` (CLAUDE.md rule) across `prayer_card`, `task_card`, `permission_dialog`,
  `prayer_status_dialog`, `greeting_widget`, `share_card`, `offline_banner`.

## F28 — Desktop version shown in Profile is stale — VERIFIED, user-visible (desktop)
- `AppConstants.desktopVersion = '1.0.3.71'` (`lib/core/constants/app_constants.dart:7`, comment "keep in sync with
  msix_version") is displayed at `lib/features/profile/profile_screen.dart:295`; `pubspec.yaml:116` has
  `msix_version: 1.0.3.114`. Manual sync step was missed (release process issue, not code logic).
- Decision (user): **P6 cleanup**, not fix track.

## F29 — Duplicate / divergent theme tokens (AppTheme vs AppConstants) — VERIFIED (static)
- Independent copies of brand, status, spacing and font-size tokens. Same name, different value:
  `AppTheme.primaryDark #F5B301` vs `AppConstants.primaryDark #D4890A`; dark neutrals differ
  (`AppTheme.surfaceDark #1A1B1E` / `backgroundDark #111317` / `outlineDark #47474F` vs `AppConstants.darkSurface #1E1E1E`
  / `darkBackground #121212` / `darkBorder #3A3A3A`) (`app_theme.dart:26–45`, `app_constants.dart:11, :42–47`).
- `darkTheme` / `amoledTheme` FAB, ElevatedButton, focus border use light `primary #B5821B` (`app_theme.dart:165–201, :249–285`).
  Current look — preserve unless a UI spec decides.
- Dynamic themes have no `textTheme` (`app_theme.dart:325–382`); `AppTheme.primaryFont` / `arabicFont` and
  `dynamic_color` import unused (`:2, :7–9`). Consolidation candidate for a theme phase.

## F30 — Tasks screen issues (lib/features/tasks) — code VERIFIED (static), impact UNVERIFIED
- **(a) Task shown twice** — **Tag: fix track, LOW.** a task due today with a time within the next 3 h is in both Today (`isDueToday && !isOverdue`)
  and Due Soon; both sections render (`tasks_screen.dart:1152–1171, :1242–1265`). Likely user-visible.
- **(b) Pin / sort ignored in dated sections** — **Tag: fix track, MEDIUM; first confirm it is not intentional.** `_applySort` floats pinned tasks (`:1014–1017`), but every dated section is
  re-sorted by `dueDate` (`:1149, :1155, :1171, :1179, :1188, :1196, :1204`). `modules/tasks.md` § TasksScreen says pinned
  tasks always float → doc conflict (code wins).
- **(c) Completed-today with null `completedAt`** — **Tag: fix track, MEDIUM.** `_isCompletedToday` returns `true` when `completedAt == null` (`:1022`).
- **(d) Editing a task due in the past** — **Tag: fix track, HIGH.** `showDatePicker(initialDate: _selectedDueDate, firstDate: DateTime.now())`
  (`task_form_screen.dart:232–233`) breaks the Flutter assert `initialDate >= firstDate`. Device behavior UNVERIFIED.
- **(e) Tags list aliased** — **Tag: fix track, MEDIUM.** `_tags = task.tags ?? []` (`task_form_screen.dart:69`) shares the list with the original `Task`;
  subtasks are copied (`:76`).
- **(f) Focus resume refresh** — **Tag: P3 (provider duplication).** `_checkFocusTaskCompleted` invalidates `tasksProvider(const TaskFilterParams())` (`:164`), but
  the screen watches `allTasksProvider` / `taskStatisticsProvider` (both stream/autoDispose, so they may refresh anyway).

## F31 — Tasks scout backlog (lib/features/tasks) — UNVERIFIED
Check only when a phase touches the area:
- Arabic numerals missing (raw ints): section counts (`tasks_screen.dart:1406`), stats row and calendar (`:736–752, :660,
  :720`), quick-add date (`:2830`); form dates, recurrence label and subtask counter (`task_form_screen.dart:609, :830,
  :1312–1324, :1400`); most stats values (`task_stats_screen.dart:182, :196–199, :524–533, :657, :687, :869–889`).
  Focus chips use hard-coded `'١٥'…` (`task_form_screen.dart:1100–1106`).
- Inline EN/AR strings without `.tr()` in all 3 files (CLAUDE.md rule); Arabic typo 'تمت تحديث المهمة' (`task_form_screen.dart:201`);
  plural 'مهام' for any count (`tasks_screen.dart:1940, :1980, :1998, :2037`).
- Two language sources: UI uses `Localizations.localeOf`; notifications / focus use prefs `language` (`task_form_screen.dart:138,
  :187`, `tasks_screen.dart:1627`).
- No in-flight guard on save / quick add → possible duplicate tasks (`task_form_screen.dart:445`, `tasks_screen.dart:2717`).
- Focus Mode scheduled for date-only (midnight) or past due times (`task_form_screen.dart:136, :185`); the custom-duration field
  does not follow chip taps (`initialValue`, `:1123`).
- `_bulkComplete` toggles already-completed selected tasks back to incomplete (`tasks_screen.dart:1919`).
- Just-completed tasks outside Today/Overdue vanish immediately (the `_recentlyCompleted` exemption is undone by `!t.isCompleted`,
  `:1167–1208`); only tasks completed before today, with no others, give a blank list with no empty state (`:1215`).
- Category: `other` has no chip in the form picker or quick add (`task_form_screen.dart:363`, `tasks_screen.dart:2876–2882`);
  an unknown saved filter falls back to `other` (`:188–191`).
- Calendar view ignores filters/search; select mode survives a switch to calendar (`tasks_screen.dart:254, :271, :492–522`).
- `_duplicateTask` drops subtasks, recurrence, focus, estimate, pin (`:1832–1841`); `_showPriorityPicker` skips the stats invalidate (`:2114`).
- `_InlineSubtaskCard` builds from stale `widget.task.subtasks` (lost update on fast taps); a failed add leaves `_adding` true (`:2980–3023`).
- Missing `mounted` checks after `await` (`tasks_screen.dart:1929, :1969, :2194, :2208`; `task_form_screen.dart:134–148, :1265`).
- Stats: average completion time only counts tasks with a `dueDate` and truncates to hours (`task_stats_screen.dart:739–748`); streak
  not re-read on refresh (`:39–58`); Overview errors render nothing (`:120–147`).
- RTL: `EdgeInsets.only(right:)` / `Positioned(right:)` (`tasks_screen.dart:1535, :2784, :2886`).

## F32 — Home screen issues (lib/features/home) — code VERIFIED (static), impact UNVERIFIED
- **(a) Task streak only counts Home completions** — **Tag: likely user-visible bug → fix track, HIGH.** `task_streak_count` / `task_streak_date` are written only by
  `home_screen.dart` `_incrementStreak` (`:1736–1752`), called when the last "today" task is completed from Home (`:1675`).
  `tasks_screen.dart` has no reference to the streak keys, so finishing the day on the Tasks tab does not extend
  the streak shown in Home, Stats, achievements and the tasks widget. Likely user-visible.
- **(b) Prefs write during build** — **Tag: P4 (Home decomposition).** the streak mini-stat uses `FutureBuilder(future: _getStreak())` (`:1386–1387`), so a new
  future on every rebuild; `_getStreak` writes `task_streak_count = 0` when the streak is broken (`:1730`).
- **(c) Prayer progress labels skip Jumu'ah** — **Tag: fix track, LOW; grouped with F26.** hard-coded Arabic list / `kPrayerNames[i]` (`:1213–1222`), not
  `getPrayerDisplayName` (CLAUDE.md rule). Same family as F26.
- **(d) Tutorial retry never stops after dispose** — **Tag: P4 (Home decomposition).** `_launchTutorialWhenActive` re-schedules itself every 300 ms while
  `!mounted` (`:97–101, :110–113`); a disposed State never remounts and `_pendingTutorialLaunch` is not cleared.
- **(e) Unused code**: `_buildDailyProgressRing` (`:1755`), `_buildRecentActivity` / `_getRecentRecords` (`:1853, :1951`),
  `_getPrayerEmoji` (`:243`) have no callers. **Tag: P6 cleanup.**

## F33 — Home scout backlog (lib/features/home) — UNVERIFIED
Check only when a phase touches the area:
- Inline EN/AR strings without `.tr()` across the screen (only `app_tagline`, tutorial and InfoTip keys are translated);
  AppBar title `'Aura | هالة'` hard-coded (`home_screen.dart:326`).
- Raw Western digits in Arabic: task progress `'$percentage%'` and mini-stats (`:1298, :1373–1390`).
- Countdown: shows `--:--` for the first second (notifier starts at zero) and after reaching zero until the provider
  refreshes `nextPrayer`; `0s` shown for a sub-second remainder (`:54–55, :192–241`).
- `dailyPrayerStatusProvider.load(fajrTime:)` runs once in `initState`; if prayer times are not loaded yet, `fajrTime` is
  null and the load is not repeated (`:74–79`).
- Celebration re-fires when the last task is un-completed and completed again; `wasLastTask` uses a possibly stale
  `valueOrNull` (`:1660–1681`). `overlay.remove()` after 3 s is unguarded (`:1695`).
- Streak "yesterday" uses `now.subtract(Duration(days: 1))` (DST edge) (`:1724, :1746`).
- Mobile adds the pre-tasks gap even in `tasksOnly` mode (`:501`); redundant `?.` on non-null `prayerTimesProvider` (`:75`).

## F34 — Main shell issues (lib/features/main) — code VERIFIED (static), impact UNVERIFIED
- **(a) Swipe reaches hidden tabs (mobile)** — **Tag: fix track, MEDIUM.** the PageView always holds all 5 pages with swipe enabled
  (`main_wrapper_screen.dart:1290–1309`); app mode only hides nav items, so in `tasksOnly` / `prayerOnly` a swipe opens
  Prayer/Quran or Tasks. Likely user-visible.
- **(b) Untracked-prayer sheet ignores the 20-minute rule** — **Tag: fix track, grouped with F19 as one "20-minute
  rule" item (define the rule once, apply everywhere).** past = adhan time passed (`:598–600`); marking goes straight
  to `markToday` without `canMarkPrayer` (`:1017–1038`).
- **(c) Resume untracked check reads reset prayer times** — **Tag: fix track, MEDIUM.** `_checkUntrackedPrayers()` is not awaited (`:115`) and awaits
  `isPrayerTrackingEnabled()` (`:586`) before reading `prayerTimesProvider` (`:594`), while `ref.invalidate(prayerTimesProvider)`
  runs synchronously at `:121`. The comment's "check BEFORE invalidating" intent is not met; the check may see empty times
  and return.
- **(d) `setCurrentRoute` without try-catch or Android guard** — **Tag: P2 (PlatformChannels registry adds the
  Android-only guard).** `_updateCurrentRoute` (`:759–762`) runs on every tab change,
  also on Windows where `MainActivity` does not exist → unhandled `MissingPluginException` (CLAUDE.md: channels always try-catch).
- **(e) Desktop popup unmounts the shell** — **Tag: fix track, LOW (Windows).** while `_activePopup != null`, `build` returns only the popup (`:1166–1288`), so
  `_DesktopShell` and its nested navigator are disposed; pushed routes and sidebar collapse state are lost after each popup.

## F36 — Prayer feature issues (lib/features/prayer) — code VERIFIED (static), impact UNVERIFIED
- **(a) Hanafi Asr never applied** — **Tag: fix track, CRITICAL, first in queue (FX-0); includes the MWL fallbacks for MoonsightingCommittee / Singapore / Turkey and F36c.** `prayer_screen.dart` `_saveCalculationSettings` and `settings_screen.dart:113` store
  `AsrMadhab.value` `'Hanafi'`; `prayer_times_provider.dart` `_getAsrMadhab` matches the lowercase enum
  (`prayer_settings.dart` `hanafi`) → falls back to Shafi, and sends `'shafi'` to native (`:505`). No caller of
  `setAsrMadhab`. `'MoonsightingCommittee'`, `'Singapore'`, `'Turkey'` fall back to MWL (`:531–547`). Likely user-visible.
- **(b) Prayer tab next prayer goes stale** — **Tag: fix track, HIGH.** local copy updated only in `_loadPrayerTimes` (`initState`, pull-to-refresh);
  countdown `onComplete` reloads the provider but not the local state, and the screen never watches it (`prayer_screen.dart:743–755, :401–424`).
- **(c) Settings page method/madhab change** — **Tag: fix track, MEDIUM, grouped with F36a (FX-0).** writes prefs then `Navigator.pop(context)` with no recalculation
  (`prayer_screen.dart:1544–1557`; `settings_screen.dart` calls `_recalculatePrayerTimes`).
- **(d) Doc conflict** — **RESOLVED 2026-11-07** (doc rewritten from code). `modules/prayer-tracking.md` § After-midnight rules describes `_monthlyData`, a `ref.listen` guard and
  an automatic yesterday remap that no longer exist in `prayer_tracking_screen.dart` (code wins).

## F37 — Prayer scout backlog (lib/features/prayer) — UNVERIFIED (backlog, tagged)
- Tracking: a day of five "Missed" (stored `excused`) gets the green complete marker (F25); stats count today's unreached
  prayers in the total; no try/finally in `_loadData`; raw English names and `$e` in Arabic snackbars.
- Report: `totalMissed` derived as 150 − logged (includes not-yet-due and pre-tracking days); 8-day overlapping week buckets;
  last-month window misses day 1 on some dates; best streak only 30 days and order-dependent; `'Dhuhr'` records never shown.
- Settings page: foreground-service toggle has no try-catch / platform guard; `_toggleAdhan` dead; reminder / silent changes
  do not reschedule; summary time without Arabic numerals.
- Prayer tab: unused `_calculationMethod` / `_saveCalculationSettings`, unused imports, `setState` without `mounted` checks.

## F35 — Main shell scout backlog (lib/features/main) — UNVERIFIED
Check only when a phase touches the area:
- Desktop back/Esc switches to Home instead of popping the nested navigator; `SystemNavigator.pop()` on desktop (`:1096–1109`).
- Desktop `/prayer` and `/quran` push a second screen over the PageView instead of switching tabs; sidebar keeps Home
  highlighted (`:1445–1446, :1487–1488`; pushed from `home_screen.dart`).
- Untracked check uses calendar today, not the Fajr-based effective day (`:593, :604`); repeated resumes can stack sheets (`:582, :618`).
- Post-prayer picker list has only `'Zuhr'` (a native `'Dhuhr'` → picker never shows); after Isha both pickers silently do
  nothing (`:774–777, :908–939`).
- Native handler casts `call.arguments[...]` without null/type checks or try-catch (`:255–286`).
- `_handleWidgetIntent` runs from both resume and post-frame; `prefs.remove` not awaited → possible double toggle (`:475–496`).
- Popup queue can stall: `windowManager.isVisible()` outside try, early returns leave `_isShowingPopup = true` (`:361, :395, :408`).
- `_AdhanOverlay` Stop/Prayed do not dismiss it; double `onDismiss` possible (`:1826, :1892–1910`); popup "Dismiss" keeps adhan audio playing.
- `reminder prayerTime` = adhan ms but post-check `prayerTime` = now+delay ms (`:863` vs `:1051`) — check native expectation.
- `_scheduleRemindLater`: unused `bgChannel`, `prefs`, `newTriggerTime` (`:847–856`); local `_toArabicNumerals` duplicates `NumberFormatter` (`:893`).
- Inline EN/AR strings and raw prayer names (no `getPrayerDisplayName`) in popup, overlay, pickers, untracked sheet; sidebar badge
  and tooltips not localized (`:684, :792, :954, :1175–1266, :1552, :1596, :1688, :1734, :1863–1918, :2064`).
- Two user sources (`currentUserIdProvider` vs `currentUserProvider?.uid`, `:478` vs `:589, :1027`); on mobile `jumpToPage` also
  fires `onPageChanged` (double haptic / route update).

## F38 — Quran feature issues (lib/features/quran) — code VERIFIED (static), impact UNVERIFIED
- **(a) Reader close button skips the khatma prompt** — **Tag: fix track, HIGH (khatma not recorded).** `_TopBar.onClose` calls `Navigator.pop(context)` directly
  (`quran_reader_screen.dart:496–501`), which bypasses `PopScope`; the page-604 khatma / Wird prompt and the close
  confirm (`:312–391`) only run on system back or Esc. Page-mode khatma can be lost. Likely user-visible.
- **(b) `scrollToAyaNo` is never used** — **Tag: fix track, MEDIUM.** accepted by `QuranReaderScreen` (`:27, :34`) but never read; search results,
  bookmarks and last-read open the right page but no ayah targeting. Last-read always saves ayah 1 (`_saveProgress`).
- **(c) Wird "choose one" bookmark (page mode) counts every bookmark of that color** — **Tag: fix track, HIGH (wrong Wird progress data).** `wird_tab.dart:627, :649–650`
  sets `countedBookmarkPages = {page}` (`wird_service.dart:358–365`); the auto-sync in `build()` (`:147–189`) then
  sees all other pages of that color as new and calls `syncBookmarkPages` on them.
- **(d) Stats English weekday labels off by one** — **Tag: fix track, LOW.** `quran_stats_screen.dart:390–391` indexes a Monday-first list with
  `weekday % 7` (Monday → "Tu", Sunday → "Mo"); the Arabic list is Sunday-first and correct.
- **(e) Stats average unit wrong in juz mode** — **Tag: fix track, LOW.** `averageDaily = totalPagesRead / totalDaysCompleted`
  (`wird_provider.dart:25`) but is labelled `quran_stats_juz` in juz mode (`quran_stats_screen.dart:142–144`).
- **(f) Contract doc gap** — **RESOLVED 2026-11-07** (keys added to prefs-keys.md). `contracts/prefs-keys.md` lacks `quran_bookmarks`, `quran_reading_progress`
  (`quran_bookmark_service.dart:6–7`), the Wird completed-juz / khatm keys (`wird_service.dart`) and tutorial flag names
  (`app_constants.dart:118–123`).
- Not a bug: "Reset All Progress" (key `wird_reset_today`) wiping all Wird progress is labelled and confirmed as such.

## F39 — Quran scout backlog (lib/features/quran) — UNVERIFIED (backlog, tagged)
Check only when a phase touches the area:
- Reader: marker colors misassigned on pages spanning two surahs (ayahs sorted by `ayaNo` only); the page bookmark
  (`page_<n>`, ayah 1) colors ayah 1 green and appears in green replace candidates; `_juzStartPages` (and
  `QuranService.getJuzList`) use a fixed 20-page table, possibly off for some juz (e.g. 7, 11); desktop drag/arrow
  direction ignores RTL; `_TopBar.pageNo` / `lang` unused; tutorial may no-op when the bars are hidden; preload futures
  unawaited (unhandled errors offline); `ref` after await without `mounted`; hardcoded "Failed to load page", stale "gold" comment.
- Wird: auto-sync side effects in `build()`; `_syncInProgress` stays true if the sync throws; juz grid re-scrolls on
  every build; `prevCompleted != nextCompleted` compares list identity; unawaited concurrent notifier writes
  (`recordPagesRead` + `setLinkedBookmarkColor`); `int.parse` of reminder times without try; `ref` after `showTimePicker`
  without `mounted`; `_showUndo` starts true (Undo shown after restart); count mode no 604 clamp / no error on 0;
  `wird_bookmark_unique_pages` counts bookmarks not pages; unused `setDialogState`, `_BookmarkPagesSheet.lang`, `app_spacing` import.
- Search: clear button does not cancel the debounce (stale results); no Arabic normalization, misnamed `lowerQuery`,
  unbounded results; `quranSearchProvider` family not autoDispose.
- Stats / khatma: average inflated by pages read on incomplete days; khatm circle uses juz list even in page mode;
  hidden `ShareCard` (Opacity 0) leaves a gap; `khatmDates[n-1]` alignment assumed; painter assumes 7 values; fixed sizes
  not text-scaled; deprecated `withOpacity`.
- Localization: raw `'Error: $e'` in all tabs; inline EN/AR close dialog and stats tooltip; `%d` via `toString()`
  (Wird sheets, reader replace sheet); `DateFormat(..., 'ar')` dates not through `NumberFormatter`.

## F40 — Achievements screen (lib/features/achievements) — code VERIFIED (static), impact UNVERIFIED
- **(a) Unknown earned ids inflate the header count** — **Tag: fix track, LOW.** `Achievement.earnedFromFirestore`
  (`achievement.dart:47–61`) maps an unknown id to a `special` "Unknown" badge; `earnedCount`
  (`achievements_screen.dart:67–69`) counts it but `visibleTotal` (`:64–66`) does not, so "N of M" can exceed M.
  Only if Firestore holds ids no longer in `AchievementDefinitions.all`.
- **(b) Inline EN/AR strings** — **Tag: fix track, LOW.** title, header and category names (`:73, :105, :113–115,
  :147–154`) bypass `.tr()`.
- **(c) `_totalAchievements` is set but never read** (`:23, :42`) — **Tag: P6.**
- Backlog (UNVERIFIED, check when a phase touches it): badge width from `MediaQuery` screen width (`:261`) may be
  wrong inside the desktop shell pane; load errors show as "0 earned" with no message (`:46–48`); deprecated
  `withOpacity`.

## F41 — Auth screens (lib/features/auth) — code VERIFIED (static), impact UNVERIFIED
- **(a) Guest flag reset after onboarding finishes** — **Tag: fix track, HIGH (guest data migration; user
  2026-11-07). Device check S22 (pending on nova 5T).** `_continueAsGuest` (`login_screen.dart:209–231`) awaits `pushNamed('/onboarding')` and then calls
  `setGuest(false)` if still mounted. `PreferenceScreen._finish` leaves with `pushReplacementNamed('/home')`
  (`preference_screen.dart:245`), which completes the replaced route's future while Login stays in the stack under
  `/home` (mounted). Expected result: `is_guest` = false right after guest onboarding. Then (1) Splash sends the
  next cold start to `/login` (`splash_screen.dart:218–224`), and (2) a later sign-in sees `wasGuest == false`
  (`auth_provider.dart:63, :130–139`), so `pending_guest_migration_uid` is never set and the local-task sync prompt
  is skipped. Device check: guest → finish onboarding → kill app → relaunch; Login shown = confirmed.
- **(b) Raw exception text in snackbars** — **Tag: fix track, LOW.** `_showErrorSnackBar(e.toString())` in both
  screens shows `Exception: …` (English, from `AuthService`) in Arabic UI too.
- **(c) Inline EN/AR strings** in the forgot-password dialog (`login_screen.dart:245–282`) — **Tag: fix track, LOW.**
- **(d) Dead code** — **Tag: P6.** `_showDesktopGoogleDialog`, `_step`, `_isDesktop` (login), `_isDesktopSignup`
  (signup); desktop Google sign-in now goes through `AuthService.signInWithGoogle` (`auth_service.dart:88`).
- **(e) Contract doc gap** — **RESOLVED 2026-11-07** (keys added to prefs-keys.md). `is_guest`
  (`AppConstants.keyIsGuest`) and `pending_guest_migration_uid` (`auth_provider.dart:138`) were missing.

## F42 — Azkar screen (lib/features/azkar) — code VERIFIED (static), impact UNVERIFIED
- **(a) Stale streak shown** — **Tag: fix track, LOW.** `azkar_provider.dart` `_onSessionComplete` (`:74–97`) is the
  only place `streakCount` changes; nothing resets it after a skipped day, and `_ProgressHeader` shows it whenever
  > 0 (`azkar_screen.dart:286`). A broken streak keeps showing its old value until the next completion.
- **(b) No day rollover while the app stays alive** — **Tag: fix track, LOW.** the date reset runs only in
  `AzkarNotifier._load` (`azkar_provider.dart:19–27`, provider is not autoDispose), so ticks from yesterday stay
  visible after midnight until the app process restarts.
- **(c) Inline EN/AR strings** (title, tabs, header) — **Tag: fix track, LOW.**
- **(d) Dead code** — **Tag: P6.** `AzkarState.totalSessions` is written (`_onSessionComplete`) but never read;
  `AzkarNotifier.resetDay` has no callers.
- Backlog (UNVERIFIED): `totalSessions` also grows on every un-tick/re-tick of the last item; deprecated
  `withOpacity`.
- Contract doc gap — **RESOLVED 2026-11-07**: `azkar_state` / `azkar_streak_date` added to prefs-keys.md.

## F14 — Contract doc errors corrected in Step 2 — VERIFIED
- Foreground channel is `prayer_foreground_channel_v4` (not `prayer_foreground_channel`).
- `ringer_mode` handler is in `MainActivity`, not `SilentModeAutomation.kt`.
- `_syncNativePrayerStatuses()` → renamed `_syncThenLoadPrayerStatus()` in 088d2cb (sync to Firestore, then load
  provider once). `focus_a11y_ever_enabled` → removed in bc765f6 with the accessibility service; no replacement.
  Both resolved via `git log -S` (read-only).
- Undocumented prefs files `aura_tasks_widget`, `aura_focus_state`; undocumented IDs 1–6, 2000, 4001, 5001–5006,
  5998, 5999, 9999 and channels `prayer_check`, `azkar_reminder`, `focus_mode`, `focus_mode_service`, `prayer_reschedule`.

## Doc conflicts found while relocating old CLAUDE.md (code wins; resolve in Step 2)
| # | Old CLAUDE.md said | Observed 2026-11-06 | Status |
| --- | --- | --- | --- |
| D1 | Version 1.0.0+42 | `pubspec.yaml` 1.0.0+59, msix 1.0.3.114 (doc said last msix 1.0.3.64) | VERIFIED |
| D2 | "20 named routes" and "Routes (21)" | 25 `case` routes in `main.dart` (+`/azkar`, `/quran_stats`, `/islamic_events`, `/khatma_dua`) | VERIFIED |
| D3 | 22 Kotlin files | 30 `.kt` files | VERIFIED |
| D4 | 7 MethodChannels; MainActivity "8 handlers" | 8 channel names in Kotlin incl. undocumented `com.aura.hala/app_control` | VERIFIED (Kotlin side) |
| D5 | Foreground service "launches MainActivity with `refresh_prayer_times` extra" on day transition | Code calls `NativePrayerCalculator.calculateAndSave()` (`PrayerForegroundService.kt:857`); no activity launch. Doc corrected | VERIFIED — resolved |
| D6 | Translations "~280 keys" and "~265 strings" | 450 top-level keys in each of en.json / ar.json | VERIFIED (top-level only) |
| D7 | Widget tab handoff writes `widget_navigate_to_tab` to `${packageName}_preferences` | Prefs table lists it in `FlutterSharedPreferences` and says `${packageName}_preferences` is Focus Mode only | VERIFIED — resolved: `MainActivity.kt:57` uses `FlutterPrefs.putInt` |
| D8 | Native table row "NativePrayerCalculator.kt → MainActivity.kt" for widget tab handling | Handling described is in MainActivity only | Mislabeled row; dropped |
| D9 | "Day transition" also in notification section | Same claim as D5 | VERIFIED — resolved with D5 |
