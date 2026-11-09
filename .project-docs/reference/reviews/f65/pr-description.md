# F65: compact desktop sidebar on narrow windows

Spec: `docs/designs/fix-f65-sidebar.md` (approved 2026-11-09, threshold 800). Finding fixed: F65. PR #11, merged to main
(5d37798).

## What changes
- The desktop sidebar was a fixed 260 px, about 44% of the 597-px default window from F63.
- New `DesktopShellLayout` (`lib/features/main/desktop_shell_layout.dart`), `kCompactSidebarBelow = 800`,
  `useCompactSidebar(windowWidth)`:
  - Below 800 px: a 72-px icon rail; ☰ opens the full 260-px sidebar as an overlay from the start edge (left LTR, right
    RTL) with a scrim. Content keeps its size and tree position. The overlay closes on scrim tap, item select, its toggle,
    `Esc`, or the window becoming wide. Open state in memory only (no prefs).
  - 800 px and above: today's inline sidebar (260 / 72 via the user toggle).
- `_DesktopShellState.build` hands the layout to `DesktopShellLayout`; `_DesktopSidebar` and the content pane (scale
  Theme, MediaQuery, nested Navigator) are passed in unchanged. An item tap still pops to the first route and switches
  tab, then closes the overlay. `desktopTextScale` still reads `MediaQuery.size` (window), so the item scale is unchanged.

## Commits
| # | Commit |
| --- | --- |
| 1 | 49ec374 Add F65 desktop sidebar spec (also logs 4701f7c) |
| 2 | 8d7650f Add desktop shell layout with compact icon rail (F65) |
| 3 | 2f46d25 Use the compact sidebar layout in the desktop shell (F65) |

The usual docs commit was not part of the PR; it was added on main after the merge (this description, findings F65,
device-checklist S41, STATE, log). No prefs key, translation, Kotlin or `pubspec.*` changes.

## Verification (run post-merge on main (5d37798))
- `flutter test`: 234 pass (incl. 8 in `test/features/main/desktop_shell_layout_test.dart`: 800 threshold, compact LTR
  (overlay does not move content), item tap and `Esc` close the overlay, compact RTL, wide inline toggle, overlay closes
  when the window becomes wide, sidebar hidden, item scale the same with rail, inline sidebar and overlay). Scrim tap has
  no test.
- `flutter analyze`: 418 issues, 0 errors, 0 new vs base (none in the F65 files).
- `dart format`: the two new files clean; `main_wrapper_screen.dart` was already unformatted at base 4701f7c.

## Device check S41
| Device | Result |
| --- | --- |
| Windows (unpackaged release, 150%): narrow/wide, overlay, `Esc`, maximize, Arabic, App Tour | Pending (not run) |
| Phone (release APK) regression | Pending (not run) |

🤖 Generated with [Claude Code](https://claude.com/claude-code)
