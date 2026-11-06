# Home screen widgets
Relocated from CLAUDE.md on 2026-11-06; not yet re-verified (Step 2). Channel: `com.aura.hala/widgets`.

## Widgets
- Three widgets: CombinedPrayerWidget, TasksWidget, DailyContentWidget — light/dark/LTR/RTL variants.
- Dart services: `prayer_widget_service`, `task_widget_service`.

## `PrayerWidgets.kt`
- CombinedPrayerWidget (AllPrayersWidget) with ViewFlipper tabs (Next Prayer + Timeline), 4 layout variants.
- Colors: active gold `#F5B301` / `#B5821B`; background `widget_v3_bg_dark/light` (`#111317→#1A1B1E` / `#FFF8EB→#FFF3D6`).
- Root tap → Prayer tab (index 1) via `widget_target_tab=1` extra.

## `TasksWidget.kt` / `WidgetUpdateService.kt` / `DailyContentWidget.kt`
- TasksWidget celebration state (all done): label turns gold (`#F5B301` dark / `#B5821B` light) — NOT green.
- Root tap → Tasks tab (index 3) via `widget_target_tab=3` extra.
- Task rows use `android:layoutDirection="ltr"` so Arabic titles don't break the LTR row layout.

## Tab handoff (widget → app)
- `MainActivity.handleWidgetTabIntent()` reads `widget_target_tab` from the Intent and writes `widget_navigate_to_tab`
  to prefs; Flutter `_handleWidgetIntent()` reads it (after `prefs.reload()`) and calls `_handleTabTap(index)`.
- Works for cold start (`onCreate`) and warm start (`onNewIntent`).
- Which prefs file it writes is a doc conflict — reference/findings.md. Keys: contracts/intent-extras.md.
- Other widget handoff flags (`pending_complete_task_id`, `widget_open_task_form`): contracts/prefs-keys.md.

## Gotchas
- RemoteViews: cannot use `<View>` elements (crashes Android 10). Use `<FrameLayout>` for dividers.
- Widget refreshes no longer wake the device — commit 12b37aa (from git log).
