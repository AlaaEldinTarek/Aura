# Work Queue — Aura

> Read this file at the start of every session after `/clear`.
> Check off items with `[x]` as they are done.

---

## Phase 1 — PR #140 device checks + merge

- [ ] S-F52d-1 — suppress post-Isha full reload (PR #137)
- [ ] S-F51n-1 — Arabic-Indic digits in iqama countdown
- [ ] S-F51n-2 — Arabic-Indic digits in iqama countdown (run 2)
- [x] S-F52i-1 — Arabic-Indic in azkar counter / progress (PASS nova 5T 2026-11-28)
- [x] S-F51p-1 — monochrome ic_notification in AzkarAlarmReceiver + FocusModeService (PASS nova 5T 2026-11-28)
- [ ] S-F51m-1 — FocusMode restores pre-Focus DND filter + ringer mode
- [x] S-F51m-2 — FocusMode device check run 2 (PASS nova 5T 2026-11-28)
- [x] S-F51m-3 — FocusMode device check run 3 (PASS nova 5T 2026-11-28)
- [x] Merge PR #140 (fix/d3-d4-to-main)

---

## Blocked checks (need live prayer / special conditions)

- [ ] S-F34c-1 — untracked-prayer sheet appears on resume
- [ ] S-F34c-2 — no sheet when all prayers tracked
- [ ] S67 — F34a swipe guard (requires signed-in account)
- [ ] S60 — F51eghkl (requires live prayer timing)
- [ ] S65 — F52bc (requires live prayer notification)

---

## Phase 2 — MEDIUM fixes

- [ ] F51f — adhan beats Focus Mode (pending S28)
- [x] F48a — Qibla accuracy (P1 + P2 vibration merged via PR #142, eb5b789, 2026-11-28; device-checked)
- [ ] F48f — Qibla accuracy part 2 (pending S24)
- [ ] F43a — confirm intent first
- [ ] F51o — spec merged (PR #147, docs/designs/fix-f51o.md); waiting on 3 owner decisions

---

## Phase 3 — P2 fixes

- [ ] F34d — spec merged with F48c (PR #148, docs/designs/fix-f34d-f48c.md); waiting on 2 owner decisions
- [ ] F48c — same spec as F34d
- [ ] F51r — spec merged (PR #149, docs/designs/fix-f51r.md); waiting on 3 scope decisions

---

## Phase 4 — P3 fixes

- [x] F30f — focus-resume refresh (PR #151, 6ad7e8f, 2026-11-28; device-checked on nova 5T)
- [ ] F47g — Firestore usage (measure first)
- [ ] F49f — duplicate enums: bug fixed by FX-0 (2026-11-08); the duplicates remain, structural cleanup for refactor phase P3 (not a fix)
- [x] F52p — already fixed: both engines map `proportional` to MWL since f9f23ad (2026-11-08); verified in source only

---

## Phase 5 — P6 cleanup (low priority)

- [ ] F9
- [ ] F16 (if S19 passes)
- [ ] F18
- [ ] F23
- [ ] F28
- [ ] F32e
- [ ] F40c
- [ ] F41d
- [ ] F42d
- [ ] F45c
- [ ] F46c
- [ ] F47e
- [ ] F50a
- [ ] F51q
- [ ] F52o

---

## Deferred / follow-ups

- [ ] fix/adhan-stop — keep tray "Stop Adhan" until playback ends + diagnose 30 s timeout
- [ ] Remove tray_quit_log.txt temp file (after owner go-ahead)
- [ ] Play Store upload — one final release after all edits done (new version + build > 60)
- [ ] F55 pin-tasks — parked until feature work starts (branch wip/crazy-haibt-tasks deleted 2026-11-28, last commit e4b1d5c)
