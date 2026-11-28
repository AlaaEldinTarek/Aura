# Fix spec: F51o widget display issues

Status: Draft — awaiting owner decisions (section "Decisions") and `approve phase P1`

Branch: `fix/f51o` (from main 7b164cc). Tag: fix track LOW. Source: `reference/findings.md` F51(o).

All claims below were checked in source on 2026-11-28 (labels per item). No device check was run.

## Finding — the six sub-items

| # | Claim in findings | Result | Where |
| --- | --- | --- | --- |
| 1 | Past prayers use the "now" dot; `dotPast` unused | VERIFIED | `PrayerWidgets.kt:321-346` (`isPast -> dotNow`; `dotPast` declared at :323, never read; drawables `widget_timeline_dot_past(_dark)` exist) |
| 2 | Day / month names follow the device locale | VERIFIED | `PrayerWidgets.kt:244,251` (`DateFormat.format("EEEE"/"MMM")` uses the default locale; the Arabic `when` maps English names only) |
| 3 | Tabular Hijri may differ from the app | VERIFIED same algorithm — no defect | `PrayerWidgets.kt:508-531` and `lib/core/utils/hijri_date.dart:6-40` use the same Julian-day formula, same epoch, same 30-year leap table. Both are tabular, so the widget matches the app. Month-name abbreviations differ (UNVERIFIED, not checked). **Dropped from this spec.** |
| 4a | Daily-content list is off by one day vs Dart | VERIFIED | Kotlin `Calendar.DAY_OF_YEAR` is 1-based (`DailyContentWidget.kt:90-91`); Dart `_dayOfYear` is 0-based (`daily_content_service.dart:139-140`). Same index on the same day gives different items. |
| 4b | Ordered differently | VERIFIED | Kotlin has "beloved deeds / Fajr / smile / speak good / beautiful / prison"; Dart has "prison / Fajr / beloved deeds / smile / speak good / beautiful". The Arabic and translation text also differ in several items (e.g. Kotlin drops the second half of Al-Baqarah 2:152 and of Aal-e-Imran 3:139; full diff not run). |
| 4c | Shows the English translation in Arabic mode | VERIFIED, but same question as F43a | `DailyContentWidget.kt:104` always sets `item.translation`. The app screen does the same (F43a, "confirm intent"). **Held until F43a is decided.** |
| 5 | Tasks widget shows yesterday's list after midnight until Flutter pushes | VERIFIED on the native side | `TasksWidget` / `NextTaskWidget` read `aura_tasks_widget` prefs that carry no date; the 30-minute alarm (`TasksWidget.kt:235`) only redraws what is stored. Dart pushes only on task change or settings change (`task_provider.dart:54`, `preferences_provider.dart:66,150`). Whether anything else pushes at midnight: UNVERIFIED. |
| 6 | NextTaskWidget has no tap target when `task_0_id` is empty | VERIFIED | `TasksWidget.kt:360-368`: the root click is set only inside `if (taskId.isNotEmpty())`; the "no tasks" branch sets the Tasks-tab fallback (:376-382), the "count > 0 but empty id" case sets nothing. |
| 7 | Only DailyContentWidget treats `amoled` as dark | VERIFIED | `amoled` is a real stored `theme_mode` value (`lib/main.dart:338,345`). `DailyContentWidget.kt:82` handles it; `PrayerWidgets.kt:81-85`, `TasksWidget.kt:221-223`, `TasksWidget.kt:302-304` do not, so AMOLED users on a light-mode phone get light widgets. |

## Fix (one commit per phase)

### P1 — Kotlin only, no prefs / channel / ID change

1. **Theme (item 7).** In the three places above, use `"dark", "amoled" -> true` (same rule as `DailyContentWidget` and `ThemedNotification.kt:23`).
2. **NextTask tap (item 6).** Set the Tasks-tab launch intent (`widget_target_tab=3`, same code as the "no tasks" branch) when `taskId` is empty. Request code stays `appWidgetId + 1000`.
3. **Past dot (item 1).** `isPast -> dotPast`. *UI change — needs owner OK (Decision 1).*
4. **Locale (item 2).** Format the English day/month with `SimpleDateFormat("EEEE" / "MMM", Locale.ENGLISH)` so the existing Arabic `when` maps always match and an English-UI user on an Arabic-locale phone sees English names. The Arabic branch is unchanged.

### P2 — Daily content alignment (Kotlin list + test)

1. Make `DailyContentWidget.CONTENT` equal to `DailyContentService._content` (same order, same text), and use `dayOfYear - 1` so both pick the same item. Excludes item 4c.
2. Add a source-text test (new file `test/features/daily_content/widget_list_sync_test.dart`) that parses both files and asserts the same Arabic strings in the same order. This is a test case, so it is C-level and covered by the same approval.

### P3 — Midnight guard (item 5; touches a prefs contract, needs Decision 2)

In the `updateTasksWidget` handler (`MainActivity.kt:364-395`) also store `saved_date` (local `yyyy-MM-dd`, computed natively) in `aura_tasks_widget`. `TasksWidget` and `NextTaskWidget` treat data whose `saved_date` is not today as empty (the existing empty state). No Dart change, no channel argument change. Document the new key in `contracts/prefs-keys.md` in the same commit.

## Decisions (owner)

1. Past prayers get the dimmer "past" dot instead of the "now" dot (visible change in the timeline tab). Yes / no?
2. P3: yesterday's list is replaced by "No tasks today" after midnight until the app pushes again (instead of staying stale). Yes / no / defer?
3. Item 4c waits on F43a; confirm.

## Files changed

- P1: `PrayerWidgets.kt`, `TasksWidget.kt` (both classes).
- P2: `DailyContentWidget.kt`, new test file.
- P3: `MainActivity.kt`, `TasksWidget.kt`, `.project-docs/contracts/prefs-keys.md`.

Out of scope: Dart `_dayOfYear` DST edge (UNVERIFIED: local-time `difference().inDays` may be one low between 00:00 and 01:00 while DST is active), `WidgetUpdateService.kt` (dead code), RTL variant of the daily widget.

## Verification

- `flutter analyze` and `flutter test` (new sync test included): pass/fail only.
- `flutter build apk --release` compiles the Kotlin. Not run until approved.
- Device (owner-observed): AMOLED theme with phone in light mode shows dark widgets (P1.1); English app on an Arabic-locale phone shows English day names (P1.4); next-task widget with a task but no id opens the Tasks tab (P1.2, hard to reproduce, source-verified only); daily widget and daily screen show the same item (P2); change the phone date to tomorrow with the app closed — tasks widget shows the empty state (P3).

## Risks

- P1 / P2 / P3 are widget-only; none touches prayer logic, alarms, notification IDs or channels.
- P3 adds a prefs key: if Kotlin and the contract doc drift, the widget stays empty. Mitigated by committing both together.
- A user who relied on the old (wrong) widget item will see a different one after P2.
