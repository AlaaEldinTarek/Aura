# F63: size the desktop window from the screen; calmer item scale when maximized

Spec: `docs/designs/fix-f63-window-size.md` (approved 2026-11-09; amendment A-1 for the item scale). Finding fixed: F63.

## What changes
- **Window size:** was a fixed logical 900 × 1400 (start-up and after a desktop notification popup), taller than the
  screen at 150% scaling (and on any 1080-high screen at 100%). Now `adaptiveWindowSize(currentWorkArea())`: 90% of the
  work-area height (without the taskbar) of the monitor under the cursor, width keeps the app's 0.64 shape (min 500 when
  it fits), never larger than 900 × 1400, centered on that work area. Unknown work area → 900 × 1400 as before. The
  popup-restore minimum (400 × 600) is capped to the window.
- **Work area** comes from `window_manager`'s public `calcWindowPosition` (no new dependency, no `pubspec` change).
  Centering keeps `center: true` / `center()`, which window_manager implements on the same monitor's work area.
- **Item scale (A-1):** `(w/500 × 0.7 + h/1556 × 0.3).clamp(0.9, 3.0)` made maximized windows ~2.9× (huge). Now
  `desktopTextScale = min(w/500, h/778).clamp(0.9, 1.8)`: default window on the test PC ~1.19, maximized ~1.29.
  Note: at 900 × 1400 the new rule gives 1.8 (old 1.53; the old "1.8×" code comment was wrong, F52o).
- Start-up log: `📐 [DESKTOP] Work area: x,y WxH, window: WxH`.

## Commits
| # | Commit |
| --- | --- |
| 1 | e19b719 Add F63 desktop window size spec |
| 2 | e662ad6 Add desktop window sizing from the work area (F63) |
| 3 | cb94e9c Size the desktop window from the work area at start-up and after popups (F63) |
| 4 | 5c260b4 Log the desktop work area and window size as numbers (F63) |
| 5 | f7ef1d8 Amend F63 spec with desktop item scale rule (A-1) |
| 6 | 5d0c597 Scale desktop items by the limiting window side (F63 A-1) |
| 7 | docs commit (findings F63/F64, S39, desktop docs, READMEs, STATE, log, this description) |

Desktop-only code paths; no Android, Kotlin, `pubspec.*`, prefs key or translation changes.

## Verification
- `flutter test`: 220 pass (+15 new in `test/core/utils/window_size_test.dart`: window sizes for 1080p at 150%,
  1080p / 1440p / 4K at 100%, narrow and offset work areas, unknown area; item scale cases; minimum cap).
- `flutter analyze`: 418 issues, 0 new vs base.

## Device checks (2026-11-09)
| Check | Result |
| --- | --- |
| S39 Windows 150% (screen 2880 × 1620): window size | PASS: log `Work area: 0,0 1920x1032, window: 597x929` (logical px VERIFIED); whole window on screen, centered |
| S39 maximize / resize | PASS: items moderately larger when maximized, nothing clipped; resize smooth |
| Android regression (release APK, data kept) | PASS: normal start-up, settings and prayer alarms kept |

**Not verified on device:** 100% scaling, and the window size after a desktop notification popup closes (both
covered only by the size rule's unit tests).

## Known issue, not caused by this fix
- **F64 (MEDIUM):** on desktop the app tour's highlight frame is shifted right by the sidebar width (tour inserted into
  the content pane's overlay while positions use window coordinates). Separate fix next.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
