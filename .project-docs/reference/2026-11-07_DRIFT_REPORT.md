# Drift report — `.project-docs/modules/` vs code (2026-11-07)
Scope: the 15 module docs only (folder READMEs were verified against code when written). Method: 4 read-only agents
checked every concrete claim; high-impact claims re-checked by the main session (ayah count, daily-content source,
Focus Mode volume exit, junk `res/` folders, side-effects guard, settings recalc, after-midnight filter, native sync).
Only divergences are listed. Code bugs found on the way → `reference/findings.md` F52. All items VERIFIED (static)
unless marked.

## achievements.md
- Unlock flow: on desktop the system notification is `DesktopNotificationService.showAchievementNotification`, an empty
  no-op; on phone the toast is shown only when the lifecycle is `resumed`, otherwise only the system notification
  (`main_wrapper_screen.dart` listener).
- Notification ID formula `7100 + (id.hashCode.abs() % 1000)` not stated (doc says "hash-based").
- `_AchievementsBadgeGrid` does not build a `visibleCategories` Set; it filters per achievement. The "always a Set" rule
  holds only for `AchievementsScreen`.
- Missing: guests never earn achievements (`checkAndAward` / `getEarnedAchievements` return `[]` for `guest_user`);
  awards stored at `users/{uid}/achievements/{id}`.
- Wird achievements: 7, not 4 (see wird.md).

## auth-sync.md
- "Offline queue" listed as an auth feature: `OfflineQueueService.enqueue` has no caller (F16).
- Google sign-in: `google_sign_in` on mobile only; desktop uses a custom loopback PKCE flow (`_signInWithGoogleDesktop`,
  `google_oauth_config.dart`).
- "Data (tasks, prayer records, wird) still pulls from Firestore on login": `_syncUserData` pulls only wird; tasks are a
  live stream keyed by `currentUserIdProvider`; prayer statuses come from a Firestore listener (Android only).
- "Guest mode migrated on signup": theme/language/wird are pushed only when the user doc does not exist yet; guest tasks
  are migrated only after a prompt (`pending_guest_migration_uid` → `guestMigrationProvider.migrate()`); signing into an
  existing account pulls cloud wird over local.
- Old note "not yet re-verified" is stale.

## desktop.md
- Build command lacks the certificate password: pubspec comments require
  `dart run msix:create --certificate-password <password>` (`certificate_path: aura_signing.pfx`).
- "Not yet documented / UNKNOWN": `desktop_notification_service.dart` (local_notifier toasts, in-process timers for
  task / wird / digest, action buttons, `notificationStream`; achievement toast no-op), `windows_startup_service.dart`
  (HKCU Run value via `reg`, `windows_startup_enabled` defaults to **true**, `registerIfEnabled()` every launch,
  `--startup` starts hidden to tray), sleep-aware timer (only `prayer_times_provider.dart` minute tick; gap > 3 min
  reschedules prayer timers only).

## desktop-scaling.md
- `iconSize = scale * 24` → actually `(24 * scale).clamp(18, 52)`; chip, ListTile and card paddings are clamped
  (values in code); doc shows them unclamped.
- Scale uses `MediaQuery.of(ctx).size` (whole window), not the `LayoutBuilder` constraints.
- Islamic events: `chipSz = ts.scale(48)` (no clamp); `emojiFz = (chipSz * 0.50).clamp(16, 40)` — doc values wrong.
- Scaled TabBar height is used only in `quran_screen.dart`; Azkar TabBar is plain (rule stated as universal).
- Code comment "900×1400 → 1.8×" is wrong (formula gives 1.53) — F52.

## dhikr-azkar.md
- "6 presets … Custom": `DhikrPresets.builtIn` has 5; plus any number of user presets (`custom_dhikr_presets`,
  `CustomZikrFormScreen`).
- Haptics via `lib/core/utils/haptic_feedback`: dhikr screen uses Flutter `HapticFeedback` + unconditional
  `Vibration.vibrate(50)`; vibration settings ignored (F52).
- Session statistics persist to Firestore only (`users/{uid}/dhikr_sessions`); guests save nothing.
- Daily content "Hadith, Ayah, Dua from Firestore": hard-coded `const` list of 20 (10 ayah + 10 hadith), no Dua
  (`enum DailyContentType { ayah, hadith }`), rotated by day of year; no Firestore.
- "Home widget `DailyContentWidget`": that is the native Android widget (Kotlin); Home builds an inline card.
- Azkar marked UNKNOWN: now known (Morning/Evening checklist, 12 + 12 items in `AzkarData`, `azkar_state` +
  `azkar_streak_date`, no Firestore / notifications / achievements).

## focus-mode.md
- Flow "Receiver → Service (overlay) → Activity": receiver starts service and activity separately; KDoc's
  fullScreenIntent claim is false.
- `AuraAccessibilityService` auto-click: dead (not in manifest; `isAccessibilityServiceEnabled` always false,
  `requestAccessibilityPermission` no-op).
- `focus_a11y_ever_enabled`: removed (bc765f6).
- "No `stopLockTask()` at timer end": false — `onCountdownComplete()` and `finishFocusMode()` call it.
- Channel lists only 3 areas; actual methods: `scheduleFocusAlarm`, `cancelFocusAlarm`, `canDrawOverlays`,
  `requestOverlayPermission`, `getFocusCompletedTaskId`, `isAccessibilityServiceEnabled`,
  `requestAccessibilityPermission`, `hasDndAccess`, `requestDndAccess`.
- Prefs: `aura_focus_mode` is written only by the dead `ACTION_FOCUS_COMPLETE` branch; live files are
  `${packageName}_preferences` and `aura_focus_state` (write-only start timestamp, F51q).
- "Blocks notification shade": no status-bar collapse code found (UNVERIFIED).
- Missing: task form promises "exit by pressing volume up 3 times", which is not implemented (F52).

## notifications-native.md
- Layer 1 (Flutter): on Android the pre-prayer reminder, "remind again" and daily task summary go through native
  `scheduleNativeNotification` → `NativeNotificationReceiver` (EMUI workaround), not flutter_local_notifications;
  pre-prayer offset is `notification_reminder_minutes` (default 10). Two 8 AM task digests exist (3999 native repeating +
  4001 plugin one-shot) — F52. Missing: task reminders (native), task "remind later" 30 min, wird reminders.
- Layer 2: `PrayerAlarmReceiver` also starts `AdhanFullScreenActivity` directly (`startActivity`), not only via
  `setFullScreenIntent`.
- "After Fajr/Isha calls `NativePrayerCalculator`": indirect, via `PrayerForegroundService.requestFlutterUpdateStatic`.
- "Silent mode": receiver sets `RINGER_MODE_VIBRATE`; duration from FlutterPrefs `silent_mode_duration` (default 20).
- `AdhanPlayer` "thread-safe": only `play()` is `@Synchronized`; `stop` / `releasePlayer` / `isPlaying` are not;
  `playbackLock` unused.
- `SilentModeAutomation.kt`: contains only dead `SilentModeScheduler`; real logic in `PrayerAlarmReceiver` and
  `ToggleSilentModeReceiver`.
- `AdhanFullScreenActivity` "✕ is the only dismiss": Back, volume keys (stop audio), and auto-finish at iqama / 3 s
  (then azkar) also exit; Stop/Keep Vibrate also require `aura_silent_mode.silent_mode_enabled`; "Stop Vibrate" does
  not close the screen (comment says it does).
- `SilentOffReceiver.kt` file does not exist — class lives in `ToggleSilentModeReceiver.kt`.
- File count: 20 of 30 `.kt` files documented; undocumented: `AzkarAlarmReceiver`, `AzkarFullScreenActivity`,
  `BackgroundServiceHandler` (dead), `DailyRecalcReceiver`, `FlutterPrefs`, `NativeNotificationReceiver`,
  `PrayerRecalcWorker`, `PrayerRescheduleService`, `RingProgressView` (dead), `TaskReminderReceiver`.
- Jumu'ah: missing 11:30 fallback, gate `jumua_reminder_enabled`, channel `jumuah_reminder`, ID 8001; uses last stored
  `dhuhr_time` (F51p).
- Foreground channel is `prayer_foreground_channel_v4`; deleted only when importance < HIGH.
- Timer "HH:MM (no seconds)": normal mode "1h 45m" / "Xس Yد"; adhan mode "Iqama in Xm Ys" with 2 action buttons; tick
  60 s; adhan/reminder modes use `ic_mosque`.
- Manifest counts: 24 `<uses-permission>` (23 unique, INTERNET twice), 20 receivers, 3 services, 4 activities.
- `layout-backup/` folder no longer exists (removed in 116547e); junk directories with shell-command names are tracked
  under `res/` (F52).
- Dart also calls `com.aura.hala/silent_mode`, which has no native handler (F9).

## prayer.md
- "9 calculation methods": internal enum has 9; UI offers 12 `AdhanCalculationMethod` strings mapped by
  `_getCalculationMethod` (UmmAlQura/Qatar → makkah, NorthAmerica → isna, Dubai → kuwait; MoonsightingCommittee,
  Singapore, Turkey → MWL fallback, F36a); FixedAngle / Proportional not selectable.
- 15-min location cache is `PrayerTimesNotifier._getCachedLocation` / `_locationCacheTTL`, not `LocationService`.
- "Side effects run once per day": guard is a notifier field; the provider is invalidated on every resume (and by the
  desktop location dialog), so side effects (incl. cleanup) re-run on every resume and cold start. Same-day reloads in
  the same notifier (Settings recalc) skip them — F52.
- Side-effects list missing desktop `DesktopAdhanService.initialize` + `DesktopPrayerScheduler.schedulePrayerTimers` and
  Android `cacheAccuratePrayerTimes` (today + 2 days); actual order: post-prayer check → digest → daily alarms → desktop
  timers → `savePrayerTimes` → `cleanupFuturePrayerRecords` → `updatePrayerTimes` → cache.
- `getNextPrayer()` sorts by time, can return Sunrise, and the fallback "tomorrow's Fajr" reuses today's Fajr time.
- Missing: minute tick (`_startNextPrayerUpdateTimer` / `_quickUpdateNextPrayer`); `updateNextPrayer()` has no caller
  (F52).
- Iqama: settings screen saves `iqama_minutes` and does not reload; native iqama keys stay stale until the next
  side-effects run.

## prayer-tracking.md
- `_syncNativePrayerStatuses()` → `_syncThenLoadPrayerStatus(fajrTime)`; also runs on cold start (2 s delay).
- Order is reversed: sync first, then one `load(forceRefresh: true)` in `finally`; the returned `bool` is ignored;
  Android then `startLiveSync()`.
- "Clears native keys": keys are overwritten with `"synced"` (skipped on read, pruned after 7 days); a failed Firestore
  write is still marked synced (F52).
- Native statuses: only `on_time` / `late` / `missed`; "Later" opens a picker; `NativeNotificationReceiver` "Mark as
  Prayed" also writes `on_time`.
- 30-second sync timer is desktop only; Android uses `startLiveSync` + 3-min re-subscribe, `stopLiveSync` on pause.
- `load()` always computes the effective day (`fajrTime` only updates `_lastFajr`); 30-s cache unless `forceRefresh`.
- Tracking screen: `_displayStatuses` returns `Map<String, PrayerStatus>` (row gets nullable lookup); 20-min filter
  lives in `_displayStatuses` (stats, calendar markers, day details), not `_buildDayDetails`.
- Cleanup runs on every notifier creation, not once per day.
- Home / prayer screen filter effective-day statuses against today's times → yesterday hidden 00:00–Fajr (F52).

## quran-wird.md
- 12,472 ayahs → **6,236** entries in `hafsData_v2-0.json`; fields also include `id`, `sura_name_ar`, `sura_name_en`.
- `UthmanicHafs` also used in the Bookmarks tab.
- Preload ±1 in `QuranSvgService` → reader preloads ±3; service has a 30-entry in-memory FIFO cache.
- Back dialog: missing first branch (page 604 + page-mode wird not completed → khatma dialog → `recordPageKhatma`,
  `markComplete`, `KhatmaCelebrationScreen`); close dialog title "Close Reader?".
- Bookmark dialog is built inside the `onBookmark` callback (uses `sheetCtx`); double close is `nav.pop(); nav.pop();`.
- `/quran_stats` = `QuranStatsScreen` (wird stats, `quranStatsProvider`); `/khatma_dua` = `KhatmaDuaScreen`, reached
  only via `MaterialPageRoute` from `KhatmaCelebrationScreen` (named route unused).

## settings-prefs.md
- 5 sections → 6: Background & Battery is Android only; Desktop ("Start with Windows") is Windows only; several rows
  conditional (silent duration, remind-before, daily summary time).
- "Replaces settings scattered across the prayer screen": prayer screen still opens the calculation dialog, iqama
  settings and adhan downloads.
- App mode selection: real onboarding route is `/onboarding` (`PreferenceScreen`), label "Prayer Only" / "الصلاة فقط";
  "Prayer & Quran" only in Profile and the dead `/mode_selection` (F46c).
- `SharedPreferencesService` override: `ProviderContainer(overrides: …)` + `UncontrolledProviderScope`; provider defined
  in `auth_provider.dart`.
- Preferences provider list omits firstLaunch, vibrationSimplified, dynamicColor, jumuahReminderEnabled,
  taskReminderMinutes, appMode, prayerTrackingEnabled, dailySummaryTime, tabNavigation, showTutorial.

## tasks.md
- `completeRecurringTask()` → private `_completeRecurringTask()` from `toggleTaskCompletion`.
- Sections: Overdue, Today's Tasks, Due Soon (3 h), Tomorrow, This Week, Next Week, Later, No Date, Completed; manual
  sort = flat reorderable list + Completed. No "Upcoming" / "All Tasks".
- Sort enum also has `manual`; dateDesc/dateAsc sort by `createdAt`.
- Context menu order: Edit, Pin/Unpin, Duplicate, Change Priority, Mark Complete/Incomplete, Delete (bottom sheet).
- Drag-to-reorder uses `ReorderableDelayedDragStartListener` in manual mode; cards pass `onLongPress: null`.
- Streak keys are written only by `HomeScreen._incrementStreak` (F32a), not TasksScreen.
- Resume list outdated: actual order `_checkUntrackedPrayers` → read Fajr → invalidate `prayerTimesProvider`,
  `tasksProvider(const TaskFilterParams())`, `allTasksProvider` → `_handleWidgetIntent` →
  `_syncThenLoadPrayerStatus` → `rescheduleAllTaskReminders` (not desktop); `stopLiveSync` on pause. The
  "must also invalidate allTasksProvider" note is done.
- `tasksProvider` is `StreamProvider.family` without autoDispose (its comment says autoDispose).
- Missing: TasksScreen's own lifecycle observer (focus completion + day change); rows are `_InlineSubtaskCard`
  (`TaskCard` only in select mode).

## ui-kit.md
- easy_localization `^3.0.3` constraint; lock has 3.0.8.
- `showTutorial` takes named required params.
- Home uses `isTutorialCompleted()` / `setTutorialCompleted()`; Seen pairs: Prayer, Quran, Tasks, Juz, Bookmarks, Wird,
  Reader. Profile "App Tour" resets all and launches via `showTutorialProvider` (skips the delays).
- InfoTipIcon: `getPrimary(isDark).withOpacity(0.7)`, size `ts.scale(18)`; also inside `PrayerCard` and 8× in the
  Wird tab.
- HomeScreen watches `currentUserProvider` without `select`.
- Shared widgets: 20 files (doc lists 8).
- `#7A6E5A` lives in `AppConstants.lightTextSecondary`, not app_theme; theme text is Roboto, Cairo only via
  `AppTypography.ar(...)`; `UthmanicHafs` font undocumented here.

## widgets.md
- 4 widgets (manifest): `AllPrayersWidget` (no class "CombinedPrayerWidget"), `TasksWidget`, `NextTaskWidget` (4×1,
  in `TasksWidget.kt`), `DailyContentWidget` (light/dark only, no RTL).
- `WidgetUpdateService.kt` is dead (not in manifest).
- Task rows `layoutDirection="ltr"` only in LTR layouts (first row of `tasks_widget.xml` lacks it); RTL layouts use
  `rtl`; next-task layouts none.
- Prefs-file doc conflict is resolved: `FlutterPrefs.putInt` → `flutter.widget_navigate_to_tab` (Long) (D7).
  `widget_target_tab` is also set by `NativeNotificationReceiver`, `TaskReminderReceiver` (3) and NextTaskWidget.
- `pending_complete_task_id` written to both `aura_tasks_widget` and FlutterPrefs.

## wird.md
- `WirdState` also has `khatmCount`, `khatmDates`; defaults (page goal 5, juz goal 1, reminders on) undocumented.
- Signatures: `setLinkedBookmarkColor(String, Set<int>)`, `Future<int> syncBookmarkPages(Set<int>)`,
  `Future<int> markJuzFromBookmarks(...)`; many notifier methods unlisted.
- Achievements: 7 (`+ wird_streak_100`, `wird_pages_100`, `wird_pages_300`), not 4.
- Reminders: on Android native `scheduleNativeNotification` (repeat daily, tab 2, IDs 5100+i); `zonedSchedule` only
  on non-Android mobile; desktop via `DesktopNotificationService`; cap 10 enforced in the notifier (service allows 20).
- Reading button opens the reader at `currentPage`, not `startPage`.
- "Add from Bookmarks" has no double pop: dialog pop → `onChooseOne` pops the sheet and opens `_BookmarkListSheet`.
