# Windows adaptive scaling
Relocated from CLAUDE.md on 2026-11-06; not yet re-verified (Step 2). Parent: desktop.md.
Goal: UI looks good at any window size (~500×800 to maximized 1920×1080+).

## Scale calculation (`lib/features/main/main_wrapper_screen.dart`, `_DesktopShellState`)
```dart
double _desktopTextScale(double w, double h) =>
    (w / 500 * 0.7 + h / 1556 * 0.3).clamp(0.9, 3.0);
```

## How it's applied (inside a `LayoutBuilder` in the desktop shell)
```dart
Theme(
  data: baseTheme.copyWith(
    visualDensity: VisualDensity(horizontal: density, vertical: density), // density = ((scale-1)*2.0).clamp(-4,2)
    iconTheme: baseTheme.iconTheme.copyWith(size: iconSize),              // iconSize = scale * 24
    chipTheme: baseTheme.chipTheme.copyWith(padding: EdgeInsets.symmetric(horizontal: chipPadH, vertical: chipPadV)),
    listTileTheme: baseTheme.listTileTheme.copyWith(contentPadding: ..., minVerticalPadding: ...),
    cardTheme: baseTheme.cardTheme.copyWith(margin: ...),
  ),
  child: MediaQuery(data: mq.copyWith(textScaler: TextScaler.linear(scale)), child: Navigator(...)),
)
```

## Universal rule — `ts.scale(n)` for every fixed pixel value
```dart
final ts = MediaQuery.textScalerOf(context);
final sz = ts.scale(48.0);   // scales with window size automatically
```
- Text scales automatically (`TextScaler.linear(scale)` in `MediaQuery`); icons via `iconTheme.size` (no explicit
  `size:` needed on most `Icon()`); Material padding via `VisualDensity`.
- Any hard-coded `width/height/padding/fontSize` that should scale must use `ts.scale()`.
- No artificial upper clamps unless needed for layout integrity (e.g. gaps that would become absurdly large).

## Patterns
- `Builder` inside `const` trees to get `textScaler`:
  `Builder(builder: (ctx) { final ts = MediaQuery.textScalerOf(ctx); return Container(width: ts.scale(48), ...); })`
- Fixed-size containers (e.g. prayer circle): wrap content in `FittedBox(fit: BoxFit.scaleDown)` so it shrinks instead
  of overflowing: `SizedBox(width: sz * 0.68, height: sz * 0.68, child: FittedBox(fit: BoxFit.scaleDown, child: Column(...)))`.
- TabBar height must scale or tabs get too thin:
  `PreferredSize(preferredSize: Size.fromHeight(MediaQuery.textScalerOf(context).scale(kTextTabBarHeight).clamp(kTextTabBarHeight, 80.0)), ...)`
- Home screen gaps scale but clamp to avoid excess whitespace:
  `gapL = ts.scale(AppConstants.paddingLarge).clamp(0.0, 28.0)`; `gapM = ts.scale(AppConstants.paddingMedium).clamp(0.0, 18.0)`.

## Islamic Events screen (`lib/features/islamic_events/islamic_events_screen.dart`)
- Always single-column `ListView` (no desktop 2-column layout). Cards scale via `ts.scale()` on padding and chip sizes.
- Emoji chips: square container; size and emoji font scale together with caps so the emoji fits:
  `chipSz = ts.scale(48.0).clamp(48.0, 72.0)`; `emojiFz = ts.scale(26.0).clamp(20.0, 38.0)`.
- Do NOT use `IntrinsicHeight` + `CrossAxisAlignment.stretch` for emoji chips (chip becomes huge, emoji overflows).
