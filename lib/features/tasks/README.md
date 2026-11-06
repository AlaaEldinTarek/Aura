# Tasks Feature Blueprint

## System Overview
The task management UI: 3 screens in one flat folder (`tasks_screen` list/calendar, `task_form_screen` create/edit,
`task_stats_screen` statistics). The screens own no data. They read `allTasksProvider` / `taskStatisticsProvider`
(`../../core/providers/task_provider.dart`) and write through `TaskService.instance` (`../../core/services/`), then
`ref.invalidate` the providers. Task model rules (`isOverdue`, `isDueToday`, recurrence): `../../core/models/README.md`.
The cross-folder feature view (notifications, sync, resume) is in `.project-docs/modules/tasks.md`; Focus Mode is in
`.project-docs/modules/focus-mode.md`. Behavior-preserving rule: no UI or logic change without an approved spec.

## Local Interface & Invariants

### Interface
| File | Public symbols / entry points |
| --- | --- |
| `tasks_screen.dart` | `TasksScreen()` (bottom-nav tab 3). Private: `_SortOrder` {dateDesc, dateAsc, priority, title, manual}, `_TaskSettingsSheet`, `_QuickAddSheet`, `_InlineSubtaskCard` (wraps core `TaskCard`), `_CelebrationOverlay` |
| `task_form_screen.dart` | `TaskFormScreen({Task? task})`: null = create, non-null = edit. Route `/task_form`, with the `Task` passed as `arguments` |
| `task_stats_screen.dart` | `TaskStatsScreen()`: route `/task_stats`, 2 tabs (Overview, Details) |

Routes are registered twice: `main.dart` `onGenerateRoute` and `main_wrapper_screen.dart` (nested navigator).
Navigation in: FAB tap → `_QuickAddSheet`; FAB long-press / Edit → `/task_form`; stats row tap → `/task_stats`.
`/task_form` pops with `true` after a save or delete, and the caller then invalidates the providers.

### Invariants
- **Sections** (`_TasksScreenState._buildSections`): filter by category → tag → search (title, description, tags,
  subtask titles) → `_applySort`. Groups: Overdue (`isOverdue`), Today (`isDueToday && !isOverdue`), Due Soon (has
  time, within 3 h), Tomorrow, This Week (< 7 days), Next Week (< 14 days), Later, No Date, Completed (completed
  today only). Only Completed collapses (`_showCompleted`, not persisted). Every dated section is re-sorted by
  `dueDate`, so pinned-first and the chosen sort order only hold in No Date and Completed.
  `.project-docs/modules/tasks.md` says pinned tasks "always float"; that is not true here.
- **Manual sort** (`_SortOrder.manual`) replaces the sections with a reorderable list of active tasks (long-press
  drag). It calls `TaskService.updateTaskOrders`.
- **Persisted filters**: the sort order (by `enum.name`) and the category (by `TaskCategory.value`) are saved. An
  unknown saved category falls back to `other`, not to "All". The tag filter, search, calendar and select mode are
  in memory only.
- **Calendar view** (`table_calendar`, month only, now ±365 days) shows all tasks and ignores the category, tag and
  search filters. The list and calendar are the only view modes; `_buildTaskGrid` is a Column, not a grid.
- **Day rollover**: `_midnightTimer` fires at local 00:00 and on resume after a date change, then invalidates both
  providers. On resume `_checkFocusTaskCompleted` completes a task that native Focus Mode finished.
- **Completion** (`_toggleTask`): there is a single screen-wide `_isToggling` guard. A completed id stays visible for
  1.5 s (`_recentlyCompleted`). The celebration shows when the last incomplete task that is due today or undated is
  completed. It runs 800 ms later and is removed after 3 s. Recurrence is handled inside `TaskService.toggleTaskCompletion`.
- **Form save** (`_TaskFormScreenState._saveTask`): the title is required (the only validator). The date and time
  are merged when both are set. With recurrence off, the form saves `RecurrenceType.none`; when editing a `none`
  task the UI shows `daily`. The category picker hides `other` (the default). The date picker's `firstDate` is
  "now".
- **Focus Mode in the form**: turning it on needs overlay + DND permission (`NotificationService.canDrawOverlays` /
  `hasDndAccess`) and a confirmation; these are Android only, so on desktop it can never be turned on. The duration
  is 15/25/45/60 or a custom value from 1 to 180 min. Saving with focus on and a due date calls `scheduleFocusMode`;
  editing with focus off calls `cancelFocusMode`.
- **Prayer conflict warning** (form): shown only in `AppMode.both` when a date and a time are set. It compares the
  task with `prayerTimesProvider` times within ±30 min and skips the name `'Sunrise'`.
- **Settings sheet**: the task notifications toggle and the reminder minutes (5/10/15/30/45/60, default 30) go through
  `taskNotificationsEnabledProvider` / `taskReminderMinutesProvider`. The prefs keys live in those providers.
- **Stats**: the top cards use `taskStatisticsProvider` and the breakdowns use `allTasksProvider` (two sources). The
  weekly chart covers the last 7 days and is drawn by hand (no chart library). "This week" starts on Monday. The
  streak is read only (`task_streak_count` / `task_streak_date`; written by `home_screen.dart`).
- **Localization**: almost every string is an inline `isArabic ? '…' : '…'` (only `'task_management'.tr()` and the
  tutorial keys `tutorial_tasks_*`). `isArabic` comes from `Localizations.localeOf`, but notification and Focus Mode
  language comes from the prefs key `language`. `NumberFormatter` is used only in places (estimates, bulk bar,
  some stats); many counts and dates show Western digits (findings F31).
- **Desktop**: the category chips use fixed sizes on Windows/macOS/Linux (`Platform` check). There are no other
  platform branches in this folder.

### Side Effects
- `TaskService.instance`: `addTask` (form, quick add, duplicate), `updateTask` (form, pin, priority, postpone,
  subtasks), `toggleTaskCompletion` (toggle, bulk, focus resume), `deleteTask` (form, bulk, clear completed),
  `updateTaskOrders` (manual sort). Each one is followed by `ref.invalidate(allTasksProvider / taskStatisticsProvider)`.
  The priority change invalidates only `allTasksProvider`, and the focus resume only `tasksProvider(const TaskFilterParams())`.
- `NotificationService.instance`: `scheduleFocusMode`, `cancelFocusMode`, `startFocusService` ("Start focus now"),
  `checkFocusTaskCompleted`, `canDrawOverlays` / `requestOverlayPermission`, `hasDndAccess` / `requestDndAccess`.
- SharedPreferences: read/write `task_sort_order`, `task_category_filter`; read `language`, `task_streak_count`,
  `task_streak_date`. Tutorial flag via `SharedPreferencesService.isTutorialTasksSeen` / `setTutorialTasksSeen`.
- Timers / animation: `_midnightTimer`, the tutorial (900 ms delay), the celebration `AnimationController` (2.8 s) and
  overlay entry, the 1.5 s `_recentlyCompleted` timeout, and haptics (`app_haptic.HapticFeedback`).

## Subdirectories & System Boundaries
- None (flat directory).

## Global Invariants
- The prefs keys above and the `/task_form` / `/task_stats` route names are contracts
  ([prefs-keys](/.project-docs/contracts/prefs-keys.md)). The streak keys are shared with `home_screen`,
  `achievement_service` and `task_widget_service`.
- All Firestore access goes through `TaskService`; no screen here touches Firestore or MethodChannels directly.

## Global Side Effects
- Task CRUD through `TaskService` (Firestore or guest local prefs, reminders, achievements). Neither these screens nor
  `TaskService` call `TaskWidgetService`; the tasks home widget is refreshed from
  `task_provider.dart` / `preferences_provider.dart` ([providers README](../../core/providers/README.md)).
- Focus Mode scheduling and the overlay/DND permission requests go through `NotificationService` (native Android).

## System Verification
- Run: `flutter test` (no tests for this folder yet). Manual checks: `.project-docs/reference/device-checklist.md`
  S15, S16, S19–S21.
- Known issues: findings F30 (verified) and F31 (scout backlog).
