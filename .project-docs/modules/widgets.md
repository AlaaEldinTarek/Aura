# Home screen widgets
Verified against code 2026-11-07 (reference/2026-11-07_DRIFT_REPORT.md). Channel: `com.aura.hala/widgets`.

## Widgets (4 providers in the manifest)
- `AllPrayersWidget` (`PrayerWidgets.kt`), `TasksWidget` and `NextTaskWidget` (4×1, both in `TasksWidget.kt`),
  `DailyContentWidget` (`DailyContentWidget.kt`). Each has a `*Receiver` companion in the manifest.
- Dart services: `prayer_widget_service`, `task_widget_service`. `WidgetUpdateService.kt` is dead (not in manifest).
- Known display issues: F51h (stale next prayer), F51o.

## `PrayerWidgets.kt`
- `AllPrayersWidget` with ViewFlipper tabs (Next Prayer + Timeline), 4 layout variants (light/dark × LTR/RTL).
- Colors: active gold `#F5B301` / `#B5821B`; background `widget_v3_bg_dark/light` (`#111317→#1A1B1E` / `#FFF8EB→#FFF3D6`).
- Root tap → Prayer tab (index 1) via `widget_target_tab=1` extra.

## `TasksWidget.kt` / `DailyContentWidget.kt`
- TasksWidget celebration state (all done): label turns gold (`#F5B301` dark / `#B5821B` light) — NOT green.
- Root tap → Tasks tab (index 3) via `widget_target_tab=3`; NextTaskWidget also sets it.
- Task rows: LTR layouts use `android:layoutDirection="ltr"` (first row of `tasks_widget.xml` lacks it); RTL layouts use
  `rtl`; `next_task_widget` layouts set none.
- `DailyContentWidget`: light and dark layouts only (no RTL variant).

## Tab handoff (widget → app)
- `MainActivity.handleWidgetTabIntent()` reads `widget_target_tab` and writes `widget_navigate_to_tab` via
  `FlutterPrefs.putInt` (`FlutterSharedPreferences`, `flutter.` prefix, stored as Long); Flutter `_handleWidgetIntent()`
  reads it (after `prefs.reload()`) and calls `_handleTabTap(index)`. Cold start (`onCreate`) and warm (`onNewIntent`).
- `widget_target_tab` is also set by `NativeNotificationReceiver` (tap tab) and `TaskReminderReceiver` (3). Keys:
  contracts/intent-extras.md.
- Other handoff flags: `pending_complete_task_id` (written to both `aura_tasks_widget` and FlutterPrefs),
  `widget_open_task_form` — contracts/prefs-keys.md.

## Gotchas
- RemoteViews: cannot use `<View>` elements (crashes Android 10). Use `<FrameLayout>` for dividers.
- Widget refreshes no longer wake the device — commit 12b37aa (from git log).
