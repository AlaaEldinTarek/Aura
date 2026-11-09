# F64: put the app tour frame on its target on desktop

Spec: `docs/designs/fix-f64-tour-highlight.md` (approved 2026-11-09, option B). Finding fixed: F64.

## What changes
- On desktop the tour is drawn in the content pane's overlay (right of the sidebar), but `TutorialOverlay` measured the
  target in window coordinates and placed the tooltip with the window height. The frame was shifted by the sidebar
  width (and any header offset), and the tooltip could overlap its target.
- `TutorialOverlay.build` now measures in the overlay the tour is drawn in: `localToGlobal(ancestor: overlay box)` for
  the frame, and the overlay's size for the painter and the tooltip's above/below placement. Falls back to today's
  values if the overlay box is unavailable.
- Option A (root overlay, which would also dim the sidebar) was not chosen: the tooltip would lose the desktop text
  scale. Mobile: the overlay is the whole window, so results are unchanged. All 7 tour callers are untouched.

## Commits
| # | Commit |
| --- | --- |
| 1 | 4684ed0 Add F64 tour highlight spec (also logs 110cf3b) |
| 2 | bf70e93 Place the tour frame and tooltip in the overlay's coordinates (F64) |
| 3 | docs commit (findings F64/F65, S40, widgets README, STATE, log, this description) |

No prefs key, translation, Kotlin or `pubspec.*` changes.

## Verification
- `flutter test`: 226 pass (+6 new in `test/core/widgets/tutorial_overlay_test.dart`: desktop LTR, desktop RTL, tooltip
  at the sidebar edge, target near the pane bottom, mobile-like single overlay, Skip). Before the fix 3 failed: LTR
  frame at (230, 140) instead of (30, 40); RTL 100 px too low; tooltip overlapping a target near the pane bottom.
- `flutter analyze`: 418 issues, 0 new vs base.

## Device check S40 (2026-11-09)
| Device | Result |
| --- | --- |
| Windows (unpackaged release): Home tour, maximized (icon-only sidebar), Prayer "Prayer Cards", Arabic (sidebar on the right) | PASS: frame on each target, tooltip inside the pane |
| Phone (release APK) | PASS: frames on target as before |

## Known issue, not caused by this fix
- **F65 (MEDIUM):** the desktop sidebar is a fixed 260 px, about 44% of the narrower default window from F63. Next item.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
