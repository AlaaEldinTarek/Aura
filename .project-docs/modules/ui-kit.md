# UI kit — theme, localization, shared widgets
Relocated from CLAUDE.md on 2026-11-06; not yet re-verified (Step 2). String/numeral/prayer-name rules: CLAUDE.md Rules.

## Theme (`lib/core/theme/app_theme.dart`)
- Material 3; light / dark / AMOLED; optional Material You via `dynamic_color`.
- Visual identity `#F5B301` (bright gold) = `AppConstants.primaryColor`.
- Light: primary `#B5821B`, surfaces `#FFF8EB`/`#FFF3D6`, text `#2A2418`/`#7A6E5A`, border `#E8D5A8`.
- Dark: primary `#F5B301`, surfaces `#111317`/`#1A1B1E`. AMOLED: true black + `#F5B301`.
- Fonts: Cairo (Arabic), Roboto (English).

## Localization
- `easy_localization` 3.0.3; keys in `assets/translations/en.json` + `ar.json` (counts: reference/findings.md).
- Full RTL; AM/PM → ص/م; Arabic-Eastern numerals throughout (`lib/core/utils/number_formatter`, `time_formatter`, `date_formatter`).
- **TextDirection conflict**: `easy_localization` exports `intl`'s `TextDirection`, shadowing Flutter's. Use
  `import 'dart:ui' as ui show TextDirection;` and `ui.TextDirection.rtl` (e.g. Quran reader).
- **Language switching**: `MainWrapperScreen.build()` must call `ref.watch(languageProvider)` — otherwise bottom nav labels
  don't rebuild on locale change.

## Tutorial system (`lib/core/widgets/tutorial_overlay.dart`)
- `showTutorial(context, steps, onDone)` inserts an `OverlayEntry`. `TutorialStep` holds a `GlobalKey` (target),
  `titleKey`, `bodyKey`. Per-screen spotlight overlays; first-visit auto-launch; Profile has a replay button.
- `TutorialOverlay` uses `TickerProviderStateMixin`: fade (300 ms, per step) + pulse (1400 ms repeating).
- `_OverlayPainter` draws: ① dark overlay with `BlendMode.clear` cutout, ② solid border, ③ expanding+fading pulsing ring.
  Cutout radius 20 (larger than the card's 16 to avoid corner gaps).
- Seen flags: `SharedPreferencesService` `isTutorialXSeen()` / `setTutorialXSeen()`. Launch via `addPostFrameCallback`
  after a 900 ms delay. Wird exception: wird.md § tutorial.
- **Home tutorial launch**: `_pendingTutorialLaunch` flag (set by `_onPermissionsDone`) + `_launchTutorialWhenActive()`
  retry loop. Retries when (a) a route is on top, (b) `mounted` is false, (c) something appears during the 800 ms settle
  window. Never silently drops — retries until it launches or `isTutorialCompleted() == true`.

## InfoTipIcon (`lib/core/widgets/info_tip_icon.dart`)
- Persistent ℹ️ tap → `AlertDialog` with translated title/body. Home screen (4 icons) + Prayer screen (2 icons) section
  headers. `Icons.info_outline`, size 18, color `primary.withOpacity(0.6)`.

## Screen patterns
- **HomeScreen timer lifecycle**: `_HomeScreenState` mixes in `WidgetsBindingObserver`; `didChangeAppLifecycleState`
  pauses the `Timer.periodic` countdown in background and resumes in foreground. Use `_startCountdownTimer()` — never
  restart the timer directly.
- **HomeScreen provider scoping**: `ref.watch(provider.select(...))` for `prayerTimesProvider`, `currentUserProvider`,
  `dailyPrayerStatusProvider` to avoid full rebuilds every prayer tick. Follow the same pattern for new watches.

## Shared widgets (`lib/core/widgets/`)
- `bottom_nav_bar`, `prayer_time_card`, `prayer_card`, `prayer_status_dialog`, `task_card`, `shimmer_loading`,
  `info_tip_icon`, `tutorial_overlay`.
