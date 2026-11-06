# Old CLAUDE.md (322 lines, commit 75d38b9) → new homes
Every fact has exactly one home; other files link to it. Stale facts are recorded as conflicts in findings.md.

| Old section | New home |
| --- | --- |
| Project Overview (name, package, version) | CLAUDE.md § Context (version → pubspec; old value D1) |
| Key Features list | reference/architecture.md § Features; feature-specific bullets → matching module |
| — bookmark delete icon + undo | modules/quran-wird.md § Bookmarks |
| — Wird summary | modules/wird.md § Overview |
| — Tutorial system / InfoTipIcon summary | modules/ui-kit.md |
| — Quran wakelock / back button summary | modules/quran-wird.md § SVG reader |
| Development Commands | CLAUDE.md § Commands (`dart format .` now marked approval-gated) |
| State management providers | reference/architecture.md § State management |
| Feature Structure tree | reference/architecture.md § Folders |
| Routes (21) | reference/architecture.md § Routes (now 25, D2) |
| `/settings` central screen | modules/settings-prefs.md |
| Platform Channel table (7) | contracts/method-channels.md (now 8, D4) |
| Native Android table — prayer/alarm/adhan/silent/boot/receivers | modules/notifications-native.md § Native files |
| — PrayerWidgets / TasksWidget / WidgetUpdateService / DailyContentWidget / tab intent | modules/widgets.md |
| — FocusModeService / Activity / AuraAccessibilityService / FocusModeReceiver | modules/focus-mode.md |
| — AndroidManifest counts, layout-backup location | modules/notifications-native.md § Gotchas |
| NEVER launch MainActivity | CLAUDE.md § Rules |
| App Initialization Flow | reference/architecture.md § Init flow |
| Prayer Time Calculation Flow + next-prayer logic | modules/prayer.md |
| Notification Architecture layers 1–2 | modules/notifications-native.md |
| Notification layer 3 (post-prayer, summary, resume sync, order) | modules/prayer-tracking.md § Native status sync |
| Achievement notifications | modules/achievements.md § Unlock flow |
| `prayer_tracking` channel | contracts/notification-ids.md (+ DailySummaryReceiver bullet) |
| Jumu'ah Reminder | modules/notifications-native.md § Jumu'ah; ID/channel → contracts/notification-ids.md |
| Foreground Service Notification | modules/notifications-native.md § Foreground service (day-transition conflict D5) |
| Native SharedPreferences File Names (table + history) | contracts/prefs-keys.md; one-line rule in CLAUDE.md § Rules |
| State Sync Pattern | modules/auth-sync.md |
| Localization: `.tr()`, both json files, numerals, getPrayerDisplayName | CLAUDE.md § Rules |
| Localization: AM/PM, fonts, key counts | modules/ui-kit.md (counts → findings D6) |
| Platform channels try-catch + emoji logs | CLAUDE.md § Rules; emoji list → contracts/log-tags.md |
| Task System (all bullets except Focus Mode) | modules/tasks.md |
| Task Focus Mode bullet | modules/focus-mode.md |
| Dhikr/Tasbeeh System | modules/dhikr-azkar.md |
| Wird System (all subsections) | modules/wird.md; notification IDs → contracts/notification-ids.md; prefs keys → contracts/prefs-keys.md |
| Windows Desktop Adaptive Scaling | modules/desktop-scaling.md |
| MSIX versioning + build command | modules/desktop.md |
| Gotcha: RemoteViews `<View>` | modules/widgets.md § Gotchas |
| Gotcha: notification channel importance | modules/notifications-native.md § Gotchas |
| Gotchas: Quran data, UthmanicHafs, SVG reader, bookmark color dialog | modules/quran-wird.md |
| Gotcha: TextDirection conflict | modules/ui-kit.md § Localization |
| Gotcha: Dhuhr/Zuhr naming | CLAUDE.md § Rules |
| Gotchas: HomeScreen timer lifecycle, provider scoping | modules/ui-kit.md § Screen patterns |
| Gotcha: language switching | modules/ui-kit.md § Localization |
| Gotchas: mode naming, bottom nav Quran visibility | modules/settings-prefs.md § App mode |
| Gotcha: iqama time in prefs | modules/prayer.md § Iqama (keys also listed in contracts/prefs-keys.md) |
| Gotcha: `Task.isOverdue` | modules/tasks.md |
| Gotcha: Makkah Dhuhr offset | modules/prayer.md |
| Gotchas: achievements sections, mode filtering, profile grid | modules/achievements.md |
| Gotchas: tutorial system, InfoTipIcon | modules/ui-kit.md |
| Gotchas: Quran wakelock, back button | modules/quran-wird.md § SVG reader |
| Gotchas: prayer tracking sync, null untracked, after-midnight, `dailyPrayerStatusProvider` fajrTime, `isPrayerTimeReached`, `_effectiveToday`, cleanup | modules/prayer-tracking.md |
| Gotcha: task cross-device sync | modules/tasks.md § Cross-device sync |
| Theme System | modules/ui-kit.md § Theme |
| Key Dependencies | reference/architecture.md § Key dependencies |
| Critical Services (edit carefully) | CLAUDE.md § Rules; per-file notes in modules |
| Assets | reference/architecture.md § Assets + modules/quran-wird.md § Data & font |
| Git Commit Guidelines | CLAUDE.md § Rules (Commits) |

Deliberate exceptions to "one home": prefs key names appear in a module when the module explains behavior, and the
contract file is the authoritative list.
