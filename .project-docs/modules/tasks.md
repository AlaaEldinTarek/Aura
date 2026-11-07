# Tasks
Verified against code 2026-11-07 (reference/2026-11-07_DRIFT_REPORT.md). Focus Mode: focus-mode.md. Folder view:
`lib/features/tasks/README.md`.

## Key files
- `lib/features/tasks/` (`tasks_screen`, `task_form_screen` `/task_form`, stats `/task_stats`)
- `lib/core/models/task`, `lib/core/services/task_service.dart`, `task_widget_service`
- `lib/core/providers/task_provider` — `tasksProvider` (`StreamProvider.family`, not autoDispose despite its comment),
  `allTasksProvider` (used by `TasksScreen`)
- `lib/core/widgets/task_card` (TasksScreen rows are `_InlineSubtaskCard`; `TaskCard` only in select mode)

## Model
- Categories: work, personal, shopping, health, study, prayer, other. Priorities: low, medium, high.
- Recurrence: none/daily/weekly/monthly — `toggleTaskCompletion` generates the next instance via private
  `_completeRecurringTask()`.
- Subtasks: `SubTask` model; `subtaskProgress` (0.0–1.0) and `completedSubtasks` are computed.
- Pin to top: `isPinned`; `_applySort()` floats pinned tasks, but dated sections re-sort by `dueDate`, so it only holds
  in No Date / Completed (F30b).
- Due time: `hasDueTime` + `TimeOfDay` in `dueDate`; badge shows 12h with ص/م.
- Firestore sync (collection: contracts/firestore-paths.md).

## `Task.isOverdue` day-level check
- Without a due time (`hasDueTime = false`): compares due DATE vs today's date (not the timestamp) — otherwise tasks due
  today show as Overdue from the start of the day (`dueDate` is midnight). With a time: exact timestamp comparison.
- Never revert to a single `DateTime.now().isAfter(dueDate!)` — it breaks the Today section.

## TasksScreen
- Sections (collapsible): Overdue, Today's Tasks, Due Soon (< 3 h; overlaps Today, F30a), Tomorrow, This Week, Next
  Week, Later, No Date, Completed. Manual sort: one flat reorderable list + Completed. Midnight timer refreshes sections;
  own lifecycle observer (focus completion check + day change).
- Sort `_SortOrder`: dateDesc / dateAsc (by `createdAt`) / priority / title / manual, persisted (`task_sort_order`).
  Filter chips: category (`task_category_filter`) + auto-generated tag chips.
- Context menu (⋮ → bottom sheet, `onMenuTap`): Edit, Pin/Unpin, Duplicate, Change Priority, Mark Complete/Incomplete,
  Delete. Drag-to-reorder only in manual sort (`ReorderableDelayedDragStartListener`); cards pass `onLongPress: null`.
  Focus-mode cards use a separate ⋮ overlay.
- Tune icon ⊞ in AppBar opens `_TaskSettingsSheet`; highlighted as the 3rd step of the Tasks tutorial (`_settingsKey`).
- Celebration overlay: `AnimationController` (NOT flutter_animate). Streak keys `task_streak_count` / `task_streak_date`
  are written only by `HomeScreen._incrementStreak` (F32a).

## Notifications
- `scheduleTaskReminder()`: with-time tasks get an X-min-before reminder (5/10/15/30/45/60 via `task_reminder_minutes`,
  default 30); without time → 9 AM. Controlled by `task_notifications_enabled`. Android delivery is native
  (notifications-native.md layer 1).
- Daily task summary (3999) and 8 AM digest (4001): notifications-native.md layer 1 (duplicate, F52e).

## Cross-device sync / app resume
- `MainWrapperScreen.didChangeAppLifecycleState` on resume, in order: `_checkUntrackedPrayers()` → read Fajr →
  `ref.invalidate(prayerTimesProvider)` → `ref.invalidate(tasksProvider(const TaskFilterParams()))` →
  `ref.invalidate(allTasksProvider)` → `_handleWidgetIntent()` → `_syncThenLoadPrayerStatus(fajr)` →
  `TaskService.instance.rescheduleAllTaskReminders()` (not desktop). On pause: `stopLiveSync()`.
- Keep invalidating `allTasksProvider` on resume so the phone picks up tasks completed on desktop.
- Offline queue: no producers (F16, auth-sync.md).
