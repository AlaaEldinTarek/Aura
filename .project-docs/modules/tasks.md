# Tasks
Relocated from CLAUDE.md on 2026-11-06; not yet re-verified (Step 2). Focus Mode: focus-mode.md.

## Key files
- `lib/features/tasks/` (`tasks_screen`, `task_form_screen` `/task_form`, stats `/task_stats`)
- `lib/core/models/task`, `lib/core/services/task_service.dart`, `task_widget_service`
- `lib/core/providers/task_provider` — `tasksProvider` (stream-based CRUD, family modifier), `allTasksProvider`
- `lib/core/widgets/task_card`

## Model
- Categories: work, personal, shopping, health, study, prayer, other. Priorities: low, medium, high.
- Recurrence: none/daily/weekly/monthly — completion auto-generates next via `completeRecurringTask()`.
- Subtasks: `SubTask` model; `subtaskProgress` (0.0–1.0) and `completedSubtasks` are computed.
- Pin to top: `isPinned`; `_applySort()` floats pinned tasks above the sort order, but dated sections re-sort by
  `dueDate`, so it only holds in No Date / Completed (findings F30b; folder view: `lib/features/tasks/README.md`).
- Due time: `hasDueTime` + `TimeOfDay` in `dueDate`; badge shows 12h with ص/م.
- Firestore sync (collection: contracts/firestore-paths.md).

## `Task.isOverdue` day-level check
- Without a due time (`hasDueTime = false`): compares due DATE vs today's date (not the timestamp) — otherwise tasks due
  today show as Overdue from the start of the day (`dueDate` is midnight). With a time: exact timestamp comparison.
- Never revert to a single `DateTime.now().isAfter(dueDate!)` — it breaks the Today section.

## TasksScreen
- Sections: Overdue / Today / Upcoming / All Tasks / Completed (collapsible). Midnight timer at 00:00 refreshes sections.
- Sort: dateDesc/dateAsc/priority/title, persisted (`task_sort_order`). Filter chips: category (`task_category_filter`)
  + auto-generated tag chips.
- Context menu ⋮: Edit/Duplicate/Change Priority/Pin/Toggle Complete/Delete (`onMenuTap`, separate from `onLongPress`
  used for drag-to-reorder).
- Tune icon ⊞ in AppBar opens `_TaskSettingsSheet`; highlighted as the 3rd step of the Tasks tutorial (`_settingsKey`).
- Celebration overlay: `AnimationController` (NOT flutter_animate). Streak: `task_streak_count` / `task_streak_date`.

## Notifications
- `scheduleTaskReminder()`: with-time tasks get an X-min-before reminder (5/10/15/30/45/60 via `task_reminder_minutes`,
  default 30); without time → 9 AM. Controlled by `task_notifications_enabled`.
- Daily summary notification uses `matchDateTimeComponents: DateTimeComponents.time` (ID: contracts/notification-ids.md).
- Daily 8 AM task digest: notifications-native.md layer 1.

## Cross-device sync / app resume
- `MainWrapperScreen.didChangeAppLifecycleState` on resume: `_checkUntrackedPrayers()`, `ref.invalidate(prayerTimesProvider)`,
  `ref.invalidate(tasksProvider)`, `_handleWidgetIntent()`, `_syncNativePrayerStatuses()`.
- `allTasksProvider` (used by `TasksScreen`) must ALSO be invalidated on resume (previously only
  `tasksProvider(const TaskFilterParams())` was) so the phone picks up tasks completed on desktop. It is `autoDispose`
  and uses `query.snapshots()` on Android (real-time) but still needs invalidation to bust stale in-memory state.
- Offline task create is queued (`offline_queue_service`, `sync_service`): auth-sync.md.
