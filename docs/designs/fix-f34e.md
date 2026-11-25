# Fix F34e — Desktop popup unmounts shell

**Status:** Approved for code (phase P1)  
**Branch:** `fix/f34e` (to be created from main)  
**Finding:** F34e (LOW)  
**Files touched:**
- `lib/features/main/main_wrapper_screen.dart`

---

## Problem

`_MainWrapperScreenState.build()` returns early when
`_isDesktop && _activePopup != null && _popupAnimCtrl != null`
(lines 1195–1317). The early return produces a bare `Scaffold` that
contains only the popup widget — it completely replaces the normal
widget tree. This unmounts `_DesktopShell` and its nested Navigator
every time a desktop notification popup appears, losing:

- pushed sub-routes (e.g. prayer-detail, task-detail)
- sidebar collapse state held by `_DesktopShellState`
- any ephemeral state in the five page-view children

---

## Fix

Extract the popup widget into a local variable and overlay it on top of
the normal shell using `Stack` + `Align`, instead of returning it early.

**Before** (abbreviated):

```dart
if (_isDesktop && _activePopup != null && _popupAnimCtrl != null) {
  // ... build popup variables ...
  return Scaffold(          // ← replaces the whole tree
    backgroundColor: bgColor,
    body: SlideTransition(
      position: slideAnim,
      child: Container(/* popup UI only */),
    ),
  );
}

// ... continues to build normal shell ...
return PopScope(child: _isDesktop ? _DesktopShell(...) : Scaffold(...));
```

**After**:

```dart
// 1. Build popup overlay widget (or null) — no early return
Widget? popupOverlay;
if (_isDesktop && _activePopup != null && _popupAnimCtrl != null) {
  // ... same popup variable setup (unchanged) ...
  popupOverlay = Align(
    alignment: Alignment.bottomRight,
    child: SizedBox(
      width: 360,
      child: SlideTransition(
        position: slideAnim,
        child: Container(/* same popup UI, unchanged */),
      ),
    ),
  );
}

// 2. Build normal shell (always)
final appMode = ref.watch(appModeProvider);
// ... rest of build unchanged ...
final shell = PopScope(
  canPop: false,
  onPopInvoked: (didPop) async { ... },
  child: _isDesktop
      ? _DesktopShell(...)
      : Scaffold(...),
);

// 3. Overlay popup if active
if (popupOverlay != null) {
  return Stack(children: [shell, popupOverlay]);
}
return shell;
```

The popup UI code (Container decoration, Column children, buttons) is
**unchanged** — only its mount point changes from a top-level `Scaffold`
to an `Align`+`SizedBox` overlay inside a `Stack`.

The `Scaffold` wrapper around the popup is removed because the shell's
own `Scaffold` (via `_DesktopShell`) already provides Material context.
`bgColor` was the `Scaffold.backgroundColor`; with the overlay approach
it becomes the `Container`'s `color` property (already set via
`BoxDecoration` or added explicitly).

---

## Contract check

| Contract | Verdict |
|----------|---------|
| SharedPreferences key names | Unchanged |
| Firestore paths | Unchanged |
| Notification IDs / channels | Not involved |
| Popup behaviour (dismiss, Prayed, Stop Adhan) | Unchanged |
| `_DesktopPopupInfo` model | Unchanged |
| New keys introduced | None |

---

## Tests

Source-text test (1 test, file `test/features/main/f34e_source_test.dart`):

- **T1**: `main_wrapper_screen.dart` does NOT contain
  `return Scaffold` inside the desktop-popup block — specifically,
  the string `'if (_isDesktop && _activePopup'` appears in the file
  but `'return Scaffold'` does NOT appear between that guard and the
  next `'final appMode'` line.

---

## Device check

| ID | Description |
|----|-------------|
| S-F34e-1 | On Windows: trigger a desktop prayer-time popup. While the popup is showing, verify the sidebar and app content (previous page, sidebar expanded state) are still visible underneath — no blank white/dark screen replacing the shell. Dismiss the popup; verify the shell state is preserved. |
