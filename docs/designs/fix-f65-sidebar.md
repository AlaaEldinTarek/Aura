# Fix: desktop sidebar takes almost half of a narrow window (F65)

Status: APPROVED (user 2026-11-09, "approve phase F65, threshold 800" + scale-unchanged confirmation and test) · Level C · branch `fix/f65-sidebar` · finding `reference/findings.md` F65 · no EGM review

User decisions (2026-11-09): option 1 — icon-only sidebar below a window-width threshold; ☰ expands it **as an
overlay over the content** (the content does not move or resize); **no new prefs keys** (the expanded state is not
remembered); Arabic (sidebar on the right) in tests and the device check.

## Problem
Device VERIFIED (user screenshot 2026-11-09 14:19, Windows 150%, window 597 × 929 logical): the expanded sidebar is
~260 of ~585 px (~44%). Code (static): `_DesktopShellState.build` (`main_wrapper_screen.dart:1355–1440`) lays out a `Row`:
`AnimatedContainer(width: _sidebarCollapsed ? 72 : 260)` with `_DesktopSidebar` (collapsed look when its width < 166),
a 1-px divider, then the content pane (`Expanded`, nested `Navigator`). Only the ☰ toggle collapses it
(`_sidebarCollapsed`, memory only). The width is not tied to the window, so the narrower default window from F63 exposes
it (at the old 900-px default it was ~29%).

## Threshold: 800 logical px
- Expanded sidebar + divider = 261 px. The content pane needs about 540 px to stay readable (desktop-scaling target
  ~500 wide, plus card padding). 261 + 540 ≈ **800**.
- Below 800 the expanded sidebar would take more than a third of the window and leave the content under ~540 px.
- On the test PC: default window 597 → compact (content 524 px instead of 336); maximized 1920 → wide (as today).
- One named constant (`kCompactSidebarBelow = 800.0`), measured on the shell's full window width (logical px).

## Item scale is unchanged (user requirement)
- `desktopTextScale` reads the **window** size, not the content pane: `MediaQuery.of(ctx).size` inside the content's
  `LayoutBuilder` (`main_wrapper_screen.dart:1395–1396`); the builder's `constraints` (pane size) are not used. Code
  VERIFIED. The sidebar width never changes `MediaQuery.size`.
- So for the same window size the scale is identical with the 72-px rail, the 260-px inline sidebar or the overlay. The
  content pane builder (scale `Theme` + `MediaQuery` + `Navigator`) is moved unchanged.
- `DesktopShellLayout` takes an optional `compactBelow` (default `kCompactSidebarBelow`) so a test can force today's
  inline layout (`compactBelow: 0`) at the same window width as the rail layout.

## Fix
- New `lib/features/main/desktop_shell_layout.dart` (public, testable without Firebase):
  - `bool useCompactSidebar(double windowWidth) => windowWidth < kCompactSidebarBelow;`
  - `DesktopShellLayout` widget with `sidebarVisible`, `userCollapsed`, `onToggleCollapsed`,
    `Widget Function(bool collapsed, VoidCallback onToggle, VoidCallback onItemSelected) sidebarBuilder`, `content`,
    `dividerColor`. It owns only the in-memory `_overlayOpen` flag.
  - **Wide (≥ 800):** exactly today's layout: inline sidebar `AnimatedContainer` 260 / 72 driven by `userCollapsed`
    and the ☰ toggle, divider, content `Expanded`. Opening the overlay is not possible here.
  - **Compact (< 800):** inline 72-px icon rail (the collapsed sidebar) + divider + content `Expanded`. ☰ in the rail
    opens the **expanded sidebar (260 px) as an overlay** in a `Stack` above the content, anchored to the start edge
    (`PositionedDirectional(start: 0)`: left in English, right in Arabic), with a scrim over the rest. The content keeps
    its size and position.
  - **Overlay closes** on: tapping the scrim, tapping a sidebar item (after navigating), the ☰ in the expanded
    header, `Esc`, or the window becoming wide (≥ 800). Not remembered (no prefs).
  - `sidebarVisible == false` (Quran reader): no rail, no overlay, content full width (as today).
- `_DesktopShellState.build`: replace the `Row` with `DesktopShellLayout`, passing today's `_DesktopSidebar`
  (unchanged widget; its existing `collapsed` look is used for the rail and the expanded look for the overlay) and the
  existing content pane (scale `Theme` + `MediaQuery` + nested `Navigator`, unchanged). The sidebar's item tap keeps
  today's `popUntil(first)` + `onTap(index)`, then closes the overlay.
- Unchanged: `desktopTextScale` (still from the whole window size), the F64 tour (it uses the content pane's overlay),
  sidebar items and app-mode rules, mobile layout, translations (no new strings), prefs keys, Kotlin, `pubspec.*`.

## Tests (written first; new `test/features/main/desktop_shell_layout_test.dart`)
Widget tests with a fake `sidebarBuilder` (a `Container` that shows "rail" or "full" and has item buttons), a fake
content (a keyed `Container`), and window sizes set through `tester.view`:
- `useCompactSidebar(799)` true, `useCompactSidebar(800)` false.
- Compact, LTR, window 597: the rail is 72 px at the left; content width = 597 − 73. Tap ☰ → "full" sidebar 260 px
  appears at the left over the content; the content rect is unchanged (not pushed). Tap the scrim → closed.
- Compact: open, tap an item → `onItemSelected` fired and the overlay closed. Open, press `Esc` → closed.
- Compact, **RTL**: the rail is at the right edge; the opened overlay's right edge equals the window's right edge;
  content unchanged.
- Wide, LTR, window 1200: inline "full" sidebar 260 px; ☰ (via `onToggleCollapsed` / `userCollapsed`) gives the 72-px
  inline rail and the content widens (today's behavior). No overlay.
- Overlay open, window resized to 1200 → overlay gone, wide layout shown.
- `sidebarVisible: false` → no rail, no overlay, content full width.
- **Scale unchanged:** the fake content records `desktopTextScale(MediaQuery.size)`. At window 597 × 929: compact rail
  layout vs today's inline expanded layout (`compactBelow: 0`) → the same scale (≈ 1.19); also with the overlay open →
  the same scale.

## File boundary
- Production: new `lib/features/main/desktop_shell_layout.dart`; `lib/features/main/main_wrapper_screen.dart`
  (`_DesktopShellState.build` sidebar layout only; `_DesktopSidebar` unchanged).
- Test (new): `test/features/main/desktop_shell_layout_test.dart`.
- Docs: `.project-docs/reference/findings.md` (F65), `.project-docs/reference/device-checklist.md` (new S41),
  `.project-docs/modules/desktop-scaling.md`, `.project-docs/modules/desktop.md`, `.project-docs/STATE.md`,
  `.project-docs/log/<date>.md`, `lib/features/main/README.md`.

## Verification
- `flutter test`, `flutter analyze` (0 new vs base), `dart format` on new files; release APK (desktop-only change) and
  Windows release builds.
- Device, new **S41** (Windows, unpackaged release, 150%):
  1. Default window (597 wide): icon rail only; content uses the rest.
  2. ☰ → full sidebar slides over the content (content does not move); pick an item → navigates and closes; open again
     → click outside → closes; open again → `Esc` → closes.
  3. Drag the window wider than 800 → full inline sidebar as today; ☰ collapses / expands it inline. Narrower than 800
     again → icon rail.
  4. Maximize → full inline sidebar.
  5. Arabic: repeat 1–3 with the sidebar on the right (overlay opens from the right); restore English.
  6. App tour (F64) still on target in the compact layout.
- Phone: release APK installs and runs unchanged (regression).
- Record results in the device checklist and log. Do not mark PASS unless the check ran.

## Commits
1. `desktop_shell_layout.dart` + tests (no caller).
2. `_DesktopShellState` uses `DesktopShellLayout`.
3. Docs.
