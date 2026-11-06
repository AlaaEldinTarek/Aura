# Contract — intent extras & handoff flags
Seeded from old CLAUDE.md on 2026-11-06; Confidence: Unknown until Step 2.

| Name | Kind | Writer | Reader | Notes |
| --- | --- | --- | --- | --- |
| `widget_target_tab` | Intent extra (int) | PrayerWidgets.kt (=1 Prayer), TasksWidget.kt (=3 Tasks) | `MainActivity.handleWidgetTabIntent()` (`onCreate` + `onNewIntent`) | |
| `widget_navigate_to_tab` | Prefs key | MainActivity | Flutter `_handleWidgetIntent()` → `_handleTabTap(index)` | Prefs file is a doc conflict (findings.md) |
| `refresh_prayer_times` | Intent extra | none | — | Old CLAUDE.md claim was stale: the service recalculates natively and never launches MainActivity (findings D5). Not in Kotlin; Dart side unchecked → Step 2 |

Other widget handoff flags (`pending_complete_task_id`, `widget_open_task_form`): contracts/prefs-keys.md.
