# UI kit — theme, localization, shared widgets
Verified against code 2026-11-07 (reference/2026-11-07_DRIFT_REPORT.md). String/numeral/prayer-name rules: CLAUDE.md
Rules. Folder views: `lib/core/theme/README.md`, `lib/core/widgets/README.md`.

## Theme (`lib/core/theme/app_theme.dart`, tokens also in `AppConstants` — duplication F29)
- Material 3; light / dark / AMOLED; optional Material You via `dynamic_color`.
- Visual identity `#F5B301` (bright gold) = `AppConstants.primaryColor`.
- Light: primary `#B5821B`, surfaces `#FFF8EB`/`#FFF3D6`, text `#2A2418` / secondary `#7A6E5A`
  (`AppConstants.lightTextSecondary`), border `#E8D5A8`.
- Dark: primary `#F5B301`, surfaces `#111317`/`#1A1B1E`. AMOLED: true black + `#F5B301`.
- Fonts: theme text is Roboto (`app_typography.dart`); Cairo is applied only via explicit `AppTypography.ar(...)`;
  Quran text uses `UthmanicHafs` (quran-wird.md).

## Localization
- `easy_localization` (`^3.0.3`, lock 3.0.8); keys in `assets/translations/en.json` + `ar.json` (counts: reference/findings.md).
- Full RTL; AM/PM → ص/م; Arabic-Eastern numerals throughout (`lib/core/utils/number_formatter`, `time_formatter`, `date_formatter`).
- **TextDirection conflict**: `easy_localization` exports `intl`'s `TextDirection`, shadowing Flutter's. Use
  `import 'dart:ui' as ui show TextDirection;` and `ui.TextDirection.rtl` (e.g. Quran reader).
- **Language switching**: `MainWrapperScreen.build()` must call `ref.watch(languageProvider)` — otherwise bottom nav labels
  don't rebuild on locale change.

## Tutorial system (`lib/core/widgets/tutorial_overlay.dart`)
- `showTutorial({required context, required steps, required onDone})` inserts an `OverlayEntry`. `TutorialStep` holds a
  `GlobalKey` (target), `titleKey`, `bodyKey`. Per-screen spotlight overlays; first-visit auto-launch.
- `TutorialOverlay` uses `TickerProviderStateMixin`: fade (300 ms, per step) + pulse (1400 ms repeating).
- `_OverlayPainter` draws: ① dark overlay with `BlendMode.clear` cutout, ② solid border, ③ expanding+fading pulsing ring.
  Cutout radius 20 (larger than the card's 16 to avoid corner gaps).
- Flags in `SharedPreferencesService`: Home uses `isTutorialCompleted()` / `setTutorialCompleted()`; other screens use
  `isTutorialXSeen()` / `setTutorialXSeen()` for Prayer, Quran, Tasks, Juz, Bookmarks, Wird, Reader. Launch via
  `addPostFrameCallback` after a 900 ms delay. Wird exception: wird.md § tutorial.
- Profile "App Tour" resets Completed + all Seen flags, switches to tab 0 and sets `showTutorialProvider = true`; Home
  launches immediately (no 900/800 ms delays).
- **Home tutorial launch**: `_pendingTutorialLaunch` flag (set by `_onPermissionsDone`) + `_launchTutorialWhenActive()`
  retry loop. Retries when (a) a route is on top, (b) `mounted` is false, (c) something appears during the 800 ms settle
  window, until it launches or `isTutorialCompleted() == true` (never stops after dispose: F32d).

## InfoTipIcon (`lib/core/widgets/info_tip_icon.dart`)
- Persistent ℹ️ tap → `AlertDialog` with translated title/body. `Icons.info_outline`, size `ts.scale(18)`, color
  `AppConstants.getPrimary(isDark).withOpacity(0.7)`. Used on Home (4), Prayer screen (2 + inside `PrayerCard` before the
  window opens) and the Wird tab.

## Screen patterns
- **HomeScreen timer lifecycle**: `_HomeScreenState` mixes in `WidgetsBindingObserver`; `didChangeAppLifecycleState`
  pauses the `Timer.periodic` countdown on `paused` and `inactive` and resumes in foreground (desktop focus loss:
  F52k). Use `_startCountdownTimer()` — never restart the timer directly.
- **HomeScreen provider scoping**: `ref.watch(provider.select(...))` for `prayerTimesProvider`,
  `dailyPrayerStatusProvider`, `guestModeProvider`, `appModeProvider` (`currentUserProvider` is watched without select).
  Follow the select pattern for new watches.

## Shared widgets (`lib/core/widgets/`, 20 files)
- `app_card`, `aura_button`, `aura_card`, `aura_chip`, `bottom_nav_bar`, `circular_countdown`, `desktop_location_dialog`,
  `empty_state`, `greeting_widget`, `info_tip_icon`, `offline_banner`, `permission_dialog`, `prayer_card`,
  `prayer_status_dialog`, `prayer_time_card`, `setting_tile`, `share_card`, `shimmer_loading`, `task_card`,
  `tutorial_overlay`. Details: folder README.
