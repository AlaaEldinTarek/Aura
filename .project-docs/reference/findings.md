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
- **Tag: P6 cleanup (moved from settings-bridge group, spec 2026-11-09; see F49).** Unused channel with no handler;
  silent mode works natively via prefs (contracts/prefs-keys.md).
- `silent_mode_service.dart:14` invokes `setEnabled`/`setDuration`/`cancelAll`; no Kotlin registers `silent_mode`
  (calls would throw `MissingPluginException`, caught). No importer of `silent_mode_service.dart` found in `lib/`/`test/`
  → likely dead code (UNVERIFIED; "not found" ≠ unused).

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

## F15 — Dart writes `zuhr_time` into native `aura_prayer_times` — FIXED (settings-bridge commit 1, 92b9f71)
- **Tag: FIXED.** All Dart senders now use `nativePrayerKey()` (`prayer_time_rules.dart`), which maps zuhr→dhuhr.
  Covered by scan test `native_keys_scan_test.dart` and unit test `prayer_time_rules_native_key_test.dart`.
  Was: grouped in "Dart->native settings bridge" (with F49a, F49b, F9; see F49).
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
- **F20a streak counts missed/excused prayers — DONE — PR #16 merged (e09b83d), device PASS nova 5T 2026-11-11.** Spec docs/designs/fix-streak-prayer-missed.md.
- **F20b recurring-task duplicates — NOT CONFIRMED (toggle path).** Guest `_completeRecurringTask`
  (`task_service.dart:560–590`) skips the existing-child check, but un-completing runs `_deleteChildTasks` (`:519–523`)
  first, so repeated toggles leave one next instance. Concurrent double-tap race: UNVERIFIED.
- **F20c daily task digest never repeats on its own — VERIFIED.** `scheduleDailyTaskDigest`
  (`notification_service.dart:1040–1068`) is a one-shot `zonedSchedule` (no `matchDateTimeComponents`); it is re-armed
  only by `PrayerTimesNotifier.loadPrayerTimes` side effects (once per date per app process), so days without an app
  start get no digest and counts are frozen at schedule time.
  **Tag: likely user-visible bug → fix track** (with F7, F15, F19; needs an approved spec; do not fix during refactor phases).

### FX-1 — Prayer status ignored/misread in prayer counting (fix item linking F20a + F25) — DONE
- **DONE — FX-1 merged on fix/streak-prayer-missed (651a9c2) 2026-11-11; device PASS nova 5T (Zuhr_2026-11-11: stored missed, snackbar red, streak excludes day, calendar excludes day).** Spec docs/designs/fix-streak-prayer-missed.md. Existing `excused` records kept as-is; treated as not-prayed by new counting logic.
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

## F25 — In-app "Missed" is stored as `excused` and counted as prayed — DONE
- `showPrayerStatusDialog` "Missed" / لم أصلّ option returns `PrayerStatus.excused`
  (`lib/core/widgets/prayer_status_dialog.dart:57, :63`; callers `home_screen.dart:1640`, `prayer_screen.dart:246`,
  `prayer_tracking_screen.dart:608`). Notification / desktop paths store `missed` (`notification_service.dart:125`,
  `desktop_notification_service.dart:256`, `prayer_alarm_service.dart:332`) → same user action, two stored values.
- Effects of `excused`: `prayer_screen.dart:796` treats it as completed; `PrayerTrackingService.getStatistics` does not count
  it as missed (`prayer_tracking_service.dart:344–348`); `DailyPrayerSummary.completedCount` counts it as completed
  (`prayer_record.dart:148`); streaks count it (F20a); `PrayerCard` still shows a red "Missed" badge.
- Fixing it touches stored data semantics (existing `excused` records) → needs spec + user decision.
- **Tag: likely user-visible bug → fix track, HIGH priority. DONE — FX-1 merged on fix/streak-prayer-missed (651a9c2), device PASS nova 5T 2026-11-11.** Linked with F20a as one fix item **FX-1** (above).

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
- **(a) Hanafi Asr never applied** — **DONE — FX-0 merged to main via PR #1 (195e284), after-fix S29 + S33 PASS 2026-11-08 (FX-0 commit 4, 2026-11-08; unit-tested, after-fix device check pending).** **Tag: fix track, CRITICAL, first in queue (FX-0); includes the MWL fallbacks for MoonsightingCommittee / Singapore / Turkey, F36c and F52a.** `prayer_screen.dart` `_saveCalculationSettings` and `settings_screen.dart:113` store
  `AsrMadhab.value` `'Hanafi'`; `prayer_times_provider.dart` `_getAsrMadhab` matches the lowercase enum
  (`prayer_settings.dart` `hanafi`) → falls back to Shafi, and sends `'shafi'` to native (`:505`). No caller of
  `setAsrMadhab`. `'MoonsightingCommittee'`, `'Singapore'`, `'Turkey'` fall back to MWL (`:531–547`). Likely user-visible.
  Likely root cause: duplicate `AsrMadhab` / method enums (F49f, linked to FX-0).
- **(b) Prayer tab next prayer goes stale** — **Tag: fix track, HIGH.** local copy updated only in `_loadPrayerTimes` (`initState`, pull-to-refresh);
  countdown `onComplete` reloads the provider but not the local state, and the screen never watches it (`prayer_screen.dart:743–755, :401–424`).
- **(c) Settings page method/madhab change** — **DONE — FX-0 merged to main via PR #1 (195e284), after-fix S29 + S33 PASS 2026-11-08 (FX-0 commit 10, 2026-11-08; no unit test for the screen, after-fix device check S33 pending).** **Tag: fix track, MEDIUM, grouped with F36a (FX-0).** writes prefs then `Navigator.pop(context)` with no recalculation
  (`prayer_screen.dart:1544–1557`; `settings_screen.dart` calls `_recalculatePrayerTimes`).
  Device evidence (2026-11-08, nova 5T, base, S33): six saves from the prayer settings page dialog (Method and Asr
  Madhab tiles; log `Saved calculation settings:` is printed only by `prayer_screen.dart`) — Qatar 12:32:38,
  Singapore 12:32:51, Egyptian 12:33:05, UmmAlQura 12:33:47, MuslimWorldLeague 12:34:25 — none followed by a
  recalculation. The only recalc came at 12:34:00, 13 ms after the app regained focus from the status bar (trigger UNKNOWN: a
  similar focus return at 12:36:33 did not recalculate), using
  the then-stored UmmAlQura (`Calculation method: makkah`): Isha alarm moved 18:22 → 18:39. The final MWL save had no
  recalc, so prefs said MWL while alarms / widget / native data were still Umm al-Qura until the next resume. Qatar was
  never calculated. Device impact VERIFIED for this path. General Settings path: not exercised in this run (no save
  there was followed by its `loadPrayerTimes`), so F36c's note that Settings recalculates is neither confirmed nor
  contradicted — UNVERIFIED (`reference/logcat/S33-method-2026-11-08.txt`).
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
- **Status 2026-11-11 — F38a + F38c: design approved (design only), NOT fixed.** Design `docs/designs/fix-quran-khatma-wird.md` on branch `fix/quran-khatma-wird`, commits, newest first: `41ef2fd` docs: approve F38 design (design only; UNVERIFIED items remain open); `69730e7` docs: fix dangling risk reference and CUJ 6 wording in F38 design; `a37dfde` docs: apply review minors to F38 design (streak, close taps, dates); `0d7af9c` docs: apply round-6 F38 review fixes (CUJ 4, S45 step 3); `a4c969e` docs: apply round-5 F38 review fixes (S46 start state, Goal 7); `1fd8b48` docs: clarify S45/S46 device-state wording; `80cb9e8` docs: state that S45/S46 device results do not transfer between devices; `3d6ed3f` docs: apply gate-review fixes to F38 design (S45/S46 days, known limit); `cee328d` docs: apply round-3 review fixes to F38 design (S45 order, scope, goals); `78b5369` docs: list later F38a/F38c spec commits in STATE and findings; `5396481` docs: correct resolve report on F38 visibleForTesting import claim; `59f6c63` docs: fix F38 S46 step order, import claim, and overlap wording; `17e2e69` docs: qualify F38 Goal 5 guard wording; `bae3f40` docs: add sync-revert and double-tap risks and follow-ups to F38; `0f1f4fa` docs: list F38a/F38c spec commits in STATE and findings; `8a0b66c` docs: qualify F38 design guarantees against Risks (a)/(b); `e1f080a` docs: track F38a/F38c review working reports referenced by round 2 report; `9da758e` docs: record round 2 review of F38a/F38c spec; spec not approved; `2eed355` docs: apply F38 review decisions to Quran khatma/Wird design; `953ec7a` docs: add F38a+F38c fix design for Quran khatma and Wird bookmark. The oldest ten of these are design, review or log text only (`9da758e` and `0f1f4fa` also edit these STATE/findings log lines); no code, tests or translation files. Design Status is Approved (design only); Level C code still needs "approve phase". Nothing in this section has been confirmed on a device; the "code VERIFIED (static)" tag above still means code reading only. Device checks S45 (F38a) and S46 (F38c) are written and not run. Open: Arabic wording of `wird_bookmark_already_counted` (native review); service-level tests (UNVERIFIED probe); double-tap behavior ("Repeated close taps", S45 step 3); `maybePop` reaching `PopScope` on device (S45); `project-log` skill claim (skill file not read).

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
  2026-11-07); group "sign-in & onboarding flow" with F46a, F47f. DEVICE-VERIFIED 2026-11-07: S22 on nova 5T (API 29), base 1.0.0+59 — Login shown on relaunch.** **Status 2026-11-09: FIXED on `fix/signin-onboarding` (7e494f2), not merged; device check S22 after-fix pending.**
  Effect (1) confirmed on device; effect (2) (migration prompt skipped) follows from code, not device-checked (S20). `_continueAsGuest` (`login_screen.dart:209–231`) awaits `pushNamed('/onboarding')` and then calls
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
- **(a) Stale streak shown** — **Tag: fix track, MEDIUM (tracking; same family as F32a streak; user 2026-11-07).** `azkar_provider.dart` `_onSessionComplete` (`:74–97`) is the
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

## F43 — Daily content screen (lib/features/daily_content) — code VERIFIED (static), impact UNVERIFIED
- **(a) English-only translation and source in Arabic UI** — **Tag: fix track, LOW.** `DailyContent` has only
  `translation` / `source` in English (`daily_content_service.dart`); `daily_content_screen.dart:94–122` shows them
  right-aligned under the Arabic text. May be intended (bilingual card) — confirm intent before fixing.
- **(b) Inline EN/AR title strings** (`:23–25`) — **Tag: fix track, LOW.**
- Backlog (UNVERIFIED): `_dayOfYear` (`daily_content_service.dart:139–140`) is 0-based and wraps by list length, so
  Jan 1 always shows item 0; whether the native `DailyContentWidget` picks the same item is not checked here
  (see modules/widgets when documenting android kotlin).

## F44 — Dhikr feature (lib/features/dhikl) — code VERIFIED (static), impact UNVERIFIED
- **(a) "Continue" in the completion dialog resets the counter** — **Tag: fix track, LOW.** The button calls
  `_incrementCounter` (`dhikr_screen.dart:215–218`), which resets when `_isCompleted` is true (`:106–109`), so it
  behaves exactly like "Start New". Likely user-visible.
- **(b) Raw integers in Arabic UI** — **Tag: fix track, LOW.** counter `'$_currentCount'`, `'/ $_currentTarget'`
  (`:716, :726`), target label (`:615`) and the target sheet values (`:478+`) skip `NumberFormatter` (CLAUDE.md rule).
- **(c) Inline EN/AR strings** in all three screens — **Tag: fix track, LOW.**
- Backlog (UNVERIFIED): `_onComplete` (dialog + unawaited Firestore write) runs inside `setState`; stats load runs
  7 sequential range queries plus 2 others; progress bar `Alignment.centerLeft` ignores RTL; `_loadCustomPresets`
  calls `setState` without a `mounted` check; double haptics (`HapticFeedback` + `vibration` plugin, see F23);
  session row falls back to hardcoded `'Custom'`; deprecated `withOpacity`.
- Contract doc gap — **RESOLVED 2026-11-07**: `custom_dhikr_presets` added to prefs-keys.md.

## F45 — Islamic events screen (lib/features/islamic_events) — code VERIFIED (static), impact UNVERIFIED
- **(a) Event countdowns go stale across midnight** — **Tag: fix track, LOW.** `islamicEventsProvider`
  (`islamic_events_provider.dart:5–7`) is a plain `Provider` computed once per process; `daysUntil` and "Today!" do
  not advance until the app restarts. Also affects the Home event card (`daysUntil <= 30` filter).
- **(b) Hijri date shown with Western digits in Arabic UI** — **Tag: fix track, LOW.** `_hijriLabel`
  (`islamic_events_screen.dart:73–76`) uses `HijriDate.formatAr` directly; it returns raw digits (see F24 backlog).
- **(c) Unused `isDesktop` + `Platform` / `kIsWeb` imports** (`:1, :3, :23`) — **Tag: P6.**
- Backlog (UNVERIFIED): event dates rely on the arithmetic `HijriDate` (F24: possible off-by-one, `day` 0 at year
  boundary) and may differ from local sighting by 1–2 days; multi-day events (e.g. first 10 days of Dhul Hijjah)
  show only their first day, then jump to next year; Arabic "بعد $n يوم" uses singular يوم for every n; inline
  countdown strings; deprecated `withOpacity`.

## F46 — Onboarding (lib/features/onboarding) — code VERIFIED (static), impact UNVERIFIED
- **(a) Onboarding resets language / theme / mode to defaults on re-login** — **Tag: fix track, MEDIUM (user
  2026-11-07); group "sign-in & onboarding flow" with F41a, F47f. Not intended: 5873793 ("Stop login from resetting device
  language and theme") fixed the same effect at login. Device check S23 (not run yet). Open product question for
  the fix spec: returning users skip onboarding entirely, or onboarding preloads saved values?** **Status 2026-11-09: FIXED on `fix/signin-onboarding` (7f3889a): returning users (`first_launch` false) skip onboarding (user decision); not merged; S23 after-fix pending.** `_PreferenceScreenState` starts from `_language = 'en'`,
  `_theme = 'system'`, `_mode = AppMode.both` (`preference_screen.dart:27–29`) instead of the saved values, and every
  sign-in routes to `/onboarding` (`login_screen.dart:51, :71`, `signup_screen.dart:56, :76`). An Arabic / dark /
  prayer-only user who signs out and back in sees English defaults; "Skip" (`:353–354`) or "Continue" through
  saves them (`_finish`, `:233–238`). Fresh installs are unaffected (defaults match).
- **(b) Inline EN/AR strings** throughout the wizard — **Tag: fix track, LOW.**
- **(c) Dead code** — **Tag: P6.** `ModeSelectionScreen` / route `/mode_selection` (no navigator); no-op
  `ctx.findAncestorStateOfType<State>()` in `_finish` (`:235–236`).
- Backlog (UNVERIFIED): `_finish` swallows every error with no message (`:247`); no `PopScope`, so system back on
  steps 1–4 leaves onboarding (exits the app after sign-in, cancels guest from Login); progress-bar margin uses
  `right:` (ignores RTL); carousel marketing claims ("9 scholarly methods", "Silences all notifications") not checked
  against code.

## F47 — Profile screen (lib/features/profile) — code VERIFIED (static), impact UNVERIFIED
- **(a) Edited display name may not refresh** — **Tag: fix track, LOW.** `_showEditNameDialog` calls
  `user.updateDisplayName` (`profile_screen.dart:897`), but the screen rebuilds only from `authStateProvider`
  (`authStateChanges`, `auth_provider.dart:29–30`), which does not emit on profile updates; the Firestore user doc
  is not updated either. Needs a device check.
- **(b) Raw numbers in Arabic UI** — **Tag: fix track, LOW.** completion `'${…}%'` (`:645–647`) and the guest-sync
  count `replaceAll('%d', '${migration.taskCount}')` (`:360–362`) skip `NumberFormatter`.
- **(c) Raw error text** — **Tag: fix track, LOW.** `'Error: $e'` snackbars in edit-name / change-password (`:902, :957`).
- **(d) Inline EN/AR strings** for most labels — **Tag: fix track, LOW.**
- **(e) Dead code** — **Tag: P6.** `_showThemeDialog`, `_getThemeModeText`, `_showLanguageDialog`,
  `_JumuahReminderTile` have no callers (theme / language / Jumu'ah live in Settings).
- **(f) Logout has no defined destination** — **Tag: fix track, group "sign-in & onboarding flow" (with F41a, F46a;
  user 2026-11-07). The fix spec must define logout behavior.** **Status 2026-11-09: FIXED on `fix/signin-onboarding` (3552c52): logout → Login with the stack cleared when no user is signed in afterwards; local data kept (F59); not merged; S36 pending (Android + Windows).** `_showLogoutDialog` only calls `signOut()`
  (`:1035–1037`); nothing navigates (no auth listener in `main_wrapper_screen.dart`). The shell stays open on
  `guest_user` data with `is_guest == false`; the next cold start goes to `/login` (`splash_screen.dart:218–224`).
- **(g) Firestore usage (performance — measure, don't guess)** — **Tag: P3 (repositories / caching; user
  2026-11-07).** `_buildPrayerStatsSummary` builds `FutureBuilder(future: _loadProfileStats())` inside `build`
  (`:632–633`), so every rebuild runs 3 reads (`getStatistics`, `calculateCurrentStreak`, `getEarnedCount`,
  `:845–851`); `_AchievementsBadgeGrid.initState` runs `checkAndAward` (reads + possible writes) on every mount
  (`:1179–1182`). To measure before P3: count Firestore reads/writes per Profile visit and per rebuild (debug log
  counters or Firebase console usage), on a signed-in account.
- Backlog (UNVERIFIED): `migrate()` errors are unhandled (no snackbar, button throws); change-password tile shown for
  Google accounts and has no recent-login handling; deprecated `withOpacity`.

## F48 — Qibla screen (lib/features/qibla) — code VERIFIED (static), impact UNVERIFIED
- **(a) Instruction text ignores 0/360 wrap and direction** — **Tag: fix track, MEDIUM (Qibla accuracy affects
  prayer; users follow the text; user 2026-11-07); group "Qibla accuracy" with F48f.** `_buildInstructions` uses `(_qiblaDirection! - _heading!).abs()` (`qibla_screen.dart:353–355`): with
  qibla 5° and heading 355° (10° off) it says "Turn to the right" instead of "facing/close"; for every larger
  offset it always says "Turn to the right", even when left is shorter (`:366–368`). The dial marker itself is
  correct. Affects users whose qibla bearing is near north (e.g. south of Makkah).
- **(b) Error title chosen by theme, not language** — **Tag: fix track, LOW.** `isDark ? 'خطأ في تحميل القبلة' :
  'Error loading Qibla'` (`:415`): dark theme shows Arabic, light shows English.
- **(c) Endless spinner without compass events** — **Tag: P2 (platform guard).** `_isLoading` turns false only in the
  compass listener (`:97–100`); `FlutterCompass.events?.listen` does nothing if the stream is null (no sensor, and
  likely Windows — the route is built in the desktop shell). No error or fallback shown. Desktop behavior UNVERIFIED.
- **(d) Raw digits in Arabic UI** — **Tag: fix track, LOW.** distance `'${distance.toStringAsFixed(0)} كم'` (`:233–235`).
- **(e) Inline EN/AR strings; raw `e.toString()` error text** — **Tag: fix track, LOW.**
- **(f) Possible magnetic-vs-true-north offset** — **Tag: fix track, MEDIUM pending measurement (user 2026-11-07);
  group "Qibla accuracy" with F48a. Device check S24 (not run yet).** The bearing is relative to true north
  (`_calculateQiblaDirection`, `:111–129`), but no declination correction is applied to the `flutter_compass`
  heading (`:81–101`). If that heading is magnetic, the arrow is off by the local declination (~4–5° in Egypt).
- Backlog (UNVERIFIED): `setState` after `await getBestLocation` without `mounted`
  (`:59, :103`); `CompassPainter.heading` always 0 (unused parameter); app-bar `titlePadding` `left: 16` ignores RTL.

## F49 — Settings feature (lib/features/settings) — code VERIFIED (static), impact UNVERIFIED
- **Fix-track group "Dart->native settings bridge"** — **FIXED** (branch `fix/settings-bridge`, commits 1–4). All 7
  bugs resolved: F15 (commit 1), F49a + F49h (commit 2), F49b (commit 3), F51i + F49i + adhan_enabled dedup (commit 4).
  F9 moved to P6 cleanup. Device checks S25, S26, S42, S43 pending.
- **(a) Silent-mode toggle never reaches native** — **FIXED (settings-bridge commit 2, fec8f32).** Both
  `PrayerAlarmReceiver.kt` and `AdhanFullScreenActivity.kt` now read `silent_mode_enabled` from
  `FlutterSharedPreferences` via `FlutterPrefs`. Device check: S25 (pending).
  Was: fix track HIGH; group "Dart->native settings bridge"; device scenario S25.
- **(b) Chosen adhan reciter is not persisted natively** — **FIXED (settings-bridge commit 3, b0821b2).** `AdhanPlayer.play`
  now reads `selected_adhan_id` from `FlutterPrefs` and resolves the file via `AdhanFiles.resolve()`.
  In-memory `customAdhanPath`, `setCustomAdhan`/`getCustomAdhan` channel methods removed. Preview uses a new
  `previewAdhan` method that plays without storing. Device check: S26 (pending).
  Was: fix track HIGH; group "Dart->native settings bridge"; device scenario S26.
- **(c) Calculation dialog does not scroll; Asr madhab section unreachable on small screens** — **DONE — FX-0 merged to main via PR #1 (195e284), after-fix S29 + S33 PASS 2026-11-08 (FX-0 commit 5a, 2026-11-08; unit-tested, after-fix device check pending).** **Tag: fix track,
  HIGH; joined FX-0 (CRITICAL group; user 2026-11-08, spec A-1).** `PrayerCalculationSettingsDialog` lays out 14
  `ListTile`s in a non-scrolling `Column` (`prayer_calculation_settings_dialog.dart:37–157`). All madhab entry points
  open it: Settings tile (`settings_screen.dart:100`), prayer settings page Method and Asr Madhab tiles
  (`prayer_screen.dart:1486, :1517`). Device evidence (2026-11-08, nova 5T, base): the list is cut off at "Singapore"
  and does not scroll, so Hanafi cannot be selected anywhere; S29 cannot be set up at normal Display/Font size.
  Device impact VERIFIED. (Split from the old (c); the selection half is (j).)
- **(j) Calculation dialog does not show a tap** — **DONE — FX-0 merged to main via PR #1 (195e284), after-fix S29 + S33 PASS 2026-11-08 (FX-0 commit 5a, 2026-11-08; unit-tested, after-fix device check pending).** **Tag: fix track, MEDIUM; joined FX-0 (user 2026-11-08, spec
  A-1).** The dialog is stateless (`:11`), so `isSelected` / `groupValue` stay on `currentMethod` / `currentMadhab`
  passed at open (`:74, :78, :116, :120`); a tapped option does not show as selected until reopened. A Hanafi user
  cannot see the selection take effect (Settings entry point keeps the dialog open). Code VERIFIED (static).
- **(k) Asr Madhab tile opens the dialog at the methods list** — **REPLACED by F57 (user 2026-11-08): split dialogs; the
  scroll-to-madhab fix below is dropped.** ~~Tag: fix track, LOW; outside FX-0 (user 2026-11-08).~~ The prayer settings page's Asr Madhab tile (`prayer_screen.dart:1517`) opens the same dialog as the
  Method tile, starting at the 12 methods, so the madhab section is the last thing on screen (after A-1's scroll fix
  the user must still scroll past all methods). Proposed fix (not in A-1: it changes the `show()` signature, a caller
  and adds a UI behavior): optional `scrollToMadhab` flag on `show()` / constructor, `GlobalKey` on the madhab
  header + `Scrollable.ensureVisible` after first frame; only the Asr Madhab tile passes it; widget test at 360×640.
  Device observation (nova 5T, base); code VERIFIED (static).
- **(d) Raw values in UI** — **Tag: fix track, LOW.** Settings subtitle shows stored keys (`'$_calculationMethod ·
  $_asrMadhab'`, `settings_screen.dart:99`); minute counts (`:135, :170, :322, :348`) and the summary time (`:236`)
  are raw digits in Arabic.
- **(e) Inline EN/AR strings** across the folder — **Tag: fix track, LOW.**
- **(f) Duplicate `AsrMadhab` enums** (`asr_madhab_selection.dart` vs `core/models/prayer_settings.dart`, different
  string forms) and two method enums — **Tag: P3, linked to FX-0** (likely root cause of F36a; fix with FX-0).
- **(g) Contract doc error** — `contracts/prefs-keys.md` listed `aura_prefs` as holding "custom adhan" and
  `aura_silent_mode.silent_mode_enabled` as native-only; code shows custom adhan is in memory only and the flag has
  no writer. **Corrected in `contracts/prefs-keys.md` in the settings EGM commit (2026-11-07).**
- **(h) Silent-mode toggle receiver reads language from `aura_prefs`** — **FIXED (settings-bridge commit 2, fec8f32).**
  `ToggleSilentModeReceiver`'s `getLanguage` method removed; callers at lines 142, 222, 238 switched to a new
  `getLanguagePreference` method that reads from `aura_prayer_times` (the correct source).
  Was: fix track LOW; group "Dart->native settings bridge".
- **(i) Boot receiver's `aura_prefs.notifications_enabled` check has no effect** — **FIXED (settings-bridge commit 4,
  990c71d).** Dead check removed from `PrayerBootReceiver.reschedulePrayerAlarms`. `aura_prefs` now has zero readers.
  Was: joined settings-bridge group (spec 2026-11-09, §8); was P6 cleanup.
- Backlog (UNVERIFIED): iqama save does not recalculate (new iqama shows after the next load); service ignores a
  legacy `Dhuhr` iqama key; theme dialog lacks `amoled` (shown as "System" if set elsewhere); download errors are
  English-only; `setState` / `ref` after awaits without `mounted` in places; deprecated `withOpacity`.

## F50 — Splash screen (lib/features/splash) — code VERIFIED (static), impact UNVERIFIED
- **(a) Unused permission helper** — **Tag: P6.** `_requestNotificationPermission` (`splash_screen.dart:37–44`) has
  no caller (`initState` comment says permission is requested after onboarding); it is the only use of the
  `notification_service.dart` import.
- **(b) Routing depends on the 2.5 s delay, not on state readiness** — **Tag: fix track LOW, group
  "sign-in & onboarding flow" (user 2026-11-07).** **Status 2026-11-09: FIXED on `fix/signin-onboarding` (620a394): notifiers start as loading, Splash waits for all three inputs and navigates once; unit-tested; not merged.** `FirstLaunchNotifier` / `GuestModeNotifier` start as
  `AsyncValue.data(true)` / `data(false)` (`preferences_provider.dart:196–199, :225–228`), so the
  `guestModeAsync.isLoading` guard (`splash_screen.dart:211`) never holds during the initial read, and
  `firstLaunchProvider` is not checked at all. If the prefs reads have not finished when `splashDuration` ends, a guest
  is sent to `/login` and a returning user to `/onboarding`. Prefs reads are normally much faster than 2.5 s; no
  device evidence.
- Backlog (UNVERIFIED): `_AuthNavigationHandler` schedules a `pushReplacementNamed` on every rebuild after the delay;
  a provider change during the route transition (old route still mounted) could navigate twice. Deprecated
  `withOpacity` (`:81`).

## F51 — Android native (android/app/src/main/kotlin/com/aura/hala) — code VERIFIED (static), impact UNVERIFIED
Scout claims re-checked in code before tagging: (a), (e), (k) invoke paths, (m), (p), (q). Checked and fine:
calculator method/madhab strings equal Dart enum `.name` values (`prayer_settings.dart`); Dart cache keys map
`Zuhr` → `cached_{date}_dhuhr` (`prayer_times_provider.dart:419`); `prayer_latitude/longitude` written as Float.
- **Fix-track group "locale-dependent keys"** (user 2026-11-07, HIGH, first HIGH item right after FX-0) = F51a.
  Rule for the spec: every key, prefs name or Firestore path is built locale-independently (`Locale.US` /
  `Locale.ROOT` in Kotlin; integer `toString` / `toIso8601String` in Dart). **Audit 2026-11-07 (read-only, `lib/` +
  `android/app/src/main/kotlin/`)**: Kotlin `String.format` / `SimpleDateFormat` / `DateFormat.format` without an explicit
  locale → only `DailySummaryReceiver.todayDateKey` + `pruneOldPrayerStatuses` build keys; all other hits are log
  lines or UI text. Kotlin key-case conversion uses `lowercase()` (`Locale.ROOT`, safe); no `toLowerCase()` /
  `toUpperCase()`. Kotlin `cached_` prefix uses `Int.toString().padStart` (safe). Dart: no `DateFormat` without an
  explicit locale and no `NumberFormat`; date keys (`_recordDocId` Firestore id, `WirdProgress.dateKey`, task stats,
  `cached_*`) use `int.toString().padLeft` or `toIso8601String`, which are locale-independent. Result: no further hits.
- **(a) Daily summary uses device-locale digits in date keys** — **Tag: fix track HIGH (tracking + data), group
  "locale-dependent keys" (user 2026-11-07: data loss for phones using Arabic-Indic digits); device scenario S27 (user runs).**
  **Status 2026-11-08: DONE — merged via PR #2 (e61f345; fix d9ff65c); VERIFIED by ar-EG unit test (failed on old
  code, passes after); S27 optional.** `DailySummaryReceiver.todayDateKey` and `pruneOldPrayerStatuses`
  (`DailySummaryReceiver.kt:155–165`) build dates with `String.format("%02d", …)` (default locale); every writer uses
  `SimpleDateFormat("yyyy-MM-dd", Locale.US)` (`PrayerAlarmReceiver.kt:388, :418, :855–1041`,
  `NativeNotificationReceiver.kt:119`). On a device whose locale formats Arabic-Indic digits, `today` never matches →
  summary always reports 5 untracked; the cutoff compares `"2026-1…" < "2026-١…"` as always true → prune (runs first
  in `onReceive`, `:76`, even when tracking is off) deletes **all** `prayer_status_*` keys, including today's
  not-yet-synced native answers. Depends on device locale, not app language.
- **(b) Prune ignores sync state** — **Tag: fix track MEDIUM (data).** Keys older than 7 days are removed whatever
  their value (`:161–175`); if the app is not opened for 7+ days, native answers never reach Firestore.
- **(c) Summary counts prayers not yet due** — **Tag: fix track MEDIUM (tracking).** `untracked` checks key
  presence only (`:99–102`); Isha after the summary time (summer, high latitude, or an early custom time) is counted.
- **(d) Status date = time of the action, not of the prayer** — **Tag: fix track MEDIUM (tracking).** Post-check
  buttons and `NativeNotificationReceiver` "mark prayed" use `Date()` (`PrayerAlarmReceiver.kt:1027–1041`,
  `NativeNotificationReceiver.kt:116–121`); an Isha post-check answered after midnight is stored on the next day.
- **(e) Silent-mode window can leave the phone on vibrate** — **Tag: fix track MEDIUM (adhan).**
  `EXTEND_SILENT` writes only `silent_end_time=0` and keeps `is_silent_active=true` (`ToggleSilentModeReceiver.kt:186–211`);
  the next adhan saves the current ringer (vibrate) as `saved_ringer_mode` unconditionally (`PrayerAlarmReceiver.kt:706–707`),
  so the later restore returns to vibrate. Both `restoreRingerMode` copies lack try/catch (restoring SILENT without
  DND access may throw).
- **(f) Focus Mode may cover the adhan screen** — **Tag: fix track MEDIUM (adhan) pending device scenario S28.
  Product rule for the spec (user 2026-11-07): adhan always takes priority over Focus Mode.**
  `FocusModeService.monitorRunnable` relaunches `FocusModeActivity` within 100 ms whenever it is not visible and keeps
  a touch-blocking overlay (`FocusModeService.kt:107–119, :271–367`); nothing checks `adhan_active`. Audio likely
  still plays; the adhan screen's controls may be unreachable. The same loop re-posts notification 5996 every 100 ms.
- **(g) `cancelAllAlarms` cancels adhan alarms only** — **Tag: fix track MEDIUM (tracking), confirm callers.**
  Cancels request codes 1001–1006 (`PrayerAlarmReceiver.kt:301–315`); reminder (+1000) and post-check (+2000) alarms
  survive a cancel (e.g. after a location change) and fire with old times.
- **(h) Widgets show a stale or invented next prayer** — **Tag: fix track MEDIUM (prayer times); same root as
  memory "next-prayer architecture".** `AllPrayersWidget` reads `next_prayer_*` only (`PrayerWidgets.kt:117–120`),
  defaulting to `"Asr"` when MainActivity removes the key (`putString(…, null)`, `MainActivity.kt:293–295`); a passed
  time stops the countdown at 0 until another writer runs. `updateNextPrayer` builds tomorrow's Fajr as today's
  `fajr_time` + 24 h (`PrayerAlarmReceiver.kt:634`); the foreground service self-heals only toward sooner times.
- **(i) Boot restarts a foreground service the user turned off** — **FIXED (settings-bridge commit 4, 990c71d).**
  Boot, daily-recalc, and swipe-away now use `startServiceIfAllowed` which checks
  `flutter.background_notification_enabled` via `FlutterPrefs`; `onStartCommand` null-intent also checks and
  calls `stopSelf()` when disabled. Device check: S42, S43 (pending).
  Was: fix track MEDIUM; group "Dart->native settings bridge".
- **(j) Azkar may show twice / after dismiss** — **Tag: fix track MEDIUM. User 2026-11-07: the double launch is
  unintended; intended behavior = exactly one azkar launch, at iqama.** The adhan screen
  launches azkar at iqama (`AdhanFullScreenActivity.kt:94–101`) and `AzkarAlarmReceiver` (scheduled at iqama + 10 min,
  `PrayerAlarmReceiver.kt:569–572`) launches it again; the 3 s delayed lambda is not removed in `onDestroy`, so azkar
  opens even if the user closed the adhan screen during "Stand for prayer".
  Device evidence (2026-11-08, nova 5T, base, Zuhr): adhan screen closed at 11:38:04 (before iqama 11:53);
  `AzkarAlarmReceiver` fired 12:03:00 (iqama + 10 min) and `ActivityTaskManager` logged two
  `START … AzkarFullScreenActivity` 130 ms apart (12:03:00.074 and .207; the second returned result 3, delivered to
  the existing screen), so the user saw one screen. Cause UNKNOWN; not investigated (user 2026-11-08)
  (`reference/logcat/dhuhr-2026-11-08.txt`).
- **(k) Fallback adhan cannot be stopped** — **Tag: fix track MEDIUM (adhan).** After a failed custom/built-in
  attempt `releasePlayer()` drops the volume-key stop; the final notification-sound fallback uses an untracked local
  `MediaPlayer` (`AdhanPlayer.kt:401–412`), so `stop()` and `isPlaying()` ignore it; a `MediaPlayer` leaks when a raw
  file is missing (`:290–325`); vibration fires twice on custom failure. No audio focus or `AudioAttributes`.
- **(l) Boot recovery is fragile** — **Tag: fix track MEDIUM (adhan), device check.** Boot work runs in
  `Handler.postDelayed(30 s)` without `goAsync()` (`PrayerBootReceiver.kt:40–47`); `PrayerRescheduleService` skips
  past times and never recalculates (`PrayerRescheduleService.kt:111–146`), so after a boot on a new day adhan depends
  on the foreground service / worker recalc.
- **(m) Focus Mode end-of-session issues** — **Tag: fix track LOW.** DND restore forces `INTERRUPTION_FILTER_ALL` +
  `RINGER_MODE_NORMAL` (user's prior DND lost; can end a prayer vibrate window); "restart" after completion runs
  without foreground/monitor and saves empty task fields; relaunch after the duration has passed restarts the full
  timer; request-code hash collisions replace another task's alarm (`FocusModeActivity.kt:310–330`,
  `FocusModeService.kt:187–212, :418–430`, `FocusModeReceiver.kt:49`).
- **(n) Arabic UI numerals / strings** — **Tag: fix track LOW.** Raw digits: summary count + wrong plural
  (`DailySummaryReceiver.kt:116`), iqama countdown (`AdhanFullScreenActivity.kt:90`), azkar counters
  (`AzkarFullScreenActivity.kt:317, :328`). English-only: channel names (all receivers), "Focus Mode Active" in both
  branches (`FocusModeService.kt:388`), `PrayerRescheduleService` text, `StopAdhanReceiver` "Unknown".
- **(o) Widget display issues** — **Tag: fix track LOW.** Past prayers use the "now" dot (`dotPast` unused); day /
  month names follow the device locale; tabular Hijri may differ from the app; DailyContentWidget list is off by one
  day vs `daily_content_service.dart`, ordered differently, and shows the English translation in Arabic mode; tasks
  widget shows yesterday's list after midnight until Flutter pushes; NextTaskWidget has no tap target when `task_0_id`
  is empty; only DailyContentWidget treats `amoled` as dark.
- **(p) Other user-visible LOW** — **Tag: fix track LOW.** Jumu'ah notification has no tap action and uses the stored
  `dhuhr_time` of whatever day (`JumuahReminderReceiver.kt:30–58, :135–141`); foreground service deletes/recreates its
  channel when the user lowers importance (`PrayerForegroundService.kt:147–155`); Sunrise can show as next with
  "Until Azan" (confirm intent); `AzkarAlarmReceiver` small icon is the launcher mipmap; `NativeNotificationReceiver`
  daily repeat re-arms from fire time and shifts `prayerTimeMs` by a fixed 24 h; calculator truncates minutes and
  uses one DST offset (cache fallback only).
- **(q) Dead code** — **Tag: P6 cleanup.** VERIFIED (static): `AuraAccessibilityService.kt` (+ `res/xml` config,
  string, proguard keep) and `WidgetUpdateService.kt` are not in the manifest; `RingProgressView.kt` unreferenced;
  `StopAdhanReceiver` is declared but nothing sends `STOP_ADHAN`; `ToggleSilentModeReceiver` `ENABLE_SILENT` branch
  and `SilentModeScheduler.triggerSilentMode`; `FocusModeReceiver` `ACTION_FOCUS_COMPLETE` path (writes
  `aura_focus_mode`, broadcasts `FOCUS_TASK_DONE`, channel `focus_mode`, notification 5999 — none used);
  `FocusModeService` `ACTION_TASK_DONE` / `ACTION_TASK_NOT_DONE`; `aura_focus_state` is write-only;
  `PrayerForegroundService.loadPrayerIconForPrayer`; `PrayerRescheduleService.calculatePrayerTimes`;
  `DailyContentWidget.ACTION_DAILY_UPDATE`; `AdhanPlayer.playbackLock` / empty `unregisterVolumeReceiver`;
  unreachable Sunrise checks in `PrayerAlarmReceiver.onReceive`; stale comments (StopAdhan KDoc, "20 min",
  "opens app picker", "updates every second").
- **(r) Platform guards** — **Tag: P2.** `setExactAndAllowWhileIdle` without try/catch in `PrayerAlarmReceiver`,
  `NativeNotificationReceiver`, `TaskReminderReceiver` (manifest declares `USE_EXACT_ALARM`, so low risk);
  foreground-service self-restart uses `PendingIntent.getService` on O+; `openExactAlarmSettings` reports success on
  failure; boot also listens to `android.intent.action.REBOOT`.
- Backlog (UNVERIFIED): `AdhanPlayer.stop`/`releasePlayer` unsynchronized across threads; synchronous `prepare()` on
  the receiver thread; cold-start `navigation` call may reach Dart before its handler is set; foreground service
  retries the calculator every tick when no coordinates are stored; calculator prefs reads sit outside `try`;
  latent Dhuhr/Zuhr split in status keys if any caller ever sends `"Dhuhr"` (all found send `"Zuhr"`).

## F52 — Module drift check (`.project-docs/modules/`, 2026-11-07) — code VERIFIED (static), impact UNVERIFIED
Source: `reference/2026-11-07_DRIFT_REPORT.md` (doc drift fixed in the modules). Only bugs not already logged; the
drift check also re-confirmed F16, F25, F30a/b/f, F32a/d, F36a/c, F38a/c, F42, F46c, F49a, F51h/i/j/l/m/p/q. Items
(a)–(c) re-checked in code by the main session.
- **(a) Settings / iqama changes don't reach alarms or native data until the next resume** — **DONE — FX-0 merged to main via PR #1 (195e284), after-fix S29 + S33 PASS 2026-11-08 (FX-0 commits 7–11, 2026-11-08; refresh helpers unit-tested, after-fix device checks S31/S33 pending).** **Tag: fix track MEDIUM
  (prayer times, adhan); joined FX-0 (user 2026-11-07: same settings → times → alarms path as F36a / F36c; the FX-0
  spec must cover recalculation AND alarm / native refresh).** `settings_screen.dart`
  `_recalculatePrayerTimes` calls `loadPrayerTimes(DateTime.now())` (`:295–300`) on the existing notifier;
  `_lastSideEffectsDate == todayKey` returns before side effects (`prayer_times_provider.dart:255–257`), so adhan alarms,
  post-prayer checks, widgets, native calc method and cached times keep the old settings until a resume
  (`ref.invalidate`, `main_wrapper_screen.dart:121`) or the next day. `/iqama_settings` saves `iqama_minutes` and never
  reloads. Also: side effects re-run on every resume (guard is per notifier instance).
- **(b) After midnight, Home and Prayer screens hide yesterday's statuses** — **Tag: fix track MEDIUM (tracking).**
  The provider holds the effective day (yesterday until Fajr), but `home_screen.dart:302–309` and
  `prayer_screen.dart:221` filter it with `isPrayerTimeReached` against today's times → all hidden 00:00–Fajr.
  `_markPrayerAsCompleted` runs `canMarkPrayer` against today's times (`prayer_screen.dart:235–242`), blocking yesterday's
  Isha after midnight (provider would allow it; tracking screen works).
- **(c) Native statuses marked synced even when the Firestore write fails** — **Tag: fix track MEDIUM (tracking +
  data).** `syncNativePrayerStatuses` ignores `recordPrayer`'s `bool` (`prayer_alarm_service.dart:336–347`;
  `recordPrayer` returns false on error, `prayer_tracking_service.dart:69–104`) and calls `clearNativePrayerStatus`
  (value → `"synced"`) → never retried.
- **(d) Full reload every minute after Isha** — **Tag: fix track LOW, device check.** After Isha `getNextPrayer` returns a
  tomorrow-dated Fajr; `_quickUpdateNextPrayer` (`prayer_times_provider.dart:150–157`) calls `loadPrayerTimes(now)` each
  tick until midnight (`isLoading` toggles; GPS cached; side effects guarded). Possible loading flicker.
- **(e) Two 8 AM task digests** — **Tag: fix track LOW.** `scheduleDailyTaskSummary` (3999, native repeating,
  `task_service.dart:730`) and `scheduleDailyTaskDigest` (4001, plugin, `prayer_times_provider.dart:308`) both target 8:00
  with different text (see F8, F20c).
- **(f) Focus Mode promises an exit that does not exist** — **DONE (5cedaf3, S44 PASS 2026-11-10).** Implemented
  volume-up ×3 exit detector, shared `performExit(isEarly)`, elapsed-time subtitle, updated hint text. Spec
  `docs/designs/fix-focus-exit.md`.
- **(g) Wird data loss / divergence** — **Tag: fix track MEDIUM (data).** `recordPagesRead` adds nothing to
  `wird_total_pages_read` when the day was already completed (`wird_service.dart:100–112`; promotes the F20 backlog item;
  feeds `wird_khatma` / `wird_pages_*`). `syncFromFirestore` replaces local settings / streak / totals with the cloud copy
  on every init, no merge, and `wird_progress_history` never syncs (`wird_service.dart:490–560`).
- **(h) Wird achievements awarded late** — **Tag: fix track LOW.** No wird code calls `checkAndAward` (callers:
  `prayer_tracking_service.dart:134`, `task_service.dart:531`, `profile_screen.dart:1180`).
- **(i) Wird reminder says pages in juz mode (mobile)** — **Tag: fix track LOW.** `WirdService.scheduleReminders` passes
  only `dailyPageGoal`, no juz flag (`wird_service.dart:466–470`, `notification_service.dart:1093–1095`); desktop gets
  `isJuzMode`.
- **(j) Desktop reminder timers drift after sleep and are today-only** — **Tag: fix track LOW (Windows).** Wake detection
  reschedules only prayer timers (`prayer_times_provider.dart:127–133`); task / wird / digest `Timer`s in
  `desktop_notification_service.dart` (`:382, :423, :459`) are not; wird and digest cover today only (`:416, :457`).
- **(k) Home countdown stops when the desktop window loses focus** — **Tag: fix track LOW (Windows), behavior inferred.**
  `home_screen.dart:205–207` cancels the timer on `inactive` as well as `paused`.
- **(l) Dhikr ignores vibration settings** — **Tag: fix track LOW.** `dhikr_screen.dart:111–127` uses Flutter
  `HapticFeedback` + unconditional `Vibration.vibrate(50)`, not `lib/core/utils/haptic_feedback.dart` (see F23, F44 backlog).
- **(m) "Start with Windows" is opt-out** — **Tag: fix track LOW (user 2026-11-07: should be off by default).** `windows_startup_enabled`
  defaults to true (`windows_startup_service.dart:20`); `registerIfEnabled()` runs every launch (`main.dart:94`).
- **(n) Pinned float relies on a stable sort** — **Tag: fix track LOW, with F30b.** `_applySort` re-sorts to float pinned
  tasks (`tasks_screen.dart:1014–1017`); Dart `List.sort` is not guaranteed stable.
- **(o) Dead code / stale comments** — **Tag: P6 cleanup.** Dart `PrayerTimesNotifier.updateNextPrayer` (no caller);
  `BackgroundServiceHandler.kt` (unreferenced; `MainActivity` registers the channel); unused `quran_service.dart` import
  (`main.dart:22`); named route `/khatma_dua` never pushed by name; dead variable `y` in `WirdService.undoComplete`
  (`:198`); duplicate INTERNET permission (`AndroidManifest.xml:3, :37`); tracked junk folders under
  `android/app/src/main/res/` named after shell commands (`drawable" && mv …`, `layout" && cp …`); stale comments:
  `main_wrapper_screen.dart:59` ("1.8×", formula gives 1.53; formula and comment replaced by F63 A-1, 2026-11-09), `AdhanFullScreenActivity.kt:300` ("Stop Vibrate" closes),
  `task_provider.dart:23–25` ("autoDispose"), `PrayerAlarmReceiver.kt:587–590` (placeholder times), `FocusModeReceiver`
  KDoc (fullScreenIntent).
- **(p) Dart and native `proportional` differ** — **Tag: P3 (two calc engines; memory "next-prayer architecture").**
  Dart maps it to MWL 18°/17° (`prayer_times_service.dart:272–274`), native uses 15°/15°
  (`NativePrayerCalculator.kt:235`). Not selectable in the UI today.
- Backlog (UNVERIFIED): overlapping fire-and-forget `checkAndAward` calls can award and toast the same achievement twice
  (`achievement_service.dart:55–64, :393–433`); desktop OAuth loopback accepts the first request of any kind and writes
  `$oauthError` into HTML unescaped (`auth_service.dart:163–181`, extends the F20 backlog item); Focus Mode "blocks the
  notification shade" — no code found.

## F53 — Prayer calculation for other dates (found while preparing FX-0, 2026-11-07) — code VERIFIED (static)
- **(a) Times for any date other than today are today's times shifted by whole days** — **DONE — FX-0 merged to main via PR #1 (195e284), after-fix S29 + S33 PASS 2026-11-08 (FX-0 commits 3 and 8, 2026-11-08; unit-tested, after-fix device check pending).** **Tag: fix track, joined FX-0
  (CRITICAL group; user 2026-11-07).** `PrayerTimesService.getPrayerTimes(date:)` always
  calls `adhan.PrayerTimes.today(...)` (`prayer_times_service.dart:80`) and adds `Duration(days: daysDifference)`
  (`:94–111`). `PrayerTimesNotifier` caches days 0–2 with it (`prayer_times_provider.dart:403–423`) as
  `cached_{date}_*`, which `NativePrayerCalculator.cachedOrComputed` / `readCached` prefer over its own calculation
  (`NativePrayerCalculator.kt:165–189`). Effect: days 1–2 are off by the daily drift (~1–2 min/day) and by **1 hour
  across a DST change** (exact 24 h added); native alarms on that day use the cached value if the app was not opened.
  Any screen asking for another date gets the same shifted times. Device impact UNVERIFIED (DST case: Egypt has DST).
  Correction (FX-0 spec, 2026-11-07): the shift does **not** cause a 1-hour DST error (24 h added to an absolute
  instant keeps the wall-clock time); the DST hour error is Kotlin's single per-day offset (F51p).
  Device evidence (2026-11-08, nova 5T, base, S18/S34): app not opened across midnight; at 00:05 and 02:53
  `NativePrayerCalc: ✅ Using cached adhan-accurate times for cached_2026-11-08` → `Fajr=04:45`; Fajr fired 04:45:00
  vs package MWL 04:46 for 2026-11-08 — the 1-min next-day drift comes from the shifted-day cache
  (`reference/logcat/S18-base.txt`). Device impact (drift) VERIFIED; DST case still UNVERIFIED.

## F54 — Iqama for alarms armed for another day (found in the FX-0 review, 2026-11-07) — code VERIFIED (static)
- **(a) An adhan alarm armed for tomorrow counts down to today's iqama instant** — **MEDIUM; out of FX-0 (user
  2026-11-07).** At adhan time `PrayerAlarmReceiver` reads `{prayer}_iqama_time` from `aura_prayer_times`
  (`PrayerAlarmReceiver.kt:543–561`) and stores it as `adhan_iqama_time` for the countdown. Dart writes those keys
  only for today's prayers (`prayer_times_provider.dart:372–379`, absolute epoch ms). When the alarm fires on a later
  day (tomorrow's Fajr armed after Isha, or native-rescheduled days without an app open), the stored value is still
  the earlier day's instant, so the countdown is wrong or already past. FX-0's next-occurrence scheduling reaches this
  path more often. Future fix: iqama per date (FX-0 spec, Future Improvements).
  Device evidence (2026-11-08, nova 5T, base, S34): Fajr alarm armed the evening before fired 04:45:00 with
  `PrayerAlarmReceiver: ✅ [ADHAN_MODE] Activated for Fajr | iqama=1794016800000 | end=1794103500021` —
  iqama 1794016800000 = 2026-11-07 05:00 (+03), yesterday's instant, 23 h 45 min before the adhan
  (`reference/logcat/S18-base.txt`). Device impact VERIFIED; stays MEDIUM, out of FX-0.
  Context (2026-11-08, base, S01 at Dhuhr): an alarm armed and fired on the same day logged
  `iqama=1794127980000` = 11:53, Zuhr 11:38 + 15 min — correct. Consistent with F54a being a day-change problem only
  (`reference/logcat/dhuhr-2026-11-08.txt`).

## F55 — Preserved WIP branch (2026-11-08) — UNVERIFIED (not reviewed)
- **(a) wip/crazy-haibt-tasks holds unreviewed task changes (+111/-7); review when the tasks fix group starts.**
  Commit e4b1d5c (pushed as backup, no PR/merge) on top of 08cc443; formerly uncommitted in the removed worktree
  `.claude/worktrees/crazy-haibt` (branch `claude/crazy-haibt` deleted). Files: `task.dart`, `task_service.dart`,
  `task_card.dart`, `tasks_screen.dart`. Base is 261 commits behind main.

## F56 — Alarms on Umm al-Qura after MWL was restored (2026-11-08) — CLOSED: user action, not a bug
- **Closed 2026-11-08 (user): the user changed the method to Umm al-Qura at ~16:49 (app in foreground
  16:49:29–16:50:38). The app correctly saved it, recalculated and re-armed all alarms (Isha 18:39 = Maghrib + 90 min);
  FX-0 behaved as designed. Release hold removed.** Original record kept below for reference.
- **(a) Selected method MWL, but alarms and stored method become Umm al-Qura** — ~~Tag: CRITICAL (user 2026-11-08);
  release 1.1.0 ON HOLD until fixed.~~ Evidence (nova 5T, FX-0 build, PID 26682;
  `reference/logcat/S33-fx0-2026-11-08.txt`, `S33-fx0-alarm.txt`, `logcat-maghrib-2026-11-08.txt`):
  - 15:43:49 `Saved calculation settings: MuslimWorldLeague, Shafi` → recalc `muslimWorldLeague`; dumpsys 15:44: Isha
    alarm 18:22, Maghrib 17:09, Isha post-check 18:52 (MWL).
  - 17:37:28 (first Dart lines in the dump; main buffer starts 17:36:45): in-memory times already Umm al-Qura (Fajr 04:44,
    Isha 18:39 = Maghrib + 90 min). Isha adhan fired 18:39:00 (`iqama=1794153240000` = 18:54). Native reschedule
    18:39:00: Fajr 04:44, Zuhr 11:40 (+3 min Umm al-Qura Dhuhr adjustment), Isha 18:38. 18:40:01 Dart
    `Calculation method: makkah`.
  - Same on 1.0.1+60 (installed 20:25, new process 25195): 20:26:02 `Calculation method: makkah`, alarms Fajr 04:44 …
    Isha 18:38; 20:26:31 `Loaded calculation settings: UmmAlQura, Shafi` (direct read of Flutter `calculation_method`).
  - Code (static): native `prayer_calc_method` (`aura_prayer_times`) is written only from Dart arguments
    (`MainActivity.kt:306, :670`) built from `calculation_method` (`prayer_times_provider.dart:369, :558`), so native
    follows the Flutter pref. The value `UmmAlQura` (UI format) is written only by UI saves (`prayer_screen.dart:375,
    :1550`, `settings_screen.dart:107`); the provider writes enum names (`:584`); no Firestore/sync writer;
    `AdhanCalculationMethod.fromValue` falls back to MWL. Writer between 15:44 and 17:36 UNKNOWN (logs rotated); app
    in foreground 15:44–15:55 and 16:49:29–16:50:38 (system buffer). Investigation: see log 2026-11-08.

## F57 — Split the Prayer Calculation dialog (user request with screenshot, 2026-11-08) — UX
- **(a) One dialog for method + madhab; split into two** — **Tag: MEDIUM (UX); supersedes F49k; schedule: release 1.1.0
  (user 2026-11-08, final; spec docs/designs/fix-f57-split-dialog.md, branch `fix/ui-1.1.0`).**
  **Status 2026-11-08: FIXED on `fix/ui-1.1.0` (2bcd95e, c8ddfa9), not merged; widget-tested; device check by user pending.** Requested behavior:
  - Prayer settings page: "Calculation Method" tile → dialog with the 12 methods only; "Asr Madhab" tile → separate
    dialog with Shafi / Hanafi only (today both open `PrayerCalculationSettingsDialog`, `prayer_screen.dart:1480–1535`).
  - Settings tab: the single "Calculation Method & Madhab" tile (`settings_screen.dart:95–118`) becomes two tiles with
    the same behavior.
  - Each tile shows its current choice as subtitle, localized (e.g. "Muslim World League", "Shafi"; today the Settings
    tile shows raw values `MuslimWorldLeague · Shafi`).
  - Tapping an option selects it (radio moves); "Done" saves, recalculates (same FX-0 path) and closes. (User
    correction 2026-11-08; replaces "tap saves and closes immediately".)
  - All strings via `.tr()` in en.json + ar.json; stored values and keys (`calculation_method`, `asr_madhab`)
    unchanged — no contract change.
  - Spec: short note, no EGM review. Tests: widget tests for both dialogs (current selection shown, tap moves the
    radio, "Done" fires the callback once with the chosen value, dialog closes).
  - Note: today the dialog saves on every tap; "save on Done only" also prevents accidental saves.

## F58 — Quran reader A+/A− zoom buttons overlap content (user report, 2026-11-08) — UI
- **(a) A+/A− overlap** — **Tag: MEDIUM (UI); fix track, release 1.1.0 (user 2026-11-08, final; spec docs/designs/fix-f58-reader-zoom.md, branch `fix/ui-1.1.0`).** **Status 2026-11-08: FIXED on
  `fix/ui-1.1.0` (d1f69f7, 8fab1d3), not merged; widget-tested; device check by user pending.** Device
  VERIFIED (user screenshot 2026-11-08): nova 5T (360 dp wide, normal Display/Font size), Quran reader, Al-Ma'idah page
  122/604 — the A+/A− box covers the right end (line start in RTL) of the last two lines (ayah 89–90). Code (static): `_MobileZoomControls` are drawn at a fixed `Positioned(right: 16,
  bottom: 80)` over the mushaf whenever the UI is shown on mobile (`quran_reader_screen.dart:555–563`, widget
  `:1571`); the position ignores RTL (not `PositionedDirectional`) and the mushaf/page layout. Other pages / screen
  sizes: UNVERIFIED.

## F59 — Logout keeps local data (user 2026-11-08, from spec fix-signin-onboarding) — privacy
- **(a) Previous user's local data survives logout** — **Tag: MEDIUM (privacy); decide later (user 2026-11-08).**
  Logout (`profile_screen.dart:1035–1037`; F47f fix keeps this) calls only `signOut()`; local prefs and local data
  (tasks, prayer tracking, wird, settings) stay on the device. A second account or a guest on a shared phone may see
  the previous user's local data. Code VERIFIED (static) for "nothing is cleared"; which data is actually visible to
  the next account: UNVERIFIED (needs a device check). Open product question: clear on logout, keep, or ask.

## F60 — Guest-sync dialog never shows (device S20, 2026-11-09) — UX
- **(a) Sync dialog skipped by a load race** — **Tag: MEDIUM (pre-existing; not caused by fix-signin-onboarding; fix later).** Device VERIFIED
  (S20, nova 5T, test user 10, 2026-11-09): `pending_guest_migration_uid` set at sign-in (`📦 2 local task(s) pending migration`), but no
  dialog after sign-in or after a relaunch; the Profile sync card appears and works. Code (static, likely cause):
  `_checkGuestMigration` (`main_wrapper_screen.dart:240, :542`) runs 1 s after the shell starts and `ref.read`s
  `guestMigrationProvider` once; that first read creates the notifier, whose async `_load()` (prefs + local task count,
  `guest_migration_provider.dart:33–47`) has not finished, so `isPending` is still false and nothing re-checks. Profile
  `ref.watch`es the provider, so its card updates. **Status 2026-11-09: FIXED on `fix/f60-guest-sync` (6931c81, c5c2c70): `refresh()` before the dialog check; offer only for the signed-in uid named by the flag (user decision); 8 unit tests; device S20 after-fix PASS (dialog after sign-in, sync once); merged to main via PR #6 (80c3794).**

## F61 — Bottom nav stays English after switching to Arabic (device S23, 2026-11-09) — UI
- **(a) Nav labels not localized after a language switch** — **Tag: LOW (pre-existing; this branch changed no Settings / nav / shell code).**
  Device VERIFIED (user, nova 5T, 2026-11-09): Settings → Arabic; bottom nav labels stay English, also after tapping another
  tab. Switching back to English then showed the nav in **Arabic** (one change behind); a relaunch shows the right language (user, 09:40–09:43). Code (static, cause UNVERIFIED): `AuraBottomNavBar` uses `.tr()` without a
  locale dependency (`core/widgets/bottom_nav_bar.dart:61–93`), and Settings calls `ctx.setLocale(...)` right after
  `Navigator.pop(ctx)` on the dialog context (`settings_screen.dart:393, :405`), so the EasyLocalization locale may not change.
  **Cause confirmed 2026-11-09 (spec fix-f61-nav-language):** the provider changed `MaterialApp.locale` before `setLocale`, and
  easy_localization's delegate installs the controller's old translations (never reloads). **Status: FIXED on `fix/f61-nav-language`
  (46ee725, e0026de): `applyAppLanguage` in Settings and onboarding; 6 tests (widget test reproduces the bug); device S38 PASS
  on the phone and Windows; merged to main via PR #8 (84ee960).**

## F62 — Damaged prefs file leaves a white window on Windows (S36 Windows, 2026-11-09) — reliability
- **(a) No recovery from an unreadable SharedPreferences file** — **Tag: MEDIUM (pre-existing; fix later).** Device VERIFIED
  (Windows, unpackaged release exe): `%APPDATA%\com.aura\aura_app\shared_preferences.json` was 1867 zero bytes (last write
  2026-06-30, cause UNKNOWN, likely an interrupted write). Start-up logged `FormatException: Unexpected character (at character 1)`
  for SharedPreferences and EasyLocalization and the window stayed white. Renamed to `shared_preferences.json.zeroed-2026-06-30.bak`;
  the app then started. MSIX installs use a virtualized copy (not affected here). Whether Android can hit the same: UNKNOWN.
  Log: `logcat/S36-windows-blank-2026-11-09.txt`. **Status 2026-11-09: FIXED on `fix/f62-corrupt-prefs` (ac30244, c2073e2): Windows-only backup of an unreadable file before the first prefs read; 7 unit tests; device S37 PASS; Android regression PASS; merged to main via PR #7 (1feac74).**

## F63 — Desktop window taller than the screen at 150% scaling (S37, 2026-11-09) — desktop UI
- **(a) Fixed 900 × 1400 window** — **Tag: MEDIUM (pre-existing; fix later).** Device VERIFIED (user, Windows at 150% display
  scaling, 2026-11-09): the window runs past the screen and the top is cut off, in the F62 test build and in the installed
  MSIX Aura. Code (static, likely cause): `main.dart` opens the window with `WindowOptions(size: Size(900, 1400))` (logical),
  i.e. 1350 × 2100 physical pixels at 150%. Test PC: 2880 × 1620 physical, work area 1920 × 1032 logical at 150% (VERIFIED
  2026-11-09). Related: modules/desktop-scaling.md. **Status 2026-11-09: FIXED on `fix/f63-window-size` (e662ad6, cb94e9c,
  5c260b4; A-1 item scale 5d0c597): window from the work area, max 900 × 1400, centered; scale min(w/500, h/778) clamped
  0.9–1.8; device S39 PASS; merged to main via PR #9 (290f8f1).**

## F64 — App tour highlight shifted on desktop (user screenshots, 2026-11-09) — desktop UI
- **(a) Highlight frame offset by the sidebar width** — **Tag: MEDIUM (pre-existing; separate fix after F63, user 2026-11-09).**
  Device VERIFIED (user screenshots 09:54 and 13:12, Windows): the tour's yellow frame sits right of its target by about the
  sidebar width (full and icon-only sidebar) and is clipped at the right edge; the sidebar is not dimmed. Code (static, likely
  cause): `showTutorial` inserts into `Overlay.of(context)` (`tutorial_overlay.dart:339`), on desktop the nested content
  navigator's overlay right of the sidebar, while the target rect uses window coordinates (`box.localToGlobal(Offset.zero)`,
  `:93`, and `:296`). Candidate fix: `Overlay.of(context, rootOverlay: true)`. Mobile: no nested navigator (not affected).
  **Status 2026-11-09: FIXED on `fix/f64-tour-highlight` (bf70e93; option B: frame and tooltip in the overlay's coordinates
  and size, the root-overlay option was rejected because it drops the desktop text scale); 6 widget tests incl. RTL and pane edge;
  device S40 PASS (Windows LTR + Arabic, maximized; phone regression); merged to main via PR #10 (58ccc74).**

## F65 — Desktop sidebar takes almost half of a narrow window (user screenshot, 2026-11-09) — desktop UI
- **(a) Fixed 260 px sidebar** — **Tag: MEDIUM (pre-existing width, exposed by the narrower F63 default window; fix next, user).**
  Device VERIFIED (user screenshot 14:19, Windows 150%, window 597 × 929 logical): the expanded sidebar is ~260 of ~585 px
  (~44%). Code (static): `_DesktopShellState` uses `width: _sidebarCollapsed ? 72.0 : 260.0` (`main_wrapper_screen.dart:1368`),
  not scaled and not tied to the window width; only the ☰ toggle collapses it (state not persisted). At the old 900-px default
  it was ~29%.
  **Status 2026-11-09: DONE (PR #11, 5d37798; device check S41 pending).** Fix: `DesktopShellLayout` (8d7650f, 2f46d25):
  below 800 px a 72-px icon rail, ☰ opens the 260-px sidebar as an overlay from the start edge; 8 widget tests incl. RTL.

## F66 — "Adhan off" only stops the sound (found during the settings-bridge spec, 2026-11-09) — prayer / adhan
- **(a) Rest of the adhan still runs with adhan off** — **Tag: UNKNOWN severity; intended behavior undecided (user
  2026-11-09); outside the "Dart->native settings bridge" group (listed there as a Non-Goal).** Code VERIFIED (static,
  main @ c5a848e): the only fire-time check of `adhan_enabled` is in `AdhanPlayer.play`, which returns before any sound
  (`AdhanPlayer.kt:179–186`). `PrayerAlarmReceiver` still runs the rest of the fire path: vibrate mode
  (`PrayerAlarmReceiver.kt:514–517`, gated only by silent mode), the prayer notification (`:527`), the full-screen
  adhan screen (`:531–534`) and adhan mode in the foreground service (`:542–560`). Device impact UNVERIFIED. Needs a
  user decision on what "adhan off" should stop before any fix.
- **Open question for the same decision (user 2026-11-09):** should previewing a reciter play when adhan is off? Today
  preview goes through `AdhanPlayer.play`, so it is silent when adhan is off; after the settings-bridge fix
  `previewAdhan` keeps that (returns `false`, the button stays in its play state, no message).
- **Second open question for the same decision (user 2026-11-09, review A1):** should a reciter preview be able to
  interrupt a prayer adhan? Today it can: preview goes through `AdhanPlayer.play`, which calls `stop()` first
  (`AdhanPlayer.kt:190`), so tapping preview while the prayer adhan plays stops it and plays the preview. The
  settings-bridge fix keeps this (`previewAdhan` uses the same stop-then-play sequence). Related, also pre-existing:
  after a prayer adhan stops a preview, the downloads screen still shows the stop button; tapping it sends `stopAdhan`
  and stops the prayer adhan.

## F67 — Native code reads the app language from a channel-pushed copy (found during the settings-bridge spec, 2026-11-09)
- **(a) 16 native `language` reads use copies, not the Dart setting** — **Tag: fix track LOW (later, user 2026-11-09);
  outside the "Dart->native settings bridge" group, which keeps the copy (its contract lists it as a known
  channel-pushed duplicate).** Code VERIFIED (static, main @ c5a848e): the setting is `flutter.language`
  (`shared_preferences_service.dart:84`). Kotlin reads `getString("language", …)` 16 times in 12 files
  (`AdhanFullScreenActivity`, `AzkarAlarmReceiver`, `AzkarFullScreenActivity`, `DailyContentWidget`,
  `DailySummaryReceiver`, `JumuahReminderReceiver`, `PrayerAlarmReceiver` ×2, `PrayerForegroundService` ×2,
  `PrayerWidgets`, `StopAdhanReceiver`, `TasksWidget` ×2, `ToggleSilentModeReceiver` ×2), from copies that Dart pushes
  over channels: `aura_prayer_times` via `updatePrayerWidgets` (`MainActivity.kt:285`) and `updatePrayerTimes`
  (`PrayerForegroundService.kt:116`), `aura_tasks_widget` (`MainActivity.kt:330`), focus state
  (`FocusModeService.kt:241`). Proposed later fix: read `flutter.language` through `FlutterPrefs` everywhere.
- **When Dart pushes the language (static):** immediately on change — `LanguageNotifier.setLanguage`
  (`preferences_provider.dart:124–152`, reached from Settings and onboarding via `applyAppLanguage` and from Profile
  `:990, :1002`) calls `PrayerWidgetService.savePrayerTimes` (both prayer channels) and
  `TaskWidgetService.refreshWidget`. Also on every prayer-times refresh (`prayer_times_provider.dart:319, :347, :526,
  :540`). Gaps: the immediate push is skipped when no prayer times are loaded yet (`:137`), and push errors are only
  logged (`:150–151`); in both cases native keeps the old language until the next refresh.
  `SharedPreferencesService.restorePreferences` (`shared_preferences_service.dart:269–276`) writes the language without
  a push, but has no caller found. Device timing UNVERIFIED.

## F68 — Silent-mode notification with action buttons removed (user report, 2026-11-10) — VERIFIED (static + git)
- **Tag: fix track MEDIUM (adhan/silent).** Before commit `6514f26` ("Redesign full-screen adhan"),
  `PrayerAlarmReceiver.showPrayerNotification()` posted the adhan notification (IDs 1001–1006, channel
  `prayer_times`) with `setAutoCancel(false)`, `BigTextStyle`, vibration pattern, and action buttons ("Stop
  Vibrate" / "Vibrate Always" via `DISMISS_SILENT` / `EXTEND_SILENT` to `ToggleSilentModeReceiver`) when
  `silentModeEnabled && isSilentActive`. The notification stayed in the shade and let the user change the
  silent-mode choice after dismissing the full-screen activity.
  Commit `6514f26` stripped `showPrayerNotification` to a minimal 3-second auto-dismiss with zero action buttons
  (commit message: "All controls now live in the full-screen UI"). The buttons were moved to
  `AdhanFullScreenActivity` (works) and as `addAction` calls in `PrayerForegroundService.showAdhanModeNotification`
  (invisible — `setCustomBigContentView` without `DecoratedCustomViewStyle` hides `addAction` buttons).
  Net result: no working silent-mode notification exists in the shade after the adhan screen is dismissed.
  **Pre-existing:** `6514f26` is 305 commits before the settings-bridge branch point; `fix/settings-bridge` did
  not change `showPrayerNotification` (zero diff confirmed). Not a regression from PR #12.
  Device: nova 5T, Android 10 (API 29).
- **Why the buttons were removed (from `6514f26` diff + commit message):** it was a UI consolidation during the
  adhan redesign, not a fix for a specific problem. The commit assumed the full-screen activity's buttons were
  sufficient. There was no separate silent-mode notification — the buttons lived on the same adhan notification
  (same IDs 1001–1006). The redesign stripped that notification to a minimal full-screen-intent trigger
  (`setTimeoutAfter(3000)`, `setAutoCancel(true)`) and moved all controls into the activity. The oversight: the
  full-screen activity is ephemeral — once dismissed, the user has no way to cancel or keep vibration for the
  rest of the silent period (up to 20 min). The foreground service `addAction` calls were added as a fallback
  but are invisible due to the custom-view issue. **Spec constraint:** the fix must not re-introduce the old
  problem of overloading the adhan notification (which now serves only as a `setFullScreenIntent` trigger with a
  3-second lifespan). A separate notification avoids coupling with the adhan notification lifecycle.
- **Fix plan (spec needed, Level C):** add a new, separate standard notification (no custom layout) with two
  action buttons ("Stop Vibration" / "Keep Vibration"). It appears when the app activates silent mode and
  disappears when silent mode ends or when the user presses either button. Remove the dead `addAction` calls
  from `PrayerForegroundService.showAdhanModeNotification()`. The foreground service custom layout and the
  full-screen activity stay unchanged. Needs new notification ID + channel assignment (contracts update).

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
