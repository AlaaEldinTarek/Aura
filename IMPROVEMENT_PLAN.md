# Aura App — UI/UX & Performance Improvement Plan

Generated: 2026-05-04  
Total items: 22 (from audit of 26 raw findings, 4 merged/skipped as non-applicable)

**Rule before each step**: Estimate token cost. If context is running low, STOP and note resume point.

---

## Priority Order

### 🔴 HIGH IMPACT (do first)

- [ ] **#1** — `home_screen.dart:119` — Use `select()` on all 6 provider watches to stop full-screen rebuilds on every prayer tick
- [ ] **#2** — `home_screen.dart:46` — Pause `Timer.periodic` countdown when app is backgrounded (AppLifecycleState)
- [ ] **#6** — `task_card.dart:298` — Add `movementDuration` + `AnimatedSize` to Dismissible swipe animation
- [ ] **#10** — `profile_screen.dart:38` — Shimmer skeleton instead of blank spinner during profile load
- [ ] **#13** — `tasks_screen.dart` — Empty state widget with CTA when user has zero tasks
- [ ] **#14** — `home_screen.dart:1022` — Loading feedback when marking prayer from home screen
- [ ] **#25** — `task_form_screen.dart` — Wrap form body in `SingleChildScrollView` to prevent overflow on small screens

### 🟡 MEDIUM IMPACT (do second)

- [ ] **#3** — `wird_tab.dart:110` — Convert `ListView(children:[])` to `ListView.builder()`
- [ ] **#5** — `main_wrapper_screen.dart:752` — Move `taskWidgetSyncProvider` watch down to child widget
- [ ] **#7** — `tasks_screen.dart:395` — `AnimatedSwitcher(300ms)` between loading spinner and task list
- [ ] **#8** — `home_screen.dart:999` — `AnimatedOpacity`/`AnimatedSize` on completed task removal
- [ ] **#9** — `tasks_screen.dart:197` — `AnimatedCrossFade` on search/calendar visibility toggle
- [ ] **#12** — `prayer_screen.dart:119` — 5 shimmer prayer cards while prayer times load
- [ ] **#15** — `main_wrapper_screen.dart:317` — "All caught up" snackbar after last untracked prayer resolved
- [ ] **#16** — `bottom_nav_bar.dart:139` — `AnimatedScale` pulse on nav badge count increase
- [ ] **#22** — `main_wrapper_screen.dart:220` — Null-safe `?.isEmpty ?? true` on prayer times check
- [ ] **#23** — `home_screen.dart:449` — `Directionality` wrapper on prayer card rows for RTL Arabic
- [ ] **#24** — `task_card.dart:332` — `Directionality` on horizontal scroll action bar for RTL

### 🟢 LOW IMPACT (do last)

- [ ] **#11** — `quran_screen.dart:88` — 10-row shimmer placeholder for surah list
- [ ] **#17** — `task_card.dart:245` — Move hardcoded `'#'` tag prefix to `AppConstants.tagPrefix`
- [ ] **#18** — `home_screen.dart:338,703` — Extract duplicated prayer name dict to `getPrayerDisplayName()` util
- [ ] **#19** — Core widgets + feature screens — Add `const` constructors to all eligible stateless widgets

---

## Progress Log

| Step | Item | Status | Session |
|------|------|--------|---------|
| 1 | #1 HomeScreen select() | ✅ done | session-1 |
| 2 | #2 Timer lifecycle pause | ✅ done | session-1 |
| 3 | #6 TaskCard Dismissible animation | ✅ done | session-1 |
| 4 | #10 Profile shimmer | ✅ done | session-2 |
| 5 | #13 Tasks empty state | ✅ done (already existed) | session-1 |
| 6 | #14 Prayer marking feedback | ✅ done | session-1 |
| 7 | #25 TaskForm scroll | ✅ done (already ListView) | session-1 |
| 8 | #3 WirdTab ListView.builder | ⬜ pending | — |
| 9 | #5 taskWidgetSync watch move | ⬜ pending | — |
| 10 | #7 TasksScreen AnimatedSwitcher | ✅ done | session-1 |
| 11 | #8 HomeScreen task removal anim | ✅ done | session-2 |
| 12 | #9 TasksScreen search/cal anim | ✅ done | session-1 |
| 13 | #12 PrayerScreen shimmer | ✅ done (already existed) | session-2 |
| 14 | #15 All caught up toast | ✅ done | session-1 |
| 15 | #16 NavBar badge animation | ✅ done | session-1 |
| 16 | #22 Null-safe prayer check | ✅ done (already safe) | session-1 |
| 17 | #23 Prayer card RTL | ✅ done (Flutter handles automatically) | session-2 |
| 18 | #24 TaskCard RTL scroll | ✅ done (Flutter handles automatically) | session-2 |
| 19 | #11 Surah shimmer | ✅ done | session-2 |
| 20 | #17 Tag prefix constant | ✅ done | session-1 |
| 21 | #18 Prayer name util | ✅ done | session-1 |
| 22 | #19 const constructors | ✅ done | session-2 |

---

## Token Budget Rule

Before starting each step, check estimated context usage:
- Each file read ≈ 500–2000 tokens depending on size
- Each edit response ≈ 300–800 tokens
- Build output ≈ 200 tokens
- **Stop threshold**: if estimated remaining context < 8,000 tokens, stop and record resume point below

## Resume Point
_Last completed step_: Step 22 — #19 const constructors  
_Next step_: Steps 8 & 9 still pending (#3 WirdTab ListView.builder, #5 taskWidgetSync watch move) — low priority, optional
