# Fix: app tour highlight shifted on desktop (F64)

Status: APPROVED (user 2026-11-09, "approve phase F64, option B" + RTL test/check + tooltip uses overlay size) · Level C · branch `fix/f64-tour-highlight` · finding `reference/findings.md` F64 · no EGM review

## Problem
Device VERIFIED (user screenshots 2026-11-09 09:54 and 13:12, Windows): the tour's yellow frame sits to the right of its
target by about the sidebar width (full and icon-only sidebar) and is clipped at the right edge.

Cause (code VERIFIED):
- `showTutorial` inserts the tour into `Overlay.of(context)` (`tutorial_overlay.dart:339`). On desktop the nearest
  overlay is the shell's nested content navigator (`main_wrapper_screen.dart`, `_DesktopShell`), which starts right of
  the sidebar.
- `TutorialOverlay.build` computes the frame in **window** coordinates: `box.localToGlobal(Offset.zero) & box.size`
  (`:90–94`), and paints it inside that overlay with `size: screenSize` (`MediaQuery` window size, `:88, :125`).
- So the frame is drawn shifted by the overlay's own offset (the sidebar width). On mobile the overlay starts at (0, 0),
  so window and overlay coordinates are the same (not affected).
- Callers (7): `home_screen.dart:184`, `prayer_screen.dart:116`, `quran_reader_screen.dart:131`,
  `quran_screen.dart:73, :99`, `wird_tab.dart:116`, `tasks_screen.dart:100` — all go through `showTutorial`, so one fix
  covers every tour.

## Options considered
- **A. Root overlay** (`Overlay.of(context, rootOverlay: true)`): coordinates match and the sidebar is dimmed too, but the
  tour leaves the content pane's `MediaQuery` that carries the desktop text scale (`desktopTextScale`), so on desktop the
  tooltip text would render at 1.0× instead of the window scale (a visible change). Not chosen.
- **B. Same overlay, overlay coordinates (chosen):** compute the frame relative to the overlay the tour is drawn in.
  Only the bug changes; the tooltip, dimming area and scale stay as today.

## Fix (B)
- `TutorialOverlay.build`: get the overlay's render box (`Overlay.of(context).context.findRenderObject() as RenderBox?`)
  and compute `targetRect = box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size`; if the overlay box is not
  available, fall back to today's global rect.
- **Tooltip placement uses the overlay's size, not the window's** (user requirement): the painter size and the tooltip's
  above/below decision and vertical clamp (`:100–104`, today `MediaQuery` window height) use the overlay box's size
  (fallback: today's `MediaQuery` size). Horizontally the tooltip is already laid out inside the overlay's `Stack`
  (`Positioned(left: 0, right: 0)` + `Center`), so it stays inside the pane.
- RTL (Arabic): the desktop sidebar is on the right and the pane starts at x = 0, so today the horizontal offset happens
  to be 0; the overlay-relative rect keeps that correct (covered by a test and S40).
- Unchanged: the scroll-into-view check in `showTutorial` (`:292–312`; it compares window coordinates with the window
  size, which is consistent), the tooltip layout and text, step order, prefs flags, and all 7 callers.
- Mobile: overlay at (0, 0) and the same size as the window → identical result.

## Tests (written first; new `test/core/widgets/tutorial_overlay_test.dart`)
Widget test with a desktop-like layout: a `Row` with a 200-px-wide sidebar and an `Expanded` nested `Navigator`; inside it
a target `Container` (GlobalKey) at a known position. Call `showTutorial` with a context inside the nested navigator,
pump, and read the frame from the overlay's `CustomPaint` painter (`targetRect`):
- The frame equals the target's rect **in the nested overlay's coordinates** (left = target's x inside the pane, not
  200 + x). Fails on today's code (left is 200 px too far).
- RTL layout (sidebar on the right, `Directionality(rtl)`): the frame equals the target's rect in the pane's coordinates.
- Tooltip near the sidebar edge: target at the pane's left edge, and a second case with the target near the pane's
  bottom: the tooltip's rect lies fully inside the pane (left ≥ pane left, right ≤ pane right, top ≥ pane top,
  bottom ≤ pane bottom), and in the bottom case it is placed above the target.
- Single-overlay layout (no sidebar, mobile-like): the frame equals the target's window rect (unchanged behavior).
- Tapping "Skip" removes the tour and calls `onDone` (regression).

## File boundary
- Production: `lib/core/widgets/tutorial_overlay.dart` (`TutorialOverlay.build` only).
- Test (new): `test/core/widgets/tutorial_overlay_test.dart`.
- Docs: `.project-docs/reference/findings.md` (F64), `.project-docs/reference/device-checklist.md` (new S40),
  `.project-docs/STATE.md`, `.project-docs/log/<date>.md`, `lib/core/widgets/README.md`.
- Not touched: the 7 callers, `main_wrapper_screen.dart`, translations, prefs keys (tutorial flags), Kotlin, `pubspec.*`.

## Verification
- `flutter test`, `flutter analyze` (0 new vs base), `dart format` on new files; release APK and Windows release builds.
- Device, new **S40**:
  - Windows (unpackaged release): Profile → App Tour → each Home step: the frame sits exactly on its target, with the full
    sidebar and with the icon-only sidebar (maximized); also the Prayer tour step "Prayer Cards"; tooltip inside the
    pane. Then switch to **Arabic** (sidebar on the right) and repeat the Home tour; restore English.
  - Phone (release APK): App Tour → frames on target as before (regression).
- Record results in the device checklist and log. Do not mark PASS unless the check ran.

## Commits
1. Test (desktop-like layout) + fix in `TutorialOverlay.build`.
2. Docs.
