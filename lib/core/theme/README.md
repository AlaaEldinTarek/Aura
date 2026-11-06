# Core Theme Blueprint

## System Overview
Material 3 theme data, typography and spacing tokens (3 files, flat, no I/O). `main.dart` picks `AppTheme.lightTheme`,
`darkTheme`, `amoledTheme`, or a dynamic-color theme built from the system `ColorScheme`. Many widgets read colors from
`AppConstants` (`lib/core/constants/app_constants.dart`) instead of `Theme.of(context)`. The two token sets are
**independent copies**, not one source — findings F29. UI conventions: `.project-docs/modules/ui-kit.md`.
Behavior-preserving rule: no visual changes without an approved spec.

## Local Interface & Invariants

### Interface
| File | Public API |
| --- | --- |
| `app_theme.dart` | `AppTheme` (static): `lightTheme`, `darkTheme`, `amoledTheme`, `buildDynamicLightTheme(ColorScheme)`, `buildDynamicDarkTheme(ColorScheme)`; palette consts (`primary`, `primaryDark`, surface / background / outline per light / dark / AMOLED, `success`, `warning`, `error`); `primaryFont`, `arabicFont` |
| `app_typography.dart` | `AppTypography` (static `TextStyle`s): `displayL`, `displayM`, `headingL`, `headingM`, `headingS`, `bodyL`, `bodyM`, `bodyS`, `label`, `labelS`, `caption`; `ar(style)` |
| `app_spacing.dart` | `AppSpacing`: `xs` 4, `sm` 8, `md` 12, `base` 16, `lg` 20, `xl` 24, `xxl` 32, `xxxl` 48; aliases `screenH`, `screenV`, `cardPadding`, `sectionGap`, `itemGap`, `labelGap`, `iconMd`, `iconLg` |

### Invariants
- **Brand gold**: light `primary` = `#B5821B`; dark / AMOLED `colorScheme.primary` = `#F5B301` (`AppTheme.primaryDark`).
  `AppConstants.getPrimary(isDark)` returns the same pair (comment: "matches native widgets"). Native widgets use
  the same colors, so keep all three in sync.
- **Current dark look**: in `darkTheme` / `amoledTheme`, the FAB, `ElevatedButton`, input focus border and `secondary` use the
  light `primary` `#B5821B` (not `#F5B301`). Preserve this unless a spec changes it (findings F29).
- **Material 3** everywhere (`useMaterial3: true`). AMOLED = pure black background / surface, card `#111111`.
- **Dynamic color**: only through the `build*Dynamic*Theme` builders with a scheme supplied by the caller (`main.dart`); those
  themes set **no** `textTheme` (default Material typography). The `dynamic_color` pref is read outside this folder.
- **Typography**: English `Roboto`, Arabic `Cairo`. The theme never switches font by locale; Arabic needs an explicit
  `AppTypography.ar(style)` (Cairo, line height +0.2). Styles carry no color (applied via theme / `copyWith`).
  `caption` is not mapped into `textTheme`.
- **Shapes**: card radius 16, button / input radius 12 are hardcoded in `AppTheme` (no shared tokens).
- **Spacing**: `AppSpacing` doc says "always use these values"; `AppConstants` carries a parallel scale (`gap4`,
  `paddingSmall`, …) with the same numbers.

### Side Effects
- None (pure constants and `ThemeData` builders).

## Subdirectories & System Boundaries
- None (flat directory).

## Global Invariants
- Colors here, in `AppConstants`, and in the Kotlin widget / notification resources must change together (brand
  identity `#F5B301` / `#B5821B`).

## Global Side Effects
- None.

## System Verification
- Run: `flutter test` (no theme tests); visual checks: device-checklist S13 (widgets light / dark), S21 (Arabic / RTL).
