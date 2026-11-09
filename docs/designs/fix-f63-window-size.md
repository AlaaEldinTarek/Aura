# Fix: desktop window taller than the screen (F63)

Status: APPROVED (user 2026-11-09, "approve phase F63") · Level C · branch `fix/f63-window-size` · finding `reference/findings.md` F63 · no EGM review

User decisions (2026-11-09): size the window **from the screen** (no fixed size), using the **work area** (without the
taskbar) of the monitor the window opens on, centered there; **never larger than today's 900 × 1400**; the **minimum
size must also fit** the work area at 150% scaling. Remembering size/position: not now (possible separate item).

## Problem
Device VERIFIED (user, Windows at 150% display scaling, 2026-11-09): the window runs past the screen and the top is cut
off, in the branch builds and in the installed MSIX Aura. Code (static): the window size is a fixed logical
`Size(900, 1400)` in two places:
- `main.dart:87` and `:98`: `WindowOptions(size: Size(900, 1400), center: true)` for the hidden `--startup` start and
  the normal start.
- `main_wrapper_screen.dart:447–449`: after a desktop notification popup closes, `setMinimumSize(Size(400, 600))`,
  `setSize(Size(900, 1400))`, `center()`.
A 1920 × 1080 screen at 150% is 1280 × 720 logical (less the taskbar), so a 1400-high window does not fit; at 100% a
1080-high screen does not fit it either.

## Fix
- **Work area** (no new dependency): `window_manager` (direct dependency) exports `calcWindowPosition(size, alignment)`
  (`window_manager-0.3.9/lib/src/utils/calc_window_position.dart`). It picks the display under the mouse cursor
  (fallback: primary) and uses its `visiblePosition` / `visibleSize` (the work area). New async
  `Future<Rect?> currentWorkArea()` in `lib/core/utils/window_size.dart`: top-left corner =
  `calcWindowPosition(Size.zero, Alignment.topLeft)`, bottom-right = `calcWindowPosition(Size.zero,
  Alignment.bottomRight)`; any error or an empty rect → `null`. `screen_retriever` (transitive) is not imported, so no
  `pubspec` change. Units (logical vs physical pixels on Windows): UNVERIFIED; the device check logs the measured area.
- **Size rule** (pure, in the same file), `Size adaptiveWindowSize(Rect? workArea)`:
  - `workArea == null` → `Size(900, 1400)` (today's size; today's `center: true` placement).
  - height = `min(1400, 0.90 × workArea.height)`.
  - width = `min(900, 0.90 × workArea.width, max(height × 900/1400, min(500, 0.90 × workArea.width)))` — keeps the
    app's current shape (0.64), but never narrower than 500 when the work area allows it (desktop-scaling target
    ~500 wide; the sidebar is ~390), never wider than the work area or 900.
  - Never larger than 900 × 1400.
- **Minimum** (pure), `Size fitMinimumSize(Size desiredMin, Size window)`: each side `min(desiredMin, window)`. Used where
  a minimum is set today (popup restore: 400 × 600), so it can never exceed the fitted window. Start-up sets no minimum
  today and still sets none.
- **Placement**: centered on the same monitor's work area: `calcWindowPosition(size, Alignment.center)`, applied with
  `windowManager.setBounds` after the window is ready (start-up) and in the popup restore (replacing `center()`). When
  `currentWorkArea()` is `null`, keep `center: true` / `center()` as today.
- **Where**:
  - `main.dart` desktop block (already guarded): compute `workArea` and `size` before `waitUntilReadyToShow`; use
    `size` in both `WindowOptions`; inside the ready callback (both paths) set the centered bounds. The hidden
    `--startup` path keeps `skipTaskbar` and stays hidden.
  - `main_wrapper_screen.dart` popup restore: `setMinimumSize(fitMinimumSize(Size(400, 600), size))`, then
    `setBounds` centered (or today's `setSize` + `center()` when the work area is unknown).
  - Log once at start-up: `📐 [DESKTOP] Work area: <rect>, window: <size>` (existing `[DESKTOP]` tag).
- Mobile, Kotlin, `_desktopTextScale`, prefs keys, translations and `pubspec.*` are untouched.

## Tests (written first; new `test/core/utils/window_size_test.dart`)
Pure functions only (`currentWorkArea()` and the plugin calls need a real display):
- `adaptiveWindowSize(null)` → 900 × 1400.
- 1080p at 150%, work area 1280 × 672 → height 604.8, width 500 (shape would give 388.8, raised to the 500 floor).
- 1080p at 100%, work area 1920 × 1032 → height 928.8, width ≈ 597.1 (shape).
- 1440p at 100%, work area 2560 × 1392 → height 1252.8, width ≈ 805.4.
- 4K at 100%, work area 3840 × 2112 → 900 × 1400 (cap).
- Narrow work area 520 × 900 → width 468 (0.9 × 520; the 500 floor cannot exceed the work area).
- Results never exceed 900 × 1400 or 90% of the work area (checked for all cases above).
- `fitMinimumSize(400 × 600, 500 × 604.8)` → 400 × 600; `fitMinimumSize(400 × 600, 468 × 540)` → 400 × 540.

## File boundary
- Production: new `lib/core/utils/window_size.dart`; `lib/main.dart` (desktop window block);
  `lib/features/main/main_wrapper_screen.dart` (popup restore lines only).
- Test (new): `test/core/utils/window_size_test.dart`.
- Docs: `.project-docs/reference/findings.md` (F63), `.project-docs/reference/device-checklist.md` (new S39),
  `.project-docs/modules/desktop-scaling.md`, `.project-docs/modules/desktop.md`, `.project-docs/STATE.md`,
  `.project-docs/log/<date>.md`, `lib/core/utils/README.md`, `lib/features/main/README.md`.

## Verification
- `flutter test`, `flutter analyze` (0 new vs base), `dart format` on new files; release APK build (no Android change)
  and Windows release build.
- Device, new **S39** (Windows, unpackaged release exe, 150% scaling):
  1. Launch → the log shows `📐 [DESKTOP] Work area …, window …`; the whole window is inside the work area (title bar
     visible, bottom above the taskbar), centered, never larger than 900 × 1400. Record the logged numbers (they also
     settle the logical/physical question).
  2. Layout readable at that size (sidebar and content not clipped); resize and maximize still work.
  3. Optional: 100% scaling, same check. Optional: a desktop notification popup (e.g. task reminder 1 min ahead); after
     it closes, the restored window also fits and is centered.
- Record results in the device checklist and log. Do not mark PASS unless the check ran.

## Commits
1. `window_size.dart` (pure rules + `currentWorkArea`) + tests (no caller).
2. `main.dart` and the popup restore use it.
3. Docs.
