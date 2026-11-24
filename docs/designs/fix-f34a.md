# Fix F34a — Swipe reaches hidden tabs in restricted app modes

**Status:** Approved for code (phase P1)  
**Branch:** `fix/f34a` (to be created from main)  
**Finding:** F34a (MEDIUM)  
**Files touched:**
- `lib/features/main/main_wrapper_screen.dart`

---

## Problem

In `tasksOnly` and `prayerOnly` modes the bottom nav bar hides tabs the user has not enabled, but the mobile `PageView` still allows horizontal swiping to any of the five pages.

- `PageView.physics` is `NeverScrollableScrollPhysics()` only on desktop (`_isDesktop`); on mobile it is `null` (default scroll physics).
- `appMode` gates only the visible `BottomNavigationBarItem`s (in `AuraBottomNavBar`), not the PageView swipe.
- Result: a user in `tasksOnly` mode can swipe left from Home and land on the Prayer tab, which their account has disabled.

**Location:** `main_wrapper_screen.dart:1305–1308`

---

## Fix

Read `appModeProvider` once in `_MainWrapperScreenState.build()` and extend the `NeverScrollableScrollPhysics` guard to cover any mode where tabs are hidden (`appMode != AppMode.both`).

```dart
// Before
final pageView = PageView(
  controller: _pageController,
  physics: _isDesktop ? const NeverScrollableScrollPhysics() : null,
  ...
);

// After
final appMode = ref.watch(appModeProvider);
...
final pageView = PageView(
  controller: _pageController,
  physics: (_isDesktop || appMode != AppMode.both)
      ? const NeverScrollableScrollPhysics()
      : null,
  ...
);
```

`_handleTabTap` / `_pageController.jumpToPage` are unaffected — programmatic navigation still works.  
No behavior change in `AppMode.both` (the default; all five tabs visible).

---

## Contract check

| Contract | Verdict |
|----------|---------|
| SharedPreferences key names | Unchanged |
| Firestore paths | Not involved |
| Notification IDs / channels | Not involved |
| `appModeProvider` / `AppMode` enum | Read-only; not modified |
| New keys introduced | None |

---

## Tests

Source-text test (1 test, file `test/features/main/f34a_source_test.dart`):

- **T1**: the PageView `physics` line contains the `appMode != AppMode.both` guard.

---

## Device check

| Step | Description |
|------|-------------|
| S67 | In Settings, switch app mode to Tasks Only. Return to Home. Swipe horizontally — no tab change should occur. Switch back to Both, verify swipe works again. |
