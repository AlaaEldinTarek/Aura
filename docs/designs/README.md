# Designs
EGM specs (checked in, living). Master spec: `aura-refactor.md` (Step 4). Phase specs: `aura-refactor-pN-<name>.md` (P3, P5).

Fix-track specs (ADR 0001):
- `fx-0-prayer-settings.md` — FX-0: correct method / madhab, per-date times, full refresh, Kotlin adhan port, calculation
  dialog (A-1). Approved 2026-11-07, amended A-1 2026-11-08; implemented on `fix/fx-0-prayer-settings` (2026-11-08).
  Decision record: `fx-0-decisions.md`.
- `tray-quit-fix.md` — Windows tray "Quit" does not close the app (reported 2026-11-16; cause UNKNOWN). Draft, not
  approved. T1 (spec) done on `docs/tray-quit-spec`; T2 (code) and T3 (owner's check) not started.

Feature specs:
- `wird-marker.md` — Wird marker: one saved page and color per cycle replaces bookmark counting in Wird page mode. ADR 0002. Phases P2 to P6 done (PRs #25 and #27 merged, P6 docs on `docs/p6-and-state`); the two-device sync check and the permissions-page hint were reported pass by Aladdin on 2026-11-15 (method not recorded); S48 to S50 and the Windows build are not run.
